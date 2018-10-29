#define PI 3.141592653
#define SEA_HEIGHT 0.6
#define SEA_FREQ 0.16
#define SEA_CHOPPY 4.0
#define ITER_GEOMETRY 5
#define SEA_SPEED 0.8
#define SEA_TIME (1.0+_Time.y*SEA_SPEED)
float _SpecPow,_DiffPow,_RelativeHeightMin,_DistFactor,_WaterAlpha,SEA_LIGHT_ATTEN,_SpecAtten,_SpecFact;
float4 _SeaBase,_SeaWaterColor;

float3x3 Eular(float3 ang)
{
    float2 a1=float2(sin(ang.x),cos(ang.x));
    float2 a2=float2(sin(ang.y),cos(ang.y));
    float2 a3=float2(sin(ang.z),cos(ang.z));
    float3 x=float3(a1.y*a3.y+a1.x*a2.x*a3.x,a1.y*a2.x*a3.x+a3.y*a1.x,-a2.y*a3.x);
    float3 y=float3(-a2.y*a1.x,a1.y*a2.y,a2.x);
    float3 z=float3(a3.y*a1.x*a2.x+a1.y*a3.x,a1.x*a3.x-a1.y*a3.y*a2.x,a2.y*a3.y);
    return float3x3(x,y,z);
}
float hash(float2 p)
{
    float h=dot(p,float2(127.1,311.7));
    return frac(sin(h)*43758.5453123);
}
float noise(in float2 p)
{
    float2 i=floor(p);
    float2 f=frac(p);
    float2 u=f*f*(3.0-2.0*f);
    return -1.0+2.0*lerp(
        lerp(hash(i+float2(0,0)),hash(i+float2(1.0,0.0)),u.x),
        lerp(hash(i+float2(0.0,1.0)),hash(i+float2(1.0,1.0)),u.x),
        u.y);
}
float sea_octave(half2 uv,float choppy)
{
    uv+=noise(uv);
    float2 wv=1.0-abs(sin(uv));
    float2 swv=abs(cos(uv));
    wv=lerp(wv,swv,wv);
    return pow(1.0-pow(wv.x*wv.y,0.65),choppy);
}
float map(float3 p)
{
    float freq=SEA_FREQ;
    float amp=SEA_HEIGHT;
    float choppy=SEA_CHOPPY;
    float2 uv=p.xz;uv.x*=0.75;
    float d,h=0.0;
    for(int i=0;i<ITER_GEOMETRY;i++)
    {
        d=sea_octave((uv+SEA_TIME)*freq,choppy);
        d+=sea_octave((uv-SEA_TIME)*freq,choppy);
        h+=d*amp;
        uv=mul(float2x2(1.6,1.2,-1.2,1.6),uv);
        freq*=1.9;
        amp*=0.22;
        choppy=lerp(choppy,1.0,0.2);
    }
    return p.y-h;
}
float3 getNormal(float3 p,float eps)
{
    float3 n;
    n.y=map(p);
    n.x=map(float3(p.x+eps,p.y,p.z))-n.y;
    n.z=map(float3(p.x,p.y,p.z+eps))-n.y;
    n.y=eps;
    return normalize(n);
}

inline float WorldPostionToLinearDepth(float3 wpos)
{
    float3 camPos=mul(unity_WorldToCamera,float4(wpos,1)).xyz;
    float d=(camPos.z-_ProjectionParams.y)/(_ProjectionParams.z - _ProjectionParams.y);
    return d;
}
inline float WorldPostionToLinearEyeDepth(float3 wpos)
{
    float3 camPos=mul(unity_WorldToCamera,float4(wpos,1)).xyz;
    float d=(camPos.z-_ProjectionParams.y)/(_ProjectionParams.z - _ProjectionParams.y);
    d=d/_ProjectionParams.w;
    return d;
}
float diffuse(float3 n,float3 l,float p)
{
    return pow(dot(n,l)*0.4+0.6,p);
}
float specular(float3 n,float3 l,float3 e,float s)
{
    float nrm=(s+_SpecAtten)/(PI*_SpecFact);
    return pow(max(dot(reflect(e,n),l),0.0),s)*nrm;
}
fixed3 SkyColor(float3 e,fixed3 reflC,float fresnel)
{
    e.y=max(e.y,0.0);
    fixed3 env=fixed3(pow(1.0-e.y,2.0),1.0-e.y,0.6+0.4*(1.0-e.y));
    env=lerp(env,reflC,fresnel);
    return env;
}
fixed3 SkyColorNoReflC(float3 e)
{
    e.y=saturate(e.y);
    return float3(clamp(1.0-e.y,0,0.9),clamp(1.0-e.y,0,0.9),0.7+(1.0-e.y)*0.4);
}
fixed3 SeaColorNoRef(float3 p,float3 n,float3 l,float3 eye,float3 ofs,float a)
{
    float fresnel = clamp(1.0 - dot(n,eye), 0.0, 1.0);
    fresnel = pow(fresnel,3.0) * 0.65;
    fixed3 reflected=SkyColorNoReflC(reflect(-eye,n));
    fixed3 refract=_SeaBase+diffuse(n,l,_DiffPow)*_SeaWaterColor*0.15;
    fixed3 color=lerp(refract,reflected,fresnel);
    float lumiance=Luminance(color);
    lumiance=smoothstep(0,0.3,lumiance);
    //a=lerp(a,1,lumiance);
    float atten=max(1.0-dot(ofs,ofs)*_DistFactor,0);
    color+=_SeaWaterColor*(p.y-_RelativeHeightMin)*0.18*atten;
    color+=specular(n,l,-eye,_SpecPow);
    return color*a;
}
fixed3 SeaColorNoSpec(float3 p,float3 n,float3 l,float3 eye,float3 ofs,fixed3 reflC,fixed3 refrC,float relDepth,float a)
{
    float fresnel = clamp(1.0 - dot(n,eye), 0.0, 1.0);
    fresnel = pow(fresnel,3.0) * 0.65;
    fixed3 reflected=SkyColor(reflect(-eye,n),reflC,fresnel);
    fixed3 refract=_SeaBase+diffuse(n,l,_DiffPow)*_SeaWaterColor*0.15;
    #if defined(_REFRACTION)
    refract=lerp(refrC,refract,saturate(relDepth*_WaterAlpha));
    #endif
    fixed3 color=lerp(refract,reflected,fresnel);
    float lumiance=Luminance(color);
    lumiance=smoothstep(0,0.5,lumiance);
    a=lerp(a,1,lumiance);
    float atten=max(1.0-dot(ofs,ofs)*_DistFactor,0);
    color+=_SeaWaterColor*(p.y-_RelativeHeightMin)*0.18*atten;
    return color*a;
}
fixed3 SeaColor(float3 p,float3 n,float3 l,float3 eye,float3 ofs,fixed3 reflC,fixed3 refrC,float relDepth,float a)
{
    float fresnel = clamp(1.0 - dot(n,eye), 0.0, 1.0);
    fresnel = pow(fresnel,3.0) * 0.65;
    fixed3 reflected=SkyColor(reflect(-eye,n),reflC,0.8);
    fixed3 refract=_SeaBase+diffuse(n,l,80)*_SeaWaterColor*0.12;
    #if defined(_REFRACTION)
    refract=lerp(refrC,refract,saturate(relDepth*_WaterAlpha));
    #endif
    fixed3 color=lerp(refract,reflected,fresnel);
    float lumiance=Luminance(color);
    lumiance=smoothstep(0,0.5,lumiance);
    a=lerp(a,1,lumiance);
    float atten=max(1.0-dot(ofs,ofs)*_DistFactor,0);
    float relativeDst=(p.y-_RelativeHeightMin);
    color+=(_SeaWaterColor*relativeDst*SEA_LIGHT_ATTEN*atten);
    //color=lerp(color,reflC,fresnel);
    color+=specular(n,l,-eye,_SpecPow);
    return color;
}
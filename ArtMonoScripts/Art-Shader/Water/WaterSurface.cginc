#define PI 3.141592653
float _SpecPow,_DiffPow,_RelativeHeightMin,_DistFactor,_WaterAlpha;
float4 _SeaBase,_SeaWaterColor;
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
    float nrm=(s+8.0)/(PI*8.0);
    return pow(max(dot(reflect(e,n),l),0.0),s)*nrm;
}
fixed3 SkyColor(float3 e,float a,fixed3 reflC)
{
    e.y=saturate(e.y);
    return (reflC+ a*float3(clamp(pow(1.0-e.y,2),0,0.9),clamp(1.0-e.y,0,0.9),0.7+(1.0-e.y)*0.4))/2;
}

fixed3 SeaColor(float3 p,float3 n,float3 l,float3 eye,float3 ofs,fixed3 reflC,fixed3 refrC,float relDepth,float a)
{
    float fresnel = clamp(1.0 - dot(n,eye), 0.0, 1.0);
    fresnel = pow(fresnel,3.0) * 0.65;
    fixed3 reflected=SkyColor(reflect(-eye,n),a,reflC);
    fixed3 refract=_SeaBase+diffuse(n,l,_DiffPow)*_SeaWaterColor*0.15*a;
    #if defined(_REFRACTION)
    refract=lerp(refrC,refract,saturate(relDepth*_WaterAlpha));
    #endif
    fixed3 color=lerp(refract,reflected,fresnel);
    float atten=max(1.0-dot(ofs,ofs)*_DistFactor,0);
    color+=_SeaWaterColor*(p.y-_RelativeHeightMin)*0.18*atten;
    color+=specular(n,l,-eye,_SpecPow)*a;
    return color;
}
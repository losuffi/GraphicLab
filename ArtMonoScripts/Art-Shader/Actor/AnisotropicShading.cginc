#include "UnityCG.cginc"
#include "UnityStandardCore.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
//#include "UnityStandardBRDF.cginc"
sampler2D _JitterMap;
sampler2D _EmissionTex;
float _exp;
float _Specstrength,_AnisotropicWithDiffuse;
float _Stanstrength;
float offset,_ShiftScale,_ColPow;
float4 _JitterMap_ST,_AnisotropicSpecularColor,_AnisotropicDiffColor;
fixed4 _EmissionCol,_ShadowCol;
inline float activation(float input)
{
    return 1/(1+exp(-input));
}


inline half4 BRDF3_Unity_PBS_Anisotropic (half4 oriCol, half3 n,half3 diffColor, half3 specColor, half oneMinusReflectivity,
 float3 T,
 half smoothness, float3 viewDir,
    UnityLight light, UnityIndirect gi)
{
    float3 L=light.dir;
    half onl=saturate(dot(n,L));
    half nv = sqrt(1-dot(T,viewDir)*dot(T,viewDir));
    float3 H=normalize(L+viewDir);
    half TH=dot(T,H);
    half nH=sqrt(1-TH*TH);
    half at=smoothstep(-1,0,TH);
    nH=at*pow(nH,_exp);
    fixed3 specC=nH*_AnisotropicSpecularColor;
    oriCol=_ShadowCol+oriCol*(1-_ShadowCol);
    half3 color=specC*(_AnisotropicWithDiffuse*onl + (1-_AnisotropicWithDiffuse)) *_Specstrength;
    return half4((color+oriCol*_Stanstrength), 1);
}
fixed4 AnisotropicMetallicPBRRender(float4 tex,float3 originNormal,float3 worldTangent,float3 worldPos,float3 eyeVec,float atten)
{
    FragmentCommonData s=MetallicSetup(tex);
    float alpha=Alpha(tex.xy);
    clip(alpha-_Cutoff);
    s.normalWorld=originNormal;
    s.eyeVec=eyeVec;
    s.posWorld=worldPos;
    s.diffColor=PreMultiplyAlpha(s.diffColor,alpha,s.oneMinusReflectivity,s.alpha);
    UnityLight mainLight=MainLight();

    float4 ambientOrLightmapUV;
    ambientOrLightmapUV.rgb = Shade4PointLights (
    unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
    unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
    unity_4LightAtten0, worldPos, originNormal);

    half occlusion=Occlusion(tex.xy);
    UnityGI gi=FragmentGI(s,occlusion,ambientOrLightmapUV,atten,mainLight);
    
    //Jitter
    float4 uv=tex;
    uv=float4(TRANSFORM_TEX(uv,_JitterMap),0,0);;
    half shift=tex2D(_JitterMap,uv.xy).g*_ShiftScale;
    worldTangent=normalize(worldTangent+shift*originNormal);
    float4 col= UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
    float4 c=BRDF3_Unity_PBS_Anisotropic (col,s.normalWorld,s.diffColor, s.specColor, s.oneMinusReflectivity, worldTangent, s.smoothness, -s.eyeVec, gi.light, gi.indirect);
    //c.rgb+=Emission(tex.xy);
    c.rgb+=tex2D(_EmissionTex,tex).rgb*_EmissionCol.rgb;
    c.a=alpha;
   // c.rgb=lerp(_ShadowCol.rgb,c.rgb,l);// c.rgb*(1-_ShadowCol.rgb);
    c.rgb=pow(c.rgb,_ColPow);
    return OutputForward(c,s.alpha);
}

float3x3 CreateTangentToWorldAniso(float3 worldLightDir,float3 worldTangent,float dir)
{
    dir= dir * unity_WorldTransformParams.w;
    float3 binormal=cross(worldLightDir,worldTangent)*dir;
    float3 normal=normalize(cross(worldTangent,binormal));
    return float3x3(worldTangent,binormal,normal);
}
#include "UnityCG.cginc"
#include "UnityStandardCore.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
//#include "UnityStandardBRDF.cginc"
sampler2D _JitterMap,_FlowMap;
sampler2D _EmissionTex;
float _exp;
float _Specstrength,_AnisotropicWithDiffuse,_Diffstrength;
float _Stanstrength;
float offset,_ShiftScale,_ColPow;
float4 _JitterMap_ST,_AnisotropicSpecularColor,_AnisotropicDiffColor;
fixed4 _EmissionCol,_ShadowCol;
float4 _rimParams;
inline float activation(float input)
{
    return 1/(1+exp(-input));
}

inline float3 FlowDir(float3 tangent,float3 biTangent,float4 tex)
{
    float2 pic=tex2D(_FlowMap,tex.xy).ra;
    float theta=pic.x*pic.y;
    float3 dir=tangent*cos(theta)+biTangent*sin(theta);
    return dir;
}

inline half4 BRDF3_Unity_PBS_Anisotropic (half3 olcolor,half4 oriCol, half3 n,half3 diffColor, half3 specColor, half oneMinusReflectivity,
 float3 T,
 half smoothness, float3 viewDir,
    UnityLight light, UnityIndirect gi)
{
    float3 L=light.dir;
    half nl=saturate(sqrt(1-dot(n,L)*dot(n,L)));
    half nv = saturate(sqrt(1-dot(T,viewDir)*dot(T,viewDir)));
    float3 H=Unity_SafeNormalize (float3(light.dir) + viewDir);
    half TH=dot(T,H);
    half nH=sqrt(1-TH*TH);
    half lh = saturate(dot(light.dir, H));
    //half at=smoothstep(-1,0,TH);
    nH=pow(nH,_exp);
    
    float perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
    half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
#if UNITY_BRDF_GGX
    // GGX with roughtness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughtness remapping.
    roughness = max(roughness, 0.002);
    half V = SmithJointGGXVisibilityTerm (nl, nv, roughness);
    float D = GGXTerm (nH, roughness);
#else
    // Legacy
    half V = SmithBeckmannVisibilityTerm (nl, nv, roughness);
    half D = NDFBlinnPhongNormalizedTerm (nH, PerceptualRoughnessToSpecPower(perceptualRoughness));
#endif

    half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later

#   ifdef UNITY_COLORSPACE_GAMMA
        specularTerm = sqrt(max(1e-4h, specularTerm));
#   endif

    // specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    specularTerm = max(0, specularTerm * nl);
#if defined(_SPECULARHIGHLIGHTS_OFF)
    specularTerm = 0.0;
#endif

    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
    half surfaceReduction;
#   ifdef UNITY_COLORSPACE_GAMMA
        surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
#   else
        surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
#   endif

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(_AnisotropicSpecularColor) ? 1.0 : 0.0;



    half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));


    fixed3 specC=specularTerm*_AnisotropicSpecularColor*FresnelTerm (_AnisotropicSpecularColor, lh);
    specC+=surfaceReduction*gi.specular * FresnelLerp (_AnisotropicSpecularColor, grazingTerm, nv);
    oriCol=_ShadowCol+oriCol*(1-_ShadowCol);
    half3 difC=diffColor*(gi.diffuse+light.color*diffuseTerm);

    half rim=1-nv;
    rim=smoothstep(_rimParams.x,_rimParams.y,rim)*_rimParams.z*saturate(1.33-roughness);
    specC+= rim*saturate(nl)*((1-_rimParams.w)*olcolor+_rimParams.w*light.color);

    half3 color=specC*_Specstrength+_Diffstrength*difC;
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
    half3 lcolor=mainLight.color;
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
    float4 c=BRDF3_Unity_PBS_Anisotropic (lcolor,col,s.normalWorld,s.diffColor, s.specColor, s.oneMinusReflectivity, worldTangent, s.smoothness, -s.eyeVec, gi.light, gi.indirect);
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
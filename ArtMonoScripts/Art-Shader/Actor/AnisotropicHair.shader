Shader "ArtStandard/Actor/Hair"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _AnisotropicSpecularColor("Specular Color",Color)=(1,1,1,1)
        _AnisotropicDiffColor("Hair Wire Color",Color)=(1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
        _EmissionTex("Emission",2D)="black"{}
        _EmissionCol("Emission Color",Color)=(1,1,1,1)
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0

        _MetallicGlossMap("Metallic", 2D) = "black" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0
        [ToggleOff] _AnisotropicWithDiffuse("Aniso With Diff",Float) =1.0
        _ShiftScale("Shift Scale", Float) = 1.0
        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}
        _JitterMap("Jitter Map",2D) ="black" {}
        _ColPow("Color Pow",Range(0.1,2))=1
        _ShadowCol("Shadow Col",Color)=(0,0,0,1)
        _exp("Exponet",Range(10,200))=90
        _Specstrength("Spec Strength",Range(0,1))=0.5
        _Stanstrength("Standard Strength",Range(0,1))=0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 0 
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor("_SrcFactor",Float)=5
		[Enum(UnityEngine.Rendering.BlendMode)] _DstFactor("_DstFactor",Float)=10
        [ToggleOff] _ZWrite("_ZWrite",Float)=1
    }
    SubShader
    {
        Tags{"RenderType"="Opaque" "PerformanceChecks"="False"}
        Pass
        {
            Name "Forward"
            Tags {"LightMode"= "ForwardBase" }
            Blend[_SrcFactor] [_DstFactor]
            Cull[_Cull]
            ZWrite[_ZWrite]
            CGPROGRAM
            #pragma target 3.0
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _ _GLOSSYRELECTIONS_OFF
            #pragma shader_feature _FADEINBACKGROUND

            #pragma multi_compile_fwdbase 

            #pragma vertex vert
            #pragma fragment frag

            #include "../CustomForwardPBRCore.cginc"
            #include "AnisotropicShading.cginc"
            struct a2v
            {
                float4 vertex:POSITION;
                float4 tangent:TANGENT;
                float4 texcoord:TEXCOORD0;
                float3 normal:NORMAL;
            };
            struct Input
            {
                float4 pos:SV_POSITION;
                float4 uv:TEXCOORD0;
                float3 eyeVec:TEXCOORD1;
                float3 worldPos:TEXCOORD2;
                float4 tangentToWorld[3]:TEXCOORD3;
                SHADOW_COORDS(6)
            };
            Input vert(a2v v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                Input o;
                UNITY_INITIALIZE_OUTPUT(Input,o);
                o.pos=UnityObjectToClipPos(v.vertex);
                float4 pw=mul(unity_ObjectToWorld,v.vertex);
                o.worldPos=pw.xyz;
                o.eyeVec=normalize(pw-_WorldSpaceCameraPos);
                float4 tangentworld=float4(UnityObjectToWorldDir(v.tangent.xyz),v.tangent.w);
                float3 wn=UnityObjectToWorldNormal(v.normal);
                float3x3 tangentToWorld=CreateTangentToWorldPerVertex(wn,tangentworld.xyz,tangentworld.w);
                //float3x3 tangentToWorld=CreateTangentToWorldAniso(_WorldSpaceLightPos0,tangentworld.xyz,-tangentworld.w);
                o.tangentToWorld[0].xyz=tangentToWorld[0];
                o.tangentToWorld[0].w=tangentworld.w;
                o.tangentToWorld[1].xyz=tangentToWorld[1];
                o.tangentToWorld[2].xyz=tangentToWorld[2];
                TRANSFER_SHADOW(o);
                o.uv=v.texcoord;
                return o;
            }
            fixed4 frag(Input i):SV_Target
            {
                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);
                float3 worldNormal=PerPixelWN(i.uv,i.tangentToWorld);
                //return fixed4(i.tangentToWorld[2].xyz,1);
                half dir=i.tangentToWorld[0].w;
                //float3 T=normalize(i.tangentToWorld[0].xyz)*dir;
                float3 T=i.tangentToWorld[0].xyz;
               // return fixed4( (T+1)/2,1);
                // float3 Y=normalize(i.tangentToWorld[1].xyz);
                // T= FlowMapModifyDir(T,Y,i.uv.xy);
                // #if defined(SHADOWS_SCREEN)
                UNITY_LIGHT_ATTENUATION(atten,i,i.worldPos);
                // #else
                // float atten=1;
                // #endif
                //return fixed4(T,1);
                return AnisotropicMetallicPBRRender(i.uv,worldNormal,T,i.worldPos,i.eyeVec,atten);
            }
            ENDCG
        }
    }
    FallBack "VertexLit"
    CustomEditor "PBREditorGUI"
}
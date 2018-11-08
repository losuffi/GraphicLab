Shader "ArtStandard/Standard/Forward"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0

        _MetallicGlossMap("Metallic", 2D) = "black" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}
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

            #include "Bin/CustomForwardPBRCore.cginc"
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
                float3x3 tangentToWorld=CreateTangentToWorldPerVertex(wn,tangentworld.xyz,-tangentworld.w);
                o.tangentToWorld[0].xyz=tangentToWorld[0];
                o.tangentToWorld[1].xyz=tangentToWorld[1];
                o.tangentToWorld[2].xyz=tangentToWorld[2];
                TRANSFER_SHADOW(o);
                o.uv=float4(TRANSFORM_TEX(v.texcoord,_MainTex),0,0);
                return o;
            }
            fixed4 frag(Input i):SV_Target
            {
                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);
                float3 worldNormal=PerPixelWN(i.uv,i.tangentToWorld);
                
                UNITY_LIGHT_ATTENUATION(atten,i,i.worldPos);

                float3 binormal=i.tangentToWorld[1].xyz;
                float f=1-abs(dot(binormal,i.eyeVec));

                //return fixed4(f,0,0,1);
                return MetallicPBRRender(i.uv,worldNormal,i.worldPos,i.eyeVec,atten,pow(f,2));
            }
            ENDCG
        }
    }
    FallBack "VertexLit"
    CustomEditor "PBREditorGUI"
}
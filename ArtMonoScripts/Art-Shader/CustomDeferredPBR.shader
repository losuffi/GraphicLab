Shader "Lyf/PBR/Deffered"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DetailMask("Detail Mask", 2D) = "white" {}

        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        _DetailNormalMap("Normal Map", 2D) = "bump" {}

        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0


        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
        
    }
    CGINCLUDE
        #define UNITY_SETUP_BRDF_INPUT MetallicSetup
    ENDCG
    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 300
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt


            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature ___ _DETAIL_MULX2
            #pragma shader_feature _PARALLAXMAP

            #pragma multi_compile_prepassfinal
            #pragma multi_compile_instancing

            #pragma vertex vertDeferred
            #pragma fragment frag

            #include "UnityStandardCore.cginc"

            void frag(
                VertexOutputDeferred i,
                out half4 outGBuffer0 : SV_Target0,
                out half4 outGBuffer1 : SV_Target1,
                out half4 outGBuffer2 : SV_Target2,
                out half4 outEmission : SV_Target3          // RT3: emission (rgb), --unused-- (a)
            #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
                ,out half4 outShadowMask : SV_Target4       // RT4: shadowmask (rgba)
            #endif
            )
            {   
                
                    #if (SHADER_TARGET < 30)
                outGBuffer0 = 1;
                outGBuffer1 = 1;
                outGBuffer2 = 0;
                outEmission = 0;
                #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
                    outShadowMask = 1;
                #endif
                return;
                #endif

                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

                FRAGMENT_SETUP(s)
                UNITY_SETUP_INSTANCE_ID(i);

                // no analytic lights in this pass
                UnityLight dummyLight = DummyLight ();
                half atten = 1;

                // only GI
                half occlusion = Occlusion(i.tex.xy);
            #if UNITY_ENABLE_REFLECTION_BUFFERS
                bool sampleReflectionsInDeferred = false;
            #else
                bool sampleReflectionsInDeferred = true;
            #endif

                UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, dummyLight, sampleReflectionsInDeferred);

                half3 emissiveColor = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect).rgb;

                #ifdef _EMISSION
                    emissiveColor += Emission (i.tex.xy);
                #endif

                #ifndef UNITY_HDR_ON
                    emissiveColor.rgb = exp2(-emissiveColor.rgb);
                #endif

                UnityStandardData data;
                data.diffuseColor   = s.diffColor;
                data.occlusion      = occlusion;
                data.specularColor  = s.specColor;
                data.smoothness     = s.smoothness;
                data.normalWorld    = s.normalWorld;

                

                UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

                // Emissive lighting buffer
                outEmission = half4(emissiveColor, 1);

                // Baked direct lighting occlusion if any
                #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
                    outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, IN_WORLDPOS(i));
                #endif
            }
            ENDCG
        }
    }

    FallBack "VertexLit"
    CustomEditor "StandardShaderGUI"
}
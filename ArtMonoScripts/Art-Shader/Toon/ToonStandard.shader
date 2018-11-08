Shader "ArtStandard/Toon/Object/Standard"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0
        _MetallicGlossMap("Metallic", 2D) = "black" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0
        [ToggleOff] _WithRamp("With Ramp", Float) = 0.0
        [ToggleOff] _WithFresnel("With Fresnel Line", Float) = 0.0
        [ToggleOff] _WithOutLine("With Out Line", Float) = 0.0
        _SpecScale("Specular Scale",Float)=1.0
        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}
        _RampMap("Ramp Map",2D)="white"{}

        _shadowCol("Shadow Col",Color)=(0,0,0,1)
        _lightCol("Light Col",Color)=(1,1,1,1)

        _LineColor("Line Color",Color)=(1,1,1,1)
        _EdgeWidth("Edge Width",Range(0.1,10))=1
        _EdgeClamp("Edge Clamp",Range(0,1))=0
        _LineDistMax("Line Dist Max",Float)=20

        _rimParams("Rim Params",Vector)=(0,1,5,1)

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "white" {}

        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 0 
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor("_SrcFactor",Float)=1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstFactor("_DstFactor",Float)=0
        [ToggleOff] _ZWrite("_ZWrite",Float)=1
    }
    CGINCLUDE
        #define UNITY_SETUP_BRDF_INPUT MetallicSetup
        #define _EMISSION
    ENDCG
    SubShader
    {
        Pass
        {
            Name "FORWARD"
            Tags{"LightMode"="ForwardBase"}
            Blend[_SrcFactor] [_DstFactor]
            Cull[_Cull]
            ZWrite[_ZWrite]
            CGPROGRAM
            #include "ToonStandardCore.cginc"
            #include "../Bin/CustomForwardPBRCore.cginc"
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _ _GLOSSYRELECTIONS_OFF
            #pragma shader_feature _FADEINBACKGROUND

            #pragma multi_compile_fwdbase
            VertexOutputForwardBase vert(VertexInput v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                VertexOutputForwardBase o;
                UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBase, o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
                #if UNITY_REQUIRE_FRAG_WORLDPOS
                    #if UNITY_PACK_WORLDPOS_WITH_TANGENT
                        o.tangentToWorldAndPackedData[0].w = posWorld.x;
                        o.tangentToWorldAndPackedData[1].w = posWorld.y;
                        o.tangentToWorldAndPackedData[2].w = posWorld.z;
                    #else
                        o.posWorld = posWorld.xyz;
                    #endif
                #endif
                o.pos = UnityObjectToClipPos(v.vertex);

                o.tex = TexCoords(v);
                o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
                float3 normalWorld = UnityObjectToWorldNormal(v.normal);
                #ifdef _TANGENT_TO_WORLD
                    float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

                    float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
                    o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
                    o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
                    o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
                #else
                    o.tangentToWorldAndPackedData[0].xyz = 0;
                    o.tangentToWorldAndPackedData[1].xyz = 0;
                    o.tangentToWorldAndPackedData[2].xyz = normalWorld;
                #endif

                //We need this for shadow receving
                UNITY_TRANSFER_SHADOW(o, v.uv1);

                o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);

                #ifdef _PARALLAXMAP
                    TANGENT_SPACE_ROTATION;
                    half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
                    o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
                    o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
                    o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
                #endif

                UNITY_TRANSFER_FOG(o,o.pos);
                return o;
            }
            fixed4 frag(VertexOutputForwardBase i):SV_Target
            {
                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);
                FRAGMENT_SETUP(s)
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                UnityLight mainLight=MainLight();
                half3 oriLight= mainLight.color;
                UNITY_LIGHT_ATTENUATION(atten,i,s.posWorld);
                half occlusion = Occlusion(i.tex.xy);
                UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);

                half4 c = UNITY_Toon_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect,atten,oriLight);
                c.rgb += Emission(i.tex.xy);
                UNITY_APPLY_FOG(i.fogCoord, c.rgb);
                return OutputForward (c, s.alpha);
            }
            ENDCG
        }
        Pass
        {
            Name "Outline"
            Cull Front
            CGPROGRAM
            #include "../Bin/CustomForwardPBRCore.cginc"
            #pragma vertex vert
            #pragma fragment frag
            float _WithOutLine,_LineDistMax;
            float _EdgeClamp,_EdgeWidth;
            fixed4 _LineColor;
            struct lineinput
            {
                float4 pos:SV_POSITION;
                float4 wpos:TEXCOORD0;
            };
            lineinput vert(a2v v)
            {
                lineinput o;
                float4 pos=mul(unity_ObjectToWorld,v.vertex);
                o.wpos=pos;
                float3 normal=UnityObjectToWorldNormal(v.normal);
                normal.z=-0.5f;
                pos=pos+float4(normalize(normal),0)*_EdgeWidth*_EdgeClamp;
                pos=UnityObjectToClipPos(mul(unity_WorldToObject,pos));
                o.pos=pos;
                return o;
            }
            fixed4 frag(lineinput i):SV_Target
            {
                float3 dir=(_WorldSpaceCameraPos-i.wpos);
                _WithOutLine*=(1-step(_LineDistMax,length(dir)));
                clip(_WithOutLine-0.5);
                return fixed4(_LineColor.rgb,1);
            }
            ENDCG
        }
    }
    FallBack "Standard"
    CustomEditor "PBREditorGUI"
}
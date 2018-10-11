// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Artifact Shaders/Particle/Add"
{
	Properties
	{
		_TintColor ("Tint Color", Color) = (1,1,1,1)
		_MainTex ("Particle Texture", 2D) = "white" {}
		_InvFade ("Soft Particles Factor", Range(0.01,3)) = 1
		_ZOfs ("Z Offset", Float) = 0
		_Multiplier ("Multiplier", Float) = 1
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 0
	}

	Category
	{
		Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
		Blend SrcAlpha One
		AlphaTest Greater .01
		ColorMask RGB
		Cull[_Cull]
		Lighting Off ZWrite Off
		ZTest Off

		SubShader
		{
			Pass
			{
			
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_particles
				#pragma multi_compile_fog
				
				#include "UnityCG.cginc"

				sampler2D _MainTex;
				half _Multiplier;
				fixed4 _TintColor;

				uniform float _Global_Fade;

				struct appdata_t {
					float4 vertex : POSITION;
					fixed4 color : COLOR;
					float2 texcoord : TEXCOORD0;
				};

				struct v2f {
					float4 vertex : SV_POSITION;
					fixed4 color : COLOR;
					float2 texcoord : TEXCOORD0;
					UNITY_FOG_COORDS(1)
					#ifdef SOFTPARTICLES_ON
					float4 projPos : TEXCOORD2;
					#endif
				};
				
				float4 _MainTex_ST;

				v2f vert (appdata_t v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
					#ifdef SOFTPARTICLES_ON
					o.projPos = ComputeScreenPos (o.vertex);
					COMPUTE_EYEDEPTH(o.projPos.z);
					#endif
					o.color = v.color;
					o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
					UNITY_TRANSFER_FOG(o,o.vertex);
					return o;
				}

				sampler2D_float _CameraDepthTexture;
				float _InvFade;
				float _ZOfs;

				fixed4 frag (v2f i) : SV_Target
				{
					#ifdef SOFTPARTICLES_ON
					float sceneZ = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
					float partZ = i.projPos.z;
					float fade = saturate (_InvFade * (sceneZ + _ZOfs - partZ)) * saturate(_InvFade * partZ);
					clip(fade);
					i.color.a *= fade;
					#endif

					half4 tint = half4(_TintColor.rgb * _Multiplier, saturate(_TintColor.a));

					fixed4 col = i.color * tint * tex2D(_MainTex, i.texcoord);
					UNITY_APPLY_FOG(i.fogCoord, col);

					col.a *= _Global_Fade;
					return col;
				}
				ENDCG 
			}
		}	
	}
}

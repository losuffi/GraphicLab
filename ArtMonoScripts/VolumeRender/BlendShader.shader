Shader"Hidden/DownSampleBlend"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Pass
        {
            Name "BlendSrc"
            Tags {"LightMode" = "ForwardBase"}

            CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
			};

			sampler2D _MainTex;
			sampler2D ResultTex;
			float4 _MainTex_TexelSize;

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv.xy;
                return o;
            }
            fixed4 frag(v2f i):SV_Target
            {
                fixed4 back = tex2D(_MainTex, i.uv);
                fixed4 res = tex2D(ResultTex, i.uv);
                return fixed4(back.rgb * (1 - res.a) + res.rgb, 1.0);
            }
            ENDCG
        }
    }
}
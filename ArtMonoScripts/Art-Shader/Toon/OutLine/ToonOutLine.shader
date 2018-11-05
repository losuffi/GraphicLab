Shader"Lyf/Toon/Outline/Fresnel"
{
    Properties
    {
        _LineColor("Line Color",Color)=(1,1,1,1)
        _EdgeWidth("Edge Width",Range(0.1,10))=1
    }
    SubShader
    {
        Tags{
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            }
        Pass
        {
            Name "Forward"
            Tags {"LightMode" = "ForwardBase"}
            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag
            float4 _LineColor;
            float _EdgeWidth;
            struct v2f
            {
                float4 pos:SV_POSITION;
                float3 wPos:TEXCOORD0;
                float3 worldN:TEXCOORD1;
            };
            v2f vert(float4 v:POSITION,float4 n:NORMAL)
            {
                v2f o;
                o.pos= UnityObjectToClipPos(v);
                o.wPos=mul(unity_ObjectToWorld,v);
                o.worldN= UnityObjectToWorldNormal(n);
                return o;
            }
            fixed4 frag(v2f i):SV_Target
            {
                float3 viewDir=_WorldSpaceCameraPos.xyz-i.wPos;
                float nDotv=dot(normalize(viewDir),i.worldN);
                nDotv=saturate(nDotv);
                return fixed4(_LineColor.rgb,pow(1-nDotv,1/_EdgeWidth));
            }
            ENDCG
        }
        // Pass
        // {
        //     Name "Deferred"
        //     Tags{ "LightMode" = "Deferred"}
        //     CGPROGRAM
        //     ENDCG
        // }
    }
}
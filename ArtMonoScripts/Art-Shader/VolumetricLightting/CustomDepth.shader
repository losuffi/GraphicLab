Shader "Hidden/RayMarching"
{
    SubShader
    {
        Tags{"RenderType"="Opaque"}
        Pass
        {
            Fog{Mode Off}    
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct v2f
            {
                float4 pos:SV_POSITION;
                float depth:TEXCOORD0;
            };
            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                COMPUTE_EYEDEPTH(o.depth);
                o.depth=o.depth*_ProjectionParams.w;
                return o;
            }
            
            fixed frag(v2f i):SV_Target
            {
                return i.depth;
            }
            ENDCG
        }
    }
}
Shader "Test"
{
    Properties
    {
        _TessellationScale("Tessellation Scale",Range(0,1000))=8
    }
    SubShader
    {
        Tags {"LightMode"="ForwardBase" "Queue"="Transparent" "RenderType"="Opaque"}
        Pass
        {
            Name "FORWARD"
            Cull Off
            ZWrite On
		    //Tags { "LightMode" = "ForwardBase" }
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag  
            #pragma hull hs
            #pragma domain ds
            #pragma multi_compile_fwdbase
            //#pragma exclude_renderers nomrt
            #include "./Bin/Tessellation.cginc"

            float4 TessellationVertex(TVD v)
            {
                return UnityObjectToClipPos(v.vertex);
            }   

            [UNITY_domain("tri")]
            float4 ds(TessellationFactors factors,
                    OutputPatch<TVD,3> patch,
                    float3 barycentricCoordinates:SV_DomainLocation):SV_POSITION
            {
                TVD data;
                DS_PROGRAM_INTERPOLATE(vertex)
                DS_PROGRAM_INTERPOLATE(normal)
                DS_PROGRAM_INTERPOLATE(tangent)
                DS_PROGRAM_INTERPOLATE(uv)
                DS_PROGRAM_INTERPOLATE(uv1)
                DS_PROGRAM_INTERPOLATE(uv2)
                return TessellationVertex(data);
            }
            fixed4 frag():SV_Target
            {
                return half4(1,1,1,1);
            }
            ENDCG
        }
    }
    Fallback "VertexLit"
}
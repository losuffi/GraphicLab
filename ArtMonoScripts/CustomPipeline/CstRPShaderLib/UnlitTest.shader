Shader "CstRP/Unlit/Test"
{
    Properties
    {
        _Color("Color RGB",Color)=(1,1,1,1)
    }
    SubShader
    {
        Pass
        {
            Tags{"LightMode"="CstRP"}
            HLSLPROGRAM
            #pragma vertex CstRPVertex
            #pragma fragment CstRpFragment
            #pragma target 3.5
            #pragma multi_compile_instancing
            #include "Base.hlsl"
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
	            UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
            UnlitVertexOutput CstRPVertex(UnlitVertexInput i)
            {
                UnlitVertexOutput o;
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_TRANSFER_INSTANCE_ID(i, o);
                float4 wpos=mul(UNITY_MATRIX_M,i.pos);
                o.clipPos=mul(unity_MatrixVP,wpos);
                return o;
            }
            float4 CstRpFragment(UnlitVertexOutput i):SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
            }
            ENDHLSL
        }
    }
}
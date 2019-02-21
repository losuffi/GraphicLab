#ifndef BASE
#define BASE
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
CBUFFER_START(UnityPerFrame)
    float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
CBUFFER_END

#define UNITY_MATRIX_M unity_ObjectToWorld
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
struct UnlitVertexInput
{
    float4 pos:POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct UnlitVertexOutput
{
    float4 clipPos:SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
#endif
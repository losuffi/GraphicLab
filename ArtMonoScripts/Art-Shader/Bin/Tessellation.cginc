#include "UnityCG.cginc"
float _TessellationScale;
#define DS_PROGRAM_INTERPOLATE(fieldName) data.fieldName=\
    patch[0].fieldName * barycentricCoordinates.x + \
    patch[1].fieldName * barycentricCoordinates.y + \
    patch[2].fieldName * barycentricCoordinates.z;


struct TVD
{
    float4 vertex:POSITION;
    float4 tangent:TANGENT;
    float4 texcoord:TEXCOORD0;
    float3 normal:NORMAL;
};

struct TessellationFactors
{
    float edge[3] :SV_TessFactor;
    float inside:SV_InsideTessFactor;
};

TVD vert(TVD a)
{
    return a;
}

float TessellationEdgeFactor(TVD tv1,TVD tv2)
{
    float3 p0=UnityObjectToViewPos(tv1.vertex);
    float3 p1=UnityObjectToViewPos(tv2.vertex);
    float edgeLength=distance(p0,p1);
    float3 center=(p0+p1)*0.5;
    float viewDistance=distance(center,_WorldSpaceCameraPos);
    return (_TessellationScale*1000000)/(viewDistance*viewDistance*viewDistance);
}

TessellationFactors hsCountFunc(InputPatch<TVD,3> patch)
{
    TessellationFactors f;
    // f.edge[0]=7;
    // f.edge[1]=7;
    // f.edge[2]=7;
    // f.inside=1;
    f.edge[0]=TessellationEdgeFactor(patch[1],patch[2]);
    f.edge[1]=TessellationEdgeFactor(patch[0],patch[2]);
    f.edge[2]=TessellationEdgeFactor(patch[0],patch[1]);
    f.inside=(f.edge[0] + f.edge[1] + f.edge[2]) * (1 / 3.0);;
    return f;
}
[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("integer")]
[UNITY_patchconstantfunc("hsCountFunc")]
TVD hs(InputPatch<TVD,3> patch,uint id:SV_OutputControlPointID)
{
    return patch[id];
}
// [UNITY_domain("tri")]
// v2f ds(TessellationFactors factors,
//         OutputPatch<TVD,3> patch,
//         float3 barycentricCoordinates:SV_DomainLocation)
// {
//     TVD data;
//     DS_PROGRAM_INTERPOLATE(vertex);
//     DS_PROGRAM_INTERPOLATE(tangent);
//     DS_PROGRAM_INTERPOLATE(texcoord);
//     DS_PROGRAM_INTERPOLATE(normal);
//     return TessellationVertex(data);
// }

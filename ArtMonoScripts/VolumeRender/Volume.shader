Shader "ArtStandard/Volume/Standard"
{
    Properties
    {
        _DensityLUT("Density LUT",2D) ="black"{}
        _ScatteringLUT("Scattering LUT",2D) ="black"{}
        _SampleRadiusScale("Radius Scale",Float) = 1
        _DensityLUTSize("Density LUT Size",Vector) = (32, 16, 32, 16)
        _ScatteringLUTSize("Scattering LUT Size",Vector) = (32, 16, 64 ,1)
        _ParticleDensity("Particle Density",Float) = 0.2
        _AttenuationCoff("Attenuation Coff",Float) = 0.001
        _EarthRadius("Ambient EarthRadius",Range(0,1)) = 0.7 
        _LightAttenuation("Light Attenuation",Vector) =(0.01,0.01,0,0)
        _CloudAmbientParams("Ambient Params",Vector) = (0.5, 0.6, 0 ,0)
        _fRayLen("RayLen",Float) = 1
    }
    SubShader
    {
        Pass
        {
            Name "ForwardBase"
            Tags {"LightMode" = "ForwardBase"}
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #define NUM_MAXSTEPS 64
            #include "Lighting.cginc"
            #include "UnityCG.cginc"
            #include "VolumePrecompute.cginc"
            #pragma vertex vert
            #pragma fragment frag

            float _fRayLen;
            sampler2D _src;
            sampler3D _3dTex;
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 eyeView:TEXCOORD0;
                float2 uv:TEXCOORD1;
            };

            inline float4 GetWorldPositionFromDepthValue( float2 uv, float linearDepth ) 
            {
                float camPosZ = _ProjectionParams.y + _ProjectionParams.z* linearDepth;
                float height = 2 * camPosZ / unity_CameraProjection[1][1];
                float width = _ScreenParams.x / _ScreenParams.y * height;
                float camPosX = width * uv.x - width / 2;
                float camPosY = height * uv.y - height / 2;
                float4 camPos = float4(camPosX, camPosY, camPosZ, 1.0);
                return mul(unity_CameraToWorld, camPos);
                //return camPos;
            }
            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.eyeView = float3(-1,-1,1);
                o.uv = v.texcoord;
                return o;
            }
            fixed4 frag(v2f o):SV_Target
            {
                float3 f3CurrPos = _WorldSpaceCameraPos.xyz;
                const float3 center = float3(0,0,10);
                const float radius = 2.0;
                float3 col = float3 (0, 0, 0);
                float3 ray = normalize(GetWorldPositionFromDepthValue(o.uv,0).xyz - _WorldSpaceCameraPos.xyz);
                for(int i = 1; i < NUM_MAXSTEPS; ++i)
                {
                    f3CurrPos += _fRayLen *ray;
                    float dist = length(f3CurrPos - center);
                    col += step(dist, radius) *0.05;
                }
                float4 res = tex2D(_src, o.uv);
                float4 oth = tex3D(_3dTex, float3(o.uv,0));
                //res = saturate(oth.r - 0.5 * (oth.g + oth.b + oth.a));
                res = pow(oth.r * (1 - oth.g) * (1 - oth.b) * (1 - oth.a) * 1.8,0.8);
                return res;
            }
            ENDCG
        }
    }
}
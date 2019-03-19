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
            #define NUM_MAXSTEPS 128
            #include "Lighting.cginc"
            #include "UnityCG.cginc"
            #include "VolumePrecompute.cginc"
            #pragma vertex vert
            #pragma fragment frag

            float _fRayLen;
            sampler2D _src;
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 eyeView:TEXCOORD0;
                float2 uv:TEXCOORD1;
            };

            inline float4 GetWorldPositionFromDepthValue( float2 uv, float linearDepth ) 
            {
                float camPosZ = _ProjectionParams.x + _ProjectionParams.y* linearDepth;
                float height = 2 * camPosZ / unity_CameraProjection[1][1];
                float width = _ScreenParams.x / _ScreenParams.y * height;
                float camPosX = width * uv.x - width / 2;
                float camPosY = height * uv.y - height / 2;
                float4 camPos = float4(camPosX, camPosY, -camPosZ, 1.0);
                return mul(unity_CameraToWorld, camPos);
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
                float3 f3CurrPos = float3(0, 0, 0);
                const float3 center = float3(0,5,10);
                const float radius = 20.0;
                float3 col = float3 (0, 0, 0);
                float3 ray = normalize(GetWorldPositionFromDepthValue(o.uv,0.2).xyz - _WorldSpaceCameraPos.xyz);
                for(int i = 1; i < NUM_MAXSTEPS; ++i)
                {
                    f3CurrPos += _fRayLen *ray;
                    float dist = length(f3CurrPos - center);
                    col.x += step(radius,dist)*0.5;
                }
                float4 res = tex2D(_src, o.uv);
                res.rgb += col;
                return res;
            }
            ENDCG
        }
    }
}
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
            #define NUM_MAXSTEPS 1
            #include "Lighting.cginc"
            #include "UnityCG.cginc"
            #include "VolumePrecompute.cginc"
            #pragma vertex vert
            #pragma fragment frag

            float _fRayLen;
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 eyeView:TEXCOORD0;
                float3 wpos : TEXCOORD1;
            };

            v2f vert(float4 v: POSITION, float3 bin : Color)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v);
                o.wpos = mul(unity_ObjectToWorld, v).xyz;
                o.eyeView = o.wpos - _WorldSpaceCameraPos.xyz;
                return o;
            }
            fixed4 frag(v2f o):SV_Target
            {
                float fNormalDensity;
                float3 center = mul(unity_ObjectToWorld, float3(0, 0, 0));
                bool bflag = any(step(abs(_WorldSpaceCameraPos.xyz - center) ,float3(5, 5, 5)));
                float3 origin = bflag * _WorldSpaceCameraPos.xyz + !bflag * o.wpos;
                //float3 origin = o.wpos;
                float3 f3Dir = normalize(o.eyeView);
                float4 f4Result = float4(0, 0, 0, 0);
                float3 f3CurrPos = float3(0, 0, 0);
                float bBreak = 1;
                [unroll(NUM_MAXSTEPS)]
                for(int i = 1; i < NUM_MAXSTEPS; ++i)
                {
                    f3CurrPos += f3Dir * _fRayLen + origin;
                    bBreak = any(step(abs(f3CurrPos - center), float3(5, 5, 5)));
                    float3 f3EntryPointUSSpace = normalize(f3CurrPos - center);
                    SampleDensity(f3EntryPointUSSpace, f3Dir, fNormalDensity);
                    float fMultiSctr ;
                    SampleSctr(f3EntryPointUSSpace, f3Dir, fMultiSctr);
                    float fdotTheta = dot(_WorldSpaceLightPos0.xyz, -f3Dir);
                    f4Result += BlendParticalRender(fNormalDensity, fMultiSctr, _fRayLen, fdotTheta, _LightColor0.rgb, unity_AmbientSky.rgb, f3EntryPointUSSpace);
                }
                return f4Result;
            }
            ENDCG
        }
    }
}
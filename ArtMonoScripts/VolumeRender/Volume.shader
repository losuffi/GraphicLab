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
            #include "Lighting.cginc"
            #include "UnityCG.cginc"
            #include "VolumePrecompute.cginc"
            #pragma vertex vert
            #pragma fragment frag

            float _fRayLen;
            struct v2f
            {
                float3 eyeView:TEXCOORD0;
                float3 wpos:TEXCOORD1;
            };

            v2f vert(float4 v: POSITION)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v);
                o.opos = v;
                o.wpos = mul(unity_ObjectToWorld,v).xyz;
                o.eyeView = _WorldSpaceCameraPos - wpos;
                return o;
            }

            fixed4 frag(v2f o):SV_Target
            {
                float fNormalDensity;
                SampleDensity(o.opos, o.eyeView, fNormalDensity);
                float fMultiSctr;
                SampleSctr(o.opos, o.eyeView, fMultiSctr);
                float dotTheta = dot(mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz , o.eyeView);
                return BlendParticalRender(fNormalDensity, fMultiSctr, _fRayLen, dotTheta, _LightColor0.rgb, unity_AmbientSky.rgb, o.opos);
            }
            ENDCG
        }
    }
}

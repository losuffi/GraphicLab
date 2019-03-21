Shader "ArtStandard/Volume/Standard"
{
    Properties
    {
        _MaxStep("Max Step",Int) = 64
        _MaxHeight("Max Height",Float) = 1000
        _MinHeight("Min Height",Float) = 400
        _SigmaScattering("Sigma Scattering",Range(0,1)) = 0.1
        _SigmaExtinction("Sigma Extinction",Range(0,1)) = 0.1
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

            float _MaxHeight;
            float _MinHeight;
            float _SigmaScattering;
            float _SigmaExtinction;
            float _MaxStep;
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            sampler2D _src,_WeatherTex;
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
                const float3 center = float3(0,3,10);
                const float radius = 2.0;

                float fdepth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, o.uv));
                float3 f3EndPoint = GetWorldPositionFromDepthValue(o.uv,fdepth).xyz;

                float startFlag=1;
                startFlag *=step(0,f3EndPoint.y);
                float3 ray = normalize(f3EndPoint - _WorldSpaceCameraPos.xyz);
                float2 f2innerCIntersecion, f2outCIntersecion;
                float maxLen = length(f3EndPoint - _WorldSpaceCameraPos.xyz);
                startFlag *= step(0,GetRaySphereIntersection(f3CurrPos, ray, float3(0, -_MinHeight, 0), _MinHeight * 2, f2innerCIntersecion)-0.1);
                startFlag *= step(0,GetRaySphereIntersection(f3CurrPos, ray, float3(0, -_MaxHeight, 0), _MaxHeight * 2, f2outCIntersecion)-0.1);

                startFlag *= step(0,maxLen - f2innerCIntersecion.y);
                float4 src = tex2D(_src,o.uv);
                if(!startFlag)
                    return src;
                maxLen = min(maxLen, f2outCIntersecion.y);

                float3 Entry = f3CurrPos + ray * f2innerCIntersecion.y;
                float3 Exit = f3CurrPos + ray * maxLen;

                float3 f3stepLen = (Exit - Entry) / _MaxStep;
                float fstepLen = length(f3stepLen);
                float fscatteredLight = 0;
                float ftransmittance = 1;
                f3CurrPos = Entry;
                [loop]
                for(int i = 1; i < _MaxStep; ++i)
                {
                    if(ftransmittance < 0.01)
                        break;
                    f3CurrPos += f3stepLen;
                    //Get Density
                    float3 f3weather = tex2D(_WeatherTex,abs(frac(f3CurrPos.xz/float2(1024,1024))));
                    float fdensity = f3weather.r;
                    //Height Signal
                    float faltitudeStart = f3weather.b * _MaxHeight;
                    float height = f3weather.g * (_MaxHeight - faltitudeStart) + faltitudeStart;
                    float foneOverHeight = 1 / height;
                    float faltitudeDiff = f3CurrPos.y - faltitudeStart;
                    float fheightSignal = faltitudeDiff * (faltitudeDiff - height) * foneOverHeight * foneOverHeight * -4;                   
                    //Shape
                    float4 f4shape = tex3D(_3dTex, abs(frac(f3CurrPos/float3(1280,320,1280))));
                    float fshape = f4shape.r * (f4shape.g + f4shape.b + f4shape.a);
                    fdensity *= step(0, faltitudeStart);
                    fdensity *= (1+saturate(fheightSignal));
                    fdensity *= fshape;
                    fdensity *= smoothstep(_MinHeight, _MaxHeight, f3CurrPos.y);

                    float fSigmaS = _SigmaScattering * fdensity;
                    float fSigmaE = _SigmaExtinction * fdensity;

                    float dotTheta = dot(_WorldSpaceLightPos0.xyz,ray);
                    float S = HGPhase(dotTheta, 0.1) * fSigmaS;
                    float Tr = exp(-fSigmaE * fstepLen);

                    float Sint = (S - S * Tr) / (fSigmaE+0.000001);
                    fscatteredLight += ftransmittance * Sint;//ftransmittance * Sint;
                    ftransmittance *= Tr;
                }
                //return src+fscatteredLight;

                float4 res = src * (1+float4(fscatteredLight * _LightColor0.rgb,1));

                return res;
            }
            ENDCG
        }
    }
}
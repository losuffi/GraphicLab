Shader "ArtStandard/Volume/Standard"
{
    Properties
    {
        _MaxStep("Max Step",Int) = 64
        _MaxHeight("Max Height",Float) = 1000
        _MinHeight("Min Height",Float) = 400
        _SigmaScattering("Sigma Scattering",Range(0,1000)) = 0.1
        _SigmaExtinction("Sigma Extinction",Range(0,1)) = 0.1
        _WethearCover("Weather Cover",Range(0,10)) = 0
        _SigmaPowder("Sigma Powder",Range(0,200)) = 1
        _SilverSpreadAndIntensity("SilverSpread And Intensity",Vector) = (0,1,0,0)
        _WindSpeed("Wind Speed",Vector) = (0,0,0,0)
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
            float _SigmaPowder;
            float _MaxStep;
            float _WethearCover;
            float2 _SilverSpreadAndIntensity;
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            sampler2D _src,_WeatherTex;
            sampler3D _3dTex,_DetailTex;
            float4 _WindSpeed;
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
            inline float3 Repeat(float3 f3origin)
            {
                f3origin = abs(f3origin);
                uint3 i3p = floor(f3origin);
                uint3 i3flga =step(0.1,i3p % 2);
                float3 fval = frac(f3origin);
                return fval * i3flga + (1 - i3flga) * (1 - fval);
            }
            inline float2 Repeat(float2 f2origin)
            {
                f2origin = abs(f2origin);
                uint2 i2p = floor(f2origin);
                uint2 i2flga =step(0.1,i2p % 2);
                float2 fval = frac(f2origin);
                return fval; //* i2flga + (1 - i2flga) * (1 - fval);
            }

            inline float2 DominArea(float2 pos)
            {
                return Repeat(pos / float2(5120,5120));
            }

            inline float Remap(float value, float originMin, float orginMax, float newMin, float newMax)
            {
                if(abs(orginMax - originMin)<1e-4)
                    return newMin;
                return newMin + (((value - originMin)/(orginMax - originMin)) * (newMax - newMin));
            }
            
            inline float GetHeightFractionForPoint(float3 pos)
            {
                float fheightFraction = (pos.y - _MinHeight) / (_MaxHeight - _MinHeight);
                return saturate(fheightFraction);
            }

            inline float GetDensityHeightGradientForPoint(float Height, float2 weatherData)
            {
                float a = step(0.9,weatherData.y) * Remap(Height, 0, 0.2, 0, 1.0) * Remap(Height, 0.3, 0.5, 1.0, 0);
                return a;
            }

            float BeerLambert(float opticalDepth)
            {
                float ExtinctionCoEff = _SigmaExtinction;
                return exp(-ExtinctionCoEff * opticalDepth);
            }

            float Powder(float opticalDepth)
            {
                float ExtinctionCoEff = _SigmaPowder;
                return 1.0 - exp(-2 * ExtinctionCoEff * opticalDepth);
            }

            inline float GetDensity(float3 f3CurrPos,out float fHeight)
            {
                float2 f2xz = DominArea(f3CurrPos.xz);
                float3 f3weather = tex2Dlod(_WeatherTex,float4(f2xz,0,0));
                //Height Signal
                fHeight = GetHeightFractionForPoint(f3CurrPos);
                float4 f4shape = tex3Dlod(_3dTex,float4(Repeat((f3CurrPos)/float3(4096,1024,4096)),0));
                float3 f3Detail = tex3Dlod(_DetailTex,float4(Repeat((f3CurrPos)/float3(512,512,512)),0));
                float fshape = f4shape.x;
                float fdetail = f3Detail.x * 0.25 + f3Detail.y * 0.125 + f3Detail.z *0.0625;
                
                float fdensity = fshape;// * f3weather.r;
                //fdensity *=saturate(GetDensityHeightGradientForPoint(fHeight, f3weather.yz));
                //float weatherCover = saturate(Remap(f3weather.r,_WethearCover,1.0, 0, 1.0));
                fdensity = Remap(fdensity, f3weather.r * _WethearCover, 1.0, 0, 1.0);
                fdensity *= f3weather.r;

                fdensity = Remap(fdensity,fdetail * 0.2, 1.0, 0, 1);
                return fdensity;
            }
            inline float EvaluateLight(float3 wpos, float dotTheta)
            {
                const float3 RandomUnitSphere[6] = 
				{
					{0.3f, -0.8f, -0.5f},
					{0.9f, -0.3f, -0.2f},
					{-0.9f, -0.3f, -0.1f},
					{-0.5f, 0.5f, 0.7f},
					{-1.0f, 0.3f, 0.0f},
					{-0.3f, 0.9f, 0.4f}
				};

                float fNumStep = 6;
                float fstepScale = 2;
                float3 directionToLight = _WorldSpaceLightPos0.xyz;
                float3 lightColor = _LightColor0.rgb;

                float3 stepLength = directionToLight * fstepScale;
                float fHeight;
                float densitySum =0;
                for(int i = 0; i < fNumStep; ++i)
                {
                    float3 randomOffset = RandomUnitSphere[i] * stepLength * (i+1);
                    float3 samplePos = wpos + randomOffset;
                    densitySum +=GetDensity(samplePos,fHeight);
                    wpos += stepLength;
                }
                
                float hgForward = HGPhase(dotTheta, 0.8);
                float hgBackward = HGPhase(dotTheta, 0.99 - _SilverSpreadAndIntensity.x) * _SilverSpreadAndIntensity.y;
                float hg = max(hgForward, hgBackward);
                float lightEng1 = BeerLambert(densitySum);
                float lightEng2 = BeerLambert(densitySum * 0.25) *0.7;
                float lightEng = max(lightEng1,lightEng2);
                float powder = Powder(densitySum);

                return 2 * lightColor * lightEng * hg * powder;
            }
            
            

            fixed4 frag(v2f o):SV_Target
            {
                float3 f3CurrPos = _WorldSpaceCameraPos.xyz;

                float fdepth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, o.uv));
                float3 f3EndPoint = GetWorldPositionFromDepthValue(o.uv,fdepth).xyz;

                float startFlag=1;
                startFlag *=step(0,f3EndPoint.y);
                float3 ray = normalize(f3EndPoint - _WorldSpaceCameraPos.xyz);
                float2 f2innerCIntersecion, f2outCIntersecion;
                float maxLen = length(f3EndPoint - _WorldSpaceCameraPos.xyz);
                maxLen = step(1000,maxLen) * 20000 + maxLen;
                startFlag *= step(0,GetRaySphereIntersection(f3CurrPos, ray, float3(0, -50000 , 0), _MinHeight + 50000, f2innerCIntersecion)-0.1);
                startFlag *= step(0,GetRaySphereIntersection(f3CurrPos, ray, float3(0, -50000, 0), _MaxHeight + 50000, f2outCIntersecion)-0.1);

                startFlag *= step(0,maxLen - f2innerCIntersecion.y);
                float4 src = tex2D(_src,o.uv);
                if(!startFlag)
                    return src;
                maxLen = min(maxLen, f2outCIntersecion.y);

                float3 Entry = f3CurrPos + ray * f2innerCIntersecion.y;
                float3 Exit = f3CurrPos + ray * maxLen;

                float3 f3stepLen = (Exit - Entry) / _MaxStep;
                float fstepLen = length(f3stepLen);
                float3 fscatteredLight = 0;
                float ftransmittance = 1;
                float densitySum = 0;
                f3CurrPos = Entry;
                float3 offset = _Time.y * _WindSpeed.xyz;
                [loop]
                for(int i = 1; i < _MaxStep; ++i)
                {
                    float fHeight;
                    float fdensity =GetDensity(f3CurrPos + offset,fHeight);
                    if(fdensity>0)
                    {
                        densitySum += fdensity;
                        ftransmittance = BeerLambert(densitySum);
                        float3 ambient = 0;//fHeight * unity_AmbientSky.rgb;
                        float dotTheta = dot(_WorldSpaceLightPos0.xyz,ray);
                        float LightCol = EvaluateLight(f3CurrPos + offset, dotTheta);
                        fscatteredLight += (ambient + LightCol) * ftransmittance;
                    }
                    f3CurrPos += f3stepLen;
                    if(ftransmittance < 0.01)
                        break;
                }
                //ftransmittance = Remap(ftransmittance,0,1,0,1);
                float4 res =src * ftransmittance + float4(fscatteredLight,1);
                return res;
            }
            ENDCG
        }
    }
}
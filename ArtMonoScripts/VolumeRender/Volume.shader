Shader "ArtStandard/Volume/Standard"
{
    Properties
    {
        _MaxStep("Max Step",Int) = 64
        _MaxHeight("Max Height",Float) = 1000
        _MinHeight("Min Height",Float) = 400
        _SigmaExtinction("Sigma Extinction",Range(0,1)) = 0.1
        _WethearCover("Weather Cover",Range(0,1)) = 0
        _WindSpeed("Wind Speed",Vector) = (0,0,0,0)

        _WeatherScale("Weather Scale",Float) = 0.0001
        _DensityScale("Density Scale",Float) = 0.001
        _DetailScale("Detail Scale",Float) =0.01
        _HighFreqModifier("High Freq Modifier",Float) = 1


        _CloudTopColor("Cloud Top Color",Color) = (1,1,1,1)
        _CloudBottomColor("Cloud Bottom Color",Color) = (0.5,0.5,0.5,0.5)

        _DirLightFactor("Dir Light Factor",Range(0,10)) = 1
        _IndirLightFactor("InDir Light Factor",Range(0,1)) = 1

        _HGFowardG("Forward G",Range(-1,1)) = 0.8
        _HGBackG("Back G",Range(-1,1)) = -0.5
        _LightStepLen("Light Step Len",Float) = 1
        _LightConeRadius("Light ConeRadius",Range(0,1)) = 1
        _OpticalDepthFactor("Optical Depth Factor",Range(0,1)) = 0.5
        _BlueNoise("2D BlueNoise",2D)="black"{}
        _Threshole("Threshole",Range(0,5)) = 1 
        //_WeatherTex("Weather Tex",2D)="black"{}
    }
    SubShader
    {
        Pass
        {
            Name "ForwardBase"
            Tags {"LightMode" = "ForwardBase"}
            Cull Off
            CGPROGRAM
            #include "Lighting.cginc"
            #include "UnityCG.cginc"
            #include "VolumePrecompute.cginc"
            #pragma vertex vert
            #pragma fragment frag
            #define BIGSTEP 3
            float _MaxHeight;
            float _MinHeight;

            float _SigmaExtinction;
            float _MaxStep;
            float _WethearCover,_Threshole;
            float _LightConeRadius,_OpticalDepthFactor;
            float4 _CloudTopColor, _CloudBottomColor,_Randomness,_BlueNoise_TexelSize;
            float _WeatherScale,_DensityScale,_DetailScale,_HighFreqModifier,_DirLightFactor,_IndirLightFactor,_LightStepLen,_HGFowardG,_HGBackG;

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            sampler2D _WeatherTex,_BlueNoise;
            sampler3D _3dTex,_DetailTex;
            float4 _WindSpeed;
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 eyeView:TEXCOORD0;
                float2 uv:TEXCOORD1;
            };

            float getRandomRayOffset(float2 uv)
            {
                float noise = tex2D(_BlueNoise, uv).x;
                noise =mad(noise, 2.0, -1.0);
                return noise;
            }

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

            inline float GetDensityHeightGradientForPoint(float Height, float3 weatherData)
            {
                float a = step(0.9,weatherData.z) * Remap(Height, 0, 0.2, 0, 1.0) * Remap(Height, 0.3, 0.4, 1.0, 0);
                float b = step(0.9,weatherData.y) * Remap(Height, 0.4, 0.6, 0, 1.0) * Remap(Height, 0.6, 0.9, 1.0, 0);
                float c = step(weatherData.y,0.2) * Remap(Height, 0.1, 0.3, 0, 1.0) * Remap(Height, 0.3, 0.6, 1.0, 0);
                return a;
            }

            float BeerLambert(float opticalDepth)
            {
                float ExtinctionCoEff = _SigmaExtinction;
                float d = -opticalDepth * ExtinctionCoEff;
                return max(exp(d), exp(d * 0.5) *0.7);
            }

            float Powder(float opticalDepth, float dotTheta)
            {
                float powder = 1.0 - exp(-opticalDepth * 2.0);
                return lerp(1.0, powder, saturate((-dotTheta * 0.5) + 0.5));
            }

            float GetLightEnergy(float opticalDepth, float dotTheta, float powderDensity)
            {
                float beerPowder = 2.0 * BeerLambert(opticalDepth) * Powder(powderDensity, dotTheta);
                float HG = max(HGPhase(dotTheta, _HGFowardG), HGPhase(dotTheta,_HGBackG))*0.1 + 0.8;
                return beerPowder * HG;
            }

            float3 GetWeather(float3 Pos)
            {
                float scale = 0.00001 + _WeatherScale * 0.0004;
                float3 weatherData = tex2Dlod(_WeatherTex, float4(Pos.xz* scale,0,0)).rgb;
                weatherData.r =saturate(weatherData.r - _WethearCover);
                return weatherData;
            }

            inline float GetDensity(float3 f3CurrPos,float3 f3weather ,float fHeight)
            {
                float scale = 0.00001 + _DensityScale * 0.0004;
                float sampleDensity = tex3Dlod(_3dTex,float4(f3CurrPos * scale,0)).r;
                sampleDensity = Remap(sampleDensity * pow(1.2 - fHeight, 0.1),0.1,1.0,0,1.0);
                sampleDensity *= GetDensityHeightGradientForPoint(fHeight, f3weather);

                float cloudCover = f3weather.r;
                sampleDensity = saturate(Remap(sampleDensity, saturate(fHeight/cloudCover),1.0,0.0,1.0));
                sampleDensity *= cloudCover;

                float3 f3Detail = tex3Dlod(_DetailTex,float4(f3CurrPos * _DetailScale * scale,0));
                float fdetail = f3Detail.x * 0.25 + f3Detail.y * 0.125 + f3Detail.z *0.0625;
                float highFreqModifier = lerp(1.0 - fdetail, fdetail, saturate(fHeight * 10.0));
                
                sampleDensity = Remap(sampleDensity, highFreqModifier *_HighFreqModifier, 1.0, 0.0, 1.0);
                return max(sampleDensity, 0.0);
            }
            inline float3 EvaluateLight(float3 pos, float dotTheta, float density, float3 weatherData, float fHeight)
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

                float fNumStep = 5;
                float3 directionToLight = _WorldSpaceLightPos0.xyz;
                float3 lightColor = _LightColor0.rgb;

                float densitySum =0;
                for(int i = 0; i < fNumStep; ++i)
                {
                    pos += _LightStepLen * directionToLight;
                    float3 randomOffset = RandomUnitSphere[i] * _LightStepLen *_LightConeRadius *  (i+1);
                    float3 samplePos = pos + randomOffset;
                    fHeight = GetHeightFractionForPoint(samplePos);
                    weatherData = GetWeather(samplePos);
                    densitySum +=GetDensity(samplePos,weatherData,fHeight) * (weatherData.b + 1.0);
                }
                
                pos += 32.0 * _LightStepLen * directionToLight;
                weatherData = GetWeather(pos);
                fHeight = GetHeightFractionForPoint(pos);
                densitySum += GetDensity(pos, weatherData,fHeight) * (weatherData.b + 1.0) * 3.0;

                return GetLightEnergy(densitySum, dotTheta, density) * lightColor;
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
                float maxLen = distance(f3EndPoint,_WorldSpaceCameraPos.xyz);
                maxLen = step(0.99,fdepth) * 1200000 + maxLen;
                startFlag *= step(0,GetRaySphereIntersection(f3CurrPos, ray,_WorldSpaceCameraPos.xyz+float3(0, -500000, 0), _MinHeight + 500000, f2innerCIntersecion)-0.1);
                startFlag *= step(0,GetRaySphereIntersection(f3CurrPos, ray,_WorldSpaceCameraPos.xyz+float3(0, -500000, 0), _MaxHeight + 500000, f2outCIntersecion)-0.1);

                startFlag *= step(0,maxLen - f2innerCIntersecion.y);
                if(!startFlag)
                    return 0;
                maxLen = min(maxLen, f2outCIntersecion.y);

                float3 Entry = f3CurrPos + ray * f2innerCIntersecion.y;
                float3 Exit = f3CurrPos + ray * maxLen;

                float fNumStep = lerp(_MaxStep * 0.5, _MaxStep, ray.y);
                
                float3 f3stepLen = (Exit - Entry) / fNumStep;
                float fstepLen = length(f3stepLen);
                float4 fscatteredLight = 0;
                float zeroCount = 0;
                int stepCount =1;
                float3 offset = _Time.y * _WindSpeed.xyz;
                Entry += f3stepLen * BIGSTEP * 0.75 *getRandomRayOffset((o.uv+_Randomness.xy)*_BlueNoise_TexelSize*_ScreenParams.xy);
                f3CurrPos = Entry;
                [loop]
                for(int i = 1; i < fNumStep; i+=stepCount)
                {
                    if(distance(f3CurrPos,Entry) > maxLen)
                        break;
                    if(fscatteredLight.a >=0.99)
                        break;
                    float fHeight = GetHeightFractionForPoint(f3CurrPos + offset);
                    if(fHeight < 0 || fHeight>1)
                        break;
                    float3 weatherData = GetWeather(f3CurrPos + offset);
                    float fdensity =GetDensity(f3CurrPos + offset, weatherData, fHeight);
                    fdensity *=_OpticalDepthFactor;
                    if(weatherData.r <= 0.1)
                    {
                        f3CurrPos += f3stepLen * stepCount;
                    }
                    if(fdensity>0)
                    {
                        zeroCount = 0;
                        if(stepCount > 1)
                        {
                            i-= stepCount -1;
                            f3CurrPos -= f3stepLen * (stepCount -1);
                            weatherData = GetWeather(f3CurrPos + offset);
                            fHeight =GetHeightFractionForPoint(f3CurrPos + offset);
                            fdensity = GetDensity(f3CurrPos + offset, weatherData,fHeight);
                        }
                        float3 ambient = lerp(_CloudBottomColor.xyz,_CloudTopColor.xyz,fHeight) * _IndirLightFactor;
                        float dotTheta = dot(_WorldSpaceLightPos0.xyz,ray);
                        float LightCol = EvaluateLight(f3CurrPos + offset, dotTheta, fdensity, weatherData, fHeight) *_DirLightFactor;
                        float4 particleCol = fdensity;
                        particleCol.rgb = LightCol + ambient;
                        particleCol.rgb *= particleCol.a;
                        fscatteredLight = (1 - particleCol.a) * particleCol + fscatteredLight;
                    }
                    else
                    {
                        zeroCount +=1;
                    }
                    stepCount = zeroCount > 10 ? BIGSTEP : 1;
                    f3CurrPos += f3stepLen * stepCount;
                    //i+=(stepCount-1);
                }
                //ftransmittance = smoothstep(0,0.5,ftransmittance);
                return clamp(fscatteredLight,0,_Threshole);
            }
            ENDCG
        }
        
    }
}
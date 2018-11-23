Shader "Hidden/RayMarching"
{
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define PI 3.141592653
            
            #include "UnityCG.cginc"
            #include "UnityDeferredLibrary.cginc"

            sampler2D msg;
            int SampleCount;
            float4 light;
            float4 lightPos;
            float scatteringCoef;
            float _G;
            struct ve2f
            {
                float4 pos:SV_POSITION;
                float4 uv:TEXCOORD0;
            };
            half GetAtten(float3 wpos)
            {
                float3 tolight=wpos-lightPos.xyz;
                half3 ldir=-normalize(tolight);
                float d=dot(tolight,tolight)*lightPos.w;
                float atten=tex2D(_LightTextureB0,d.rr).UNITY_ATTEN_CHANNEL;
                atten*=UnityDeferredComputeShadow(tolight,0,float2(0,0));
                return atten;
            }

            float4 GetWorldPositionFromDepthValue( float2 uv, float linearDepth ) 
            {
                float camPosZ = _ProjectionParams.y + (_ProjectionParams.z - _ProjectionParams.y) * linearDepth;
                float height = 2 * camPosZ / unity_CameraProjection._m11;
                float width = _ScreenParams.x / _ScreenParams.y * height;
                float camPosX = width * uv.x - width / 2;
                float camPosY = height * uv.y - height / 2;
                float4 camPos = float4(camPosX, camPosY, camPosZ, 1.0);
                return mul(unity_CameraToWorld, camPos);
            }
            
            float3 ScatteringCoefRayleigh()
            {
                return float3(5.8,13.5,33.1)*scatteringCoef;
            }
            float3 ScatteringCoefMie()
            {
                return 0.2*scatteringCoef;
            }
            float PhaseMie(float Costheta)
            {
                float denom=abs(1+_G*_G+2*_G*Costheta);
                return (1/(4*PI))*(1-_G*_G)/(denom*sqrt(denom));
            }
            float PhaseRaylei(float Costheta)
            {
                return (3/(16*PI))*(1+Costheta*Costheta);
            }
            ve2f vert(float4 v:POSITION,float4 uv:TEXCOORD0)
            {
                ve2f o;
                o.pos=UnityObjectToClipPos(v);
                o.uv=uv;
                return o;
            }
            fixed4 frag(ve2f i):SV_Target
            {
                float4 m=tex2D(msg,i.uv);
                clip(m.z-0.1);

                float3 wpos=GetWorldPositionFromDepthValue(m.xy,m.w);
                float3 st=(_WorldSpaceCameraPos.xyz-wpos)/SampleCount;

                float3 currentPos=_WorldSpaceCameraPos.xyz;
                float4 res=0;
                [loop]
                for(int i=0;i<SampleCount;++i)
                {
                    half atten=GetAtten(currentPos);
                    float3 tolight=lightPos.xyz-currentPos;
                    float Costheta=dot(normalize(st),tolight);
                    float c=(ScatteringCoefRayleigh()*PhaseRaylei(Costheta) + ScatteringCoefMie()*PhaseMie(Costheta))/(ScatteringCoefMie()+ScatteringCoefRayleigh());
                    float3 il= light*c;
                    float ex=-exp(-length(st)*(ScatteringCoefMie()+ScatteringCoefRayleigh()));
                    il*=(1+ex);
                    res.xyz+=il*atten;
                    currentPos+=st;
                }
                return fixed4(res.xyz,1);
            }
            ENDCG
        }
    }
}
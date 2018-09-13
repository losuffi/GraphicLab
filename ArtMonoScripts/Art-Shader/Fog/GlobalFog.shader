// Upgrade NOTE: replaced 'defined BLURFOG' with 'defined (BLURFOG)'

Shader "Lyf/Environment/Fog"
{
    Properties
    {
        _MainTex("Main Tex",any)=""{}
    }
    SubShader
    {
        CGINCLUDE
        #define ACT_SAMPLE(name,coff)  activiation(name##_DepthStrength * name.a * coff)
        #define STR_SAMPLE(name) (name.a * name##_DepthStrength)
        #include "UnityCG.cginc"
        sampler2D _MainTex;
        sampler2D _CameraDepthNormalsTexture;
        sampler2D _AxisTexture;
        fixed4 _FogColor;
        float _FogDensity;
        float _FogHMax;
        float _FogHMin;
        float _FogDMax;
        float _FogDepthMode;
        struct v2f
        {
            float4 pos:SV_POSITION;
            half2 uv: TEXCOORD0;
        };
        float4x4 _ViewToWorldMat;
        float _BlurSize;
        half4 _MainTex_TexelSize;
        struct gaussianV2F
        {
            float4 pos:SV_POSITION;
            half2 uv[5]:TEXCOORD0;
        };
        gaussianV2F vertGaussian(appdata_img v)
        {
            gaussianV2F o;
            o.pos=UnityObjectToClipPos(v.vertex);
            half2 uv=v.texcoord;
            o.uv[0]=uv;
            o.uv[1]=uv+float2(0,_MainTex_TexelSize.y)*_BlurSize;
            o.uv[2]=uv-float2(0,_MainTex_TexelSize.y)*_BlurSize;
            o.uv[3]=uv+float2(0,_MainTex_TexelSize.y)*_BlurSize;
            o.uv[4]=uv-float2(0,_MainTex_TexelSize.y)*_BlurSize;
            return o;
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
        gaussianV2F horiGaussian(appdata_img v)
        {
            gaussianV2F o;
            o.pos=UnityObjectToClipPos(v.vertex);
            half2 uv=v.texcoord;
            o.uv[0]=uv;
            o.uv[1]=uv+float2(_MainTex_TexelSize.x,0)*_BlurSize;
            o.uv[2]=uv-float2(_MainTex_TexelSize.x,0)*_BlurSize;
            o.uv[3]=uv+float2(_MainTex_TexelSize.x*2,0)*_BlurSize;
            o.uv[4]=uv-float2(_MainTex_TexelSize.x*2,0)*_BlurSize;
            return o;
        }
        fixed4 fragGaussian(gaussianV2F i):SV_Target
        {            
            float weight[3] ={0.4026,0.2442,0.0545};
            float4 res=tex2D(_MainTex,i.uv[0]);
            float3 color=res.rgb*weight[0];
            color+=tex2D(_MainTex,i.uv[1]).rgb*weight[1];
            color+=tex2D(_MainTex,i.uv[2]).rgb*weight[1];
            color+=tex2D(_MainTex,i.uv[3]).rgb*weight[2];
            color+=tex2D(_MainTex,i.uv[4]).rgb*weight[2];
            return fixed4(color,res.a);
        }
        float activiation(float input)
        {
            float res=exp(-input);
            res+=1;
            res=1/res;
            res=res-0.5;
            res*=2;
            return res;
        }
        ENDCG
        Pass
        {
            ZWrite Off
            Cull Off
            NAME "FOGDRAW"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _BLURFOG
            #pragma shader_feature _CSKY
            v2f vert(appdata_img v)
            {
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.uv=v.texcoord;
                return o;
            }
            
            inline fixed range01Value(float input)
            {
                fixed flag= (0.5f-input)/abs(0.5f-input);
                fixed res= input+0.01*flag;
                return res;
            }
            fixed4 frag(v2f i):SV_Target
            {
                float4 background=tex2D(_MainTex,i.uv);
                
                float d;
                float3 backgroundNormal;
                DecodeDepthNormal(tex2D(_CameraDepthNormalsTexture,i.uv),d,backgroundNormal);
                //backgroundNormal=normalize(mul((float3x3)_ViewToWorldMat,backgroundNormal));
                float depth=d*_ProjectionParams.z;

                float3 wpos=GetWorldPositionFromDepthValue(i.uv,d);


                depth=d;
                depth=saturate(depth/_FogDMax);
                float height=wpos.y;
                float length=_FogHMax-_FogHMin;
                height=height-_FogHMin;
                height=height/length;
                height=height>1||height<0?1:height;
                

                float3 light=normalize(float3(_WorldSpaceLightPos0.x,0,_WorldSpaceLightPos0.z));
                float3 wDir=normalize(wpos);
                float lightDir=dot(light,wDir);
                lightDir=lightDir*0.5+0.5;

                float luminance= Luminance(background.rgb);

                float4 HeightAxisColor=tex2Dlod(_AxisTexture,half4(1.0/8-0.05,range01Value(height),0,0));
                float HeightAxisColor_DepthStrength=tex2Dlod(_AxisTexture,half4(2.0/8-0.05,range01Value(depth),0,0)).a;
                float4 LightDirAxis=tex2Dlod(_AxisTexture,half4(3.0/8-0.05,range01Value(lightDir),0,0));
                float LightDirAxis_DepthStrength=tex2Dlod(_AxisTexture,half4(4.0/8-0.05,range01Value(depth),0,0)).a;
                float4 LuminanceAxis=tex2Dlod(_AxisTexture,half4(5.0/8-0.05,range01Value(luminance),0,0));
                float LuminanceAxis_DepthStrength=tex2Dlod(_AxisTexture,half4(6.0/8-0.05,range01Value(depth),0,0)).a;
                float4 DepthAxisColor=tex2Dlod(_AxisTexture,half4(7.0/8-0.05,range01Value(depth),0,0));
                float DepthAxisColor_DepthStrength=1;
                float D=exp(depth-1)*_FogDensity;
                float3 color=background.rgb;
                float skyAtomosphere=step(0.99,d);
                color=lerp(color,HeightAxisColor.rgb,ACT_SAMPLE(HeightAxisColor,D));
                color=lerp(color,LightDirAxis.rgb,ACT_SAMPLE(LightDirAxis,D));
                color=lerp(color,LuminanceAxis.rgb,ACT_SAMPLE(LuminanceAxis,D));
                color=lerp(color,DepthAxisColor.rgb,ACT_SAMPLE(DepthAxisColor,D));
                float st=D*(STR_SAMPLE(HeightAxisColor)+STR_SAMPLE(LightDirAxis)+STR_SAMPLE(LuminanceAxis)+STR_SAMPLE(DepthAxisColor));
                //color= pow(color,0.2);
                //color =float4(HeightAxisColor.a,0,0,1);
                #if !defined (_CSKY)
                    color=lerp(color,background.rgb,skyAtomosphere);
                #endif
                #if defined (_BLURFOG)
                return fixed4(color,st);
                #else 
                return fixed4(color,1);
                #endif
            }
            ENDCG
        }

        Pass
        {
            ZWrite Off
            Cull Off
            NAME "FOGADD"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            sampler2D _FogBuffer;
            v2f vert(appdata_img v)
            {
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.uv=v.texcoord;
                return o;
            }
            fixed4 frag(v2f i):Sv_Target
            {
                fixed3 b= tex2D(_MainTex,i.uv).rgb;
                fixed4 c=tex2D(_FogBuffer,i.uv);
                return fixed4(lerp(b,c.rgb,activiation(c.a)),1);
            }
            ENDCG
        }
        
        Pass
        {
            NAME "VERTGAUSSIAN"
            CGPROGRAM
            #pragma vertex vertGaussian
            #pragma fragment fragGaussian
            ENDCG
        }
        Pass
        {
            NAME "HORIGAUSSIAN"
            CGPROGRAM
            #pragma vertex horiGaussian
            #pragma fragment fragGaussian
            ENDCG
        }
    }
}
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Lyf/Environment/SeaWater"
{
    Properties
    {
        _MainTex("Main Tex",2D)="white"{}
        _namida("Namida",Float)=1.0
        _A("A",Float)=3.0
        _f("Frequency",Float)=40.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 300
        pass
        {
            Name "DEFERREDSEA"
            Tags { "LightMode" = "Deferred" }
            CGPROGRAM
            #define Pi (3.141592653)
            #define T (_Time.y)
            #define VecMagnitude(i) (i.x*i.x+i.y*i.y+i.z*i.z)
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct v2f
            {
                float4 pos:SV_POSITION;
                half2 uv:TEXCOORD0;
                float3 worldNormal:TEXCOORD2;
                float3 eyeVec:TEXCOORD3;
            };
            sampler2D _MainTex;
            float _namida,_f,_A;

            inline float Gerstner(float x)
            {
                float o=_A*(sin(2*Pi*(x/(_namida+0.1)+2*T*_f))+cos(2*Pi*(x/(_namida+0.1)+T*_f)));
                return o;
            }

            v2f vert(appdata_tan i)
            {
                v2f o;
                float3 wPos=mul(unity_ObjectToWorld,i.vertex).xyz;
                float3 startPoint=mul(unity_ObjectToWorld,float4(50,0,50,1)).xyz;
                float3 dir=wPos-startPoint;
                float dist=sqrt(VecMagnitude(dir));
                dir=normalize(dir+float3(0.1,0.1,0.1));
                float3 worldNormal=UnityObjectToWorldNormal(i.normal);
                float3 biWorldTangent=normalize(cross(worldNormal,dir));
                float3 temp=wPos-dir*_namida;
                wPos=wPos+worldNormal*Gerstner(dist);
                float3 dirTangent=normalize(wPos-temp);
                float3 nWorldNormal=cross(dirTangent,biWorldTangent);
                o.worldNormal=nWorldNormal;
                o.pos=UnityObjectToClipPos(i.vertex);
                //o.pos=mul(UNITY_MATRIX_VP,float4(wPos,1));
                o.uv=i.texcoord;
                o.eyeVec=normalize(o.pos-_WorldSpaceCameraPos);
                return o;
            }
            void frag(v2f i,out half4 gb0:COLOR0,out half4 gb1:COLOR1,out half4 gb2:COLOR2,out half4 gb3:COLOR3)
            {
                gb0=half4(0.15,0.27,0.96,1);
                gb1=half4(0,0,0,1);
                gb2=half4(i.worldNormal* 0.5 + 0.5, 1.0);
                gb3=half4(0,0,0,0);
            }
            ENDCG
        }
    }
    FallBack "VertexLit"
}
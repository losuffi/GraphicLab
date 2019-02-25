Shader "ArtStandard/Volume/Sphere"
{
    Properties
    {
        _Center("Origin Transform",Vector)=(1,1,1,1)
        _Noise("Noise",2D)="black"{}
    }
    SubShader
    {
        //Tags{"LightMode"="Volume"}
        //GrabPass{"_BgTex"}
        Pass
        {
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag
            #define STEP_SIZE 20
            float4 _Center;
            sampler2D _Noise,_BgTex;
            struct v2f
            {
                float4 pos:SV_POSITION;
                float3 wpos:TEXCOORD0;
                float4 uv:TEXCOORD2;
            };

            float noise(in float3 pos)
            {
                float3 p=floor(pos);
                float3 f=frac(pos);
                f=f*f*(3.0-2.0*f);
                float2 uv=(p.xy+float2(37,17)*p.z)+f.xy;
                float2 rg=tex2D(_Noise,float4((uv+0.5)*0.01,0,0) ).yx;

                return -1.0+2.0*lerp(rg.x,rg.y,f.z);
            }
            float map5(in float3 pos)
            {
                float3 q=pos-float3(0,0.1,1.0)*_Time.y;
                float f;
                f=0.5*noise(q);q*=2.02;
                f+=0.25*noise(q);q*=2.03;
                f+=0.125*noise(q);q*=2.01;
                f+=0.0625*noise(q);q*=2.02;
                f+=0.03125*noise(q);
                return saturate(1.5-pos.y-2.0+1.75*f);
            }

            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.wpos=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.uv=v.texcoord;
                return o;
            }
            float map4(in float3 pos)
            {
                float3 q=pos-float3(0,0.1,1.0)*_Time.y;
                float f;
                f=0.5*noise(q);q*=2.02;
                f+=0.25*noise(q);q*=2.03;
                f+=0.125*noise(q);q*=2.01;
                f+=0.0625*noise(q);q*=2.02;
                return saturate(1.5-pos.y-2.0+1.75*f);
            }
            float map3(in float3 pos)
            {
                float3 q=pos-float3(0,0.1,1.0)*_Time.y;
                float f;
                f=0.5*noise(q);q*=2.02;
                f+=0.25*noise(q);q*=2.03;
                f+=0.125*noise(q);q*=2.01;
                return saturate(1.5-pos.y-2.0+1.75*f);
            }
            float map2(in float3 pos)
            {
                float3 q=pos-float3(0,0.1,1.0)*_Time.y;
                float f;
                f=0.5*noise(q);q*=2.02;
                f+=0.25*noise(q);q*=2.03;
                return saturate(1.5-pos.y-2.0+1.75*f);
            }
            float SphereDisField(float3 wpos,float3 center,float radius)
            {
                return distance(center,wpos)-radius;
            }
            float3 normal(float3 p,float3 center,float r)
            {
                const float3 eps=float3(0.001,0,0);
                float3 n= float3( 
                 SphereDisField(p+eps.xyy,center,r)-SphereDisField(p-eps.xyy,center,r),
                 SphereDisField(p+eps.yxy,center,r)-SphereDisField(p-eps.yxy,center,r),
                 SphereDisField(p+eps.yyx,center,r)-SphereDisField(p-eps.yyx,center,r)
                );
                return normalize(n);
            }
            float4 integrate(in float4 sum,float dif,float den,fixed3 bgCol,float t)
            {
                float3 lin =float3(0.65,0.7,0.75)*1.4+float3(1.0,0.6,0.3)*dif;
                float4 col =float4(lerp(float3(1.0,0.95,0.8),float3(0.25,0.3,0.35),den),den);
                col.xyz*lin;
                //col.xyz=lerp(col.xyz,bgCol,1.0-exp(-0.003*t*t));
                col.a*=0.4;
                col.rgb*=col.a;
                return sum+col*(1.0-sum.a);
            }
            
            #define MARCH(STEPS,MAP) for(int i=0;i<STEPS;i++){float3 pos=origin+t*dirn; if(sum.a>0.99) break; float den=MAP(pos); if(den>0.01){float dif=saturate((den-MAP(pos+0.3*sundir))/0.6); sum=integrate(sum,dif,den,bgCol,t);} t+=max(0.05,0.02*t);}
            fixed4 frag(v2f i):SV_Target
            {
                float3 dir=i.wpos-_WorldSpaceCameraPos.xyz;
                float3 dirn=normalize(dir);
                float dist=0;
                float3 opos=mul(unity_ObjectToWorld,float3(0,0,0)).xyz;
                float3 origin;
                if(any(step(0.5*_Center.xyz+1e-4,abs(_WorldSpaceCameraPos.xyz-opos))))
                {
                    origin=i.wpos;
                }
                else
                {
                    origin=_WorldSpaceCameraPos.xyz;
                }

                float3 sundir=normalize(float3(1,1,1));
                float sun=saturate(dot(dirn,sundir));

                float3 bgCol=float3(0.6,0.71,0.75)-dirn.y*0.2*float3(1.0,0.5,1.0)+0.15*0.5;
                bgCol+=0.2*float3(1.0,0.6,0.1)*pow(sun,8.0);
                //
                //Cloud Render
                float4 sum=0;
                float t= 0.0;
                
                for(int i=0;i<30;i++)
                {
                    t+=0.1;
                    t=t*t;
                    sum.a+=t;//*noise(origin+i*dirn);
                }
                //MARCH(STEP_SIZE,map5);
                // MARCH(STEP_SIZE,map4);
                // MARCH(STEP_SIZE,map3);
                // MARCH(STEP_SIZE,map2);
                return saturate(sum);
            }
            ENDCG
        }
    }
}
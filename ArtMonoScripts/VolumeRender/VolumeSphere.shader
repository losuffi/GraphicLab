Shader "ArtStandard/Volume/Sphere"
{
    Properties
    {
        _Center("Origin Transform",Vector)=(0,0,0,1)
        _Noise("Noise",2D)="black"{}
    }
    SubShader
    {
        //Tags{"LightMode"="Volume"}
        Pass
        {
            Cull Off
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag
            #define STEP_SIZE 20
            float4 _Center;
            sampler2D _Noise;
            struct v2f
            {
                float4 pos:SV_POSITION;
                float3 wpos:TEXCOORD0;
                float4 uv:TEXCOORD2;
            };


            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.wpos=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.uv=v.texcoord;
                return o;
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
            fixed4 frag(v2f i):SV_Target
            {
                float3 dir=i.wpos-_WorldSpaceCameraPos.xyz;
                float3 dirn=normalize(dir);
                float dist=0;
                float3 origin=i.wpos;
                i.uv.xy+=_Time.y*0.02;
                float minDist=tex2Dlod(_Noise,i.uv)*_Center.w;
                for(int i=0;i<STEP_SIZE;i++)
                {
                    dist= SphereDisField(origin,_Center.xyz,_Center.w);
                    if(dist<minDist+0.01)
                    {
                        return fixed4(1,1,1,1)*pow(saturate(dot(normal(origin,_Center.xyz,_Center.w),_WorldSpaceLightPos0.xyz)),4);
                    }
                    origin+=dist*dirn;
                }
                clip(-0.1);
                return fixed4(1,1,1,1);
            }
            ENDCG
        }
    }
}
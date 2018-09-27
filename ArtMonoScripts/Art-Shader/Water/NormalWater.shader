
Shader"Lyf/Environment/NormalWater"
{
    Properties
    {
        _Tex_ST("Tex ST",Vector)=(5,5,5,5)
        _LightDir("Light Direction",Vector)=(-1,1,1,0)
        _TessellationScale("Tessellation Scale",Range(0,1000))=8
        _SpecPow("Specular Pow",Range(0.1,100))=60
        _DiffPow("Diffuse Pow",Range(0.1,50))=30
        _RelativeHeightMin("Height Min",Range(0,1))=0.3
        _DistFactor("Distance Factor",Range(0.0002,0.00001))=0.0002
        _SeaBase("Sea Base Color",Color)=(0.1,0.19,0.22,1)
        _SeaWaterColor("Sea Water Color",Color)=(0.8,0.9,0.6,1)
        _Distortion("Distortion",Range(0.1,1))=0.5
    }
    SubShader
    {
        GrabPass{"_RefractionTex"}
        Pass
        {
            Tags{"LightMode"="ForwardBase" "Queue"="Transparent" "RenderType"="Opaque"}
            Cull Off
            ZWrite Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma hull hs
            #pragma domain ds
            #include "../Bin/Tessellation.cginc"
            #include "UnityStandardCore.cginc"
            #include "WaterSurface.cginc"
            #pragma multi_compile_fwdbase nolightmap
            #pragma shader_feature _RECSHADOW

            float4 _Tex_ST,_LightDir;
            //From Cs
            sampler2D _DispCS,_NormCS;
            float _Choppiness,_Distortion;
            struct v2f
            {
                float4 pos:SV_POSITION;
                float4 screenPos:TEXCOORD0;
                float4 uv:TEXCOORD1;
                float4 tangentToWorld[3]:TEXCOORD2;
                float4 oriWPos:TEXCOORD5;
                SHADOW_COORDS(6)
            };
            inline float3 MovePos(float4 nuv)
            {
                return tex2Dlod(_DispCS,nuv).xyz*_Choppiness;
            }
            inline float4 HeightPoint(float4 uv,float4 oPos)
            {
                float4 wpos=mul(unity_ObjectToWorld,oPos);   
                wpos.xyz+=MovePos(uv);
                return mul(unity_WorldToObject,wpos);
            }
            v2f TessellationVertex(TVD v)
            {
                v2f o;
                o.uv.xy=v.texcoord*_Tex_ST.xy;
                o.uv.zw=v.texcoord*_Tex_ST.zw;
                float3 wn=UnityObjectToWorldNormal(v.normal);
                float4 huv=float4(o.uv.xy,0,0);
                float3 tangent=v.tangent.xyz;
                float4 opos=HeightPoint(huv,v.vertex);
                o.pos=UnityObjectToClipPos(opos);
                o.screenPos=ComputeScreenPos(o.pos);
                float4 tangentworld=float4(UnityObjectToWorldDir(tangent),v.tangent.w);
                float3x3 tTw=CreateTangentToWorldPerVertex(wn,tangentworld.xyz,-tangentworld.w);
                o.oriWPos=mul(unity_ObjectToWorld,v.vertex);
                float3 wpos=mul(unity_ObjectToWorld,opos);
                o.tangentToWorld[0].xyz=tTw[0];
                o.tangentToWorld[1].xyz=tTw[1];
                o.tangentToWorld[2].xyz=tTw[2];
                o.tangentToWorld[0].w=wpos.x;
                o.tangentToWorld[1].w=wpos.y;
                o.tangentToWorld[2].w=wpos.z;
                TRANSFER_SHADOW(o);
                return o;
            }
            [UNITY_domain("tri")]
            v2f ds(TessellationFactors factors,
                    OutputPatch<TVD,3> patch,
                    float3 barycentricCoordinates:SV_DomainLocation)
            {
                TVD data;
                DS_PROGRAM_INTERPOLATE(vertex);
                DS_PROGRAM_INTERPOLATE(tangent);
                DS_PROGRAM_INTERPOLATE(texcoord);
                DS_PROGRAM_INTERPOLATE(normal);
                return TessellationVertex(data);
            }
            fixed4 frag(v2f i):SV_Target
            {
                float3 wpos=float3(i.tangentToWorld[0].w,i.tangentToWorld[1].w,i.tangentToWorld[2].w);
                float3 dist=_WorldSpaceCameraPos.xyz-wpos;
                
                float3 viewDir=normalize(dist);
                float3 bump=(tex2D(_NormCS,i.uv.zw)).xyz;
                float2 ofs=(bump.xy)*_Distortion;
                i.screenPos.xy+=ofs;
                fixed3 reflCol=tex2Dproj(_MainTex,UNITY_PROJ_COORD(i.screenPos)).rgb;
                bump=normalize(float3(i.tangentToWorld[0].xyz*bump.x+i.tangentToWorld[1].xyz*bump.y+i.tangentToWorld[2].xyz*bump.z));
                #if defined(SHADOWS_SCREEN) && defined(_RECSHADOW)
                UNITY_LIGHT_ATTENUATION(atten,i,wpos);
                #else
                float atten=1;
                #endif
                
                fixed3 seaColor=SeaColor((wpos-i.oriWPos),bump,normalize(_LightDir),viewDir,dist,reflCol,atten);
                fixed3 skyColor=SkyColor(-viewDir,atten,reflCol);
                fixed3 color=lerp(skyColor,seaColor,pow(smoothstep(0.0,-0.05,-viewDir.y),0.3));
                return fixed4(color,1.0);
            }
            ENDCG
        }
    }
    Fallback "VertexLit"
    CustomEditor "SimpleWaterGUI"
}
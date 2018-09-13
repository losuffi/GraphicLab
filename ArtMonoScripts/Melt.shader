
Shader "Artifact Shaders/Melt"
{
    Properties
    {
        _MeltLevel("Melt Level",Range(0,1))=0
        _MainTex("Main Tex",2D)="white"{}
        _MeltMap("Melt Map",2D)="white"{}
        _MeltFirstColor("Melt First Color",Color)=(0,0,0,1)
        _MeltSecondColor("Melt Second Color",Color)=(1,1,1,1)
        _Width("Width",Float)=1
	    [Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor("_SrcFactor",Float)=5
		[Enum(UnityEngine.Rendering.BlendMode)] _DstFactor("_DstFactor",Float)=10
		
    }
    SubShader
    {
        CGINCLUDE
        #pragma vertex vert
        #pragma fragment frag
        #include "Lighting.cginc"
        #include "AutoLight.cginc"
        
        sampler2D _MeltMap;
        float4 _MeltMap_ST;
        sampler2D _MainTex;
        float4 _MainTex_ST;
        float _MeltLevel;
        float4 _MeltFirstColor;
        float4 _MeltSecondColor;
        float _Width;
        ENDCG
        Pass
        {
            Cull off
            Blend [_SrcFactor][_DstFactor]
            CGPROGRAM
            #pragma multi_compile_fwdbase
            struct a2v
            {
                float4 vertex:POSITION;
                float4 texcoord:TEXCOORD0;
                float4 tangent:TANGENT;
                float3 normal:NORMAL;
            };
            struct v2f
            {
                float4 pos:SV_POSITION;
                float3 normal:NORMAL;
                float3 lightDir:TEXCOORD1;
                float2 uvMeltMap:TEXCOORD2;
                float2 uvMainMap:TEXCOORD3;
                SHADOW_COORDS(5)
            };
            v2f vert(a2v v)
            {
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.uvMeltMap=TRANSFORM_TEX(v.texcoord,_MeltMap);
                o.uvMainMap=TRANSFORM_TEX(v.texcoord,_MainTex);
                TANGENT_SPACE_ROTATION;
                o.lightDir=mul(rotation,ObjSpaceLightDir(v.vertex)).xyz;
                o.normal=mul(rotation,v.normal);
                TRANSFER_SHADOW(o);
                return o;
            }
            float4 frag(v2f i):SV_Target
            {
                float3 melt=tex2D(_MeltMap,i.uvMeltMap).rgb;
                clip(melt.r-_MeltLevel);
                float t=1-smoothstep(0,_Width,melt.r-_MeltLevel);
                float3 meltColor=lerp(_MeltFirstColor,_MeltSecondColor,t);
                meltColor=pow(meltColor,5);
                float3 main=tex2D(_MainTex,i.uvMainMap).rgb;
                float3 result=lerp(main,meltColor,t*step(0.0001,_MeltLevel));
                return float4(result,1);
            }
            ENDCG
        }
        Pass
        {
            Tags{"LightMode"="ShadowCaster"}
            CGPROGRAM
            #pragma multi_compile_shadowcaster
            struct v2f
            {
                V2F_SHADOW_CASTER;
                float2 uvMeltMap:TEXCOORD1;
            };
            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                o.uvMeltMap=TRANSFORM_TEX(v.texcoord,_MeltMap);
                return o;
            }
            float4 frag(v2f i):SV_Target
            {
                float3 melt=tex2D(_MeltMap,i.uvMeltMap).rgb;
                clip(melt.r-_MeltLevel);
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
}
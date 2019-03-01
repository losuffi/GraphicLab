Shader"ArtStandard/ToolEffect/Distortion"
{
    Properties
    {
        _Normal("Distortion Map",2D)="white"{}
        _DistorParams("Distor Params",Vector)=(1,1,1,1)
        _DistorRange("Distor Range",Vector)=(1,1,1,1)
    }
    SubShader
    {
        GrabPass{"_GrapTexture"}
        Pass
        {
            Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
            Cull Off
            Blend One Zero
            ColorMask RGB
            Lighting Off ZWrite Off
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_particles
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            float4 _DistorParams,_DistorRange;
            sampler2D _GrapTexture;
            sampler2D _Normal;

            struct v2f
            {
                float4 pos:SV_POSITION;
                float4 uv:TEXCOORD0;
                float4 map:TEXCOORD1;
            };
            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.uv=ComputeScreenPos(o.pos);
                o.map=v.texcoord;
                return o;
            }
            fixed4 frag(v2f i):SV_Target
            {
                half2 offset=UnpackNormal(tex2D(_Normal,i.map+_Time.y*_DistorParams.xy)).xy;
                
                offset*=_DistorParams.z;
                float len= length(i.map.xy-half2(0.5,0.5));
                len=pow(len,_DistorParams.w)*_DistorRange.w;
                len=smoothstep(0.01,1,exp(-len));
                i.uv.xy+=offset*len;
                half4 bgcol=tex2Dproj(_GrapTexture,UNITY_PROJ_COORD(i.uv));
                clip(bgcol.a-.2);
                return bgcol;
            }
            ENDCG
        }
    }
}
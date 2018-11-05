Shader "ArtStandard/Toon/Object/Standard"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0

        _MetallicGlossMap("Metallic", 2D) = "black" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _LineColor("Line Color",Color)=(1,1,1,1)
        _EdgeWidth("Edge Width",Range(0.1,10))=1
        _EdgeClamp("Edge Clamp",Range(0,1))=0

        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 0 
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor("_SrcFactor",Float)=5
		[Enum(UnityEngine.Rendering.BlendMode)] _DstFactor("_DstFactor",Float)=10
        [ToggleOff] _ZWrite("_ZWrite",Float)=1
    }
    SubShader
    {
        Pass
        {

        }
    }
}
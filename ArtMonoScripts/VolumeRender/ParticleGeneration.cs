using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ParticleGeneration : MonoBehaviour
{
    [SerializeField]
    private ComputeShader GenerationCS;
    [SerializeField]
    private float ReferenceParticleRadius;
    [SerializeField]
    private bool IsLinearColorSpace;
    private RenderTexture Test3DTex;
    private RenderTexture WeatherTex;
    private RenderTexture DetailTex;


    public RenderTexture Test3DTexutureWrite()
    {
        //Test3DTex.enableRandomWrite = true;
        Test3DTex = new RenderTexture(128, 128, 0, RenderTextureFormat.ARGB32);
        Test3DTex.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        Test3DTex.volumeDepth = 128;
        Test3DTex.enableRandomWrite = true;
        Test3DTex.wrapMode = TextureWrapMode.Mirror;
        Test3DTex.filterMode = FilterMode.Trilinear;
        Test3DTex.useMipMap = true;
        Test3DTex.autoGenerateMips =false;
        Test3DTex.Create();

        DetailTex = new RenderTexture(32, 32, 0, RenderTextureFormat.ARGB32);
        DetailTex.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        DetailTex.volumeDepth = 32;
        DetailTex.enableRandomWrite = true;
        DetailTex.filterMode = FilterMode.Trilinear;
        DetailTex.wrapMode = TextureWrapMode.Mirror;
        DetailTex.Create();

        int kernel = GenerationCS.FindKernel("Tex3DTest");
        GenerationCS.SetBool("IsLinearColorSpace",IsLinearColorSpace);
        GenerationCS.SetTexture(kernel, "tex", Test3DTex);
        GenerationCS.Dispatch(kernel, Test3DTex.width / 32, Test3DTex.height / 32, Test3DTex.volumeDepth);

        kernel = GenerationCS.FindKernel("DetailTest");
        GenerationCS.SetTexture(kernel, "detailTex", DetailTex);
        GenerationCS.Dispatch(kernel, DetailTex.width / 32, DetailTex.height / 32, Test3DTex.volumeDepth);
        Shader.SetGlobalTexture("_3dTex", Test3DTex);
        Shader.SetGlobalTexture("_DetailTex", DetailTex);

        WeatherTex = new RenderTexture(128, 128, 0, RenderTextureFormat.ARGB32);
        WeatherTex.enableRandomWrite = true;
        WeatherTex.wrapMode = TextureWrapMode.Mirror;
        WeatherTex.filterMode = FilterMode.Trilinear;
        WeatherTex.useMipMap =true;
        WeatherTex.autoGenerateMips = false;
        WeatherTex.Create();
        kernel = GenerationCS.FindKernel("TexWeather");
        GenerationCS.SetTexture(kernel, "weather", WeatherTex);
        GenerationCS.Dispatch(kernel, WeatherTex.width / 32, WeatherTex.height / 32, 1);
        Shader.SetGlobalTexture("_WeatherTex", WeatherTex);
        WeatherTex.GenerateMips();
        Test3DTex.GenerateMips();
        return WeatherTex;
    }
}
[System.Serializable]
public struct ReferenceParticle
{
    [SerializeField]
    public float standardScale;
}

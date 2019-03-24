using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ParticleGeneration : MonoBehaviour
{
    [SerializeField]
    private ReferenceParticle referenceParticle;
    [SerializeField]
    private ComputeShader GenerationCS;
    [SerializeField]
    private Vector4 LUTSize;
    [SerializeField]
    private Vector4 SingleScartteringLUTSize;
    [SerializeField]
    private float ReferenceParticleRadius;
    [SerializeField]
    private float AttenuationCoeff;
    [SerializeField]
    private float ScatteringCoeff;
    [SerializeField]
    private int ScatteringCount;
    [SerializeField]
    private Material shader;

    //[SerializeField]
    private RenderTexture Test3DTex;
    private RenderTexture WeatherTex;
    private RenderTexture DetailTex;

    private RenderTexture OpticalDepthLUTTemp;
    private RenderTexture SingleScatteringLUTTemp;
    private RenderTexture MultScatteringLUTTemp;

    private RenderTexture[] SctrTemp;

    public RenderTexture Generation(out RenderTexture OtherTemp)
    {
        OpticalDepthLUTTemp = new RenderTexture(Mathf.FloorToInt(LUTSize.x * LUTSize.y), Mathf.FloorToInt(LUTSize.z * LUTSize.w), 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        OpticalDepthLUTTemp.enableRandomWrite = true;
        OpticalDepthLUTTemp.Create();

        //OpticalDepthLUT.enableRandomWrite = true;
        transform.localScale *= referenceParticle.standardScale;
        int kernel = GenerationCS.FindKernel("OpticalDepthLUTGenerator");
        GenerationCS.SetTexture(kernel, "OpticalDepthLUT", OpticalDepthLUTTemp);
        GenerationCS.SetFloat("fReferenceParticleRadius", ReferenceParticleRadius);
        GenerationCS.SetVector("f4LUTSize", LUTSize);
        GenerationCS.Dispatch(kernel, Mathf.FloorToInt(LUTSize.x * LUTSize.y) / 32, Mathf.FloorToInt(LUTSize.z * LUTSize.w) / 32, 1);

        //Single Scarttering Precompute
        SingleScatteringLUTTemp = new RenderTexture(Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y), Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w), 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        SingleScatteringLUTTemp.enableRandomWrite = true;
        SingleScatteringLUTTemp.Create();
        //Mult Scattering 
        MultScatteringLUTTemp = new RenderTexture(Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y), Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w), 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        MultScatteringLUTTemp.enableRandomWrite = true;
        MultScatteringLUTTemp.Create();

        SctrTemp = new RenderTexture[2];
        SctrTemp[0] = new RenderTexture(Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y), Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w), 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        SctrTemp[0].enableRandomWrite = true;
        SctrTemp[0].Create();

        SctrTemp[1] = new RenderTexture(Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y), Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w), 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
        SctrTemp[1].enableRandomWrite = true;
        SctrTemp[1].Create();

        kernel = GenerationCS.FindKernel("SingleScaterringLUTGenerator");
        GenerationCS.SetTexture(kernel, "SingleSctrLUT", SingleScatteringLUTTemp);
        GenerationCS.SetTexture(kernel, "IterateLUT", SctrTemp[0]);
        GenerationCS.SetVector("f4SingleSctrLUTSize", SingleScartteringLUTSize);
        GenerationCS.SetFloat("fScatteringCoeff", ScatteringCoeff);
        GenerationCS.SetFloat("fAttenuationCoeff", AttenuationCoeff);
        GenerationCS.Dispatch(kernel, Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y) / 32, Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w) / 32, 1);

        for (int i = 0; i < ScatteringCoeff; i++)
        {
            kernel = GenerationCS.FindKernel("MultiScaterringLUTGenerator");
            GenerationCS.SetTexture(kernel, "SingleSctrInput", SctrTemp[i % 2]);
            GenerationCS.SetTexture(kernel, "IterateLUT", SctrTemp[(i + 1) % 2]);
            GenerationCS.SetTexture(kernel, "MultiSctrLUT", MultScatteringLUTTemp);
            GenerationCS.SetBool("bIsFirstSctr", i == 0);
            GenerationCS.Dispatch(kernel, Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y) / 32, Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w) / 32, 1);
        }
        OtherTemp = OpticalDepthLUTTemp;
        return MultScatteringLUTTemp;
    }
    public void SaveGeneration()
    {
        if (OpticalDepthLUTTemp == null)
            return;
        var tex = new Texture2D(OpticalDepthLUTTemp.width, OpticalDepthLUTTemp.height, TextureFormat.RGBAFloat, false, true);
        RenderTexture.active = OpticalDepthLUTTemp;
        tex.ReadPixels(new Rect(0, 0, OpticalDepthLUTTemp.width, OpticalDepthLUTTemp.height), 0, 0);
        tex.Apply();
        System.IO.File.WriteAllBytes(Application.dataPath + "/OpticalDepthPNG.png", tex.EncodeToPNG());

        if (MultScatteringLUTTemp == null)
            return;
        var tex2 = new Texture2D(MultScatteringLUTTemp.width, MultScatteringLUTTemp.height, TextureFormat.RGBAFloat, false, true);
        RenderTexture.active = MultScatteringLUTTemp;
        tex2.ReadPixels(new Rect(0, 0, MultScatteringLUTTemp.width, MultScatteringLUTTemp.height), 0, 0);
        tex2.Apply();
        System.IO.File.WriteAllBytes(Application.dataPath + "/MultScatteringPNG.png", tex2.EncodeToPNG());
    }
    public RenderTexture Test3DTexutureWrite()
    {
        //Test3DTex.enableRandomWrite = true;
        Test3DTex = new RenderTexture(128, 32, 0, RenderTextureFormat.ARGB32);
        Test3DTex.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        Test3DTex.volumeDepth = 128;
        Test3DTex.enableRandomWrite = true;
        Test3DTex.Create();

        DetailTex = new RenderTexture(32, 32, 0, RenderTextureFormat.ARGB32);
        DetailTex.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        DetailTex.volumeDepth = 32;
        DetailTex.enableRandomWrite =true;
        DetailTex.Create();

        int kernel = GenerationCS.FindKernel("Tex3DTest");
        GenerationCS.SetTexture(kernel, "tex", Test3DTex);
        GenerationCS.Dispatch(kernel, Test3DTex.width / 32, Test3DTex.height / 32, Test3DTex.volumeDepth);

        kernel = GenerationCS.FindKernel("DetailTest");
        GenerationCS.SetTexture(kernel,"detailTex",DetailTex);
        GenerationCS.Dispatch(kernel, DetailTex.width / 32, DetailTex.height / 32, Test3DTex.volumeDepth);
        Shader.SetGlobalTexture("_3dTex", Test3DTex);
        Shader.SetGlobalTexture("_DetailTex",DetailTex);

        WeatherTex = new RenderTexture(1024, 1024, 0, RenderTextureFormat.ARGB32);
        WeatherTex.enableRandomWrite = true;
        WeatherTex.Create();
        kernel = GenerationCS.FindKernel("TexWeather");
        GenerationCS.SetTexture(kernel, "weather", WeatherTex);
        GenerationCS.Dispatch(kernel, WeatherTex.width / 32, WeatherTex.height / 32, 1);
        Shader.SetGlobalTexture("_WeatherTex", WeatherTex);
        return Test3DTex;
    }
}
[System.Serializable]
public struct ReferenceParticle
{
    [SerializeField]
    public float standardScale;
}

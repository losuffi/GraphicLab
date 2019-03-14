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
    private Texture2D noiseSource;
    [SerializeField]
    private float ReferenceParticleRadius;
    [SerializeField]
    private float AttenuationCoeff;
    [SerializeField]
    private float ScatteringCoeff;
    [SerializeField]
    private int ScatteringCount;


    private RenderTexture OpticalDepthLUTTemp;
    private RenderTexture SingleScatteringLUTTemp;
    private RenderTexture MultScatteringLUTTemp;

    private RenderTexture[] SctrTemp;

    public RenderTexture Generation()
    {
        OpticalDepthLUTTemp = new RenderTexture(Mathf.FloorToInt(LUTSize.x * LUTSize.y), Mathf.FloorToInt(LUTSize.z * LUTSize.w), 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        OpticalDepthLUTTemp.enableRandomWrite = true;
        OpticalDepthLUTTemp.Create();

        //OpticalDepthLUT.enableRandomWrite = true;
        transform.localScale *= referenceParticle.standardScale;
        int kernel = GenerationCS.FindKernel("OpticalDepthLUTGenerator");
        GenerationCS.SetTexture(kernel, "OpticalDepthLUT", OpticalDepthLUTTemp);
        GenerationCS.SetTexture(kernel, "NoiseMap", noiseSource);
        GenerationCS.SetFloat("fReferenceParticleRadius", ReferenceParticleRadius);
        GenerationCS.SetVector("f4LUTSize", LUTSize);
        GenerationCS.Dispatch(kernel, Mathf.FloorToInt(LUTSize.x * LUTSize.y) / 32, Mathf.FloorToInt(LUTSize.z * LUTSize.w) / 32, 1);

        //Single Scarttering Precompute
        SingleScatteringLUTTemp = new RenderTexture(Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y), Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w), 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        SingleScatteringLUTTemp.enableRandomWrite = true;
        SingleScatteringLUTTemp.Create();
        //Mult Scattering 
        MultScatteringLUTTemp = new RenderTexture(Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y), Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w), 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        MultScatteringLUTTemp.enableRandomWrite = true;
        MultScatteringLUTTemp.Create();

        SctrTemp = new RenderTexture[2];
        SctrTemp[0] = new RenderTexture(Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y), Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w), 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        SctrTemp[0].enableRandomWrite = true;
        SctrTemp[0].Create();

        SctrTemp[1] = new RenderTexture(Mathf.FloorToInt(SingleScartteringLUTSize.x * SingleScartteringLUTSize.y), Mathf.FloorToInt(SingleScartteringLUTSize.z * SingleScartteringLUTSize.w), 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
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
        
        return MultScatteringLUTTemp;
    }
    public void SaveGeneration()
    {
        if (OpticalDepthLUTTemp == null)
            return;
        var tex = new Texture2D(OpticalDepthLUTTemp.width, OpticalDepthLUTTemp.height, TextureFormat.RGBA32, false, true);
        RenderTexture.active = OpticalDepthLUTTemp;
        tex.ReadPixels(new Rect(0, 0, OpticalDepthLUTTemp.width, OpticalDepthLUTTemp.height), 0, 0);
        tex.Apply();
        System.IO.File.WriteAllBytes(Application.dataPath + "/OpticalDepthPNG.png", tex.EncodeToPNG());

        if(MultScatteringLUTTemp == null)
            return;
        var tex2 = new Texture2D(MultScatteringLUTTemp.width, MultScatteringLUTTemp.height, TextureFormat.RGBAHalf, false, true);
        RenderTexture.active = MultScatteringLUTTemp;
        tex2.ReadPixels(new Rect(0, 0, MultScatteringLUTTemp.width, MultScatteringLUTTemp.height), 0, 0);
        tex2.Apply();
        System.IO.File.WriteAllBytes(Application.dataPath + "/MultScatteringPNG.png", tex2.EncodeToPNG());

    }

}
[System.Serializable]
public struct ReferenceParticle
{
    [SerializeField]
    public float standardScale;
}

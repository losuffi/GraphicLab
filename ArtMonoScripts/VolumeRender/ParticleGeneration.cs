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

    private RenderTexture OpticalDepthLUTTemp;
    private RenderTexture SingleScatteringLUTTemp;
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
        return OpticalDepthLUTTemp;
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
    }

}
[System.Serializable]
public struct ReferenceParticle
{
    [SerializeField]
    public float standardScale;
}

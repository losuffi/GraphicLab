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
    private Texture2D noiseSource;
    [SerializeField]
    private float ReferenceParticleRadius;

    private RenderTexture temp;
    public RenderTexture Generation()
    {
        temp = new RenderTexture(Mathf.FloorToInt(LUTSize.x * LUTSize.y), Mathf.FloorToInt(LUTSize.z * LUTSize.w), 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        temp.enableRandomWrite = true;
        temp.Create();
        //OpticalDepthLUT.enableRandomWrite = true;
        transform.localScale *= referenceParticle.standardScale;
        int kernel = GenerationCS.FindKernel("OpticalDepthLUTGenerator");
        GenerationCS.SetTexture(kernel, "OpticalDepthLUT", temp);
        GenerationCS.SetTexture(kernel, "NoiseMap", noiseSource);
        GenerationCS.SetFloat("fReferenceParticleRadius", ReferenceParticleRadius);
        GenerationCS.SetVector("f4LUTSize", LUTSize);
        GenerationCS.Dispatch(kernel, Mathf.FloorToInt(LUTSize.x * LUTSize.y) / 32, Mathf.FloorToInt(LUTSize.z * LUTSize.w) / 32, 1);
        return temp;
    }
    public void SaveGeneration()
    {
        if (temp == null)
            return;
        var tex = new Texture2D(temp.width, temp.height, TextureFormat.RGBA32, false, true);
        RenderTexture.active = temp;
        tex.ReadPixels(new Rect(0, 0, temp.width, temp.height), 0, 0);
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

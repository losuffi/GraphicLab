using UnityEngine;

public class FFTWave : MonoBehaviour 
{
    [SerializeField]    
    private ComputeShader csPhillipsSepectrum;
    [SerializeField]
    private int N=8;
    [SerializeField]
    private Vector2 windVec; 
    [SerializeField]
    private float gConst=9.82f;
    [SerializeField]
    private float lengthConst=10;
    [SerializeField]
    private float spectrumA=5;
    private RenderTexture phillipsSpectrum;
    private RenderTexture fftInput;

    private void OnEnable() {
        int size=System.Convert.ToInt32(Mathf.Pow(2,N));
        phillipsSpectrum=new RenderTexture(size,size,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Default);
        fftInput=new RenderTexture(size,size,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Default);
    }
    void InitPhillipsSpectrum(int size)
    {
        int CSKernel=csPhillipsSepectrum.FindKernel("phillipsSpectrum");
        csPhillipsSepectrum.SetInt("_Size",size);
        csPhillipsSepectrum.SetVector("_Wind",new Vector4(windVec.x,windVec.y,0,0));
        csPhillipsSepectrum.SetFloat("_G",gConst);
        csPhillipsSepectrum.SetFloat("_Length",lengthConst);
        csPhillipsSepectrum.SetFloat("_A",spectrumA);
        csPhillipsSepectrum.SetTexture(CSKernel,"phillipsSpectrumRes",phillipsSpectrum);
        csPhillipsSepectrum.Dispatch(CSKernel,size/8,size/8,1);
    }
}
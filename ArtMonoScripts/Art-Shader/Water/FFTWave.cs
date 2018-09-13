using UnityEngine;

public class FFTWave : MonoBehaviour 
{
    [SerializeField]    
    private ComputeShader csFFT;

    private RenderTexture fftBuffer;
    private RenderTexture fftInput;
    private void OnEnable() {
        fftBuffer=new RenderTexture(512,512,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Default);
        fftInput=new RenderTexture(512,512,0,RenderTextureFormat.ARGB32,RenderTextureReadWrite.Default);
    }
}
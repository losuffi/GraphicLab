using UnityEngine;

public class FFTWave : MonoBehaviour 
{
    private enum Quality:int
    {
        Low=0,
        Normal=1,
        High=2,
        Ultimate=3,
    }

    [SerializeField]    
    private ComputeShader csPhillipsSepectrum;
    [SerializeField]
    private ComputeShader csFFTTransform;
    [SerializeField]
    private Quality quality=Quality.Normal;
    [SerializeField]
    private Vector2 windVec; 
    [SerializeField]
    private float gConst=9.82f;
    [SerializeField]
    private float lengthConst=10;
    [SerializeField]
    private float spectrumA=5;
    [SerializeField]
    private float strength=1.0f;
    [SerializeField]
    private float chopponess=1.0f;
    [SerializeField]
    private Texture2D noise0;
    [SerializeField]
    private Texture2D noise1;
    [SerializeField]
    private Texture2D noise2;
    [SerializeField]
    private Texture2D noise3;
    [SerializeField ]
    private MeshRenderer rend;
    [SerializeField ]
    private MeshRenderer rend2;
    private RenderTexture h0k;
    private RenderTexture hminus0k;
    private RenderTexture temp;
    private RenderTexture fftInput_dY,fftInput_dX,fftInput_dZ;
    private RenderTexture output_dY,output_dX,output_dZ;
    [HideInInspector]
    public RenderTexture displacementMap,normalMap;

    private RenderTexture Debugfft_dy;

    private int size=0;
    private void OnEnable() {
        switch(quality)
        {
            case Quality.Normal:
                size=256;
                break;
            case Quality.Low:
                size=128;
                break;
            case Quality.High:
                size=512;
                break;
            case Quality.Ultimate:
                size=1024;
                break;
        }

        h0k=new RenderTexture(size,size,24);
        h0k.enableRandomWrite=true;
        h0k.Create();
        hminus0k=new RenderTexture(size,size,24);
        hminus0k.enableRandomWrite=true;
        hminus0k.Create();
        temp=new RenderTexture(size,size,24);
        temp.enableRandomWrite=true;
        temp.Create();
        fftInput_dY= new RenderTexture(size,size,24);
        fftInput_dY.enableRandomWrite=true;
        fftInput_dY.Create();
        fftInput_dX= new RenderTexture(size,size,24);
        fftInput_dX.enableRandomWrite=true;
        fftInput_dX.Create();
        fftInput_dZ= new RenderTexture(size,size,24);
        fftInput_dZ.enableRandomWrite=true;
        fftInput_dZ.Create();
        output_dY=new RenderTexture(size,size,24);
        output_dY.enableRandomWrite=true;
        output_dY.Create();
        output_dX=new RenderTexture(size,size,24);
        output_dX.enableRandomWrite=true;
        output_dX.Create();
        output_dZ=new RenderTexture(size,size,24);
        output_dZ.enableRandomWrite=true;
        output_dZ.Create();
        displacementMap=new RenderTexture(size,size,0,RenderTextureFormat.ARGBFloat);
        displacementMap.enableRandomWrite=true;
        displacementMap.autoGenerateMips=true;
        displacementMap.filterMode=FilterMode.Bilinear;
        displacementMap.wrapMode=TextureWrapMode.Repeat;
        displacementMap.Create();
        normalMap=new RenderTexture(size,size,0,RenderTextureFormat.ARGBFloat);
        normalMap.enableRandomWrite=true;
        normalMap.autoGenerateMips=true;
        normalMap.filterMode=FilterMode.Bilinear;
        normalMap.wrapMode=TextureWrapMode.Repeat;
        normalMap.Create();
        Debugfft_dy= new RenderTexture(size,size,24);
        Debugfft_dy.enableRandomWrite=true;
        Debugfft_dy.Create();
        InitPhillipsSpectrum(size);
    }
    void InitPhillipsSpectrum(int size)
    {
        int CSKernel=csPhillipsSepectrum.FindKernel("phillipsSpectrum");
        csPhillipsSepectrum.SetInt("_Size",size);
        csPhillipsSepectrum.SetVector("_Wind",new Vector4(windVec.x,windVec.y,0,0));
        csPhillipsSepectrum.SetFloat("_G",gConst);
        csPhillipsSepectrum.SetFloat("_Length",lengthConst);
        csPhillipsSepectrum.SetFloat("_A",spectrumA);
        csPhillipsSepectrum.SetTexture(CSKernel,"phillipsSpectrumResH0K",h0k);
        csPhillipsSepectrum.SetTexture(CSKernel,"phillipsSpectrumRes_Minus_H0K",hminus0k);
        csPhillipsSepectrum.SetTexture(CSKernel,"noise_R1",noise0);
        csPhillipsSepectrum.SetTexture(CSKernel,"noise_I1",noise1);
        csPhillipsSepectrum.SetTexture(CSKernel,"noise_R2",noise2);
        csPhillipsSepectrum.SetTexture(CSKernel,"noise_I2",noise3);
        csPhillipsSepectrum.Dispatch(CSKernel,size/8,size/8,1);
    }
    void UpdateSepectrum(float t)
    {
        int CSkernel=csFFTTransform.FindKernel("CShkt");
        csFFTTransform.SetInt("_Size",size);
        csFFTTransform.SetFloat("_G",gConst);
        csFFTTransform.SetFloat("_T",t);
        csFFTTransform.SetTexture(CSkernel,"h0k",h0k);
        csFFTTransform.SetTexture(CSkernel,"h0minusk",hminus0k);
        csFFTTransform.SetTexture(CSkernel,"hkt_y",fftInput_dY);
        csFFTTransform.SetTexture(CSkernel,"hkt_x",fftInput_dX);
        csFFTTransform.SetTexture(CSkernel,"hkt_z",fftInput_dZ);
        csFFTTransform.Dispatch(CSkernel,size/8,size/8,1);
    }
    void InverseFFT(RenderTexture sepectrum,RenderTexture target)
    {
        int CSkernel=(int)quality;
        CSkernel*=2;
        csFFTTransform.SetTexture(CSkernel,"Spetrum",sepectrum);
        csFFTTransform.SetTexture(CSkernel,"output",temp);
        csFFTTransform.Dispatch(CSkernel,1,size,1);
        CSkernel+=1;
        csFFTTransform.SetTexture(CSkernel,"Spetrum",temp);
        csFFTTransform.SetTexture(CSkernel,"output",target);
        csFFTTransform.Dispatch(CSkernel,size,1,1);
    }
    void FFT(RenderTexture spaceSignal,RenderTexture target)
    {
        int CSkernel=11;
        csFFTTransform.SetTexture(CSkernel,"space_d",spaceSignal);
        csFFTTransform.SetTexture(CSkernel,"debugOut",temp);
        csFFTTransform.Dispatch(CSkernel,1,size,1);
        CSkernel+=1;
        csFFTTransform.SetTexture(CSkernel,"space_d",temp);
        csFFTTransform.SetTexture(CSkernel,"debugOut",target);
        csFFTTransform.Dispatch(CSkernel,size,1,1);
    }
    void CombinedDisp()
    {
        int CSkernel=csFFTTransform.FindKernel("CMDisp");
        csFFTTransform.SetTexture(CSkernel,"dY",output_dY);
        csFFTTransform.SetTexture(CSkernel,"dX",output_dX);
        csFFTTransform.SetTexture(CSkernel,"dZ",output_dZ);
        csFFTTransform.SetTexture(CSkernel,"DispOut",displacementMap);
        csFFTTransform.SetInt("_Size",size);
        csFFTTransform.SetFloat("strength",strength);
        csFFTTransform.Dispatch(CSkernel,size/8,size/8,1);
        
    }
    void CombinedNorm()
    {
        int CSkernel=csFFTTransform.FindKernel("CMNorm");
        csFFTTransform.SetTexture(CSkernel,"dY",output_dY);
        csFFTTransform.SetTexture(CSkernel,"dX",output_dX);
        csFFTTransform.SetTexture(CSkernel,"dZ",output_dZ);
        csFFTTransform.SetTexture(CSkernel,"NormOut",normalMap);
        csFFTTransform.SetInt("_Size",size);
        csFFTTransform.SetFloat("chopponess",chopponess);
        csFFTTransform.Dispatch(CSkernel,size/8,size/8,1);
    }
    private void Update() {
        UpdateSepectrum(Time.time);
        InverseFFT(fftInput_dY,output_dY);
        InverseFFT(fftInput_dX,output_dX);
        InverseFFT(fftInput_dZ,output_dZ);
        CombinedDisp();
        CombinedNorm();
        // FFT(output_dY,Debugfft_dy);
        // rend2.sharedMaterial.SetTexture("_MainTex",fftInput_dY);
        // rend.sharedMaterial.SetTexture("_MainTex",Debugfft_dy);
    }
}
using UnityEngine;

public class VolumetricLighttingAgent : MonoBehaviour {
    [SerializeField]
    private MeshRenderer debug;
    [SerializeField]
    private VolumetricLightSource lightSource;
    [SerializeField]
    private Shader RayMarchingShader;
    [SerializeField]
    private ComputeShader SamplesKernel;
    [SerializeField]
    private Camera viewCamera;

    [Header("Media Area Description")]   
    [SerializeField]
    private Vector3 AreaSize;
    private RenderTexture mask;
    private Matrix4x4 clipMatrix;

    [Header("Calcular Property")]
    [SerializeField]
    private float SampleDepthThreshole=10f;
    [SerializeField]
    [Range(3,6)]
    private int epipolarLineDensity;
    [SerializeField]
    [Range(4,18)]
    private int maxEpipolarLineInitPoint;
    [SerializeField]
    [Range(2,10)]
    private int maxEpipolarInterpolatePointEveryStage;

    [Header("Light Coef")]
    [SerializeField]
    private float _PhaseG;
    [SerializeField]
    private float scatteringCoef;
    [SerializeField]
    private Color scatteringColor;
    [SerializeField]
    private int RayMarchingCount=8;
    private void OnDrawGizmos() {
        Gizmos.DrawWireCube(transform.position+new Vector3(0,AreaSize.y/2,0),AreaSize);
    }
    private void updateClipMatrix()
    {
        clipMatrix=Matrix4x4.zero;
        clipMatrix.SetColumn(0,new Vector4(1.0f/AreaSize.x,0,0,0));
        clipMatrix.SetColumn(1,new Vector4(0,1.0f/AreaSize.y,0,0));
        clipMatrix.SetColumn(2,new Vector4(0,0,1.0f/AreaSize.z,0));
        clipMatrix.SetColumn(3,Vector4.zero);
        clipMatrix=clipMatrix*transform.worldToLocalMatrix;
    }

    #region  EPIPOLAR 
    private RenderTexture epipolarTex;
    private RenderTexture epipolarOutput;
    private Vector2 lightSourceEpipolarCoord;
    private int epipolarSpaceSizeX;
    private int epipolarSpaceSizeY;
    private void createEpipolarTexture()
    {
        epipolarSpaceSizeX=epipolarLineDensity*32;
        epipolarSpaceSizeY=maxEpipolarLineInitPoint*maxEpipolarInterpolatePointEveryStage;
        epipolarTex=new RenderTexture(epipolarSpaceSizeX,epipolarSpaceSizeY,0,RenderTextureFormat.ARGBHalf);
        epipolarTex.enableRandomWrite=true;
        epipolarTex.Create();
        RayMarchingTex=new RenderTexture(epipolarSpaceSizeX,epipolarSpaceSizeY,0,RenderTextureFormat.ARGBHalf);
        RayMarchingTex.enableRandomWrite=true;
        RayMarchingTex.Create();
        epipolarOutput=new RenderTexture(epipolarSpaceSizeX,epipolarSpaceSizeY,0,RenderTextureFormat.ARGBHalf);
        epipolarOutput.enableRandomWrite=true;
        epipolarOutput.Create();
    }
    private void updateEpipolarTexture()
    {
        if(epipolarTex==null)
        {
            createEpipolarTexture();
        }
        int csKernel=SamplesKernel.FindKernel("UpdateEpipolarTex");
        SamplesKernel.SetTexture(csKernel,"EpipolarTex",epipolarTex); 
        SamplesKernel.SetFloat("LineDensity",epipolarLineDensity*8);
        SamplesKernel.SetFloat("InitSampleCount",maxEpipolarLineInitPoint);
        SamplesKernel.SetFloat("InterpolateSampleCount",maxEpipolarInterpolatePointEveryStage);
        CalcularLightPoint();
        SamplesKernel.SetVector("SourceCoord",lightSourceEpipolarCoord);
        SamplesKernel.SetTexture(csKernel,"DepthBuffer",PostManager.Instantiete.DepthPost);
        SamplesKernel.SetVector("DepthBufferSize",new Vector2(PostManager.Instantiete.DepthPost.width,PostManager.Instantiete.DepthPost.height));
        SamplesKernel.SetFloat("DepthThreshold",SampleDepthThreshole/viewCamera.farClipPlane);
        SamplesKernel.Dispatch(csKernel,epipolarSpaceSizeX/32,epipolarSpaceSizeY/32,1);
        updateRayMarching();
        lerpEpipolarTexSpace();
    }

    private void lerpEpipolarTexSpace()
    {
        if(epipolarTex==null)
        {
            createEpipolarTexture();
        }
        int csKernel=SamplesKernel.FindKernel("LerpWork");
        SamplesKernel.SetTexture(csKernel,"input",epipolarTex); 
        SamplesKernel.SetTexture(csKernel,"samples",RayMarchingTex);
        SamplesKernel.SetTexture(csKernel,"outPut",epipolarOutput);
        SamplesKernel.Dispatch(csKernel,epipolarSpaceSizeX/32,epipolarSpaceSizeY/32,1);
        debug.sharedMaterial.SetTexture("_MainTex",epipolarOutput);
    }

    private void CalcularLightPoint()
    {
        Vector3 p=viewCamera.worldToCameraMatrix.MultiplyPoint(lightSource.transform.position);
        Vector4 np=new Vector4(p.x,p.y,p.z,1);
        np=viewCamera.projectionMatrix*np;
        np=np/np.w;
        lightSourceEpipolarCoord=new Vector2(np.x,np.y);
    }
    private void DisposeEpipolar()
    {
        epipolarTex=null;
    }
    #endregion

    #region Shadow
    private Material RayMarchingMat;
    private RenderTexture RayMarchingTex;
    private void updateRayMarching()
    {
        if(RayMarchingMat==null)
        {
            RayMarchingMat=new Material(RayMarchingShader);
        }
        RayMarchingMat.SetTexture("msg",epipolarTex);
        RayMarchingMat.SetInt("SampleCount",RayMarchingCount);
        RayMarchingMat.SetVector("lightPos",lightSource.v4Pos);
        RayMarchingMat.SetColor("light",scatteringColor);
        RayMarchingMat.SetFloat("scatteringCoef",scatteringCoef);
        RayMarchingMat.SetFloat("_G",_PhaseG);
        Graphics.Blit(epipolarTex,RayMarchingTex,RayMarchingMat);
        
    }
    #endregion
    private void Update() {
        updateEpipolarTexture();
    } 

}
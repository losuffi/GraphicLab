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
    [SerializeField]
    private int EpipolarLineTexelCount=512;

    [Header("Light Coef")]
    [SerializeField]
    private float _PhaseG;
    [SerializeField]
    private float scatteringCoef;
    [SerializeField]
    private Color scatteringColor;
    [SerializeField]
    private int RayMarchingCount=8;

    [Header("Rect Space Transform")]
    [SerializeField]
    private int RectWidth=64;
    [SerializeField]
    private int RectHeight=64;
    [SerializeField]
    private int SpatialSigma;
    [SerializeField]
    private int ColorSigma;

    private int width=512;
    private int height=512;
    private Vector4 _CamToWorldParams;
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
        epipolarTex=new RenderTexture(epipolarSpaceSizeX,epipolarSpaceSizeY,24,RenderTextureFormat.ARGBFloat);
        epipolarTex.enableRandomWrite=true;
        epipolarTex.Create();
        RayMarchingTex=new RenderTexture(epipolarSpaceSizeX,epipolarSpaceSizeY,0,RenderTextureFormat.ARGBHalf);
        RayMarchingTex.enableRandomWrite=true;
        RayMarchingTex.Create();
        epipolarOutput=new RenderTexture(epipolarSpaceSizeX,epipolarSpaceSizeY,0,RenderTextureFormat.ARGBHalf);
        epipolarOutput.enableRandomWrite=true;
        epipolarOutput.Create();
        RectPanel=new RenderTexture(RectWidth,RectHeight,0,RenderTextureFormat.ARGBHalf);
        RectPanel.enableRandomWrite=true;
        RectPanel.Create();
        width=PostManager.Instantiete.CurrentBuffer.width;
        height=PostManager.Instantiete.CurrentBuffer.height;
        opt=new RenderTexture(width,height,0,RenderTextureFormat.ARGBHalf);
        opt.enableRandomWrite=true;
        opt.Create();
        PostManager.Instantiete.PushInPostStack(new PostManager.PostAgent(null,opt,100));
    }
    private void updateEpipolarTexture()
    {
        if(epipolarTex==null)
        {
            createEpipolarTexture();
        }
        int csKernel=SamplesKernel.FindKernel("UpdateEpipolarTex");
        SamplesKernel.SetTexture(csKernel,"EpipolarTex",epipolarTex); 
        CalcularLightPoint();
        SamplesKernel.SetVector("SourceCoord",lightSourceEpipolarCoord);
        SamplesKernel.SetTexture(csKernel,"DepthBuffer",PostManager.Instantiete.DepthPost);
        SamplesKernel.SetVector("RectTexSize",new Vector4(RectWidth,RectHeight,1.0f/RectWidth,1.0f/RectHeight));
        SamplesKernel.SetVector("epipolarSize",new Vector2(epipolarSpaceSizeX,epipolarSpaceSizeY));
        SamplesKernel.SetVector("DepthBufferSize",new Vector2(PostManager.Instantiete.DepthPost.width,PostManager.Instantiete.DepthPost.height));
        SamplesKernel.SetFloat("DepthThreshold",SampleDepthThreshole/viewCamera.farClipPlane);
        SamplesKernel.SetVector("EpipolarParams",new Vector4(EpipolarLineTexelCount,maxEpipolarInterpolatePointEveryStage,0,0));
        SamplesKernel.SetVector("ScreenParams",new Vector4(Screen.width,Screen.height,1.0f/Screen.width,1.0f/Screen.height));
        SamplesKernel.Dispatch(csKernel,epipolarSpaceSizeX/32,epipolarSpaceSizeY/32,1);
        updateRayMarching();
        lerpEpipolarTexSpace();
        updateTransformToRect();
        updateOutput();
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
        _CamToWorldParams=new Vector4(
            viewCamera.farClipPlane,
            viewCamera.nearClipPlane,
            viewCamera.projectionMatrix.m11,
            (Screen.width*1.0f/Screen.height)
        );
        RayMarchingMat.SetTexture("msg",epipolarTex);
        RayMarchingMat.SetInt("SampleCount",RayMarchingCount);
        RayMarchingMat.SetVector("lightPos",lightSource.v4Pos);
        RayMarchingMat.SetColor("light",scatteringColor);
        RayMarchingMat.SetFloat("scatteringCoef",scatteringCoef);
        RayMarchingMat.SetFloat("_G",_PhaseG);
        RayMarchingMat.SetVector("CamParams",_CamToWorldParams);
        RayMarchingMat.SetVector("WorldCamPos",viewCamera.transform.position);
        RayMarchingMat.SetMatrix("CamToWorld",viewCamera.cameraToWorldMatrix);
        Graphics.Blit(epipolarTex,RayMarchingTex,RayMarchingMat);
        
        
    }
    #endregion
    #region RectTransform
    private RenderTexture RectPanel;
    private void updateTransformToRect()
    {
        SamplesKernel.SetVector("epipolarSize",new Vector2(epipolarSpaceSizeX,epipolarSpaceSizeY));
        SamplesKernel.SetTexture(3,"temp",epipolarOutput);
        SamplesKernel.SetTexture(3,"SecPlane",RectPanel);
        SamplesKernel.Dispatch(3,RectWidth/32,RectHeight/32,1);
    }
    #endregion
    
    #region output
    private RenderTexture opt;
    private void updateOutput()
    {
        //Debug.Log(width+","+height);
        SamplesKernel.SetVector("epipolarSize",new Vector2(epipolarSpaceSizeX,epipolarSpaceSizeY));
        SamplesKernel.SetTexture(2,"temp",RectPanel);
        SamplesKernel.SetTexture(2,"opt",opt);
        SamplesKernel.SetTexture(2,"samples",PostManager.Instantiete.InitPost);
        SamplesKernel.SetVector("sizef",new Vector2(1f/width,1f/height));
        SamplesKernel.SetVector("RectTexSize",new Vector2(RectWidth,RectHeight));
        SamplesKernel.Dispatch(2,width/8,height/8,1);
    }
    #endregion
    
    
    private void Update() {
        updateEpipolarTexture();
    } 
    private void OnWillRenderObject() {
        debug.sharedMaterial.SetTexture("_MainTex",RectPanel);
    }
}
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

    [Header("Shadow Property")]
    [SerializeField]
    private Vector2 shadowSize;
    [SerializeField]
    private float shadowFar;
    [SerializeField]
    private Shader shadowDepthShader;
    [SerializeField]
    private LayerMask layer;

    [Header("Calcular Property")]
    [SerializeField]
    private float SampleDepthThreshole=10f;
    [SerializeField]
    [Range(64,1024)]
    private int epipolarLineDensity=512;
    [SerializeField]
    [Range(4,32)]
    private int maxEpipolarLineInitPoint=8;
    [SerializeField]
    [Range(8,64)]
    private int maxEpipolarInterpolatePointEveryStage=32;
    [SerializeField]
    private int EpipolarLineTexelCount=512;

    [Header("Light Coef")]
    [SerializeField]
    private float _PhaseG;
    [SerializeField]
    private float Extinction;
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
        epipolarSpaceSizeX=epipolarLineDensity;
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
        if(shadowMap==null)
        {
            UpdateShadowMap();
        }
        int csKernel=SamplesKernel.FindKernel("RayMarching");
        SamplesKernel.SetTexture(csKernel,"input",epipolarTex);
        SamplesKernel.SetTexture(csKernel,"RaymarchingRes",RayMarchingTex);
        SamplesKernel.SetVector("shadowProjParams",shadowProjectionParams);
        SamplesKernel.SetVector("CamParams",_CamToWorldParams);
        SamplesKernel.SetVector("DParams",DParams);
        SamplesKernel.SetVector("WorldCamPos",viewCamera.transform.position);
        SamplesKernel.SetMatrix("CamToWorld",viewCamera.cameraToWorldMatrix);
        SamplesKernel.SetInt("SampleCount",RayMarchingCount);
        SamplesKernel.SetVector("lightPos",lightSource.v4Pos);
        SamplesKernel.SetVector("mediaParams",new Vector4(scatteringCoef,Extinction,_PhaseG,0));
        SamplesKernel.SetVector("scatterColor",scatteringColor);
        SamplesKernel.SetMatrix("shadowMat",world2ShadowProjection);
        SamplesKernel.SetVector("DepthBufferSize",shadowSize);
        SamplesKernel.SetTexture(csKernel,"DepthBuffer",shadowMap);
        SamplesKernel.Dispatch(csKernel,epipolarSpaceSizeX/32,epipolarSpaceSizeY/32,1);       
    }
    #endregion
    #region RectTransform
    private RenderTexture RectPanel;
    private void updateTransformToRect()
    {
        SamplesKernel.SetVector("epipolarSize",new Vector2(epipolarSpaceSizeX,epipolarSpaceSizeY));
        SamplesKernel.SetTexture(3,"temp",epipolarOutput);
        SamplesKernel.SetTexture(3,"samples",epipolarTex);
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
    #region Shadow
    private RenderTexture shadowMap;
    private Camera shadowMapCamera;
    private Matrix4x4 world2ShadowProjection;
    private Vector4 shadowProjectionParams,DParams;
    private void UpdateShadowMap()
    {
        if(shadowMap==null)
        {
            shadowMap=new RenderTexture(Mathf.FloorToInt(shadowSize.x),Mathf.FloorToInt(shadowSize.y),24,RenderTextureFormat.RFloat);
            shadowMap.enableRandomWrite=true;
            shadowMap.filterMode=FilterMode.Point;
            shadowMap.wrapMode=TextureWrapMode.Clamp;
        }
        if(shadowMapCamera==null)
        {
            GameObject go=new GameObject("Depth Cam");
            shadowMapCamera= go.AddComponent<Camera>();
            go.hideFlags=HideFlags.HideAndDontSave;
            shadowMapCamera.enabled=false;
            shadowMapCamera.clearFlags=CameraClearFlags.SolidColor;
        }
        shadowMapCamera.cullingMask=layer.value;
        shadowMapCamera.transform.position=lightSource.transform.position;
        shadowMapCamera.transform.rotation=lightSource.transform.rotation;
        shadowMapCamera.orthographic=false;
        shadowMapCamera.nearClipPlane=0.01f;
        shadowMapCamera.farClipPlane=shadowFar;
        shadowMapCamera.fieldOfView=lightSource.angles;
        shadowMapCamera.aspect=shadowSize.x/shadowSize.y;
        shadowMapCamera.renderingPath=RenderingPath.Forward;
        shadowMapCamera.targetTexture=shadowMap;
        shadowMapCamera.backgroundColor=Color.white;
        world2ShadowProjection=shadowMapCamera.projectionMatrix*shadowMapCamera.worldToCameraMatrix;
        shadowProjectionParams=new Vector4(shadowMapCamera.projectionMatrix.m32,shadowMapCamera.nearClipPlane,shadowMapCamera.farClipPlane,1.0f/shadowMapCamera.farClipPlane);
        shadowMapCamera.RenderWithShader(shadowDepthShader,"RenderType");
    }
    #endregion    
    private void OnWillRenderObject() {
        DParams=new Vector4(-1+viewCamera.farClipPlane/viewCamera.nearClipPlane,1,(-1+viewCamera.farClipPlane/viewCamera.nearClipPlane)/viewCamera.farClipPlane,1/viewCamera.farClipPlane);
        _CamToWorldParams=new Vector4(viewCamera.nearClipPlane,viewCamera.farClipPlane-viewCamera.nearClipPlane,viewCamera.projectionMatrix.m11,viewCamera.aspect);
        updateEpipolarTexture();
        UpdateShadowMap();
        debug.sharedMaterial.SetTexture("_MainTex",RectPanel);
    }
}
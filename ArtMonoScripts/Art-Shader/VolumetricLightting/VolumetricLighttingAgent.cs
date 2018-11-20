using UnityEngine;

public class VolumetricLighttingAgent : MonoBehaviour {
    [SerializeField]
    private VolumetricLightSource lightSource;
    [SerializeField]
    private ComputeShader ScattingKernel;
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
    [Range(3,6)]
    private int epipolarLineDensity;
    [SerializeField]
    [Range(4,18)]
    private int maxEpipolarLineInitPoint;
    [Range(2,10)]
    private int maxEpipolarInterpolatePointEveryStage;

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
    private Vector2 lightSourceEpipolarCoord;
    private int epipolarSpaceSizeX;
    private int epipolarSpaceSizeY;
    private void createEpipolarTexture()
    {
        epipolarSpaceSizeX=epipolarLineDensity*4;
        epipolarSpaceSizeY=(maxEpipolarLineInitPoint-1)*maxEpipolarInterpolatePointEveryStage;
        epipolarTex=new RenderTexture(epipolarSpaceSizeX,epipolarSpaceSizeY,0,RenderTextureFormat.ARGBHalf);
    }
    private void updateEpipolarTexture()
    {
        if(epipolarTex==null)
        {
            createEpipolarTexture();
        }
        int csKernel=SamplesKernel.FindKernel("UpdateEpipolarTex");
        SamplesKernel.SetTexture(csKernel,"EpipolarTex",epipolarTex); 
        SamplesKernel.SetFloat("LineDensity",epipolarLineDensity);
        SamplesKernel.SetFloat("InitSampleCount",maxEpipolarLineInitPoint);
        SamplesKernel.SetFloat("InterpolateSampleCount",maxEpipolarInterpolatePointEveryStage);
        SamplesKernel.Dispatch(csKernel,epipolarSpaceSizeX/32,epipolarSpaceSizeY/32,1);
    }
    private void DisposeEpipolar()
    {
        epipolarTex=null;
    }
    #endregion
}
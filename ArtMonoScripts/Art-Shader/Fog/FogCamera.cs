using UnityEngine;
[RequireComponent(typeof(Camera)), DisallowMultipleComponent, ExecuteInEditMode]
public class FogCamera : MonoBehaviour {

    [SerializeField]
    private Shader fogShader;
    [SerializeField]
    [Range(512,10240)]
    private int AxisQuality=1024;
    [SerializeField]
    [Range(120,12000)]
    private int AxisWidthQuality=120;
    [SerializeField]
    private Texture2D AxisTexture;
    [SerializeField]
    [Range(0,30f)]
    private float fogDensity=0.4f;
    [SerializeField]
    private float HeightMax;
    [SerializeField]
    private float HeightMin;
    [SerializeField]
    [Range(0.1f,1f)]
    public float DepthMax=0.5f;
    [SerializeField]
    private bool BlurFog=true;
    [SerializeField]
    private bool ContainSky=true;
    [SerializeField]
    private Gradient HeightAxis;
    [SerializeField]
    private Gradient BiHeightAxis;
    [SerializeField]
    private Gradient DepthAxis;
    [SerializeField]
    private Gradient BiDepthAxis;
    [SerializeField]
    private Gradient LightDirAxis;
    [SerializeField]
    private Gradient BiLightDirAxis;
    [SerializeField]
    private Gradient LumianceAxis;
    [SerializeField]
    private Gradient BiLumianceAxis;
    [SerializeField]
    [Range(0.2f,3f)]
    private float blurSize=0.6f;
    [SerializeField]
    [Range(0,4)]
    private int iterations=3;
    [SerializeField]
    [Range(1,8)]
    private int downSample=2;
    private Material mat;
    private Camera cam;
    private void OnEnable() {
        cam=GetComponent<Camera>();
        cam.depthTextureMode|=DepthTextureMode.DepthNormals;
        if(AxisTexture==null)
        {
            ToTexture();
        }
    }
    public void ToTexture()
    {   
        Texture2D t=new Texture2D(AxisWidthQuality,AxisQuality,TextureFormat.ARGB32,false,false);
        for(int i=0;i<AxisQuality;i++)
        {
            for(int j=0;j<AxisWidthQuality/8;j++)
            {
                t.SetPixel(j,i,HeightAxis.Evaluate((i*1f)/AxisQuality));
            }
            for(int j=AxisWidthQuality/8;j<AxisWidthQuality*2/8;j++)
            {
                t.SetPixel(j,i,BiHeightAxis.Evaluate((i*1f)/AxisQuality));
            }
            for(int j=AxisWidthQuality*2/8;j<AxisWidthQuality*3/8;j++)
            {
                t.SetPixel(j,i,LightDirAxis.Evaluate((i*1f)/AxisQuality));
            }
            for(int j=AxisWidthQuality*3/8;j<AxisWidthQuality*4/8;j++)
            {
                t.SetPixel(j,i,BiLightDirAxis.Evaluate((i*1f)/AxisQuality));
            }
            for(int j=AxisWidthQuality*4/8;j<AxisWidthQuality*5/8;j++)
            {
                t.SetPixel(j,i,LumianceAxis.Evaluate((i*1f)/AxisQuality));
            }
            for(int j=AxisWidthQuality*5/8;j<AxisWidthQuality*6/8;j++)
            {
                t.SetPixel(j,i,BiLumianceAxis.Evaluate((i*1f)/AxisQuality));
            }
            for(int j=AxisWidthQuality*6/8;j<AxisWidthQuality*7/8;j++)
            {
                t.SetPixel(j,i,DepthAxis.Evaluate((i*1f)/AxisQuality));
            }
            for(int j=AxisWidthQuality*7/8;j<AxisWidthQuality*8/8;j++)
            {
                t.SetPixel(j,i,BiDepthAxis.Evaluate((i*1f)/AxisQuality));
            }
            //t.SetPixel(1,i,DepthAxis.Evaluate((i*1f)/size));
            //t.SetPixel(2,i,LightDirAxis.Evaluate((i*1f)/size));
        }
        t.Apply();
        AxisTexture=t;
    }
    private void OnRenderImage(RenderTexture src, RenderTexture dest) {
        if(fogShader==null)
        {
            return;
        }
        if(mat==null)
        {
            mat=new Material(fogShader);
        }
        cam=GetComponent<Camera>();
        float dT=DepthMax;
        dT=DepthMax/(cam.farClipPlane/1000f);
        
        mat.SetFloat("_FogDensity",fogDensity);
        mat.SetFloat("_FogHMax",HeightMax);
        mat.SetFloat("_FogHMin",HeightMin);
        mat.SetFloat("_FogDMax",dT);
        mat.SetTexture("_AxisTexture",AxisTexture);
        mat.SetMatrix("_ViewToWorldMat",cam.cameraToWorldMatrix);
        mat.SetFloat("_BlurSize",blurSize);
        if(ContainSky)
        {
            mat.EnableKeyword("_CSKY");
        }
        else
        {
            mat.DisableKeyword("_CSKY");
        }
        if(BlurFog)
        {
            mat.EnableKeyword("_BLURFOG");
            int rtW=src.width/downSample;
            int rtH=src.height/downSample;
            var buffer0=RenderTexture.GetTemporary(rtW,rtH,0,RenderTextureFormat.ARGBHalf);
            buffer0.filterMode=FilterMode.Bilinear;
            for(int i=0;i<iterations;i++)
            {
                var buffer1=RenderTexture.GetTemporary(src.width,src.height,0,RenderTextureFormat.ARGBHalf);
                Graphics.Blit(src,buffer0,mat,0);
                Graphics.Blit(buffer0,buffer1,mat,2);
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0=buffer1;
                buffer1=RenderTexture.GetTemporary(src.width,src.height,0,RenderTextureFormat.ARGBHalf);
                Graphics.Blit(buffer0,buffer1,mat,3);
                mat.SetTexture("_FogBuffer",buffer0);
                Graphics.Blit(src,dest,mat,1);
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0=buffer1;
            }
            RenderTexture.ReleaseTemporary(buffer0);
            
        }
        else
        {
            mat.DisableKeyword("_BLURFOG");
            Graphics.Blit(src,dest,mat,0);
        }
    }

}
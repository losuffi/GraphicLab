using UnityEngine;

public class VolumeCamera : MonoBehaviour
{
    [SerializeField]
    private Material material;
    [SerializeField]
    private Shader BlendShader;
    [SerializeField]
    [Range(1,8)]
    public int downSmple = 2;
    private RenderTexture temp;
    
    private Material blenderMat;
    private int propertySrcID;
    private int resultID;
    private void OnEnable()
    {
        propertySrcID = Shader.PropertyToID("_Randomness");
        resultID =Shader.PropertyToID("ResultTex");
    }
    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        // if (temp == null)
        // {
        //     temp = new RenderTexture(src.width / 2, src.height / 2, 0, RenderTextureFormat.ARGB32);
        //     temp.enableRandomWrite = true;
        //     temp.Create();
        // }
        temp =RenderTexture.GetTemporary((int)(src.width/(float)downSmple),(int)(src.height/(float)downSmple),0,src.format,RenderTextureReadWrite.Default, src.antiAliasing);
        material.SetVector(propertySrcID, new Vector2(Random.value,Random.value));
        Graphics.Blit(src, temp, material);
        if(blenderMat == null)
        {
            blenderMat = new Material(BlendShader);
        }
        blenderMat.SetTexture(resultID,temp);

        Graphics.Blit(src, dest, blenderMat);

        RenderTexture.ReleaseTemporary(temp);
    }
}
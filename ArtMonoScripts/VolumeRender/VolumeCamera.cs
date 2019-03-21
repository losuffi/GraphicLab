using UnityEngine;

public class VolumeCamera : MonoBehaviour
{
    [SerializeField]
    private Material material;
    [SerializeField]
    private Material addCopy;
    private RenderTexture temp;
    private int propertySrcID;
    private void OnEnable()
    {
        propertySrcID = Shader.PropertyToID("_src");
    }
    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        // if (temp == null)
        // {
        //     temp = new RenderTexture(src.width / 2, src.height / 2, 0, RenderTextureFormat.ARGB32);
        //     temp.enableRandomWrite = true;
        //     temp.Create();
        // }
        material.SetTexture(propertySrcID, src);
        Graphics.Blit(src, dest, material);
    }
}
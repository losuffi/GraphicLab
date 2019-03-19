using UnityEngine;

public class VolumeCamera : MonoBehaviour
{
    [SerializeField]
    private Material material;
    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        material.SetTexture("_src", src);
        Graphics.Blit(src, dest, material);
    }
}
using UnityEngine;

public class VolumetricLighttingAgent : MonoBehaviour {
    [SerializeField]
    private VolumetricLightSource lightSource;
    [SerializeField]
    private ComputeShader ScattingKernel;
    [SerializeField]
    private Mesh mesh;

    private RenderTexture mask;
}
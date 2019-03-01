using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ParticleGeneration : MonoBehaviour
{
    [SerializeField]
    private ReferenceParticle referenceParticle;
    [SerializeField]
    private ComputeShader GenerationCS;

    Texture3D OpticalDepthLUT;

    private void OnWillRenderObject()
    {
        transform.localScale*=referenceParticle.standardScale;
    }

}
[System.Serializable]
public struct ReferenceParticle
{
    [SerializeField]
    public float standardScale;
}

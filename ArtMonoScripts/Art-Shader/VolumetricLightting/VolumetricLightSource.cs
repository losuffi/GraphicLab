using UnityEngine;

public class VolumetricLightSource : MonoBehaviour {
    [SerializeField]
    private float Intensity;
    [SerializeField]
    private LightType Type;
    [SerializeField]
    private Light lightobj;
    [SerializeField]
    public float range;
    [SerializeField]
    public float angles;
    public Vector4 v4Pos
    {
        get
        {
            return new Vector4(transform.position.x,transform.position.y,transform.position.z,1/(range*range));
        }
    }
}
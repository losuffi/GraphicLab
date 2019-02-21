using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ScriptableInstancing : MonoBehaviour
{
    static int colorID = Shader.PropertyToID("_Color");
    MaterialPropertyBlock propertyBlock;
    private void OnValidate()
    {
        if (propertyBlock == null)
        {
            propertyBlock = new MaterialPropertyBlock();
        }
        float x = Random.Range(0, 1.0f);
        float y = Random.Range(0, 1.0f);
        float z = Random.Range(0, 1.0f);
        propertyBlock.SetColor(colorID, new Color(x, y, z, 1));
        GetComponent<MeshRenderer>().SetPropertyBlock(propertyBlock);
    }
}

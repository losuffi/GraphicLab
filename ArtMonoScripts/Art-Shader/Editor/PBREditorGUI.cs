using UnityEngine;
using UnityEditor;
public class PBREditorGUI:ShaderGUI
{
    private bool IsBP=false;
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        base.OnGUI(materialEditor,properties);
        Material m= materialEditor.target as Material;
        SetKeyword(m,"_NORMALMAP",m.GetTexture("_BumpMap"));
        SetKeyword(m,"_METALLICGLOSSMAP",m.GetTexture("_MetallicGlossMap"));
        IsBP=m.IsKeywordEnabled("_BPMODEL");
        IsBP=GUILayout.Toggle(IsBP,"BP Model");
        SetKeyword(m,"_BPMODEL",IsBP);
        SetKeyword(m,"_STANDMODEL",!IsBP);
        m.EnableKeyword("SHADOWS_SCREEN");
    }
    private void SetKeyword(Material m,string keyword,bool state)
    {
        if(state)
            m.EnableKeyword(keyword);
        else
            m.DisableKeyword(keyword);
    }
}
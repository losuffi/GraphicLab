using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(FogCamera))]
public class FogCameraEditor : Editor {
    private static FogCamera current;
    public override void OnInspectorGUI() {
        EditorGUI.BeginChangeCheck();
        {
            base.OnInspectorGUI();
        }
        if(GUILayout.Button("RenderInScene"))
        {
            SceneView.onSceneGUIDelegate+=OnSceneView;
        }
        if(GUILayout.Button("UnRenderInScene"))
        {
            SceneView.onSceneGUIDelegate-=OnSceneView;
            Selection.activeObject=current;
            if(current!=null)
            {
                Object.DestroyImmediate(current);
            }
        }
        if(GUILayout.Button("PreRenderGradient"))
        {
            (target as FogCamera).ToTexture();
        }
        if(EditorGUI.EndChangeCheck())
        {
            (target as FogCamera).ToTexture();
        }
    }
    private void OnDisable() {
        SceneView.onSceneGUIDelegate-=OnSceneView;
    }
    void OnSceneView(SceneView sv)
    {
        
        var c= sv.camera;
        Selection.activeObject=c;
        current=c.GetComponent<FogCamera>();
        if(current==null)
        {
            current=c.gameObject.AddComponent<FogCamera>();
        }
        //var gCamera=(target as FogCamera).GetComponent<Camera>();
        EditorUtility.CopySerialized(target,current);
        /*float percent=((c.farClipPlane/gCamera.farClipPlane));
        percent= percent/Mathf.Pow(1.7f, c.fieldOfView-gCamera.fieldOfView);
        current.DepthMax/=percent*/;
    }
}
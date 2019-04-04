using UnityEngine;
using UnityEditor;

public class EditorParticleGeneration : ScriptableWizard
{

    [MenuItem("Graphic Lab/EditorParticleGeneration")]
    private static void MenuEntryCall()
    {
        DisplayWizard<EditorParticleGeneration>("Title");
    }
    private ParticleGeneration entity;
    private RenderTexture a3;
    private void OnGUI()
    {
        entity = EditorGUILayout.ObjectField(entity, typeof(ParticleGeneration), true) as ParticleGeneration;
        if (GUILayout.Button("Test 3D") && entity != null)
        {
            a3 = entity.Test3DTexutureWrite();
        }
        EditorGUILayout.ObjectField(a3, typeof(Texture), true);
    }
    private void OnWizardCreate()
    {

    }
}
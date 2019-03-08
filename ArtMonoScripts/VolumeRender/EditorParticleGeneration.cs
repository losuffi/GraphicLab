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
    private void OnGUI()
    {
        entity = EditorGUILayout.ObjectField(entity, typeof(ParticleGeneration), true) as ParticleGeneration;
        if (GUILayout.Button("Generation") && entity != null)
        {
            Selection.activeObject = entity.Generation();
        }
        if (GUILayout.Button("Save Tex3D") && entity != null)
        {
            entity.SaveGeneration();
        }
    }
    private void OnWizardCreate()
    {

    }
}
using UnityEngine;
using UnityEngine.Experimental.Rendering;
[CreateAssetMenu(menuName = "Pipeline/Custom")]
public class CustomPipelineAsset : RenderPipelineAsset
{
    public CustomPipelineAsset()
    {
    }

    protected override IRenderPipeline InternalCreatePipeline()
    {
        return new CustomPipelineContex();
    }
}

public class CustomPipelineContex : IRenderPipeline
{
    public bool disposed{get{return true;}}

    public void Dispose()
    {

    }

    public void Render(ScriptableRenderContext renderContext, Camera[] cameras)
    {
        foreach(var c in cameras)
        {
            renderContext.SetupCameraProperties(c);
            renderContext.DrawSkybox(c);
            renderContext.Submit();
        }
    }
}
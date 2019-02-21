using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using System.Collections.Generic;
[CreateAssetMenu(menuName = "Pipeline/Custom")]
public class CustomPipelineAsset : RenderPipelineAsset
{
    [SerializeField]
    public bool enableDynamicBatching;
    [SerializeField]
    public bool enableInstancing;
    private CustomPipelineContex contex;
    public CustomPipelineAsset()
    {

    }

    protected override IRenderPipeline InternalCreatePipeline()
    {
        if (contex == null)
        {
            contex = new CustomPipelineContex(this);
            contex.Init();
        }
        return contex;
    }
}

public class CustomPipelineContex : IRenderPipeline
{
    public bool disposed { get { return true; } }
    private CommandBuffer bufTemp;
    private ScriptableCullingParameters cullingParameters;
    private CullResults cull;
    private CustomPipelineAsset asset;
    public CustomPipelineContex(CustomPipelineAsset a)
    {
        asset = a;
    }
    public void Dispose()
    {

    }
    public void Init()
    {
    }
    public void Render(ScriptableRenderContext renderContext, Camera[] cameras)
    {
        foreach (var c in cameras)
        {
            renderContext.SetupCameraProperties(c);
            BufferCommand(renderContext, c);
            CullingAndDraw(renderContext, c);
            renderContext.Submit();
        }
    }
    public void BufferCommand(ScriptableRenderContext contex, Camera cam)
    {
        if(bufTemp==null)
        {
            bufTemp=new CommandBuffer();
            bufTemp.name=cam.name;
        }
        bufTemp.ClearRenderTarget(true, false, cam.backgroundColor);
        contex.ExecuteCommandBuffer(bufTemp);
        bufTemp.Clear();
    }
    public void CullingAndDraw(ScriptableRenderContext context, Camera cam)
    {

        if (!CullResults.GetCullingParameters(cam, out cullingParameters))
        {
            return;
        }
#if UNITY_EDITOR
        if (cam.cameraType == CameraType.SceneView)
            ScriptableRenderContext.EmitWorldGeometryForSceneView(cam);
#endif
        UnityEngine.Profiling.Profiler.BeginSample("GCSource");
        CullResults.Cull(ref cullingParameters, context, ref cull);
        UnityEngine.Profiling.Profiler.EndSample();
        DrawRendererSettings drawSettings = new DrawRendererSettings(cam, new ShaderPassName("CstRP"));
        if (asset.enableDynamicBatching)
            drawSettings.flags = DrawRendererFlags.EnableDynamicBatching;
        if (asset.enableInstancing)
            drawSettings.flags |= DrawRendererFlags.EnableInstancing;
        drawSettings.sorting.flags = SortFlags.CommonOpaque;
        FilterRenderersSettings filterSettings = new FilterRenderersSettings(true) { renderQueueRange = RenderQueueRange.opaque };
        context.DrawRenderers(cull.visibleRenderers, ref drawSettings, filterSettings);
        context.DrawSkybox(cam);
        drawSettings.sorting.flags = SortFlags.CommonTransparent;
        filterSettings.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cull.visibleRenderers, ref drawSettings, filterSettings);
    }
}
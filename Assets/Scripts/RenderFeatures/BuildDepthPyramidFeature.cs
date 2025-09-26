using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BuildDepthPyramidFeature : ScriptableRendererFeature
{
    public RenderPassEvent renderPassEvent;
    public int maxMipLevel = 8;
    private BuildDepthPyramidPass _pyramidFeature;
    public override void Create()
    {
        _pyramidFeature = new BuildDepthPyramidPass();
        _pyramidFeature.maxMipLevel = maxMipLevel;
        _pyramidFeature.renderPassEvent = renderPassEvent;
        
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_pyramidFeature);
    }
}

public class BuildDepthPyramidPass : ScriptableRenderPass
{
    private int _pyramidMaxLevel;
    private RenderTexture pyramidTexture;
    private RenderTexture mipTexture;
    public int maxMipLevel;
    private Material copyMat;
    private int baseSize = 1024;
    private int DepthPyramidID = Shader.PropertyToID("DepthPyramidTex");
    private int ID_DepthTexture = Shader.PropertyToID("_DepthTexture");
    public BuildDepthPyramidPass()
    {
        copyMat = new Material(Shader.Find("Unlit/BakeDepthPyramid"));
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get("BuildDepthPyramid");
        var depthTarget = renderingData.cameraData.renderer.cameraDepthTargetHandle;
        // var h= depthTarget.rt.height;
        // var w = depthTarget.rt.width;
        pyramidTexture = RenderTexture.GetTemporary(baseSize, baseSize, 0, RenderTextureFormat.RGHalf);
        pyramidTexture.filterMode = FilterMode.Point;
        pyramidTexture.autoGenerateMips = false;
        pyramidTexture.useMipMap = true;
        //Graphics.CopyTexture(depthTarget, 0, 0, pyramidTexture, 0, 0);
        RenderTexture lastTexture = null;
        try
        {
            for (int i = 0; i <= maxMipLevel; i++)
            {
                mipTexture = RenderTexture.GetTemporary(baseSize >> i, baseSize >> i, 0, RenderTextureFormat.RGHalf);
                mipTexture.name = "MipTexture";
                if (lastTexture == null)
                {
                    Graphics.Blit(depthTarget.rt, mipTexture);
                }
                else
                {
                    copyMat.SetTexture(ID_DepthTexture, lastTexture);
                    Graphics.Blit(null, mipTexture, copyMat);
                }

                Graphics.CopyTexture(mipTexture, 0, 0, pyramidTexture, 0, i);
                context.ExecuteCommandBuffer(cmd);
                //Graphics.CopyTexture(mipTexture, 0, 0, pyramidTexture, 0, i);
                lastTexture = mipTexture;
            }

            Shader.SetGlobalTexture(DepthPyramidID, pyramidTexture);
            HizManager.staticRT = pyramidTexture;
        }
        finally
        {
            RenderTexture.ReleaseTemporary(lastTexture);
            RenderTexture.ReleaseTemporary(mipTexture);
            CommandBufferPool.Release(cmd);
        }
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        RenderTexture.ReleaseTemporary(pyramidTexture);
        //Debug.Log("FrameCleanup");
    }
    
}

using System.Collections.Generic;
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
    //private RenderTexture mipTexture;
    private List<RenderTexture> listMipTexture;
    public int maxMipLevel;
    private Material copyMat;
    private int baseSize = 1024;
    private int DepthPyramidID = Shader.PropertyToID("_HizDepthTexture");
    private int ID_DepthTexture = Shader.PropertyToID("_DepthTexture");
    public BuildDepthPyramidPass()
    {
        copyMat = new Material(Shader.Find("Unlit/BakeDepthPyramid"));
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get("BuildDepthPyramid");
        var depthTarget = renderingData.cameraData.renderer.cameraDepthTargetHandle;
        pyramidTexture = new RenderTexture(baseSize, baseSize, 0, RenderTextureFormat.RHalf, maxMipLevel + 1);
        pyramidTexture.useMipMap = true;
        pyramidTexture.filterMode = FilterMode.Point;
        RenderTexture lastTexture = null;
        listMipTexture = new List<RenderTexture>();
        try
        {
            for (int i = 0; i <= maxMipLevel; i++)
            {
                var mipTexture = RenderTexture.GetTemporary(baseSize >> i, baseSize >> i, 0, RenderTextureFormat.RHalf);
                mipTexture.name = "MipTexture_"+i;
                listMipTexture.Add(mipTexture);
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
                lastTexture = mipTexture;
            }

            Shader.SetGlobalTexture(DepthPyramidID, pyramidTexture);
            if (HizManager.Ins != null)
            {
                HizManager.Ins.hizTexture = pyramidTexture;
            }
        }
        finally
        {
            RenderTexture.ReleaseTemporary(lastTexture);
            foreach (var miptex in listMipTexture)
            {
                RenderTexture.ReleaseTemporary(miptex);
            }
            CommandBufferPool.Release(cmd);
        }
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        //pyramidTexture.Release();
        pyramidTexture = null;
        //RenderTexture.ReleaseTemporary(pyramidTexture);
        //Debug.Log("FrameCleanup");
    }
    
}

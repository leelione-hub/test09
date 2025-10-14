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
    private int baseSize = 4096;
    private int TexSizeX = 1920;
    private int TexSizeY = 1080;
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
        if (pyramidTexture != null)
        {
            pyramidTexture.Release();
            pyramidTexture = null;
        }
        //RT的格式为RenderTextureFormat.RFloat可以显著增加精准度特别是在距离很大的时候，移动端可以考虑使用RHalf类型，那样最好控制显示距离
        pyramidTexture = new RenderTexture(TexSizeX, TexSizeY, 0, RenderTextureFormat.RFloat, maxMipLevel + 1);
        pyramidTexture.name = "pyramidTexture";
        pyramidTexture.useMipMap = true;
        pyramidTexture.filterMode = FilterMode.Point;
        RenderTexture lastTexture = null;
        listMipTexture = new List<RenderTexture>();
        try
        {   
            for (int i = 0; i <= maxMipLevel; i++)
            {
                var mipTexture = RenderTexture.GetTemporary(TexSizeX >> i, TexSizeY >> i, 0, RenderTextureFormat.RFloat);
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
                //HizManager.Ins.hizComputeShader.SetTexture(0, "_HizDepthTexture", pyramidTexture);
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
        // pyramidTexture.Release();
        // pyramidTexture = null;
        //RenderTexture.ReleaseTemporary(pyramidTexture);
        //Debug.Log("FrameCleanup");
    }
    
}

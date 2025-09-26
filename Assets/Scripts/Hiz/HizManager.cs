using System;
using UnityEngine;
using UnityEngine.Rendering;

public class HizManager : MonoBehaviour
{
    [Header("Hi-Z Settings")]
    public bool enableHizCulling = true;
    public int maxMipLevel = 8; // 最大Mip级别
    public float depthBias = 0.1f; // 深度偏差，防止Z-fighting导致的错误剔除
    
    private Camera mainCamera;
    //public RenderTexture[] hizPyramid;
    public ComputeShader hizComputeShader;
    private CommandBuffer hizCommandBuffer;
    public RenderTexture hizTexture;
    public static RenderTexture staticRT;
    
    // Hi-Z金字塔的尺寸
    private int hizWidth, hizHeight;
    
    void Start()
    {
        mainCamera = Camera.main;
        
        if (mainCamera != null && mainCamera.depthTextureMode == DepthTextureMode.None)
        {
            mainCamera.depthTextureMode = DepthTextureMode.Depth;
        }
        
        InitializeHizPyramid();
        RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
    }


    private void Update()
    {
        hizTexture = staticRT;
    }

    void InitializeHizPyramid()
    {
        
    }

    void OnBeginCameraRendering(ScriptableRenderContext context, Camera camera)
    {
        if (camera != mainCamera || !enableHizCulling)
        {
            return;
        }

        BuildHizPyramid(context);
    }

    void BuildHizPyramid(ScriptableRenderContext context)
    {
        CommandBuffer cmd = CommandBufferPool.Get("Hi-Z Pyramid");
        
        try
        {
           
        }
        finally
        {
            CommandBufferPool.Release(cmd);
        }
    }
    
    
    public int GetMaxMipLevel()
    {
        return maxMipLevel;
    }
    
    void OnDestroy()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
    }
}
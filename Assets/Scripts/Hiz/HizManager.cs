using UnityEngine;
using UnityEngine.Rendering;

public class HizManager : MonoBehaviour
{
    [Header("Hi-Z Settings")]
    public bool enableHizCulling = true;
    public int maxMipLevel = 8; // 最大Mip级别
    public float depthBias = 0.1f; // 深度偏差，防止Z-fighting导致的错误剔除
    
    private Camera mainCamera;
    public RenderTexture[] hizPyramid;
    public ComputeShader hizComputeShader;
    private CommandBuffer hizCommandBuffer;
    
    // Hi-Z金字塔的尺寸
    private int hizWidth, hizHeight;
    
    void Start()
    {
        mainCamera = Camera.main;
        //hizComputeShader = Resources.Load<ComputeShader>("HizCompute");
        
        if (mainCamera.depthTextureMode == DepthTextureMode.None)
        {
            mainCamera.depthTextureMode = DepthTextureMode.Depth;
        }
        
        InitializeHizPyramid();
        SetupCommandBuffer();
    }
    
    void InitializeHizPyramid()
    {
        hizWidth = Mathf.CeilToInt(Screen.width / 2.0f);
        hizHeight = Mathf.CeilToInt(Screen.height / 2.0f);
        
        hizPyramid = new RenderTexture[maxMipLevel];
        
        for (int i = 0; i < maxMipLevel; i++)
        {
            hizPyramid[i] = new RenderTexture(hizWidth >> i, hizHeight >> i, 0, RenderTextureFormat.RFloat)
            {
                enableRandomWrite = true,
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp
            };
            hizPyramid[i].Create();
        }
    }
    
    void SetupCommandBuffer()
    {
        hizCommandBuffer = new CommandBuffer { name = "Hi-Z Pyramid" };
        
        // 将深度缓冲区复制到Hi-Z金字塔的第0级
        hizCommandBuffer.Blit(BuiltinRenderTextureType.Depth, hizPyramid[0]);
        
        // 构建Hi-Z金字塔
        for (int i = 1; i < maxMipLevel; i++)
        {
            int dispatchX = Mathf.CeilToInt(hizPyramid[i].width / 8.0f);
            int dispatchY = Mathf.CeilToInt(hizPyramid[i].height / 8.0f);
            
            hizCommandBuffer.SetComputeTextureParam(hizComputeShader, 0, "SourceTex", hizPyramid[i - 1]);
            hizCommandBuffer.SetComputeTextureParam(hizComputeShader, 0, "ResultTex", hizPyramid[i]);
            hizCommandBuffer.SetComputeIntParam(hizComputeShader, "SourceMip", i - 1);
            hizCommandBuffer.DispatchCompute(hizComputeShader, 0, dispatchX, dispatchY, 1);
        }
        
        mainCamera.AddCommandBuffer(CameraEvent.AfterDepthTexture, hizCommandBuffer);
    }
    
    public RenderTexture[] GetHizPyramid()
    {
        return hizPyramid;
    }
    
    public int GetMaxMipLevel()
    {
        return maxMipLevel;
    }
    
    void OnDestroy()
    {
        if (hizCommandBuffer != null)
        {
            if (mainCamera != null)
            {
                mainCamera.RemoveCommandBuffer(CameraEvent.AfterDepthTexture, hizCommandBuffer);
            }
            hizCommandBuffer.Release();
        }
        
        if (hizPyramid != null)
        {
            foreach (var rt in hizPyramid)
            {
                if (rt != null) rt.Release();
            }
        }
    }
}
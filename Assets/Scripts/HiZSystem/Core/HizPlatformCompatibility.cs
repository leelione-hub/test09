using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace HiZTechnique
{
    /// <summary>
    /// 平台兼容性检测与适配工具
    /// 处理不同平台（PC、Android、iOS、Mac）的差异
    /// </summary>
    public static class HizPlatformCompatibility
    {
        #region 平台检测
        
        /// <summary>
        /// 检测当前平台是否支持HiZ
        /// </summary>
        public static bool IsPlatformSupported()
        {
            // 检查Compute Shader支持
            if (!SystemInfo.supportsComputeShaders)
            {
                Debug.LogWarning("[HiZ] 当前平台不支持Compute Shader，HiZ功能将被禁用");
                return false;
            }
            
            // 检查渲染API
            var graphicsDeviceType = SystemInfo.graphicsDeviceType;
            switch (graphicsDeviceType)
            {
                case GraphicsDeviceType.Direct3D11:
                case GraphicsDeviceType.Direct3D12:
                case GraphicsDeviceType.Vulkan:
                case GraphicsDeviceType.Metal:
                case GraphicsDeviceType.OpenGLCore:
                case GraphicsDeviceType.OpenGLES3:
                    return true;
                    
                case GraphicsDeviceType.OpenGLES2:
                case GraphicsDeviceType.Null:
                    Debug.LogWarning($"[HiZ] 当前图形API {graphicsDeviceType} 不支持HiZ");
                    return false;
                    
                default:
                    Debug.LogWarning($"[HiZ] 未测试的图形API: {graphicsDeviceType}");
                    return true; // 默认允许，但可能会有问题
            }
        }
        
        /// <summary>
        /// 是否是移动端平台
        /// </summary>
        public static bool IsMobilePlatform()
        {
            return Application.isMobilePlatform || 
                   Application.platform == RuntimePlatform.Android ||
                   Application.platform == RuntimePlatform.IPhonePlayer;
        }
        
        /// <summary>
        /// 是否是低端移动设备
        /// </summary>
        public static bool IsLowEndMobileDevice()
        {
            if (!IsMobilePlatform())
                return false;
                
            // 根据系统信息判断设备性能等级
            int shaderLevel = SystemInfo.graphicsShaderLevel;
            int maxTextureSize = SystemInfo.maxTextureSize;
            int processorCount = SystemInfo.processorCount;
            int systemMemorySize = SystemInfo.systemMemorySize;
            
            // 低端设备特征
            if (shaderLevel < 35) return true; // 低于ES 3.0
            if (maxTextureSize < 2048) return true;
            if (processorCount <= 2) return true;
            if (systemMemorySize < 2048) return true; // 2GB以下内存
            
            // 检查特定的低端GPU
            string gpuName = SystemInfo.graphicsDeviceName.ToLower();
            string[] lowEndGPUs = new[]
            {
                "mali-400", "mali-450", "mali-t720", "mali-t820",
                "adreno 305", "adreno 306", "adreno 308",
                "powervr", "geforce 6150"
            };
            
            foreach (var lowEndGPU in lowEndGPUs)
            {
                if (gpuName.Contains(lowEndGPU))
                    return true;
            }
            
            return false;
        }
        
        /// <summary>
        /// 是否是使用Reversed Z的平台
        /// </summary>
        public static bool UsesReversedZ()
        {
            // Reversed Z通常在以下情况使用：
            // 1. Direct3D 11+ (Unity默认开启)
            // 2. Vulkan
            // 3. Metal
            // 4. 开启了Reversed Z的OpenGL
            
            var graphicsDeviceType = SystemInfo.graphicsDeviceType;
            
            switch (graphicsDeviceType)
            {
                case GraphicsDeviceType.Direct3D11:
                case GraphicsDeviceType.Direct3D12:
                case GraphicsDeviceType.Vulkan:
                case GraphicsDeviceType.Metal:
                    return true;
                    
                case GraphicsDeviceType.OpenGLCore:
                case GraphicsDeviceType.OpenGLES3:
                    // OpenGL通常不使用Reversed Z，但可以通过GL_CLIP_CONTROL扩展实现
                    // 这里简化处理，假设不使用
                    return false;
                    
                default:
                    return false;
            }
        }
        
        #endregion
        
        #region 设置自动适配
        
        /// <summary>
        /// 根据平台自动调整设置
        /// </summary>
        public static void AdjustSettingsForPlatform(HizSettings settings)
        {
            if (!settings.autoAdjustForPlatform)
                return;
                
            if (IsLowEndMobileDevice())
            {
                ApplyLowEndMobileSettings(settings);
            }
            else if (IsMobilePlatform())
            {
                ApplyMobileSettings(settings);
            }
            else
            {
                ApplyDesktopSettings(settings);
            }
            
            // 根据图形API调整
            AdjustForGraphicsAPI(settings);
        }
        
        /// <summary>
        /// 应用桌面端设置
        /// </summary>
        private static void ApplyDesktopSettings(HizSettings settings)
        {
            settings.maxMipLevel = Mathf.Max(settings.maxMipLevel, 8);
            settings.baseResolution = Mathf.Max(settings.baseResolution, 2048);
            settings.depthFormat = HizDepthFormat.RFloat;
            settings.cullingFrameInterval = 1;
            Debug.Log("[HiZ] 已应用桌面端优化设置");
        }
        
        /// <summary>
        /// 应用移动端设置
        /// </summary>
        private static void ApplyMobileSettings(HizSettings settings)
        {
            settings.maxMipLevel = Mathf.Min(settings.maxMipLevel, 8);
            settings.baseResolution = Mathf.Min(settings.baseResolution, 1024);
            settings.depthFormat = HizDepthFormat.RHalf;
            settings.cullingFrameInterval = Mathf.Max(settings.cullingFrameInterval, 1);
            Debug.Log("[HiZ] 已应用移动端优化设置");
        }
        
        /// <summary>
        /// 应用低端移动端设置
        /// </summary>
        private static void ApplyLowEndMobileSettings(HizSettings settings)
        {
            if (!settings.lowEndMobileFallback)
                return;
                
            settings.enableHiz = false; // 低端设备默认禁用
            settings.maxMipLevel = 4;
            settings.baseResolution = 512;
            settings.depthFormat = HizDepthFormat.RHalf;
            settings.cullingFrameInterval = 2;
            settings.forceDisableComputeShader = false; // 仍然尝试使用Compute Shader
            
            Debug.Log("[HiZ] 检测到低端移动设备，已应用降级设置");
        }
        
        /// <summary>
        /// 根据图形API调整设置
        /// </summary>
        private static void AdjustForGraphicsAPI(HizSettings settings)
        {
            var graphicsDeviceType = SystemInfo.graphicsDeviceType;
            
            switch (graphicsDeviceType)
            {
                case GraphicsDeviceType.OpenGLES3:
                    // OpenGL ES 3.0对RFloat支持可能有问题，使用RHalf
                    if (IsMobilePlatform())
                    {
                        settings.depthFormat = HizDepthFormat.RHalf;
                    }
                    break;
                    
                case GraphicsDeviceType.Metal:
                    // Metal优化
                    settings.depthFormat = HizDepthFormat.RHalf;
                    break;
            }
        }
        
        #endregion
        
        #region 深度处理
        
        /// <summary>
        /// 在深度比较中使用的初始值（用于Reversed Z检测）
        /// </summary>
        public static float GetInitialDepthValue()
        {
            return UsesReversedZ() ? 0f : 1f;
        }
        
        /// <summary>
        /// 深度比较函数
        /// 返回两个深度值中"更远"的那个
        /// </summary>
        public static float CompareDepth(float depth1, float depth2)
        {
            if (UsesReversedZ())
            {
                // Reversed Z: 较小的值更远
                return Mathf.Min(depth1, depth2);
            }
            else
            {
                // 正常Z: 较大的值更远
                return Mathf.Max(depth1, depth2);
            }
        }
        
        /// <summary>
        /// 深度比较运算符（用于Shader关键字）
        /// </summary>
        public static string GetDepthCompareKeyword()
        {
            return UsesReversedZ() ? "HIZ_REVERSED_Z" : "HIZ_NORMAL_Z";
        }
        
        #endregion
        
        #region 资源格式转换
        
        /// <summary>
        /// 获取对应的RenderTextureFormat
        /// </summary>
        public static RenderTextureFormat GetRenderTextureFormat(HizDepthFormat format)
        {
            switch (format)
            {
                case HizDepthFormat.RFloat:
                    return RenderTextureFormat.RFloat;
                case HizDepthFormat.RHalf:
                    return RenderTextureFormat.RHalf;
                case HizDepthFormat.R32:
                    return RenderTextureFormat.RInt;
                default:
                    return RenderTextureFormat.RFloat;
            }
        }
        
        /// <summary>
        /// 获取对应的GraphicsFormat
        /// </summary>
        public static GraphicsFormat GetGraphicsFormat(HizDepthFormat format)
        {
            switch (format)
            {
                case HizDepthFormat.RFloat:
                    return GraphicsFormat.R32_SFloat;
                case HizDepthFormat.RHalf:
                    return GraphicsFormat.R16_SFloat;
                case HizDepthFormat.R32:
                    return GraphicsFormat.R32_UInt;
                default:
                    return GraphicsFormat.R32_SFloat;
            }
        }
        
        #endregion
    }
}

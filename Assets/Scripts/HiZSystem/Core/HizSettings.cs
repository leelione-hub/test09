using System;
using UnityEngine;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ系统配置类
    /// 包含所有可配置的参数，支持序列化保存
    /// </summary>
    [Serializable]
    public class HizSettings
    {
        [Header("基本设置")]
        [Tooltip("是否启用HiZ系统")]
        public bool enableHiz = true;
        
        [Tooltip("运行时动态开关（可用于调试或低端设备降级）")]
        public bool runtimeToggle = true;
        
        [Header("深度金字塔设置")]
        [Tooltip("深度金字塔最大Mip级别")]
        [Range(4, 12)]
        public int maxMipLevel = 8;
        
        [Tooltip("深度金字塔基础分辨率")]
        public int baseResolution = 1024;
        
        [Tooltip("深度纹理格式（移动端建议使用RHalf）")]
        public HizDepthFormat depthFormat = HizDepthFormat.RFloat;
        
        [Header("剔除设置")]
        [Tooltip("深度偏差，用于防止Z-fighting导致的错误剔除")]
        [Range(0f, 0.5f)]
        public float depthBias = 0.01f;
        
        [Tooltip("每帧最大剔除对象数")]
        [Range(64, 4096)]
        public int maxInstancesPerFrame = 1024;
        
        [Tooltip("剔除频率（每N帧执行一次剔除）")]
        [Range(1, 10)]
        public int cullingFrameInterval = 1;
        
        [Tooltip("视锥体剔除扩展范围")]
        [Range(0f, 10f)]
        public float frustumPadding = 1.0f;
        
        [Header("平台适配")]
        [Tooltip("自动检测平台能力并调整设置")]
        public bool autoAdjustForPlatform = true;
        
        [Tooltip("低端移动设备降级模式")]
        public bool lowEndMobileFallback = true;
        
        [Tooltip("强制禁用Compute Shader（某些低端设备可能不支持）")]
        public bool forceDisableComputeShader = false;
        
        [Header("性能监控")]
        [Tooltip("启用性能统计")]
        public bool enableProfiling = false;
        
        [Tooltip("统计采样帧数")]
        [Range(10, 300)]
        public int profilingFrameCount = 60;
        
        [Header("Debug")]
        [Tooltip("启用Debug可视化")]
        public bool enableDebug = false;
        
        [Tooltip("Debug显示深度金字塔的Mip级别")]
        [Range(0, 12)]
        public int debugMipLevel = 0;
        
        [Tooltip("显示剔除包围盒")]
        public bool showBoundingBoxes = false;
        
        [Tooltip("显示被剔除的对象（红色）和保留的对象（绿色）")]
        public bool showCullingResult = false;
        
        // 事件：设置变更时触发
        public event Action OnSettingsChanged;
        
        /// <summary>
        /// 触发设置变更事件
        /// </summary>
        public void NotifyChanged()
        {
            OnSettingsChanged?.Invoke();
        }
        
        /// <summary>
        /// 验证设置是否有效
        /// </summary>
        public bool Validate()
        {
            if (baseResolution < 256) baseResolution = 256;
            if (baseResolution > 4096) baseResolution = 4096;
            if (maxMipLevel < 4) maxMipLevel = 4;
            if (maxMipLevel > 12) maxMipLevel = 12;
            if (cullingFrameInterval < 1) cullingFrameInterval = 1;
            if (depthBias < 0) depthBias = 0;
            return true;
        }
        
        /// <summary>
        /// 复制设置
        /// </summary>
        public HizSettings Clone()
        {
            return new HizSettings
            {
                enableHiz = this.enableHiz,
                runtimeToggle = this.runtimeToggle,
                maxMipLevel = this.maxMipLevel,
                baseResolution = this.baseResolution,
                depthFormat = this.depthFormat,
                depthBias = this.depthBias,
                maxInstancesPerFrame = this.maxInstancesPerFrame,
                cullingFrameInterval = this.cullingFrameInterval,
                frustumPadding = this.frustumPadding,
                autoAdjustForPlatform = this.autoAdjustForPlatform,
                lowEndMobileFallback = this.lowEndMobileFallback,
                forceDisableComputeShader = this.forceDisableComputeShader,
                enableProfiling = this.enableProfiling,
                profilingFrameCount = this.profilingFrameCount,
                enableDebug = this.enableDebug,
                debugMipLevel = this.debugMipLevel,
                showBoundingBoxes = this.showBoundingBoxes,
                showCullingResult = this.showCullingResult
            };
        }
    }
    
    /// <summary>
    /// 深度纹理格式枚举
    /// </summary>
    public enum HizDepthFormat
    {
        RFloat,     // 32位浮点，精度最高
        RHalf,      // 16位浮点，移动端推荐
        R32,        // 32位整数
    }
    
    /// <summary>
    /// HiZ系统运行状态
    /// </summary>
    public enum HizSystemState
    {
        Disabled,           // 完全禁用
        Initializing,       // 初始化中
        Ready,              // 就绪但未激活
        Active,             // 正常运行
        Error,              // 发生错误
        PlatformNotSupported, // 平台不支持
    }
    
    /// <summary>
    /// 剔除结果统计
    /// </summary>
    [Serializable]
    public class HizCullingStats
    {
        public int totalInstances;
        public int visibleInstances;
        public int culledByFrustum;
        public int culledByHiz;
        public float cullingTimeMs;
        public int frameCount;
        
        public float CullingRatio => totalInstances > 0 ? (float)(culledByFrustum + culledByHiz) / totalInstances : 0f;
        public float VisibleRatio => totalInstances > 0 ? (float)visibleInstances / totalInstances : 0f;
        
        public void Reset()
        {
            totalInstances = 0;
            visibleInstances = 0;
            culledByFrustum = 0;
            culledByHiz = 0;
            cullingTimeMs = 0f;
        }
    }
}

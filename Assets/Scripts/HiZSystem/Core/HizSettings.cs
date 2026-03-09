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
        
        [Header("平台适配")]
        [Tooltip("自动检测平台能力并调整设置")]
        public bool autoAdjustForPlatform = true;
        
        [Tooltip("低端移动设备降级模式")]
        public bool lowEndMobileFallback = true;
        
        [Tooltip("强制禁用Compute Shader（某些低端设备可能不支持）")]
        public bool forceDisableComputeShader = false;
        
        [Header("Debug")]
        [Tooltip("启用调试日志")]
        public bool enableDebug = false;
        
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
                autoAdjustForPlatform = this.autoAdjustForPlatform,
                lowEndMobileFallback = this.lowEndMobileFallback,
                forceDisableComputeShader = this.forceDisableComputeShader,
                enableDebug = this.enableDebug
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
    
}

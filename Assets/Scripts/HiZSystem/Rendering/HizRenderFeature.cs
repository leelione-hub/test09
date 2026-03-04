using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using ProfilingScope = UnityEngine.Rendering.ProfilingScope;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ URP Render Feature
    /// 在渲染管中集成HiZ深度金字塔生成
    /// </summary>
    public class HizRenderFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class HizRenderFeatureSettings
        {
            [Tooltip("渲染事件时机")]
            public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
            
            [Tooltip("是否只在主相机上执行")]
            public bool mainCameraOnly = true;
            
            [Tooltip("是否支持场景视图")]
            public bool supportSceneView = false;
        }
        
        public HizRenderFeatureSettings settings = new HizRenderFeatureSettings();
        
        private HizRenderPass _renderPass;
        private bool _isEnabled = true;
        
        public override void Create()
        {
            _renderPass = new HizRenderPass(settings)
            {
                renderPassEvent = settings.renderPassEvent
            };
        }
        
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (!_isEnabled)
                return;
            
            // 检查相机类型
            if (settings.mainCameraOnly)
            {
                var camera = renderingData.cameraData.camera;
                if (camera.cameraType != CameraType.Game && 
                    camera.cameraType != CameraType.SceneView)
                {
                    return;
                }
                
                if (camera.cameraType == CameraType.SceneView && !settings.supportSceneView)
                {
                    return;
                }
                
                // 检查是否是主相机
                if (camera != Camera.main)
                {
                    return;
                }
            }
            
            // 检查HiZ系统状态
            var hizSystem = HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
                return;
            
            // 设置并添加Render Pass
            if (_renderPass.Setup(hizSystem.GetDepthPyramid()))
            {
                renderer.EnqueuePass(_renderPass);
            }
        }
        
        /// <summary>
        /// 启用/禁用Render Feature
        /// </summary>
        public void SetEnabled(bool enabled)
        {
            _isEnabled = enabled;
        }
    }
    
    /// <summary>
    /// HiZ渲染Pass
    /// </summary>
    public class HizRenderPass : ScriptableRenderPass
    {
        private HizRenderFeature.HizRenderFeatureSettings _settings;
        private HizDepthPyramid _depthPyramid;
        private ProfilingSampler _profilingSampler;
        
        public HizRenderPass(HizRenderFeature.HizRenderFeatureSettings settings)
        {
            _settings = settings;
            _profilingSampler = new ProfilingSampler("HiZ Depth Pyramid");
        }
        
        public bool Setup(HizDepthPyramid depthPyramid)
        {
            _depthPyramid = depthPyramid;
            return _depthPyramid != null && _depthPyramid.IsInitialized;
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_depthPyramid == null || !_depthPyramid.IsInitialized)
            {
                return;
            }
            
            var camera = renderingData.cameraData.camera;
            
            // 获取相机深度纹理
            var depthTexture = GetCameraDepthTexture(ref renderingData);
            if (depthTexture == null)
            {
                return;
            }
            
            CommandBuffer cmd = CommandBufferPool.Get("HiZ Depth Pyramid Pass");
            
            using (new ProfilingScope(cmd, _profilingSampler))
            {
                // 构建深度金字塔
                _depthPyramid.BuildDepthPyramid(cmd, depthTexture);
            }
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        
        /// <summary>
        /// 获取相机深度纹理
        /// </summary>
        private RenderTexture GetCameraDepthTexture(ref RenderingData renderingData)
        {
            // 尝试从UniversalRenderer获取深度纹理
            #if UNITY_2022_1_OR_NEWER
            var depthTextureHandle = renderingData.cameraData.renderer.cameraDepthTargetHandle;
            if (!depthTextureHandle.IsUnityNull())
            {
                var rt = depthTextureHandle.rt;
                if (rt != null)
                {
                    return rt;
                }
            }
            #else
            // 旧版本Unity使用不同的API
            var renderer = renderingData.cameraData.renderer as UniversalRenderer;
            if (renderer != null)
            {
                // 通过反射获取深度纹理
                var depthTexture = GetDepthTextureViaReflection(renderer);
                if (depthTexture != null)
                {
                    return depthTexture;
                }
            }
            #endif
            
            // 回退：使用着色器全局纹理
            var globalDepth = Shader.GetGlobalTexture("_CameraDepthTexture") as RenderTexture;
            if (globalDepth != null)
            {
                return globalDepth;
            }
            
            return null;
        }
        
        #if !UNITY_2022_1_OR_NEWER
        /// <summary>
        /// 通过反射获取深度纹理（兼容旧版本）
        /// </summary>
        private RenderTexture GetDepthTextureViaReflection(UniversalRenderer renderer)
        {
            try
            {
                var property = renderer.GetType().GetProperty("DepthTexture",
                    System.Reflection.BindingFlags.NonPublic |
                    System.Reflection.BindingFlags.Instance);
                
                if (property != null)
                {
                    return property.GetValue(renderer) as RenderTexture;
                }
                
                // 尝试字段
                var field = renderer.GetType().GetField("m_DepthTexture",
                    System.Reflection.BindingFlags.NonPublic |
                    System.Reflection.BindingFlags.Instance);
                
                if (field != null)
                {
                    var handle = field.GetValue(renderer);
                    if (handle != null)
                    {
                        var rtField = handle.GetType().GetField("rt");
                        if (rtField != null)
                        {
                            return rtField.GetValue(handle) as RenderTexture;
                        }
                    }
                }
            }
            catch (System.Exception e)
            {
                Debug.LogWarning($"[HiZ] 无法通过反射获取深度纹理: {e.Message}");
            }
            
            return null;
        }
        #endif
    }
}

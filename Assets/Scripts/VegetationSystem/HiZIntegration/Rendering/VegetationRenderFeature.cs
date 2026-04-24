using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;
using ProfilingScope = UnityEngine.Rendering.ProfilingScope;

namespace VegetationSystem.HiZIntegration
{
    /// <summary>
    /// 将植被渲染注入 URP RenderPass，避免在 MonoBehaviour.Update 中直接绘制。
    /// </summary>
    public class VegetationRenderFeature : ScriptableRendererFeature
    {
        public static bool IsAvailable { get; private set; }

        [System.Serializable]
        public class VegetationRenderFeatureSettings
        {
            [Tooltip("渲染事件时机")]
            public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;

            [Tooltip("是否只在主相机上执行")]
            public bool mainCameraOnly = true;

            [Tooltip("是否支持场景视图")]
            public bool supportSceneView = false;
            public bool runInEditMode = false;
            public bool overrideCameraDepthTexture = true;
        }

        public VegetationRenderFeatureSettings settings = new VegetationRenderFeatureSettings();

        private VegetationRenderPass _renderPass;
        private VegetationDepthCopyPass _depthCopyPass;
        private VegetationDepthBindPass _depthBindPass;
        private Material _copyDepthMaterial;

        private bool _subscribedToBeginCameraRendering;

        public override void Create()
        {
            IsAvailable = true;
            _renderPass = new VegetationRenderPass();
            _renderPass.renderPassEvent = settings.renderPassEvent;

            EnsureCopyDepthResources();
            if (_copyDepthMaterial != null)
            {
                var depthCopyEvent = (RenderPassEvent)Mathf.Min((int)settings.renderPassEvent + 1, (int)RenderPassEvent.BeforeRenderingPostProcessing);
                _depthCopyPass = new VegetationDepthCopyPass(depthCopyEvent, _copyDepthMaterial);
                _depthBindPass = new VegetationDepthBindPass((RenderPassEvent)Mathf.Min((int)depthCopyEvent + 1, (int)RenderPassEvent.BeforeRenderingPostProcessing));
            }

            if (!_subscribedToBeginCameraRendering)
            {
                RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
                _subscribedToBeginCameraRendering = true;
            }
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (!Application.isPlaying && !settings.runInEditMode)
            {
                return;
            }

            var camera = renderingData.cameraData.camera;
            if (camera == null)
            {
                return;
            }

            if (renderingData.cameraData.isPreviewCamera)
            {
                return;
            }

            if (settings.mainCameraOnly)
            {
                if (camera.cameraType != CameraType.Game && camera.cameraType != CameraType.SceneView)
                {
                    return;
                }

                if (camera.cameraType == CameraType.SceneView && !settings.supportSceneView)
                {
                    return;
                }

                if (camera.cameraType == CameraType.Game && Camera.main != null && camera != Camera.main)
                {
                    return;
                }
            }

            if (camera.cameraType == CameraType.SceneView && !renderingData.cameraData.resolveFinalTarget)
            {
                return;
            }

            renderer.EnqueuePass(_renderPass);

            if (settings.overrideCameraDepthTexture && _depthCopyPass != null && _depthBindPass != null)
            {
                renderer.EnqueuePass(_depthCopyPass);
                renderer.EnqueuePass(_depthBindPass);
            }
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            if (!Application.isPlaying && !settings.runInEditMode)
            {
                return;
            }

            if (!settings.overrideCameraDepthTexture || _depthCopyPass == null || _depthBindPass == null)
            {
                return;
            }

            _depthCopyPass.Setup(renderer.cameraDepthTargetHandle, renderingData.cameraData.cameraTargetDescriptor);
            _depthBindPass.Setup(_depthCopyPass.IsConfigured ? _depthCopyPass.OutputHandle : null);
        }

        protected override void Dispose(bool disposing)
        {
            IsAvailable = false;
            if (_subscribedToBeginCameraRendering)
            {
                RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
                _subscribedToBeginCameraRendering = false;
            }

            _depthCopyPass?.Dispose();
            _depthCopyPass = null;
            _depthBindPass = null;

            if (_copyDepthMaterial != null)
            {
                CoreUtils.Destroy(_copyDepthMaterial);
                _copyDepthMaterial = null;
            }

            base.Dispose(disposing);
        }

        private void EnsureCopyDepthResources()
        {
            if (_copyDepthMaterial != null)
            {
                return;
            }

            Shader copyDepthShader = Shader.Find("Hidden/Universal Render Pipeline/CopyDepth");
            if (copyDepthShader == null)
            {
                Debug.LogError("[VegetationHiZ] Cannot find URP CopyDepth shader. Camera depth override will be disabled.");
                return;
            }

            _copyDepthMaterial = CoreUtils.CreateEngineMaterial(copyDepthShader);
        }

        private void OnBeginCameraRendering(ScriptableRenderContext context, Camera camera)
        {
            if (!isActive)
            {
                return;
            }

            if (!Application.isPlaying && !settings.runInEditMode)
            {
                return;
            }

            if (camera == null)
            {
                return;
            }

            if (!(camera.cameraType == CameraType.Game || camera.cameraType == CameraType.SceneView))
            {
                return;
            }

            if (settings.mainCameraOnly && Camera.main != null && camera != Camera.main)
            {
                return;
            }

            var vegetationSystems = Object.FindObjectsByType<VegetationSystemObject>(FindObjectsSortMode.None);
            if (vegetationSystems == null || vegetationSystems.Length == 0)
            {
                return;
            }

            for (int i = 0; i < vegetationSystems.Length; i++)
            {
                var system = vegetationSystems[i];
                if (system == null || !system.isActiveAndEnabled || !system.EnableVegetationSystem)
                {
                    continue;
                }

                if (!system.UsesRenderFeatureRendering)
                {
                    continue;
                }
                
                system.ExecuteCullingForRenderPass(camera);
                system.SubmitShadowCasters();
            }
        }
    }

    public class VegetationRenderPass : ScriptableRenderPass
    {
        private readonly ProfilingSampler _profilingSampler =
            new ProfilingSampler("Vegetation HiZ Culling and Render");

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!Application.isPlaying)
            {
                return;
            }

            var camera = renderingData.cameraData.camera;
            if (camera == null)
            {
                return;
            }

            var vegetationSystems = Object.FindObjectsByType<VegetationSystemObject>(FindObjectsSortMode.None);
            if (vegetationSystems == null || vegetationSystems.Length == 0)
            {
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get("Vegetation Render Pass");
            try
            {
                using (new ProfilingScope(cmd, _profilingSampler))
                {
                    for (int i = 0; i < vegetationSystems.Length; i++)
                    {
                        var system = vegetationSystems[i];
                        if (system == null || !system.isActiveAndEnabled || !system.EnableVegetationSystem)
                        {
                            continue;
                        }
                        if (!system.UsesRenderFeatureRendering)
                        {
                            continue;
                        }
                        system.ExecuteCullingForRenderPass(camera);
                        system.RenderWithCommandBuffer(cmd);
                    }
                }
                context.ExecuteCommandBuffer(cmd);
            }
            finally
            {
                CommandBufferPool.Release(cmd);
            }
        }
    }

    public class VegetationDepthCopyPass : CopyDepthPass
    {
        private RTHandle _outputHandle;
        private RenderTextureDescriptor _descriptor;
        private bool _isConfigured;

        public VegetationDepthCopyPass(RenderPassEvent evt, Material copyDepthMaterial)
            : base(evt, copyDepthMaterial)
        {
        }

        public RTHandle OutputHandle => _outputHandle;
        public bool IsConfigured => _isConfigured;

        public void Setup(RTHandle source, RenderTextureDescriptor cameraDescriptor)
        {
            _isConfigured = false;

            if (source == null)
            {
                return;
            }

            _descriptor = cameraDescriptor;
            _descriptor.graphicsFormat = GraphicsFormat.R32_SFloat;
            _descriptor.depthStencilFormat = GraphicsFormat.None;
            _descriptor.msaaSamples = 1;
            _descriptor.depthBufferBits = 0;
            _descriptor.bindMS = false;

            RenderingUtils.ReAllocateIfNeeded(
                ref _outputHandle,
                _descriptor,
                FilterMode.Point,
                TextureWrapMode.Clamp,
                name: "_VegetationOverriddenCameraDepthTexture");

            base.Setup(source, _outputHandle);
            _isConfigured = true;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!_isConfigured || _outputHandle == null)
            {
                return;
            }

            base.Execute(context, ref renderingData);
        }

        public void Dispose()
        {
            if (_outputHandle != null)
            {
                RTHandles.Release(_outputHandle);
                _outputHandle = null;
            }

            _isConfigured = false;
        }
    }

    public class VegetationDepthBindPass : ScriptableRenderPass
    {
        private static readonly int CameraDepthTextureId = Shader.PropertyToID("_CameraDepthTexture");
        private RTHandle _source;

        public VegetationDepthBindPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
        }

        public void Setup(RTHandle source)
        {
            _source = source;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_source == null)
            {
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get("Bind Vegetation Camera Depth");
            try
            {
                cmd.SetGlobalTexture(CameraDepthTextureId, _source.nameID);
                context.ExecuteCommandBuffer(cmd);
            }
            finally
            {
                CommandBufferPool.Release(cmd);
            }
        }
    }
}

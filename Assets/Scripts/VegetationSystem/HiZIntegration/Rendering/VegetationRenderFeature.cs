using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using ProfilingScope = UnityEngine.Rendering.ProfilingScope;

namespace VegetationSystem.HiZIntegration
{
    /// <summary>
    /// 将植被渲染注入 URP RenderPass，避免在 MonoBehaviour.Update 中直接绘制。
    /// </summary>
    public class VegetationRenderFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class VegetationRenderFeatureSettings
        {
            [Tooltip("渲染事件时机")]
            public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;

            [Tooltip("是否只在主相机上执行")]
            public bool mainCameraOnly = true;

            [Tooltip("是否支持场景视图")]
            public bool supportSceneView = false;
        }

        public VegetationRenderFeatureSettings settings = new VegetationRenderFeatureSettings();

        private VegetationRenderPass _renderPass;
        private bool _subscribedToBeginCameraRendering;

        public override void Create()
        {
            _renderPass = new VegetationRenderPass();
            _renderPass.renderPassEvent = settings.renderPassEvent;

            if (!_subscribedToBeginCameraRendering)
            {
                RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
                _subscribedToBeginCameraRendering = true;
            }
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
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
        }

        protected override void Dispose(bool disposing)
        {
            if (_subscribedToBeginCameraRendering)
            {
                RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
                _subscribedToBeginCameraRendering = false;
            }

            base.Dispose(disposing);
        }

        private void OnBeginCameraRendering(ScriptableRenderContext context, Camera camera)
        {
            if (!isActive)
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

            var vegetationSystems = Object.FindObjectsByType<VegetationSystemObjectHiZ>(FindObjectsSortMode.None);
            if (vegetationSystems == null || vegetationSystems.Length == 0)
            {
                return;
            }

            for (int i = 0; i < vegetationSystems.Length; i++)
            {
                var system = vegetationSystems[i];
                if (system == null || !system.isActiveAndEnabled)
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
            var camera = renderingData.cameraData.camera;
            if (camera == null)
            {
                return;
            }

            var vegetationSystems = Object.FindObjectsByType<VegetationSystemObjectHiZ>(FindObjectsSortMode.None);
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
                        if (system == null || !system.isActiveAndEnabled)
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
}

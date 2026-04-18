using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Project.Rendering
{
    public sealed class ScreenSpaceSSSRendererFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public sealed class Settings
        {
            public Shader compositeShader;
            public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
            public bool applyToSceneView = true;
            public LayerMask layerMask = ~0;
            [Range(1, 4)] public int downsample = 1;
            public FilterMode filterMode = FilterMode.Bilinear;

            [Header("Blur")]
            [Range(0.5f, 8f)] public float blurRadius = 2f;
            [Range(0.1f, 16f)] public float depthFalloff = 4f;
            [Range(0f, 2f)] public float compositeIntensity = 1f;
            [Range(0f, 1f)] public float maskThreshold = 0.01f;
        }

        private const string ShaderName = "Hidden/Lighting/ScreenSpaceSSS";

        [SerializeField] private Settings settings = new Settings();

        private Material _material;
        private ScreenSpaceSSSPass _pass;

        public override void Create()
        {
            if (settings.compositeShader == null)
            {
                settings.compositeShader = Shader.Find(ShaderName);
            }

            if (settings.compositeShader != null && (_material == null || _material.shader != settings.compositeShader))
            {
                CoreUtils.Destroy(_material);
                _material = CoreUtils.CreateEngineMaterial(settings.compositeShader);
            }

            _pass ??= new ScreenSpaceSSSPass();
            _pass.renderPassEvent = settings.renderPassEvent;
            _pass.SetMaterial(_material);
            _pass.SetSettings(settings);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            _pass?.SetTargets(renderer.cameraColorTargetHandle, renderer.cameraDepthTargetHandle);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (_material == null || _pass == null)
            {
                return;
            }

            Camera camera = renderingData.cameraData.camera;
            if (camera == null || renderingData.cameraData.isPreviewCamera)
            {
                return;
            }

            if (camera.cameraType == CameraType.SceneView && !settings.applyToSceneView)
            {
                return;
            }

            if (camera.cameraType != CameraType.Game && camera.cameraType != CameraType.SceneView)
            {
                return;
            }

            renderer.EnqueuePass(_pass);
        }

        protected override void Dispose(bool disposing)
        {
            _pass?.Dispose();
            _pass = null;
            CoreUtils.Destroy(_material);
            _material = null;
        }

        private sealed class ScreenSpaceSSSPass : ScriptableRenderPass
        {
            private static readonly int MaskTextureId = Shader.PropertyToID("_ScreenSpaceSSSMaskTexture");
            private static readonly int SceneTextureId = Shader.PropertyToID("_ScreenSpaceSSSSceneTexture");
            private static readonly int Params0Id = Shader.PropertyToID("_ScreenSpaceSSSParams0");
            private static readonly ProfilingSampler ProfilingSampler = new("Screen Space SSS");

            private readonly List<ShaderTagId> _shaderTagIds = new();

            private Material _material;
            private Settings _settings;
            private RTHandle _source;
            private RTHandle _depth;
            private RTHandle _maskTexture;
            private RTHandle _tempA;
            private RTHandle _tempB;
            private RTHandle _sceneCopy;

            public ScreenSpaceSSSPass()
            {
                _shaderTagIds.Add(new ShaderTagId("SSSMask"));
            }

            public void SetMaterial(Material material) => _material = material;

            public void SetSettings(Settings settings)
            {
                _settings = settings;
                ConfigureInput(ScriptableRenderPassInput.Depth);
            }

            public void SetTargets(RTHandle source, RTHandle depth)
            {
                _source = source;
                _depth = depth;
            }

            public void Dispose()
            {
                _maskTexture?.Release();
                _tempA?.Release();
                _tempB?.Release();
                _sceneCopy?.Release();
                _maskTexture = null;
                _tempA = null;
                _tempB = null;
                _sceneCopy = null;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                if (_material == null)
                {
                    return;
                }

                RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
                descriptor.depthBufferBits = 0;
                descriptor.msaaSamples = 1;

                RenderTextureDescriptor blurDescriptor = descriptor;
                blurDescriptor.width = Mathf.Max(1, blurDescriptor.width / Mathf.Max(1, _settings.downsample));
                blurDescriptor.height = Mathf.Max(1, blurDescriptor.height / Mathf.Max(1, _settings.downsample));

                RenderingUtils.ReAllocateIfNeeded(ref _maskTexture, descriptor, _settings.filterMode, TextureWrapMode.Clamp, name: "_ScreenSpaceSSSMaskTexture");
                RenderingUtils.ReAllocateIfNeeded(ref _sceneCopy, descriptor, _settings.filterMode, TextureWrapMode.Clamp, name: "_ScreenSpaceSSSSceneTexture");
                RenderingUtils.ReAllocateIfNeeded(ref _tempA, blurDescriptor, _settings.filterMode, TextureWrapMode.Clamp, name: "_ScreenSpaceSSSTempA");
                RenderingUtils.ReAllocateIfNeeded(ref _tempB, blurDescriptor, _settings.filterMode, TextureWrapMode.Clamp, name: "_ScreenSpaceSSSTempB");
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (_material == null || _source == null || _depth == null)
                {
                    return;
                }

                CommandBuffer cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, ProfilingSampler))
                {
                    CoreUtils.SetRenderTarget(cmd, _maskTexture, _depth, ClearFlag.Color, Color.clear);
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();

                    SortingCriteria sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;
                    DrawingSettings drawingSettings = CreateDrawingSettings(_shaderTagIds, ref renderingData, sortingCriteria);
                    FilteringSettings filteringSettings = new(RenderQueueRange.opaque, _settings.layerMask);
                    context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);

                    Blitter.BlitCameraTexture(cmd, _source, _sceneCopy);
                    cmd.SetGlobalTexture(MaskTextureId, _maskTexture.nameID);
                    cmd.SetGlobalTexture(SceneTextureId, _sceneCopy.nameID);
                    cmd.SetGlobalVector(
                        Params0Id,
                        new Vector4(
                            Mathf.Max(0.5f, _settings.blurRadius),
                            Mathf.Max(0.1f, _settings.depthFalloff),
                            Mathf.Max(0f, _settings.compositeIntensity),
                            Mathf.Clamp01(_settings.maskThreshold)));

                    Blitter.BlitCameraTexture(cmd, _maskTexture, _tempA, _material, 0);
                    Blitter.BlitCameraTexture(cmd, _tempA, _tempB, _material, 1);
                    Blitter.BlitCameraTexture(cmd, _tempB, _source, _material, 2);
                }

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                CommandBufferPool.Release(cmd);
            }
        }
    }
}

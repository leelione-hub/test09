using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Project.Rendering
{
    // 基于 URP RendererFeature 的屏幕空间体积光。
    // 它在全屏 Pass 中沿视线做 Ray March，并把主方向光的散射累加到一张低分辨率临时图上。
    public sealed class ScreenSpaceVolumetricLightRendererFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public sealed class Settings
        {
            public Shader shader;
            public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
            public bool applyToSceneView = true;
            [Range(1, 4)] public int downsample = 2;
            public FilterMode filterMode = FilterMode.Bilinear;

            [Header("Ray March")]
            [Range(4, 128)] public int stepCount = 32;
            [Min(1f)] public float maxRayDistance = 80f;
            [Range(0f, 4f)] public float intensity = 1f;
            [Range(0f, 1f)] public float jitterStrength = 1f;

            [Header("Medium")]
            [Min(0f)] public float density = 0.04f;
            [Min(0f)] public float extinction = 0.6f;
            public float heightFogBase = 0f;
            [Min(0f)] public float heightFogFalloff = 0.05f;

            [Header("Scattering")]
            [Range(-0.9f, 0.9f)] public float anisotropy = 0.25f;
            [Range(0f, 1f)] public float shadowStrength = 1f;
            [ColorUsage(false, true)] public Color scatteringColor = Color.white;
        }

        private const string ShaderName = "Hidden/Lighting/ScreenSpaceVolumetricLight";

        [SerializeField] private Settings settings = new Settings();

        private Material _material;
        private ScreenSpaceVolumetricLightPass _pass;

        public override void Create()
        {
            if (settings.shader == null)
            {
                settings.shader = Shader.Find(ShaderName);
            }

            if (settings.shader != null && (_material == null || _material.shader != settings.shader))
            {
                CoreUtils.Destroy(_material);
                _material = CoreUtils.CreateEngineMaterial(settings.shader);
            }

            _pass ??= new ScreenSpaceVolumetricLightPass();
            _pass.renderPassEvent = settings.renderPassEvent;
            _pass.SetMaterial(_material);
            _pass.SetSettings(settings);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            _pass?.SetTarget(renderer.cameraColorTargetHandle);
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

        private sealed class ScreenSpaceVolumetricLightPass : ScriptableRenderPass
        {
            private static readonly int Params0Id = Shader.PropertyToID("_SSVLParams0");
            private static readonly int Params1Id = Shader.PropertyToID("_SSVLParams1");
            private static readonly int Params2Id = Shader.PropertyToID("_SSVLParams2");
            private static readonly int ScatterColorId = Shader.PropertyToID("_SSVLScatteringColor");

            private readonly ProfilingSampler _profilingSampler = new("Screen Space Volumetric Light");

            private Material _material;
            private RTHandle _source;
            private RTHandle _temp;
            private Settings _settings;

            public void SetMaterial(Material material)
            {
                _material = material;
            }

            public void SetTarget(RTHandle source)
            {
                _source = source;
            }

            public void SetSettings(Settings settings)
            {
                _settings = settings;
                ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Color);
            }

            public void Dispose()
            {
                _temp?.Release();
                _temp = null;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                if (_material == null)
                {
                    return;
                }

                // 这里只降低体积光中间图的分辨率。
                // 主相机颜色目标本身不应该被降分辨率。
                RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
                descriptor.depthBufferBits = 0;
                descriptor.msaaSamples = 1;
                descriptor.width = Mathf.Max(1, descriptor.width / Mathf.Max(1, _settings.downsample));
                descriptor.height = Mathf.Max(1, descriptor.height / Mathf.Max(1, _settings.downsample));

                RenderingUtils.ReAllocateIfNeeded(
                    ref _temp,
                    descriptor,
                    _settings.filterMode,
                    TextureWrapMode.Clamp,
                    name: "_ScreenSpaceVolumetricLight");
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (_material == null || _source == null || _temp == null)
                {
                    return;
                }

                CommandBuffer cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, _profilingSampler))
                {
                    // Params0：Ray March 步数、最大距离、整体强度、抖动强度。
                    _material.SetVector(
                        Params0Id,
                        new Vector4(
                            Mathf.Max(1, _settings.stepCount),
                            Mathf.Max(0.0001f, _settings.maxRayDistance),
                            Mathf.Max(0f, _settings.intensity),
                            Mathf.Clamp01(_settings.jitterStrength)));

                    // Params1：介质密度、消光系数，以及高度雾控制参数。
                    _material.SetVector(
                        Params1Id,
                        new Vector4(
                            Mathf.Max(0f, _settings.density),
                            Mathf.Max(0f, _settings.extinction),
                            _settings.heightFogBase,
                            Mathf.Max(0f, _settings.heightFogFalloff)));

                    // Params2：相位函数各向异性，以及主光阴影对散射的影响强度。
                    _material.SetVector(
                        Params2Id,
                        new Vector4(
                            Mathf.Clamp(_settings.anisotropy, -0.9f, 0.9f),
                            Mathf.Clamp01(_settings.shadowStrength),
                            0f,
                            0f));

                    _material.SetColor(ScatterColorId, _settings.scatteringColor);

                    // Pass 0 计算体积光贡献，结果先写入低分辨率临时图。
                    Blitter.BlitCameraTexture(cmd, _source, _temp, _material, 0);
                    // 当前实现直接把结果回写到相机颜色。
                    // 如果后续拆成“体积光缓冲 + 单独合成”，优先替换这里。
                    Blitter.BlitCameraTexture(cmd, _temp, _source);
                }

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                CommandBufferPool.Release(cmd);
            }
        }
    }
}

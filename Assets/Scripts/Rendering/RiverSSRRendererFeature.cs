using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Project.Rendering
{
    public sealed class RiverSSRRendererFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public sealed class Settings
        {
            public Shader shader;
            public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
            public bool applyToSceneView = true;
            [Range(1, 4)] public int downsample = 1;
            public FilterMode filterMode = FilterMode.Bilinear;
            public bool requireDepth = true;
            public bool requireOpaqueTexture = true;
        }

        private const string ShaderName = "Hidden/Water/RiverSSRTexture";
        private static readonly int RiverSSRTextureId = Shader.PropertyToID("_RiverSSRTexture");
        private static readonly int RiverSSRTextureTexelSizeId = Shader.PropertyToID("_RiverSSRTexture_TexelSize");

        [SerializeField] private Settings settings = new Settings();

        private Material _material;
        private RiverSSRRenderPass _pass;

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

            _pass ??= new RiverSSRRenderPass(RiverSSRTextureId, RiverSSRTextureTexelSizeId);
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

        private sealed class RiverSSRRenderPass : ScriptableRenderPass
        {
            private readonly int _textureId;
            private readonly int _texelSizeId;
            private readonly ProfilingSampler _profilingSampler = new("River SSR Texture");

            private Material _material;
            private RTHandle _source;
            private RTHandle _output;
            private Settings _settings;

            public RiverSSRRenderPass(int textureId, int texelSizeId)
            {
                _textureId = textureId;
                _texelSizeId = texelSizeId;
            }

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
                ConfigureInput(
                    (settings.requireDepth ? ScriptableRenderPassInput.Depth : ScriptableRenderPassInput.None) |
                    (settings.requireOpaqueTexture ? ScriptableRenderPassInput.Color : ScriptableRenderPassInput.None));
            }

            public void Dispose()
            {
                _output?.Release();
                _output = null;
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
                descriptor.width = Mathf.Max(1, descriptor.width / Mathf.Max(1, _settings.downsample));
                descriptor.height = Mathf.Max(1, descriptor.height / Mathf.Max(1, _settings.downsample));

                RenderingUtils.ReAllocateIfNeeded(
                    ref _output,
                    descriptor,
                    _settings.filterMode,
                    TextureWrapMode.Clamp,
                    name: "_RiverSSRTexture");

                ConfigureTarget(_output);
                ConfigureClear(ClearFlag.None, Color.clear);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (_material == null || _source == null || _output == null)
                {
                    return;
                }

                CommandBuffer cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, _profilingSampler))
                {
                    Blitter.BlitCameraTexture(cmd, _source, _output, _material, 0);
                    cmd.SetGlobalTexture(_textureId, _output.nameID);

                    Vector2 texelSize = new(
                        1f / Mathf.Max(1, _output.rt.width),
                        1f / Mathf.Max(1, _output.rt.height));
                    cmd.SetGlobalVector(
                        _texelSizeId,
                        new Vector4(texelSize.x, texelSize.y, _output.rt.width, _output.rt.height));
                }

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                CommandBufferPool.Release(cmd);
            }
        }
    }
}

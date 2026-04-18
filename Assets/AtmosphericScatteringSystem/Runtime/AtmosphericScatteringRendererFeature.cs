using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace AtmosphericScatteringSystem
{
    public sealed class AtmosphericScatteringRendererFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public sealed class Settings
        {
            public Shader shader;
            public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
            public bool applyToSceneView;
        }

        private const string ShaderName = "Hidden/Custom/AtmosphericScattering";

        [SerializeField] private Settings settings = new Settings();

        private Material _material;
        private AtmosphericScatteringRenderPass _pass;

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

            _pass ??= new AtmosphericScatteringRenderPass();
            _pass.renderPassEvent = settings.renderPassEvent;
            _pass.SetMaterial(_material);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            if (_pass == null)
            {
                return;
            }

            _pass.SetTarget(renderer.cameraColorTargetHandle);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (_material == null)
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

        private sealed class AtmosphericScatteringRenderPass : ScriptableRenderPass
        {
            private static readonly int BlendId = Shader.PropertyToID("_AtmosphereBlend");
            private static readonly int SkyTintId = Shader.PropertyToID("_AtmosphereSkyTint");
            private static readonly int HorizonTintId = Shader.PropertyToID("_AtmosphereHorizonTint");
            private static readonly int FogTintId = Shader.PropertyToID("_AtmosphereFogTint");
            private static readonly int DensityId = Shader.PropertyToID("_AtmosphereDensity");
            private static readonly int HeightFalloffId = Shader.PropertyToID("_AtmosphereHeightFalloff");
            private static readonly int HeightOffsetId = Shader.PropertyToID("_AtmosphereHeightOffset");
            private static readonly int FogStartDistanceId = Shader.PropertyToID("_AtmosphereFogStartDistance");
            private static readonly int MaxDistanceId = Shader.PropertyToID("_AtmosphereMaxDistance");
            private static readonly int AnisotropyId = Shader.PropertyToID("_AtmosphereAnisotropy");
            private static readonly int AerialPerspectiveId = Shader.PropertyToID("_AtmosphereAerialPerspective");
            private static readonly int ShaftParamsId = Shader.PropertyToID("_AtmosphereShaftParams");
            private static readonly int SunHaloParamsId = Shader.PropertyToID("_AtmosphereSunHaloParams");
            private static readonly int SunDirectionId = Shader.PropertyToID("_AtmosphereSunDirection");
            private static readonly int SunColorId = Shader.PropertyToID("_AtmosphereSunColor");
            private static readonly int SunScreenPosId = Shader.PropertyToID("_AtmosphereSunScreenPos");
            private static readonly int SampleCountsId = Shader.PropertyToID("_AtmosphereSampleCounts");
            private static readonly int ScatteringTextureId = Shader.PropertyToID("_AtmosphereScatteringTex");
            private static readonly int ScatteringTexelSizeId = Shader.PropertyToID("_AtmosphereScatteringTexelSize");

            private static readonly ProfilingSampler ProfilingSampler =
                new ProfilingSampler("Atmospheric Scattering");

            private Material _material;
            private RTHandle _source;
            private RTHandle _scatteringHandle;

            public AtmosphericScatteringRenderPass()
            {
                ConfigureInput(ScriptableRenderPassInput.Depth);
            }

            public void SetMaterial(Material material)
            {
                _material = material;
            }

            public void SetTarget(RTHandle source)
            {
                _source = source;
            }

            public void Dispose()
            {
                _scatteringHandle?.Release();
                _scatteringHandle = null;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                if (!TryGetVolume(out AtmosphericScatteringVolume volume))
                {
                    return;
                }

                float downsample = GetDownsample(volume);
                RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
                desc.depthBufferBits = 0;
                desc.msaaSamples = 1;
                desc.width = Mathf.Max(1, Mathf.RoundToInt(desc.width * downsample));
                desc.height = Mathf.Max(1, Mathf.RoundToInt(desc.height * downsample));

                RenderingUtils.ReAllocateIfNeeded(
                    ref _scatteringHandle,
                    desc,
                    FilterMode.Bilinear,
                    TextureWrapMode.Clamp,
                    name: "_AtmosphereScatteringTexture");

                ConfigureTarget(_source);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (_material == null || _source == null || !TryGetVolume(out AtmosphericScatteringVolume volume))
                {
                    return;
                }

                Camera camera = renderingData.cameraData.camera;
                if (camera == null)
                {
                    return;
                }

                AtmosphereQualityMode quality = volume.GetResolvedQuality();
                SetupLightParameters(ref renderingData, camera);
                SetupVolumeParameters(volume, quality);

                CommandBuffer cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, ProfilingSampler))
                {
                    CoreUtils.SetKeyword(cmd, "ATMOSPHERE_HIGH_QUALITY", quality == AtmosphereQualityMode.PC);
                    Blitter.BlitCameraTexture(cmd, _source, _scatteringHandle, _material, 0);
                    cmd.SetGlobalTexture(ScatteringTextureId, _scatteringHandle.nameID);

                    Vector2 texelSize = new Vector2(
                        1f / Mathf.Max(1, _scatteringHandle.rt.width),
                        1f / Mathf.Max(1, _scatteringHandle.rt.height));
                    cmd.SetGlobalVector(ScatteringTexelSizeId, new Vector4(texelSize.x, texelSize.y, _scatteringHandle.rt.width, _scatteringHandle.rt.height));

                    Blitter.BlitCameraTexture(cmd, _source, _source, _material, 1);
                }

                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                CommandBufferPool.Release(cmd);
            }

            private static bool TryGetVolume(out AtmosphericScatteringVolume volume)
            {
                volume = VolumeManager.instance.stack.GetComponent<AtmosphericScatteringVolume>();
                return volume != null && volume.IsActive();
            }

            private float GetDownsample(AtmosphericScatteringVolume volume)
            {
                return volume.GetResolvedQuality() == AtmosphereQualityMode.PC
                    ? volume.pcDownsample.value
                    : volume.mobileDownsample.value;
            }

            private void SetupVolumeParameters(AtmosphericScatteringVolume volume, AtmosphereQualityMode quality)
            {
                _material.SetFloat(BlendId, volume.effectBlend.value);
                _material.SetColor(SkyTintId, volume.skyTint.value.linear);
                _material.SetColor(HorizonTintId, volume.horizonTint.value.linear);
                _material.SetColor(FogTintId, volume.fogTint.value.linear);
                _material.SetFloat(DensityId, volume.density.value);
                _material.SetFloat(HeightFalloffId, volume.heightFalloff.value);
                _material.SetFloat(HeightOffsetId, volume.heightOffset.value);
                _material.SetFloat(FogStartDistanceId, Mathf.Max(0f, volume.fogStartDistance.value));
                _material.SetFloat(MaxDistanceId, volume.maxDistance.value);
                _material.SetFloat(AnisotropyId, volume.anisotropy.value);
                _material.SetFloat(AerialPerspectiveId, volume.aerialPerspective.value);
                _material.SetVector(
                    ShaftParamsId,
                    new Vector4(
                        volume.shaftIntensity.value,
                        volume.shaftDecay.value,
                        volume.shaftJitter.value,
                        volume.shaftDistanceFade.value));
                _material.SetVector(
                    SunHaloParamsId,
                    new Vector4(volume.sunHaloSize.value, volume.sunHaloIntensity.value, 0f, 0f));

                int raymarchSteps = quality == AtmosphereQualityMode.PC
                    ? volume.pcRaymarchSteps.value
                    : volume.mobileRaymarchSteps.value;
                int shaftSamples = quality == AtmosphereQualityMode.PC
                    ? volume.pcShaftSamples.value
                    : volume.mobileShaftSamples.value;

                _material.SetVector(SampleCountsId, new Vector4(raymarchSteps, shaftSamples, 0f, 0f));
            }

            private void SetupLightParameters(ref RenderingData renderingData, Camera camera)
            {
                int mainLightIndex = renderingData.lightData.mainLightIndex;
                Vector3 sunDirection = camera.transform.forward;
                Color sunColor = Color.white;

                if (mainLightIndex >= 0 && mainLightIndex < renderingData.lightData.visibleLights.Length)
                {
                    VisibleLight visibleLight = renderingData.lightData.visibleLights[mainLightIndex];
                    sunDirection = -visibleLight.localToWorldMatrix.GetColumn(2);
                    sunColor = visibleLight.finalColor;
                }

                sunDirection.Normalize();

                Vector3 worldPoint = camera.transform.position + sunDirection * Mathf.Max(1000f, camera.farClipPlane * 0.9f);
                Vector3 sunViewport = camera.WorldToViewportPoint(worldPoint);
                float sunVisible = sunViewport.z > 0f ? 1f : 0f;

                _material.SetVector(SunDirectionId, new Vector4(sunDirection.x, sunDirection.y, sunDirection.z, 0f));
                _material.SetColor(SunColorId, sunColor.linear);
                _material.SetVector(SunScreenPosId, new Vector4(sunViewport.x, sunViewport.y, sunVisible, 0f));
            }
        }
    }
}

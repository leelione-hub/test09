using System;
using HiZTechnique;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

namespace VegetationSystem
{
    public sealed class VegetationHiZController
    {
        private bool _enableHiZCulling;
        private VegetationSystemObject.HiZCullingMode _hizCullingMode;
        private float _hizDepthBias;
        private ComputeShader _hizCullingComputeShader;
        private ComputeShader _originalCullingComputeShader;

        private bool _useHiZShader;
        private int _originalKernel = -1;
        private int _hizKernel = -1;
        private int _classifyKernel = -1;
        private HizDepthPyramid _depthPyramid;
        private int _lastCullingFrame = -1;
        private int _lastShadowSubmitFrame = -1;
        private bool _initializedHiZ;
        private ComputeShader _activeComputeShader;
        private RenderTexture _fallbackDepthTexture;

        private static readonly int HizDepthTextureId = Shader.PropertyToID("_HizDepthTexture");
        private static readonly int HizTextureSizeId = Shader.PropertyToID("_HizTextureSize");
        private static readonly int HizWorldSpaceBiasId = Shader.PropertyToID("_HizWorldSpaceBias");
        private static readonly int CameraNearFarId = Shader.PropertyToID("_CameraNearFar");
        private static readonly int VPMatrixId = Shader.PropertyToID("_HiZ_VP");
        private static readonly int EnableHiZCullingId = Shader.PropertyToID("_EnableHiZCulling");
        private static readonly int HizReversedZId = Shader.PropertyToID("_HizReversedZ");

        public void SyncSettings(
            bool enableHiZCulling,
            VegetationSystemObject.HiZCullingMode hizCullingMode,
            float hizDepthBias,
            ComputeShader hizCullingComputeShader,
            ComputeShader originalCullingComputeShader)
        {
            bool settingsChanged = _enableHiZCulling != enableHiZCulling ||
                                   _hizCullingMode != hizCullingMode ||
                                   !Mathf.Approximately(_hizDepthBias, hizDepthBias) ||
                                   _hizCullingComputeShader != hizCullingComputeShader ||
                                   _originalCullingComputeShader != originalCullingComputeShader;

            _enableHiZCulling = enableHiZCulling;
            _hizCullingMode = hizCullingMode;
            _hizDepthBias = hizDepthBias;
            _hizCullingComputeShader = hizCullingComputeShader;
            _originalCullingComputeShader = originalCullingComputeShader;

            if (settingsChanged)
            {
                _initializedHiZ = false;
            }
        }

        public bool RequiresDepthPyramid(MonoBehaviour owner)
        {
            return owner.isActiveAndEnabled && _enableHiZCulling && _hizCullingMode == VegetationSystemObject.HiZCullingMode.GPU;
        }

        public bool UsesRenderFeatureRendering => _enableHiZCulling && _hizCullingMode == VegetationSystemObject.HiZCullingMode.GPU;

        public ComputeShader ActiveComputeShader => _activeComputeShader;

        public void ResetInitialization()
        {
            _initializedHiZ = false;
        }

        public void EnsureInitialized()
        {
            if (_initializedHiZ &&
                (_originalKernel >= 0 || _hizKernel >= 0 || _classifyKernel >= 0 || _activeComputeShader != null))
            {
                return;
            }

            InitializeHiZ();
        }

        public bool TryPrepareDispatch(
            Camera cullingCamera,
            out int cullKernel,
            out int classifyKernel,
            out Action<ComputeShader, int, Camera> configureCullKernel)
        {
            EnsureInitialized();

            cullKernel = -1;
            classifyKernel = -1;
            configureCullKernel = ConfigureCullKernel;

            if (_activeComputeShader == null)
            {
                return false;
            }

            cullKernel = FindCullKernel();
            classifyKernel = FindClassifyKernel();
            return cullKernel >= 0 && classifyKernel >= 0;
        }

        public bool TryBeginRenderPass(Camera fallbackCamera, Camera explicitCamera, out Camera cullCamera)
        {
            EnsureInitialized();

            if (_lastCullingFrame == Time.frameCount)
            {
                cullCamera = null;
                return false;
            }

            cullCamera = Camera.main;
            if (cullCamera == null)
            {
                cullCamera = explicitCamera != null ? explicitCamera : fallbackCamera;
            }

            return cullCamera != null;
        }

        public void MarkCulledThisFrame()
        {
            _lastCullingFrame = Time.frameCount;
        }

        public bool TryBeginShadowSubmission()
        {
            if (_lastShadowSubmitFrame == Time.frameCount)
            {
                return false;
            }

            _lastShadowSubmitFrame = Time.frameCount;
            return true;
        }

        public void SetupHiZCullingParameters(Camera cullingCamera)
        {
            if (_activeComputeShader == null || cullingCamera == null)
            {
                _depthPyramid = null;
                return;
            }

            EnsureFallbackDepthTexture();

            Texture hizTexture = _fallbackDepthTexture;
            Vector4 hizTextureInfo = new Vector4(1f, 1f, 1f, 0f);

            HizSystem hizSystem = HizSystem.Instance;
            if (hizSystem != null && hizSystem.IsActive)
            {
                HizDepthPyramid depthPyramid = hizSystem.GetDepthPyramid();
                _depthPyramid = depthPyramid;
                if (depthPyramid != null && depthPyramid.DepthPyramidTexture != null)
                {
                    hizTexture = depthPyramid.DepthPyramidTexture;
                    hizTextureInfo = new Vector4(
                        depthPyramid.BaseSize.x,
                        depthPyramid.BaseSize.y,
                        depthPyramid.MipCount,
                        0f);
                }
            }
            else
            {
                _depthPyramid = null;
            }

            int[] kernels = { _originalKernel, _hizKernel };
            foreach (int kernel in kernels)
            {
                if (kernel < 0)
                {
                    continue;
                }

                _activeComputeShader.SetTexture(kernel, HizDepthTextureId, hizTexture);
                _activeComputeShader.SetVector(HizTextureSizeId, hizTextureInfo);
                _activeComputeShader.SetFloat(HizWorldSpaceBiasId, _hizDepthBias);
                _activeComputeShader.SetVector(CameraNearFarId, new Vector2(cullingCamera.nearClipPlane, cullingCamera.farClipPlane));
                _activeComputeShader.SetBool(EnableHiZCullingId, _enableHiZCulling);
                _activeComputeShader.SetInt(HizReversedZId, HizPlatformCompatibility.UsesReversedZ() ? 1 : 0);

                Matrix4x4 vp = GL.GetGPUProjectionMatrix(cullingCamera.projectionMatrix, false) *
                               cullingCamera.worldToCameraMatrix;
                _activeComputeShader.SetMatrix(VPMatrixId, vp);
            }
        }

        public void SetHiZCullingEnabled(bool enabled)
        {
            _enableHiZCulling = enabled;
            _initializedHiZ = false;
            InitializeHiZ();
            Debug.Log($"[VegetationHiZ] HiZ culling: {(_enableHiZCulling ? "enabled" : "disabled")}");
        }

        private void InitializeHiZ()
        {
            _initializedHiZ = true;
            _useHiZShader = false;
            _originalKernel = -1;
            _hizKernel = -1;
            _classifyKernel = -1;
            _depthPyramid = null;
            _activeComputeShader = null;

            if (!_enableHiZCulling)
            {
                _activeComputeShader = _originalCullingComputeShader;
                RefreshKernelHandles();
                return;
            }

            HizSystem hizSystem = HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
            {
                Debug.LogWarning("[VegetationHiZ] HiZ system is not active, fallback to original culling.");
                _enableHiZCulling = false;
                _activeComputeShader = _originalCullingComputeShader;
                RefreshKernelHandles();
                return;
            }

            if (_hizCullingComputeShader != null)
            {
                _activeComputeShader = _hizCullingComputeShader;
                RefreshKernelHandles();

                if (_hizKernel < 0)
                {
                    Debug.LogWarning("[VegetationHiZ] Cannot find 'CullInstancesWithHiZ' kernel, fallback to original culling.");
                    _enableHiZCulling = false;
                    _activeComputeShader = _originalCullingComputeShader;
                    RefreshKernelHandles();
                    return;
                }

                _useHiZShader = true;
            }
            else
            {
                Debug.LogWarning("[VegetationHiZ] HiZ compute shader is missing, fallback to original culling.");
                _enableHiZCulling = false;
                _activeComputeShader = _originalCullingComputeShader;
                RefreshKernelHandles();
            }
        }

        private void RefreshKernelHandles()
        {
            _originalKernel = TryFindKernel(_activeComputeShader, "CullInstances");
            _hizKernel = TryFindKernel(_activeComputeShader, "CullInstancesWithHiZ");
            _classifyKernel = TryFindKernel(_activeComputeShader, "ClassifyVisibleInstances");
        }

        private static int TryFindKernel(ComputeShader shader, string kernelName)
        {
            if (shader == null)
            {
                return -1;
            }

            try
            {
                return shader.FindKernel(kernelName);
            }
            catch
            {
                return -1;
            }
        }

        private int FindCullKernel()
        {
            bool canUseHiZKernel = _enableHiZCulling &&
                                   _useHiZShader &&
                                   _hizKernel >= 0 &&
                                   _depthPyramid != null &&
                                   _depthPyramid.DepthPyramidTexture != null;

            int kernel = canUseHiZKernel ? _hizKernel : _originalKernel;
            if (kernel < 0)
            {
                kernel = TryFindKernel(_activeComputeShader, "CullInstances");
            }

            if (kernel < 0)
            {
                Debug.LogError("[VegetationHiZ] No valid CullInstances kernel found, skip culling for this frame.");
            }

            return kernel;
        }

        private int FindClassifyKernel()
        {
            int classifyKernel = _classifyKernel;
            if (classifyKernel < 0)
            {
                classifyKernel = TryFindKernel(_activeComputeShader, "ClassifyVisibleInstances");
            }

            if (classifyKernel < 0)
            {
                Debug.LogError("[VegetationHiZ] No valid ClassifyVisibleInstances kernel found, skip culling for this frame.");
            }

            return classifyKernel;
        }

        private void ConfigureCullKernel(ComputeShader shader, int kernel, Camera camera)
        {
            bool enableHiZOnKernel = _enableHiZCulling &&
                                     _useHiZShader &&
                                     _hizKernel >= 0 &&
                                     _depthPyramid != null &&
                                     _depthPyramid.DepthPyramidTexture != null;
            shader.SetBool(EnableHiZCullingId, enableHiZOnKernel);
        }

        private void EnsureFallbackDepthTexture()
        {
            if (_fallbackDepthTexture != null)
            {
                return;
            }

            _fallbackDepthTexture = new RenderTexture(1, 1, 0)
            {
                graphicsFormat = GraphicsFormat.R32_SFloat,
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp,
                useMipMap = false,
                autoGenerateMips = false,
                name = "VegetationHiZFallbackDepth"
            };
            _fallbackDepthTexture.Create();
        }
    }
}

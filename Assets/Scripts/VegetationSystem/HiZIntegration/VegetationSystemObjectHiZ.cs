using System.Collections.Generic;
using HiZTechnique;
using UnityEngine;
using UnityEngine.Rendering;
using Debug = UnityEngine.Debug;
using VGC = VegetationSystem.VgConstantProperty;

namespace VegetationSystem.HiZIntegration
{
    /// <summary>
    /// VegetationSystemObject variant with HiZ culling support.
    /// </summary>
    public class VegetationSystemObjectHiZ : VegetationSystemObject
    {
        [Header("HiZ Settings")]
        [Tooltip("Enable HiZ culling.")]
        [SerializeField]
        private bool _enableHiZCulling = true;

        [Tooltip("HiZ culling mode.")]
        [SerializeField]
        private HiZCullingMode _hizCullingMode = HiZCullingMode.GPU;

        [Tooltip("Depth bias in world space.")]
        [SerializeField]
        [Range(0f, 50f)]
        private float _hizDepthBias = 0.01f;

        [Tooltip("HiZ compute shader.")]
        [SerializeField]
        private ComputeShader _hizCullingComputeShader;

        [Tooltip("Fallback compute shader when HiZ is disabled.")]
        [SerializeField]
        private ComputeShader _originalCullingComputeShader;

        public enum HiZCullingMode
        {
            GPU,
            CPU,
        }

        private bool _useHiZShader;
        private int _originalKernel = -1;
        private int _hizKernel = -1;

        private static readonly int HizDepthTextureId = Shader.PropertyToID("_HizDepthTexture");
        private static readonly int HizTextureSizeId = Shader.PropertyToID("_HizTextureSize");
        private static readonly int HizWorldSpaceBiasId = Shader.PropertyToID("_HizWorldSpaceBias");
        private static readonly int CameraNearFarId = Shader.PropertyToID("_CameraNearFar");
        private static readonly int VPMatrixId = Shader.PropertyToID("_HiZ_VP");
        private static readonly int EnableHiZCullingId = Shader.PropertyToID("_EnableHiZCulling");
        private static readonly int HizReversedZId = Shader.PropertyToID("_HizReversedZ");

        private HizDepthPyramid _depthPyramid;
        private int _lastCullingFrame = -1;
        private int _lastShadowSubmitFrame = -1;
        private readonly Dictionary<int, int> _forwardPassIndexCache = new Dictionary<int, int>();

        public bool RequiresDepthPyramid => isActiveAndEnabled && _enableHiZCulling && _hizCullingMode == HiZCullingMode.GPU;

        private void Start()
        {
            InitializeHiZ();
        }

        private void InitializeHiZ()
        {
            _useHiZShader = false;
            _originalKernel = -1;
            _hizKernel = -1;

            if (!_enableHiZCulling)
            {
                if (_originalCullingComputeShader != null)
                {
                    cullingCS = _originalCullingComputeShader;
                }

                RefreshKernelHandles();
                return;
            }

            HizSystem hizSystem = HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
            {
                Debug.LogWarning("[VegetationHiZ] HiZ system is not active, fallback to original culling.");
                _enableHiZCulling = false;

                if (_originalCullingComputeShader != null)
                {
                    cullingCS = _originalCullingComputeShader;
                }

                RefreshKernelHandles();
                return;
            }

            if (_hizCullingComputeShader != null)
            {
                cullingCS = _hizCullingComputeShader;
                RefreshKernelHandles();

                if (_hizKernel < 0)
                {
                    Debug.LogWarning("[VegetationHiZ] Cannot find 'CullInstancesWithHiZ' kernel, fallback to original culling.");
                    _enableHiZCulling = false;

                    if (_originalCullingComputeShader != null)
                    {
                        cullingCS = _originalCullingComputeShader;
                        RefreshKernelHandles();
                    }

                    return;
                }

                _useHiZShader = true;
            }
            else
            {
                Debug.LogWarning("[VegetationHiZ] HiZ compute shader is missing, fallback to original culling.");
                _enableHiZCulling = false;

                if (_originalCullingComputeShader != null)
                {
                    cullingCS = _originalCullingComputeShader;
                }

                RefreshKernelHandles();
            }
        }

        private void RefreshKernelHandles()
        {
            _originalKernel = TryFindKernel(cullingCS, "CullInstances");
            _hizKernel = TryFindKernel(cullingCS, "CullInstancesWithHiZ");
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

        // Keep the base Update path from running for this derived type.
        protected void Update()
        {
        }

        private void SetupHiZCullingParameters()
        {
            HizSystem hizSystem = HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
            {
                return;
            }

            HizDepthPyramid depthPyramid = hizSystem.GetDepthPyramid();
            _depthPyramid = depthPyramid;
            if (depthPyramid == null || depthPyramid.DepthPyramidTexture == null)
            {
                return;
            }

            if (cullingCS == null)
            {
                return;
            }

            int[] kernels = { _originalKernel, _hizKernel };
            foreach (int kernel in kernels)
            {
                if (kernel < 0)
                {
                    continue;
                }

                cullingCS.SetTexture(kernel, HizDepthTextureId, depthPyramid.DepthPyramidTexture);
                cullingCS.SetVector(HizTextureSizeId, new Vector4(
                    depthPyramid.BaseSize.x,
                    depthPyramid.BaseSize.y,
                    depthPyramid.MipCount,
                    0f));
                cullingCS.SetFloat(HizWorldSpaceBiasId, _hizDepthBias);
                cullingCS.SetVector(CameraNearFarId, new Vector2(cullingCamera.nearClipPlane, cullingCamera.farClipPlane));
                cullingCS.SetBool(EnableHiZCullingId, _enableHiZCulling);
                cullingCS.SetInt(HizReversedZId, HizPlatformCompatibility.UsesReversedZ() ? 1 : 0);

                Matrix4x4 vp = GL.GetGPUProjectionMatrix(cullingCamera.projectionMatrix, false) *
                               cullingCamera.worldToCameraMatrix;
                cullingCS.SetMatrix(VPMatrixId, vp);
            }
        }

        public new void CSDispatch()
        {
            if (cullingCS == null)
            {
                return;
            }

            bool canUseHiZKernel = _enableHiZCulling &&
                                   _useHiZShader &&
                                   _hizKernel >= 0 &&
                                   _depthPyramid != null &&
                                   _depthPyramid.DepthPyramidTexture != null;

            int kernel = canUseHiZKernel ? _hizKernel : _originalKernel;

            if (canUseHiZKernel)
            {
                cullingCS.SetBool(EnableHiZCullingId, true);
                cullingCS.SetTexture(kernel, HizDepthTextureId, _depthPyramid.DepthPyramidTexture);
                cullingCS.SetVector(HizTextureSizeId, new Vector4(
                    _depthPyramid.BaseSize.x,
                    _depthPyramid.BaseSize.y,
                    _depthPyramid.MipCount,
                    0f));
                cullingCS.SetFloat(HizWorldSpaceBiasId, _hizDepthBias);
                cullingCS.SetVector(CameraNearFarId, new Vector2(cullingCamera.nearClipPlane, cullingCamera.farClipPlane));
                cullingCS.SetInt(HizReversedZId, HizPlatformCompatibility.UsesReversedZ() ? 1 : 0);

                Matrix4x4 proj = cullingCamera.nonJitteredProjectionMatrix;
                Matrix4x4 vp = GL.GetGPUProjectionMatrix(proj, false) *
                               cullingCamera.worldToCameraMatrix;
                cullingCS.SetMatrix(VPMatrixId, vp);
            }
            else
            {
                cullingCS.SetBool(EnableHiZCullingId, false);
            }

            if (kernel < 0)
            {
                kernel = TryFindKernel(cullingCS, "CullInstances");
            }

            if (kernel < 0)
            {
                Debug.LogError("[VegetationHiZ] No valid CullInstances kernel found, skip culling for this frame.");
                return;
            }

            Plane[] planes = GeometryUtility.CalculateFrustumPlanes(cullingCamera);
            Vector4[] planeData = new Vector4[6];
            for (int i = 0; i < 6; i++)
            {
                Vector3 normal = planes[i].normal;
                float distance = planes[i].distance;
                planeData[i] = new Vector4(normal.x, normal.y, normal.z, distance);
            }

            cullingCS.SetVectorArray(VGC.FRUSTUMPLANES, planeData);
            cullingCS.SetVector(VGC.CAMERAPOSITION, cullingCamera.transform.position);

            VgRender vgRender = GetVgRender();
            if (vgRender == null)
            {
                return;
            }

            for (int i = 0; i < vgRender.vegetationRenderDataList.Count; i++)
            {
                var renderData = vgRender.vegetationRenderDataList[i];
                Bounds mergedBounds = default;
                bool hasMergedBounds = false;

                for (int j = 0; j < renderData.LodDatas.Length; j++)
                {
                    var lodData = renderData.LodDatas[j];
                    if (lodData.mesh != null)
                    {
                        if (!hasMergedBounds)
                        {
                            mergedBounds = lodData.mesh.bounds;
                            hasMergedBounds = true;
                        }
                        else
                        {
                            mergedBounds.Encapsulate(lodData.mesh.bounds);
                        }
                    }

                    for (int k = 0; k < lodData.SubMeshDatas.Length; k++)
                    {
                        uint[] subArgs = new uint[5];
                        subArgs[0] = lodData.mesh.GetIndexCount(k);
                        subArgs[1] = 0u;
                        subArgs[2] = lodData.mesh.GetIndexStart(k);
                        subArgs[3] = lodData.mesh.GetBaseVertex(k);
                        subArgs[4] = 0u;
                        lodData.SubMeshDatas[k].argsBuffer.SetData(subArgs);
                    }

                    lodData.VisibleInstanceBuffer.SetCounterValue(0);
                }

                cullingCS.SetBuffer(kernel, VGC.ALLINSTANCES, renderData.AllInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.VISIBLECHUNINFOS, renderData.VisibleChunkBuffer);
                cullingCS.SetInt(VGC.CHUNKCOUNT, renderData.visibleChunkCount);

                Vector3 extents = hasMergedBounds ? mergedBounds.extents : Vector3.one * 0.5f;
                Vector3 boundsCenter = hasMergedBounds ? mergedBounds.center : Vector3.zero;
                cullingCS.SetVector("_Extents", extents);
                cullingCS.SetVector("_BoundsCenterOS", boundsCenter);

                Vector4 lodDistance = renderData.lodDistance;
                for (int lod = 0; lod < 4; lod++)
                {
                    if (lod < QualitySettings.maximumLODLevel)
                    {
                        lodDistance[lod] = -1f;
                    }
                    else
                    {
                        lodDistance[lod] = renderData.lodDistance[lod] * QualitySettings.lodBias;
                    }
                }

                cullingCS.SetVector(VGC.LODDISTANCE, lodDistance);
                cullingCS.SetBuffer(kernel, VGC.LOD0VISIBLEINSTANCES, renderData.LodDatas[0].VisibleInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD1VISIBLEINSTANCES, renderData.LodDatas[1].VisibleInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD2VISIBLEINSTANCES, renderData.LodDatas[2].VisibleInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD0ARGSBUFFER, renderData.LodDatas[0].SubMeshDatas[0].argsBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD1ARGSBUFFER, renderData.LodDatas[1].SubMeshDatas[0].argsBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD2ARGSBUFFER, renderData.LodDatas[2].SubMeshDatas[0].argsBuffer);

                if (renderData.visibleChunkCount < 1)
                {
                    continue;
                }

                int groupX = renderData.visibleChunkCount;
                int groupY = Mathf.CeilToInt(renderData.chunkMaxCount / 64f);
                cullingCS.Dispatch(kernel, groupX, groupY, 1);

                for (int n = 0; n < renderData.LodDatas.Length; n++)
                {
                    for (int k = 0; k < renderData.LodDatas[n].SubMeshDatas.Length; k++)
                    {
                        GraphicsBuffer.CopyCount(
                            renderData.LodDatas[n].VisibleInstanceBuffer,
                            renderData.LodDatas[n].SubMeshDatas[k].argsBuffer,
                            sizeof(uint));
                    }
                }
            }
        }

        public void ExecuteCullingForRenderPass(Camera renderCamera)
        {
            if (_lastCullingFrame == Time.frameCount)
            {
                return;
            }

            Camera cullCamera = Camera.main;
            if (cullCamera == null)
            {
                cullCamera = cullingCamera != null ? cullingCamera : renderCamera;
            }

            if (cullCamera == null)
            {
                return;
            }

            cullingCamera = cullCamera;
            ChunkCullingOnCPU();

            if (_enableHiZCulling && _hizCullingMode == HiZCullingMode.GPU)
            {
                SetupHiZCullingParameters();
            }

            CSDispatch();
            _lastCullingFrame = Time.frameCount;
        }

        public void RenderWithCommandBuffer(CommandBuffer cmd)
        {
            if (cmd == null)
            {
                return;
            }

            VgRender vgRender = GetVgRender();
            if (vgRender == null)
            {
                return;
            }

            for (int i = 0; i < vgRender.vegetationRenderDataList.Count; i++)
            {
                var renderData = vgRender.vegetationRenderDataList[i];
                for (int lodIndex = 0; lodIndex < renderData.LodDatas.Length; lodIndex++)
                {
                    var lodData = renderData.LodDatas[lodIndex];
                    if (lodData.mesh == null)
                    {
                        continue;
                    }

                    for (int subMeshIndex = 0; subMeshIndex < lodData.SubMeshDatas.Length; subMeshIndex++)
                    {
                        var subMeshData = lodData.SubMeshDatas[subMeshIndex];
                        Material material = subMeshData.rp.material;
                        if (material == null || subMeshData.argsBuffer == null)
                        {
                            continue;
                        }

                        cmd.DrawMeshInstancedIndirect(
                            lodData.mesh,
                            subMeshData.subMesh,
                            material,
                            ResolveForwardPassIndex(material),
                            subMeshData.argsBuffer,
                            0,
                            null);
                    }
                }
            }
        }

        public void SubmitShadowCasters()
        {
            if (_lastShadowSubmitFrame == Time.frameCount)
            {
                return;
            }

            _lastShadowSubmitFrame = Time.frameCount;

            VgRender vgRender = GetVgRender();
            if (vgRender == null)
            {
                return;
            }

            for (int i = 0; i < vgRender.vegetationRenderDataList.Count; i++)
            {
                var renderData = vgRender.vegetationRenderDataList[i];
                for (int lodIndex = 0; lodIndex < renderData.LodDatas.Length; lodIndex++)
                {
                    var lodData = renderData.LodDatas[lodIndex];
                    if (lodData.mesh == null)
                    {
                        continue;
                    }

                    for (int subMeshIndex = 0; subMeshIndex < lodData.SubMeshDatas.Length; subMeshIndex++)
                    {
                        var subMeshData = lodData.SubMeshDatas[subMeshIndex];
                        if (subMeshData.argsBuffer == null || subMeshData.rp.material == null)
                        {
                            continue;
                        }

                        RenderParams shadowRp = subMeshData.rp;
                        if (shadowRp.shadowCastingMode == ShadowCastingMode.Off)
                        {
                            continue;
                        }

                        shadowRp.shadowCastingMode = ShadowCastingMode.ShadowsOnly;
                        shadowRp.receiveShadows = false;

                        if (shadowRp.worldBounds.extents == Vector3.zero)
                        {
                            shadowRp.worldBounds = new Bounds(Vector3.zero, Vector3.one * 5000f);
                        }

                        Graphics.RenderMeshIndirect(shadowRp, lodData.mesh, subMeshData.argsBuffer);
                    }
                }
            }
        }

        private int ResolveForwardPassIndex(Material material)
        {
            int materialId = material.GetInstanceID();
            if (_forwardPassIndexCache.TryGetValue(materialId, out int cachedPassIndex))
            {
                return cachedPassIndex;
            }

            int passIndex = material.FindPass("ForwardLit");
            if (passIndex < 0)
            {
                passIndex = material.FindPass("UniversalForward");
            }
            if (passIndex < 0)
            {
                passIndex = material.FindPass("UniversalForwardOnly");
            }
            if (passIndex < 0)
            {
                passIndex = material.FindPass("SRPDefaultUnlit");
            }
            if (passIndex < 0)
            {
                passIndex = 0;
            }

            _forwardPassIndexCache[materialId] = passIndex;
            return passIndex;
        }

        private VgRender GetVgRender()
        {
            var field = typeof(VegetationSystemObject).GetField(
                "vgRender",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);

            if (field != null)
            {
                return field.GetValue(this) as VgRender;
            }

            return null;
        }

        public void SetHiZCullingEnabled(bool enabled)
        {
            _enableHiZCulling = enabled;
            InitializeHiZ();
            Debug.Log($"[VegetationHiZ] HiZ culling: {(_enableHiZCulling ? "enabled" : "disabled")}");
        }
    }
}

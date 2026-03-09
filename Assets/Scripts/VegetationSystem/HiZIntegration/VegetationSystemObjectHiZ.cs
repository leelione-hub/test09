using System.Collections.Generic;
using HiZTechnique;
using UnityEngine;
using UnityEngine.Rendering;
using Debug = UnityEngine.Debug;
using VGC = VegetationSystem.VgConstantProperty;

namespace VegetationSystem.HiZIntegration
{
    /// <summary>
    /// 支持 HiZ 的 VegetationSystemObject
    /// 继承自原版 VegetationSystemObject，增加 HiZ 剔除支持
    /// </summary>
    public class VegetationSystemObjectHiZ : VegetationSystemObject
    {
        [Header("HiZ 设置")]
        [Tooltip("是否启用 HiZ 剔除")]
        [SerializeField]
        private bool _enableHiZCulling = true;
        
        [Tooltip("HiZ 剔除模式")]
        [SerializeField]
        private HiZCullingMode _hizCullingMode = HiZCullingMode.GPU;
        
        [Tooltip("深度偏差（防止闪烁）")]
        [SerializeField]
        [Range(0f, 50f)]
        private float _hizDepthBias = 0.01f;
        
        [Tooltip("启用 HiZ 的 Compute Shader")]
        [SerializeField]
        private ComputeShader _hizCullingComputeShader;
        
        [Tooltip("使用原版 CS（禁用 HiZ 时）")]
        [SerializeField]
        private ComputeShader _originalCullingComputeShader;
        
        public enum HiZCullingMode
        {
            GPU,    // 在 Compute Shader 中进行
            CPU,    // 在 CPU Job 中进行（开发中）
        }
        
        // 运行时状态
        private bool _useHiZShader;
        private int _originalKernel = -1;
        private int _hizKernel = -1;
        
        // Shader 属性 ID
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

        private void Start()
        {
            InitializeHiZ();
        }

        /// <summary>
        /// 初始化 HiZ
        /// </summary>
        private void InitializeHiZ()
        {
            _useHiZShader = false;
            _originalKernel = -1;
            _hizKernel = -1;

            if (!_enableHiZCulling)
            {
                // 使用原版 Compute Shader
                if (_originalCullingComputeShader != null)
                {
                    cullingCS = _originalCullingComputeShader;
                }
                RefreshKernelHandles();
                return;
            }
            
            // 检查是否可以使用 HiZ
            var hizSystem = HiZTechnique.HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
            {
                Debug.LogWarning("[VegetationHiZ] HiZ 系统未激活，使用原版剔除");
                _enableHiZCulling = false;
                if (_originalCullingComputeShader != null)
                {
                    cullingCS = _originalCullingComputeShader;
                }
                RefreshKernelHandles();
                return;
            }
            
            // 设置 HiZ Compute Shader
            if (_hizCullingComputeShader != null)
            {
                cullingCS = _hizCullingComputeShader;
                RefreshKernelHandles();
                
                if (_hizKernel < 0)
                {
                    Debug.LogWarning("[VegetationHiZ] 找不到 CullInstancesWithHiZ kernel，使用原版剔除");
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
                Debug.LogWarning("[VegetationHiZ] 未提供 HiZ Compute Shader，使用原版剔除");
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
                return -1;

            try
            {
                return shader.FindKernel(kernelName);
            }
            catch
            {
                return -1;
            }
        }

        /// <summary>
        /// 保留空 Update 以阻止基类旧的 Update 渲染路径继续执行。
        /// </summary>
        protected void Update()
        {
            // no-op
        }

        /// <summary>
        /// 设置 HiZ 剔除参数
        /// </summary>
        private void SetupHiZCullingParameters()
        {
            var hizSystem = HiZTechnique.HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
                return;
            
            var depthPyramid = hizSystem.GetDepthPyramid();
            _depthPyramid = depthPyramid;
            if (depthPyramid == null || depthPyramid.DepthPyramidTexture == null)
                return;
            
            if (cullingCS == null)
                return;
            
            // 设置 HiZ 参数到所有 Kernel
            int[] kernels = new[] { _originalKernel, _hizKernel };
            
            foreach (int kernel in kernels)
            {
                if (kernel < 0) continue;
                
                // 设置深度纹理
                cullingCS.SetTexture(kernel, HizDepthTextureId, depthPyramid.DepthPyramidTexture);
                
                // 设置纹理尺寸
                cullingCS.SetVector(HizTextureSizeId, new Vector4(
                    depthPyramid.BaseSize.x,
                    depthPyramid.BaseSize.y,
                    depthPyramid.MipCount,
                    0));
                
                // 设置深度偏差（世界空间距离）
                cullingCS.SetFloat(HizWorldSpaceBiasId, _hizDepthBias);
                
                // 设置相机近/远平面（用于动态深度偏差计算）
                cullingCS.SetVector(CameraNearFarId, new Vector2(cullingCamera.nearClipPlane, cullingCamera.farClipPlane));
                
                // 设置是否启用 HiZ
                cullingCS.SetBool(EnableHiZCullingId, _enableHiZCulling);
                
                // 设置 Reversed Z
                cullingCS.SetInt(HizReversedZId, 
                    HiZTechnique.HizPlatformCompatibility.UsesReversedZ() ? 1 : 0);
                
                // Shader 侧使用 mul(matrix, vector)，这里不做转置。
                Matrix4x4 vp = GL.GetGPUProjectionMatrix(cullingCamera.projectionMatrix, false) * 
                              cullingCamera.worldToCameraMatrix;
                cullingCS.SetMatrix(VPMatrixId, vp);
            }
        }


        /// <summary>
        /// 重写 CSDispatch，使用 HiZ Kernel
        /// </summary>
        public new void CSDispatch()
        {
            if (cullingCS == null) return;

            bool canUseHiZKernel = _enableHiZCulling &&
                                   _useHiZShader &&
                                   _hizKernel >= 0 &&
                                   _depthPyramid != null &&
                                   _depthPyramid.DepthPyramidTexture != null;

            // 只有在HiZ资源有效时才使用HiZ kernel，否则回退到普通剔除kernel
            int kernel = canUseHiZKernel ? _hizKernel : _originalKernel;

            // 设置 HiZ 参数（如果启用）
            if (canUseHiZKernel)
            {
                cullingCS.SetBool(EnableHiZCullingId, true);
                
                // 确保 HiZ 参数已设置（可能在某些情况下 SetupHiZParameters 未被调用或参数被清除）
                cullingCS.SetTexture(kernel, HizDepthTextureId, _depthPyramid.DepthPyramidTexture);
                cullingCS.SetVector(HizTextureSizeId, new Vector4(
                    _depthPyramid.BaseSize.x,
                    _depthPyramid.BaseSize.y,
                    _depthPyramid.MipCount,
                    0));
                cullingCS.SetFloat(HizWorldSpaceBiasId, _hizDepthBias);
                cullingCS.SetVector(CameraNearFarId, new Vector2(cullingCamera.nearClipPlane, cullingCamera.farClipPlane));
                cullingCS.SetInt(HizReversedZId, 
                    HiZTechnique.HizPlatformCompatibility.UsesReversedZ() ? 1 : 0);
                
                // 更新 VP 矩阵 - 修复：不转置
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
                Debug.LogError("[VegetationHiZ] 找不到有效的 CullInstances kernel，跳过本帧剔除");
                return;
            }
            
            // 设置视锥体平面
            Plane[] planes = GeometryUtility.CalculateFrustumPlanes(cullingCamera);
            Vector4[] planeData = new Vector4[6];
            for (int i = 0; i < 6; i++)
            {
                var normal = planes[i].normal;
                var distance = planes[i].distance;
                planeData[i] = new Vector4(normal.x, normal.y, normal.z, distance);
            }
            cullingCS.SetVectorArray(VGC.FRUSTUMPLANES, planeData);
            
            // 设置相机位置
            cullingCS.SetVector(VGC.CAMERAPOSITION, cullingCamera.transform.position);

            // 获取渲染数据（通过反射访问基类的私有字段）
            var vgRender = GetVgRender();
            if (vgRender == null) return;
            
            Vector3 extens = Vector3.zero;

            // 处理每种植被
            for (int i = 0; i < vgRender.vegetationRenderDataList.Count; i++)
            {
                var renderData = vgRender.vegetationRenderDataList[i];
                
                // 重置 args buffer
                for (int j = 0; j < renderData.LodDatas.Length; j++)
                {
                    var lodData = renderData.LodDatas[j];
                    for (int k = 0; k < lodData.SubMeshDatas.Length; k++)
                    {
                        uint[] subArgs = new uint[5];
                        subArgs[0] = lodData.mesh.GetIndexCount(k);
                        subArgs[1] = (uint)0;
                        subArgs[2] = lodData.mesh.GetIndexStart(k);
                        subArgs[3] = lodData.mesh.GetBaseVertex(k);
                        subArgs[4] = 0;
                        lodData.SubMeshDatas[k].argsBuffer.SetData(subArgs);
                        extens = lodData.mesh.bounds.extents;
                    }
                    lodData.VisibleInstanceBuffer.SetCounterValue(0);
                }
                
                // 设置缓冲区
                cullingCS.SetBuffer(kernel, VGC.ALLINSTANCES, renderData.AllInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.VISIBLECHUNINFOS, renderData.VisibleChunkBuffer);
                cullingCS.SetInt(VGC.CHUNKCOUNT, renderData.visibleChunkCount);
                cullingCS.SetVector("_Extents",extens);
                
                // 设置 LOD 距离
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
                
                // 设置 LOD 缓冲区
                cullingCS.SetBuffer(kernel, VGC.LOD0VISIBLEINSTANCES, renderData.LodDatas[0].VisibleInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD1VISIBLEINSTANCES, renderData.LodDatas[1].VisibleInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD2VISIBLEINSTANCES, renderData.LodDatas[2].VisibleInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD0ARGSBUFFER, renderData.LodDatas[0].SubMeshDatas[0].argsBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD1ARGSBUFFER, renderData.LodDatas[1].SubMeshDatas[0].argsBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD2ARGSBUFFER, renderData.LodDatas[2].SubMeshDatas[0].argsBuffer);
                
                // 检查是否有可见 Chunk
                if (renderData.visibleChunkCount < 1)
                {
                    continue;
                }
                
                // 调度 Compute Shader
                int groupX = renderData.visibleChunkCount;
                int groupY = Mathf.CeilToInt(renderData.chunkMaxCount / 64f);
                cullingCS.Dispatch(kernel, groupX, groupY, 1);
                
                // 复制计数到 args buffer
                for (int n = 0; n < renderData.LodDatas.Length; n++)
                {
                    for (int k = 0; k < renderData.LodDatas[n].SubMeshDatas.Length; k++)
                    {
                        GraphicsBuffer.CopyCount(
                            renderData.LodDatas[n].VisibleInstanceBuffer,
                            renderData.LodDatas[n].SubMeshDatas[k].argsBuffer,
                            sizeof(uint) * 1);
                    }
                }
            }
        }

        /// <summary>
        /// 在 RenderPass 中执行一次完整剔除（CPU Chunk + HiZ 参数 + CS）
        /// </summary>
        public void ExecuteCullingForRenderPass(Camera renderCamera)
        {
            // 同一帧只剔除一次，GameView/SceneView 复用同一份剔除结果
            if (_lastCullingFrame == Time.frameCount)
            {
                return;
            }

            // 始终优先使用主相机进行剔除，保证 GameView/SceneView 一致
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

        /// <summary>
        /// 在 RenderPass 中通过 CommandBuffer.DrawMeshInstancedIndirect 执行绘制
        /// </summary>
        public void RenderWithCommandBuffer(CommandBuffer cmd)
        {
            if (cmd == null)
            {
                return;
            }

            var vgRender = GetVgRender();
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
                        var material = subMeshData.rp.material;
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

        /// <summary>
        /// 提交阴影投射绘制（每帧一次），供阴影阶段使用
        /// </summary>
        public void SubmitShadowCasters()
        {
            if (_lastShadowSubmitFrame == Time.frameCount)
            {
                return;
            }
            _lastShadowSubmitFrame = Time.frameCount;

            var vgRender = GetVgRender();
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

        /// <summary>
        /// 获取 VgRender（通过反射）
        /// </summary>
        private VgRender GetVgRender()
        {
            var field = typeof(VegetationSystemObject).GetField("vgRender",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            if (field != null)
            {
                return field.GetValue(this) as VgRender;
            }
            
            return null;
        }

        /// <summary>
        /// 设置 HiZ 剔除启用状态
        /// </summary>
        public void SetHiZCullingEnabled(bool enabled)
        {
            _enableHiZCulling = enabled;
            InitializeHiZ();

            Debug.Log($"[VegetationHiZ] HiZ 剔除：{(_enableHiZCulling ? "启用" : "禁用")}");
        }
    }
}

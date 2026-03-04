using System;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using HiZTechnique;

namespace VegetationSystem.HiZIntegration
{
    /// <summary>
    /// VegetationSystem HiZ集成组件
    /// 为植被系统提供HiZ遮挡剔除功能
    /// </summary>
    [RequireComponent(typeof(VegetationSystemObject))]
    public class VegetationHizIntegrator : MonoBehaviour
    {
        [Header("HiZ设置")]
        [Tooltip("是否启用HiZ剔除")]
        [SerializeField]
        private bool _enableHiZCulling = true;
        
        [Tooltip("剔除模式")]
        [SerializeField]
        private HiZCullingMode _cullingMode = HiZCullingMode.GPU;
        
        [Tooltip("深度偏差（防止闪烁）")]
        [SerializeField]
        private float _depthBias = 0.01f;
        
        [Tooltip("剔除频率（每N帧执行一次）")]
        [SerializeField]
        [Range(1, 5)]
        private int _cullingFrameInterval = 1;
        
        [Tooltip("包围盒扩展")]
        [SerializeField]
        private float _boundsPadding = 0.5f;
        
        [Header("调试")]
        [Tooltip("显示剔除统计")]
        [SerializeField]
        private bool _showDebugInfo = false;
        
        [Tooltip("显示被剔除的Chunk")]
        [SerializeField]
        private bool _showCulledChunks = false;
        
        public enum HiZCullingMode
        {
            GPU,    // 在Compute Shader中进行HiZ剔除
            CPU,    // 在Job中进行HiZ剔除
        }
        
        // 引用
        private VegetationSystemObject _vegetationSystem;
        private HizSystem _hizSystem;
        private Camera _cullingCamera;
        
        // 运行时数据
        private VegetationHiZCullingJob _hizCullingJob;
        private NativeArray<byte> _hizCullingResults;
        private NativeArray<float> _chunkDepths;
        private int _frameCounter;
        
        // 统计
        private int _totalChunks;
        private int _culledByFrustum;
        private int _culledByHiZ;
        private int _visibleChunks;
        
        // 缓存的Chunk数据
        private List<ChunkInfoForJob> _allChunks = new List<ChunkInfoForJob>();
        private Dictionary<uint, int> _guidToIndex = new Dictionary<uint, int>();
        
        // Shader属性
        private static readonly int HizDepthTextureId = Shader.PropertyToID("_HizDepthTexture");
        private static readonly int HizTextureSizeId = Shader.PropertyToID("_HizTextureSize");
        private static readonly int HizDepthBiasId = Shader.PropertyToID("_HizDepthBias");
        private static readonly int VPMatrixId = Shader.PropertyToID("_HiZ_VP");
        private static readonly int EnableHiZCullingId = Shader.PropertyToID("_EnableHiZCulling");
        private static readonly int HizReversedZId = Shader.PropertyToID("_HizReversedZ");
        
        /// <summary>
        /// 是否启用HiZ剔除
        /// </summary>
        public bool EnableHiZCulling
        {
            get => _enableHiZCulling;
            set => _enableHiZCulling = value;
        }
        
        /// <summary>
        /// 剔除模式
        /// </summary>
        public HiZCullingMode CullingMode
        {
            get => _cullingMode;
            set => _cullingMode = value;
        }

        private void Awake()
        {
            _vegetationSystem = GetComponent<VegetationSystemObject>();
            _hizSystem = HizSystem.Instance;
        }

        private void Start()
        {
            Initialize();
        }

        private void OnDestroy()
        {
            DisposeNativeArrays();
        }

        /// <summary>
        /// 初始化
        /// </summary>
        private void Initialize()
        {
            if (_vegetationSystem == null)
            {
                Debug.LogError("[VegetationHiZ] VegetationSystemObject未找到");
                return;
            }

            _cullingCamera = _vegetationSystem.cullingCamera ?? Camera.main;
            
            // 等待HiZ系统初始化
            if (_hizSystem == null)
            {
                _hizSystem = HizSystem.Instance;
            }
            
            // 收集所有Chunk信息
            CollectChunkInfo();
        }

        /// <summary>
        /// 收集Chunk信息
        /// </summary>
        private void CollectChunkInfo()
        {
            _allChunks.Clear();
            _guidToIndex.Clear();
            
            // 这里需要从VegetationSystem获取Chunk数据
            // 通过反射或者修改VgRender提供访问接口
            var vgRender = GetVgRender();
            if (vgRender != null && vgRender.vegetationChunkForJobDataNativeList.IsCreated)
            {
                var chunks = vgRender.vegetationChunkForJobDataNativeList;
                for (int i = 0; i < chunks.Length; i++)
                {
                    var chunk = chunks[i];
                    _allChunks.Add(chunk);
                    _guidToIndex[chunk.guid] = i;
                }
                
                _totalChunks = _allChunks.Count;
                
                // 初始化NativeArray
                if (_cullingMode == HiZCullingMode.CPU)
                {
                    InitializeNativeArrays();
                }
            }
        }

        /// <summary>
        /// 初始化Native Arrays
        /// </summary>
        private void InitializeNativeArrays()
        {
            DisposeNativeArrays();
            
            if (_allChunks.Count > 0)
            {
                _hizCullingResults = new NativeArray<byte>(_allChunks.Count, Allocator.Persistent);
                _chunkDepths = new NativeArray<float>(_allChunks.Count, Allocator.Persistent);
            }
        }

        /// <summary>
        /// 释放Native Arrays
        /// </summary>
        private void DisposeNativeArrays()
        {
            if (_hizCullingResults.IsCreated)
                _hizCullingResults.Dispose();
            if (_chunkDepths.IsCreated)
                _chunkDepths.Dispose();
        }

        /// <summary>
        /// 获取VgRender（通过反射）
        /// </summary>
        private VgRender GetVgRender()
        {
            var field = typeof(VegetationSystemObject).GetField("vgRender",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            if (field != null)
            {
                return field.GetValue(_vegetationSystem) as VgRender;
            }
            
            return null;
        }

        /// <summary>
        /// 获取VgCulling（通过反射）
        /// </summary>
        private VgCulling GetVgCulling()
        {
            var field = typeof(VegetationSystemObject).GetField("vgCulling",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            if (field != null)
            {
                return field.GetValue(_vegetationSystem) as VgCulling;
            }
            
            return null;
        }

        /// <summary>
        /// 获取可见Chunk HashSet（通过反射）
        /// </summary>
        private HashSet<uint> GetVisibleChunkHashSet()
        {
            var vgRender = GetVgRender();
            if (vgRender != null)
            {
                return vgRender.visibleChunkGuidHashset;
            }
            
            return null;
        }

        /// <summary>
        /// 执行HiZ剔除
        /// </summary>
        public void ExecuteHiZCulling()
        {
            if (!_enableHiZCulling || _hizSystem == null || !_hizSystem.IsActive)
                return;

            _frameCounter++;
            if (_frameCounter % _cullingFrameInterval != 0)
                return;

            var depthPyramid = _hizSystem.GetDepthPyramid();
            if (depthPyramid == null || depthPyramid.DepthPyramidTexture == null)
                return;

            switch (_cullingMode)
            {
                case HiZCullingMode.GPU:
                    SetupGPUHiZCulling(depthPyramid);
                    break;
                case HiZCullingMode.CPU:
                    ExecuteCPUHiZCulling(depthPyramid);
                    break;
            }
        }

        /// <summary>
        /// 设置GPU HiZ剔除参数
        /// </summary>
        private void SetupGPUHiZCulling(HizDepthPyramid depthPyramid)
        {
            var computeShader = _vegetationSystem.cullingCS;
            if (computeShader == null) return;

            int kernel = computeShader.FindKernel("CullInstances");
            if (kernel < 0) return;

            // 设置HiZ相关参数
            computeShader.SetTexture(kernel, HizDepthTextureId, depthPyramid.DepthPyramidTexture);
            computeShader.SetVector(HizTextureSizeId, new Vector4(
                depthPyramid.BaseSize.x,
                depthPyramid.BaseSize.y,
                depthPyramid.MipCount,
                0));
            computeShader.SetFloat(HizDepthBiasId, _depthBias);
            computeShader.SetBool(EnableHiZCullingId, true);
            computeShader.SetInt(HizReversedZId, HizPlatformCompatibility.UsesReversedZ() ? 1 : 0);
            
            // 设置VP矩阵
            // Unity 矩阵是列主序，但 HLSL mul(vector, matrix) 期望行向量
            // 所以我们需要转置矩阵或使用 mul(matrix, vector) 并调整顺序
            Matrix4x4 vp = GL.GetGPUProjectionMatrix(_cullingCamera.projectionMatrix, false) * 
                          _cullingCamera.worldToCameraMatrix;
            
            // 转置矩阵以适应 HLSL 的 mul(matrix, vector) 语义
            computeShader.SetMatrix(VPMatrixId, vp.transpose);
        }

        /// <summary>
        /// 执行CPU HiZ剔除
        /// </summary>
        private void ExecuteCPUHiZCulling(HizDepthPyramid depthPyramid)
        {
            var visibleChunks = GetVisibleChunkHashSet();
            if (visibleChunks == null || _allChunks.Count == 0)
                return;

            // 重置统计
            _culledByHiZ = 0;
            _visibleChunks = 0;

            // 准备Job数据
            var hizTexture = depthPyramid.DepthPyramidTexture;
            int baseWidth = depthPyramid.BaseSize.x;
            int baseHeight = depthPyramid.BaseSize.y;
            int mipCount = depthPyramid.MipCount;

            // 读取深度纹理数据到CPU（这可能会成为瓶颈，建议仅在调试时使用）
            // 更好的方案是使用异步回读
            
            // 创建并调度Job
            // VP矩阵需要转置以适应 math.mul(matrix, vector) 语义
            Matrix4x4 vpMatrix = GL.GetGPUProjectionMatrix(_cullingCamera.projectionMatrix, false) * 
                                _cullingCamera.worldToCameraMatrix;
            
            _hizCullingJob = new VegetationHiZCullingJob
            {
                Chunks = new NativeArray<ChunkInfoForJob>(_allChunks.ToArray(), Allocator.TempJob),
                VisibleChunkGuids = new NativeArray<uint>(new List<uint>(visibleChunks).ToArray(), Allocator.TempJob),
                Results = new NativeArray<byte>(_allChunks.Count, Allocator.TempJob),
                VP = vpMatrix.transpose,
                DepthBias = _depthBias,
                BaseWidth = baseWidth,
                BaseHeight = baseHeight,
                MipCount = mipCount,
                UseReversedZ = HizPlatformCompatibility.UsesReversedZ()
            };

            JobHandle jobHandle = _hizCullingJob.Schedule(_allChunks.Count, 32);
            jobHandle.Complete();

            // 处理结果
            ProcessCullingResults();

            // 清理
            _hizCullingJob.Chunks.Dispose();
            _hizCullingJob.VisibleChunkGuids.Dispose();
            _hizCullingJob.Results.Dispose();
        }

        /// <summary>
        /// 处理剔除结果
        /// </summary>
        private void ProcessCullingResults()
        {
            var visibleChunks = GetVisibleChunkHashSet();
            if (visibleChunks == null) return;

            for (int i = 0; i < _allChunks.Count; i++)
            {
                uint guid = _allChunks[i].guid;
                if (!visibleChunks.Contains(guid))
                    continue;

                if (_hizCullingJob.Results[i] == 1) // 被HiZ剔除
                {
                    visibleChunks.Remove(guid);
                    _culledByHiZ++;
                }
                else
                {
                    _visibleChunks++;
                }
            }

            // 更新VgRender的可见Chunk Buffer
            var vgRender = GetVgRender();
            vgRender?.RefreshVisibleChunkBuffer();
        }

        /// <summary>
        /// 在VegetationSystem的CSDispatch之前调用
        /// </summary>
        public void PreCSDispatch()
        {
            ExecuteHiZCulling();
        }

        private void Update()
        {
            // 调试信息显示
            if (_showDebugInfo)
            {
                UpdateDebugInfo();
            }
        }

        private void UpdateDebugInfo()
        {
            if (Time.frameCount % 30 == 0)
            {
                var visibleChunks = GetVisibleChunkHashSet();
                int visibleCount = visibleChunks?.Count ?? 0;
                
                Debug.Log($"[VegetationHiZ] 总Chunk: {_totalChunks}, 视锥可见: {visibleCount + _culledByHiZ}, " +
                         $"HiZ剔除: {_culledByHiZ}, 最终可见: {visibleCount}");
            }
        }

        private void OnDrawGizmos()
        {
            if (!_showCulledChunks || !_enableHiZCulling)
                return;

            Gizmos.color = new Color(1, 0, 0, 0.3f);
            
            for (int i = 0; i < _allChunks.Count; i++)
            {
                if (_hizCullingResults.IsCreated && _hizCullingResults[i] == 1)
                {
                    var chunk = _allChunks[i];
                    Gizmos.DrawWireCube(chunk.center, chunk.extents * 2f);
                }
            }
        }
    }
}

using System;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ剔除数据接口
    /// </summary>
    public interface IHizCullingObject
    {
        /// <summary>
        /// 世界空间包围盒中心
        /// </summary>
        Vector3 BoundsCenter { get; }
        
        /// <summary>
        /// 世界空间包围盒大小
        /// </summary>
        Vector3 BoundsExtents { get; }
        
        /// <summary>
        /// 是否激活
        /// </summary>
        bool IsActive { get; }
        
        /// <summary>
        /// 被剔除时的回调
        /// </summary>
        void OnCulled();
        
        /// <summary>
        /// 被恢复时的回调
        /// </summary>
        void OnVisible();
    }
    
    /// <summary>
    /// 剔除数据容器
    /// </summary>
    public struct CullingData
    {
        public float3 Center;
        public float3 Extents;
        public int InstanceID;
        public bool WasVisible;
    }
    
    /// <summary>
    /// HiZ剔除管理器
    /// 负责管理所有参与HiZ剔除的对象，并执行剔除计算
    /// </summary>
    public class HizCullingManager : IDisposable
    {
        #region 属性
        
        private HizSettings _settings;
        private ComputeShader _cullingComputeShader;
        
        // 剔除对象列表
        private List<IHizCullingObject> _cullingObjects = new List<IHizCullingObject>();
        private Dictionary<int, int> _instanceIdToIndex = new Dictionary<int, int>();
        
        // Compute Buffers
        private ComputeBuffer _centersBuffer;
        private ComputeBuffer _extentsBuffer;
        private ComputeBuffer _resultsBuffer;
        private ComputeBuffer _visibleIndicesBuffer;
        
        // CPU数据
        private List<CullingData> _cullingData = new List<CullingData>();
        private float[] _cullingResults;
        private int[] _visibleIndices;
        
        // 视锥体
        private Plane[] _frustumPlanes = new Plane[6];
        private Vector4[] _frustumPlanesVector = new Vector4[6];
        
        // 运行时状态
        private bool _isInitialized;
        private int _frameCounter;
        private AsyncGPUReadbackRequest? _pendingRequest;
        
        // 统计
        private HizCullingStats _stats = new HizCullingStats();
        private List<HizCullingStats> _statsHistory = new List<HizCullingStats>();
        
        // Shader属性ID
        private static readonly int AllCentersId = Shader.PropertyToID("_AllCenters");
        private static readonly int AllExtentsId = Shader.PropertyToID("_AllExtents");
        private static readonly int CullingResultBufferId = Shader.PropertyToID("_CullingResultBuffer");
        private static readonly int VisibleIndicesBufferId = Shader.PropertyToID("_VisibleIndicesBuffer");
        private static readonly int VPId = Shader.PropertyToID("_VP");
        private static readonly int FrustumPlanesId = Shader.PropertyToID("_FrustumPlanes");
        private static readonly int InstanceCountId = Shader.PropertyToID("_InstanceCount");
        private static readonly int DepthBiasId = Shader.PropertyToID("_DepthBias");
        private static readonly int HizDepthTextureId = Shader.PropertyToID("_HizDepthTexture");
        private static readonly int HizDepthTextureBaseWidthId = Shader.PropertyToID("_HizDepthTextureBaseWidth");
        private static readonly int HizDepthTextureBaseHeightId = Shader.PropertyToID("_HizDepthTextureBaseHeight");
        
        // Kernel
        private int _cullingKernel;
        private int _threadGroupSize = 64;
        
        /// <summary>
        /// 是否初始化完成
        /// </summary>
        public bool IsInitialized => _isInitialized;
        
        /// <summary>
        /// 当前剔除统计
        /// </summary>
        public HizCullingStats CurrentStats => _stats;
        
        /// <summary>
        /// 统计历史
        /// </summary>
        public List<HizCullingStats> StatsHistory => _statsHistory;
        
        /// <summary>
        /// 参与剔除的对象数量
        /// </summary>
        public int ObjectCount => _cullingObjects.Count;
        
        #endregion
        
        #region 初始化
        
        public bool Initialize(HizSettings settings, ComputeShader cullingShader)
        {
            _settings = settings;
            _cullingComputeShader = cullingShader;
            
            if (_cullingComputeShader == null)
            {
                Debug.LogWarning("[HiZ CullingManager] 未提供剔除Compute Shader");
                return false;
            }
            
            if (!SystemInfo.supportsComputeShaders)
            {
                Debug.LogWarning("[HiZ CullingManager] 当前平台不支持Compute Shader");
                return false;
            }
            
            _cullingKernel = _cullingComputeShader.FindKernel("CSMain");
            if (_cullingKernel < 0)
            {
                // 尝试其他kernel名称
                _cullingKernel = _cullingComputeShader.FindKernel("HizCull");
            }
            
            if (_cullingKernel < 0)
            {
                Debug.LogError("[HiZ CullingManager] 无法找到剔除Compute Shader Kernel");
                return false;
            }
            
            _isInitialized = true;
            return true;
        }
        
        #endregion
        
        #region 对象管理
        
        /// <summary>
        /// 注册剔除对象
        /// </summary>
        public void RegisterObject(IHizCullingObject obj)
        {
            if (obj == null) return;
            
            int instanceId = obj.GetHashCode();
            if (_instanceIdToIndex.ContainsKey(instanceId))
                return;
            
            _cullingObjects.Add(obj);
            _instanceIdToIndex[instanceId] = _cullingObjects.Count - 1;
            
            _cullingData.Add(new CullingData
            {
                Center = obj.BoundsCenter,
                Extents = obj.BoundsExtents,
                InstanceID = instanceId,
                WasVisible = true
            });
            
            // 标记需要重建buffers
            RebuildBuffers();
        }
        
        /// <summary>
        /// 注销剔除对象
        /// </summary>
        public void UnregisterObject(IHizCullingObject obj)
        {
            if (obj == null) return;
            
            int instanceId = obj.GetHashCode();
            if (!_instanceIdToIndex.TryGetValue(instanceId, out int index))
                return;
            
            // 如果之前是被剔除的，恢复它
            if (!_cullingData[index].WasVisible)
            {
                obj.OnVisible();
            }
            
            _cullingObjects.RemoveAt(index);
            _cullingData.RemoveAt(index);
            _instanceIdToIndex.Remove(instanceId);
            
            // 更新索引映射
            for (int i = index; i < _cullingObjects.Count; i++)
            {
                int id = _cullingObjects[i].GetHashCode();
                _instanceIdToIndex[id] = i;
            }
            
            RebuildBuffers();
        }
        
        /// <summary>
        /// 清空所有对象
        /// </summary>
        public void ClearObjects()
        {
            // 恢复所有被剔除的对象
            foreach (var obj in _cullingObjects)
            {
                if (obj != null)
                {
                    obj.OnVisible();
                }
            }
            
            _cullingObjects.Clear();
            _cullingData.Clear();
            _instanceIdToIndex.Clear();
            
            RebuildBuffers();
        }
        
        /// <summary>
        /// 更新对象包围盒数据
        /// </summary>
        public void UpdateObjectBounds(IHizCullingObject obj)
        {
            int instanceId = obj.GetHashCode();
            if (!_instanceIdToIndex.TryGetValue(instanceId, out int index))
                return;
            
            var data = _cullingData[index];
            data.Center = obj.BoundsCenter;
            data.Extents = obj.BoundsExtents;
            _cullingData[index] = data;
        }
        
        #endregion
        
        #region Buffer管理
        
        private void RebuildBuffers()
        {
            ReleaseBuffers();
            
            int count = _cullingObjects.Count;
            if (count == 0) return;
            
            // 限制每帧处理的最大实例数
            count = Mathf.Min(count, _settings.maxInstancesPerFrame);
            
            _centersBuffer = new ComputeBuffer(count, sizeof(float) * 3);
            _extentsBuffer = new ComputeBuffer(count, sizeof(float) * 3);
            _resultsBuffer = new ComputeBuffer(count, sizeof(float));
            _visibleIndicesBuffer = new ComputeBuffer(count, sizeof(int));
            
            _cullingResults = new float[count];
            _visibleIndices = new int[count];
            
            // 更新Compute Shader参数
            _cullingComputeShader.SetBuffer(_cullingKernel, AllCentersId, _centersBuffer);
            _cullingComputeShader.SetBuffer(_cullingKernel, AllExtentsId, _extentsBuffer);
            _cullingComputeShader.SetBuffer(_cullingKernel, CullingResultBufferId, _resultsBuffer);
            _cullingComputeShader.SetBuffer(_cullingKernel, VisibleIndicesBufferId, _visibleIndicesBuffer);
        }
        
        private void ReleaseBuffers()
        {
            _centersBuffer?.Release();
            _extentsBuffer?.Release();
            _resultsBuffer?.Release();
            _visibleIndicesBuffer?.Release();
            
            _centersBuffer = null;
            _extentsBuffer = null;
            _resultsBuffer = null;
            _visibleIndicesBuffer = null;
        }
        
        private void UpdateBuffers()
        {
            if (_centersBuffer == null || _cullingObjects.Count == 0)
                return;
            
            int count = Mathf.Min(_cullingObjects.Count, _settings.maxInstancesPerFrame);
            float3[] centers = new float3[count];
            float3[] extents = new float3[count];
            
            for (int i = 0; i < count; i++)
            {
                centers[i] = _cullingData[i].Center;
                extents[i] = _cullingData[i].Extents;
            }
            
            _centersBuffer.SetData(centers);
            _extentsBuffer.SetData(extents);
        }
        
        #endregion
        
        #region 剔除执行
        
        /// <summary>
        /// 执行剔除
        /// </summary>
        public void ExecuteCulling(Camera camera, RenderTexture hizDepthTexture, int hizBaseWidth, int hizBaseHeight)
        {
            if (!_isInitialized || _cullingObjects.Count == 0)
                return;
            
            _frameCounter++;
            if (_frameCounter % _settings.cullingFrameInterval != 0)
                return;
            
            // 检查是否有未完成的GPU回读请求
            if (_pendingRequest.HasValue && !_pendingRequest.Value.done)
            {
                // 跳过这一帧的剔除，避免堆积
                return;
            }
            
            // 处理上一次的结果
            if (_pendingRequest.HasValue && _pendingRequest.Value.done)
            {
                ProcessCullingResults();
                _pendingRequest = null;
            }
            
            // 执行新的剔除
            DispatchCulling(camera, hizDepthTexture, hizBaseWidth, hizBaseHeight);
        }
        
        private void DispatchCulling(Camera camera, RenderTexture hizDepthTexture, int hizBaseWidth, int hizBaseHeight)
        {
            // 更新视锥体
            GeometryUtility.CalculateFrustumPlanes(camera.projectionMatrix * camera.worldToCameraMatrix, _frustumPlanes);
            for (int i = 0; i < 6; i++)
            {
                _frustumPlanesVector[i] = new Vector4(
                    _frustumPlanes[i].normal.x,
                    _frustumPlanes[i].normal.y,
                    _frustumPlanes[i].normal.z,
                    _frustumPlanes[i].distance
                );
            }
            
            // 更新Buffer数据
            UpdateBuffers();
            
            int count = Mathf.Min(_cullingObjects.Count, _settings.maxInstancesPerFrame);
            
            // 设置Compute Shader参数
            Matrix4x4 vp = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false) * camera.worldToCameraMatrix;
            _cullingComputeShader.SetMatrix(VPId, vp);
            _cullingComputeShader.SetVectorArray(FrustumPlanesId, _frustumPlanesVector);
            _cullingComputeShader.SetInt(InstanceCountId, count);
            _cullingComputeShader.SetFloat(DepthBiasId, _settings.depthBias);
            _cullingComputeShader.SetInt(HizDepthTextureBaseWidthId, hizBaseWidth);
            _cullingComputeShader.SetInt(HizDepthTextureBaseHeightId, hizBaseHeight);
            _cullingComputeShader.SetTexture(_cullingKernel, HizDepthTextureId, hizDepthTexture);
            
            // 调度Compute Shader
            int threadGroups = Mathf.CeilToInt(count / (float)_threadGroupSize);
            _cullingComputeShader.Dispatch(_cullingKernel, threadGroups, 1, 1);
            
            // 异步读取结果
            _pendingRequest = AsyncGPUReadback.Request(_resultsBuffer);
            
            // 重置统计
            _stats.Reset();
            _stats.totalInstances = count;
        }
        
        private void ProcessCullingResults()
        {
            if (!_pendingRequest.HasValue)
                return;
            
            var request = _pendingRequest.Value;
            if (request.hasError)
            {
                Debug.LogWarning("[HiZ CullingManager] GPU回读发生错误");
                return;
            }
            
            request.GetData<float>().CopyTo(_cullingResults);
            
            int visibleCount = 0;
            int frustumCulled = 0;
            int hizCulled = 0;
            
            for (int i = 0; i < _cullingResults.Length && i < _cullingObjects.Count; i++)
            {
                var obj = _cullingObjects[i];
                if (obj == null || !obj.IsActive)
                    continue;
                
                int result = (int)_cullingResults[i];
                bool isVisible = result == 0; // 0表示可见
                
                var data = _cullingData[i];
                
                if (!isVisible)
                {
                    // 判断是被视锥体剔除还是被HiZ剔除
                    if (result == 1)
                    {
                        frustumCulled++;
                    }
                    else
                    {
                        hizCulled++;
                    }
                    
                    if (data.WasVisible)
                    {
                        obj.OnCulled();
                        data.WasVisible = false;
                        _cullingData[i] = data;
                    }
                }
                else
                {
                    visibleCount++;
                    if (!data.WasVisible)
                    {
                        obj.OnVisible();
                        data.WasVisible = true;
                        _cullingData[i] = data;
                    }
                }
            }
            
            _stats.visibleInstances = visibleCount;
            _stats.culledByFrustum = frustumCulled;
            _stats.culledByHiz = hizCulled;
            
            // 记录历史
            _statsHistory.Add(new HizCullingStats
            {
                totalInstances = _stats.totalInstances,
                visibleInstances = visibleCount,
                culledByFrustum = frustumCulled,
                culledByHiz = hizCulled,
                frameCount = Time.frameCount
            });
            
            // 限制历史记录数量
            while (_statsHistory.Count > _settings.profilingFrameCount)
            {
                _statsHistory.RemoveAt(0);
            }
        }
        
        #endregion
        
        #region 工具方法
        
        /// <summary>
        /// 获取平均剔除率
        /// </summary>
        public float GetAverageCullingRatio()
        {
            if (_statsHistory.Count == 0)
                return 0f;
            
            float sum = 0f;
            foreach (var stat in _statsHistory)
            {
                sum += stat.CullingRatio;
            }
            return sum / _statsHistory.Count;
        }
        
        /// <summary>
        /// 获取平均GPU耗时（估算）
        /// </summary>
        public float GetAverageCullingTime()
        {
            if (_statsHistory.Count == 0)
                return 0f;
            
            float sum = 0f;
            foreach (var stat in _statsHistory)
            {
                sum += stat.cullingTimeMs;
            }
            return sum / _statsHistory.Count;
        }
        
        /// <summary>
        /// 清空统计历史
        /// </summary>
        public void ClearStats()
        {
            _statsHistory.Clear();
            _stats.Reset();
        }
        
        #endregion
        
        #region IDisposable
        
        public void Dispose()
        {
            ClearObjects();
            ReleaseBuffers();
            _isInitialized = false;
        }
        
        #endregion
    }
}

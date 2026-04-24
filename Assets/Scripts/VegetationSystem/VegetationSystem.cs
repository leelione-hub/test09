using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;
using VegetationSystem.HiZIntegration;

namespace VegetationSystem
{
    public enum VgtationType
    {
        Grass,
        Tree,
        Shrub
    }

    public class VegetationSystemObject : MonoBehaviour
    {
        [Header("Data Source")]
        [SerializeField] private Terrain _terrain;
        [FormerlySerializedAs("chunkDatas")]
        [SerializeField] private TextAsset _chunkDataAsset;

        [Header("Runtime")]
        [FormerlySerializedAs("isDrawTerrainTrees")]
        [SerializeField] private bool _drawTerrainTrees;
        [FormerlySerializedAs("cullingCS")]
        [SerializeField] private ComputeShader _cullingComputeShader;
        [FormerlySerializedAs("cullingCamera")]
        [SerializeField] private Camera _cullingCamera;
        [FormerlySerializedAs("ShowGizmos")]
        [SerializeField] private bool _showGizmos;
        [FormerlySerializedAs("enableVegetationSystem")]
        [SerializeField] private bool _enableVegetationSystem = true;

        [FormerlySerializedAs("renderMesh")]
        [SerializeField, HideInInspector] private Mesh _legacyRenderMesh;
        [FormerlySerializedAs("renderMaterial")]
        [SerializeField, HideInInspector] private Material _legacyRenderMaterial;

        [Header("HiZ Settings")]
        [Tooltip("Enable HiZ culling.")]
        [SerializeField] private bool _enableHiZCulling;

        [Tooltip("HiZ culling mode.")]
        [SerializeField] private HiZCullingMode _hizCullingMode = HiZCullingMode.GPU;

        [Tooltip("Depth bias in world space.")]
        [SerializeField]
        [Range(0f, 50f)]
        private float _hizDepthBias = 0.01f;

        [Tooltip("HiZ compute shader.")]
        [SerializeField] private ComputeShader _hizCullingComputeShader;

        [Tooltip("Fallback compute shader when HiZ is disabled.")]
        [SerializeField] private ComputeShader _originalCullingComputeShader;

        [Header("Shadow Settings")]
        [Tooltip("Maximum vegetation shadow distance in meters. Set to 0 to reuse the render distance.")]
        [SerializeField]
        [Min(0f)]
        private float _maxShadowDistance = 0f;

        private TerrainTreeDatas _treeDatas;
        private ComputeShader _baseCullingShader;
        private readonly VgRuntimeRenderer _runtimeRenderer = new VgRuntimeRenderer();
        private readonly VegetationCullingPipeline _cullingPipeline;
        private readonly VegetationHiZController _hizController = new VegetationHiZController();

        private VgRender _vgRender;

        public enum HiZCullingMode
        {
            GPU,
            CPU,
        }

        public bool RequiresDepthPyramid => _hizController.RequiresDepthPyramid(this);
        public bool UsesRenderFeatureRendering => _hizController.UsesRenderFeatureRendering;
        public bool EnableVegetationSystem => _enableVegetationSystem;

        protected VegetationSystemObject()
        {
            _cullingPipeline = new VegetationCullingPipeline(new VgGpuCullingDispatcher());
        }

        private void Awake()
        {
            _baseCullingShader = _cullingComputeShader;

            if (_cullingCamera == null)
            {
                _cullingCamera = Camera.main;
            }

            if (_terrain == null)
            {
                _terrain = GetComponent<Terrain>();
            }

            if (_terrain != null)
            {
                _terrain.drawTreesAndFoliage = _drawTerrainTrees;
            }

            InitData();
        }

        private void Start()
        {
            SyncHiZSettings();
            _hizController.EnsureInitialized();
        }

        private void OnEnable()
        {
            SyncHiZSettings();
            _hizController.ResetInitialization();
        }

        protected virtual void Update()
        {
            if (UsesRenderFeatureRendering && VegetationRenderFeature.IsAvailable)
            {
                return;
            }

            if (!_enableVegetationSystem)
            {
                return;
            }

            ExecuteCulling();
            Render();
        }

        public virtual void InitData()
        {
            if (_chunkDataAsset == null)
            {
                return;
            }

            _treeDatas = TerrainTreeSerialization.LoadChunkDataFromTextAsset(_chunkDataAsset);
            if (_treeDatas == null)
            {
                return;
            }

            Vector3 terrainSize = _terrain != null ? _terrain.terrainData.size : Vector3.one;
            _vgRender = new VgRender();
            _vgRender.InitVegetationRenderData(_treeDatas, terrainSize, _terrain, gameObject.layer);
            _cullingPipeline.Initialize(_vgRender);
        }

        public void ChunkCullingOnCPU()
        {
            _cullingPipeline.ExecuteCpuCulling(_cullingCamera, _vgRender);
        }

        protected void ExecuteCulling()
        {
            ExecuteCpuCulling();
            ExecuteGpuCulling();
        }

        protected void ExecuteCpuCulling()
        {
            ChunkCullingOnCPU();
        }

        protected void ExecuteGpuCulling()
        {
            CSDispatch();
        }

        public virtual void CSDispatch()
        {
            SyncHiZSettings();

            if (_enableHiZCulling && _hizCullingMode == HiZCullingMode.GPU)
            {
                _hizController.SetupHiZCullingParameters(_cullingCamera);
            }

            if (!_hizController.TryPrepareDispatch(
                    _cullingCamera,
                    out int cullKernel,
                    out int classifyKernel,
                    out Action<ComputeShader, int, Camera> configureCullKernel))
            {
                return;
            }

            _cullingPipeline.ExecuteGpuCulling(
                _hizController.ActiveComputeShader,
                _cullingCamera,
                _vgRender,
                cullKernel,
                classifyKernel,
                _maxShadowDistance,
                configureCullKernel);
        }

        public void Render()
        {
            if (_vgRender == null)
            {
                return;
            }

            _runtimeRenderer.RenderDirect(_vgRender.vegetationRenderDataList);
        }

        public void OnDrawGizmos()
        {
            if (!Application.isPlaying || !_showGizmos || _vgRender == null)
            {
                return;
            }

            var visibleChunkList = new List<ChunkInfoForJob>();
            foreach (var chunk in _vgRender.vegetationChunkForJobDataNativeList)
            {
                if (_vgRender.visibleChunkGuidHashset.Contains(chunk.guid))
                {
                    visibleChunkList.Add(chunk);
                }

                Gizmos.color = Color.red;
                Gizmos.DrawWireCube(chunk.center, chunk.extents * 2f - Vector3.one);
            }

            foreach (var chunk in visibleChunkList)
            {
                Gizmos.color = Color.green;
                Gizmos.DrawWireCube(chunk.center, chunk.extents * 2f - Vector3.one);
            }
        }

        public void OnDestroy()
        {
            _vgRender?.Dispose();
            _cullingPipeline.Dispose();

            if (_terrain != null)
            {
                _terrain.drawTreesAndFoliage = true;
            }
        }

        protected VgRender GetVgRender()
        {
            return _vgRender;
        }

        protected bool DispatchGpuCulling(
            int cullKernel,
            int classifyKernel,
            Action<ComputeShader, int, Camera> configureCullKernel = null)
        {
            return _cullingPipeline.ExecuteGpuCulling(
                _hizController.ActiveComputeShader,
                _cullingCamera,
                _vgRender,
                cullKernel,
                classifyKernel,
                _maxShadowDistance,
                configureCullKernel);
        }

        protected VgRuntimeRenderer GetRuntimeRenderer()
        {
            return _runtimeRenderer;
        }

        public void ExecuteCullingForRenderPass(Camera renderCamera)
        {
            SyncHiZSettings();
            if (!_hizController.TryBeginRenderPass(renderCamera, _cullingCamera, out Camera cullCamera))
            {
                return;
            }

            _cullingCamera = cullCamera;
            ExecuteCpuCulling();

            if (_enableHiZCulling && _hizCullingMode == HiZCullingMode.GPU)
            {
                _hizController.SetupHiZCullingParameters(_cullingCamera);
            }

            ExecuteGpuCulling();
            _hizController.MarkCulledThisFrame();
        }

        public void RenderWithCommandBuffer(CommandBuffer cmd)
        {
            if (cmd == null)
            {
                return;
            }

            VgRender renderData = GetVgRender();
            if (renderData == null)
            {
                return;
            }

            GetRuntimeRenderer().RenderWithCommandBuffer(cmd, renderData.vegetationRenderDataList);
        }

        public void SubmitShadowCasters()
        {
            if (!_hizController.TryBeginShadowSubmission())
            {
                return;
            }

            VgRender renderData = GetVgRender();
            if (renderData == null)
            {
                return;
            }

            GetRuntimeRenderer().SubmitShadowCasters(renderData.vegetationRenderDataList);
        }

        public void SetHiZCullingEnabled(bool enabled)
        {
            _enableHiZCulling = enabled;
            SyncHiZSettings();
            _hizController.SetHiZCullingEnabled(enabled);
            _cullingComputeShader = _hizController.ActiveComputeShader;
        }

        private void SyncHiZSettings()
        {
            _hizController.SyncSettings(
                _enableHiZCulling,
                _hizCullingMode,
                _hizDepthBias,
                _hizCullingComputeShader,
                _originalCullingComputeShader != null
                    ? _originalCullingComputeShader
                    : (_baseCullingShader != null ? _baseCullingShader : _cullingComputeShader));

            _cullingComputeShader = _hizController.ActiveComputeShader ?? _cullingComputeShader;
        }
    }
}

using System.Collections.Generic;
using UnityEngine;

namespace VegetationSystem
{
    public sealed class GrassIndirectRenderer : MonoBehaviour
    {
        [SerializeField] private Vector3 _terrainSize = new Vector3(1000f, 1000f, 1000f);
        [SerializeField] private bool _enableFrustumCulling = true;
        [SerializeField] private Camera _cullingCamera;
        [SerializeField] private ComputeShader _cullingComputeShader;
        [SerializeField] private TextAsset _grassDataAsset;

        private readonly VgRuntimeRenderer _runtimeRenderer = new VgRuntimeRenderer();
        private readonly VgGpuCullingDispatcher _gpuCullingDispatcher = new VgGpuCullingDispatcher();

        private VgRender _vgRender;
        private VgCulling _cpuCulling;

        private void Start()
        {
            if (_cullingCamera == null)
            {
                _cullingCamera = Camera.main;
            }

            Terrain terrain = GetComponent<Terrain>();
            if (terrain != null)
            {
                _terrainSize = terrain.terrainData.size;
            }

            TerrainTreeData grassData = LoadGrassData();
            if (grassData == null)
            {
                enabled = false;
                return;
            }

            TerrainTreeDatas chunkedGrassData = ConvertToChunkedData(grassData, _terrainSize);

            _vgRender = new VgRender();
            _vgRender.InitVegetationRenderData(chunkedGrassData, _terrainSize, terrain, gameObject.layer);
            _cpuCulling = new VgCulling(_vgRender);
        }

        private void Update()
        {
            if (_vgRender == null || _cullingComputeShader == null || _cullingCamera == null)
            {
                return;
            }

            if (_enableFrustumCulling && _cpuCulling != null)
            {
                _cpuCulling.SetCullingCamera(_cullingCamera);
                _cpuCulling.ScheduleCulling(_vgRender.visibleChunkGuidHashset);
                _vgRender.RefreshVisibleChunkBuffer();
            }
            else
            {
                ResetVisibleChunksToAll();
            }

            int cullKernel = FindKernel("CullInstances");
            int classifyKernel = FindKernel("ClassifyVisibleInstances");
            if (cullKernel < 0 || classifyKernel < 0)
            {
                return;
            }

            _gpuCullingDispatcher.Dispatch(
                _cullingComputeShader,
                _cullingCamera,
                _vgRender,
                cullKernel,
                classifyKernel,
                0f);

            _runtimeRenderer.RenderDirect(_vgRender.vegetationRenderDataList);
        }

        private void OnDisable()
        {
            _cpuCulling?.Dispose();
            _vgRender?.Dispose();
            _cpuCulling = null;
            _vgRender = null;
        }

        private TerrainTreeData LoadGrassData()
        {
            if (_grassDataAsset == null)
            {
                return null;
            }

            return TerrainTreeSerialization.LoadTreeDataFromTextAsset(_grassDataAsset);
        }

        private TerrainTreeDatas ConvertToChunkedData(TerrainTreeData sourceData, Vector3 terrainSize)
        {
            List<TreeInstanceData> worldInstances = new List<TreeInstanceData>(sourceData.trees.Count);
            Bounds chunkBounds = default;
            bool hasBounds = false;

            for (int i = 0; i < sourceData.trees.Count; i++)
            {
                TreeInstanceData source = sourceData.trees[i];
                Vector3 worldPosition = Vector3.Scale(source.position, terrainSize);

                TreeInstanceData converted = new TreeInstanceData
                {
                    position = worldPosition,
                    scale = source.scale,
                    prototypeIndex = source.prototypeIndex,
                    rotation = source.rotation
                };
                worldInstances.Add(converted);

                Vector3 extents = new Vector3(
                    Mathf.Max(converted.scale.x, 1f),
                    Mathf.Max(converted.scale.y, 1f),
                    Mathf.Max(converted.scale.z, 1f));

                if (!hasBounds)
                {
                    chunkBounds = new Bounds(worldPosition, extents * 2f);
                    hasBounds = true;
                }
                else
                {
                    chunkBounds.Encapsulate(new Bounds(worldPosition, extents * 2f));
                }
            }

            if (!hasBounds)
            {
                chunkBounds = new Bounds(Vector3.zero, terrainSize);
            }

            return new TerrainTreeDatas
            {
                prefabPath = new List<string>(sourceData.prefabPath),
                chunkDatas = new List<TerrainChunkData>
                {
                    new TerrainChunkData
                    {
                        aabb = chunkBounds,
                        trees = worldInstances
                    }
                }
            };
        }

        private void ResetVisibleChunksToAll()
        {
            var visibleChunkSet = _vgRender.visibleChunkGuidHashset;
            visibleChunkSet.Clear();

            var allChunkInfos = _vgRender.vegetationChunkForJobDataNativeList;
            for (int i = 0; i < allChunkInfos.Length; i++)
            {
                visibleChunkSet.Add(allChunkInfos[i].guid);
            }

            _vgRender.RefreshVisibleChunkBuffer();
        }

        private int FindKernel(string kernelName)
        {
            if (_cullingComputeShader == null)
            {
                return -1;
            }

            try
            {
                return _cullingComputeShader.FindKernel(kernelName);
            }
            catch
            {
                return -1;
            }
        }
    }
}

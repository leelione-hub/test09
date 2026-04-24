using System;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

namespace VegetationSystem
{
    public sealed class VegetationRenderDataBuilder
    {
        private readonly int _instanceStride;
        private readonly int _chunkInfoStride;

        public VegetationRenderDataBuilder(int instanceStride, int chunkInfoStride)
        {
            _instanceStride = instanceStride;
            _chunkInfoStride = chunkInfoStride;
        }

        public void Build(
            VegetationRuntimeData runtimeData,
            TerrainTreeDatas treeDatas,
            Vector3 terrainSize,
            Terrain terrain = null,
            int renderLayer = -1)
        {
            runtimeData.VegetationRenderDataList.Clear();
            runtimeData.VisibleChunkGuidSet.Clear();
            if (runtimeData.ChunkInfosForJob.IsCreated)
            {
                runtimeData.ChunkInfosForJob.Dispose();
            }

            VegetationTerrainBlendData.ApplyTerrainBlendGlobals(terrain);

            Dictionary<int, List<GrassInstanceData>> instanceDatasByPrototype = new Dictionary<int, List<GrassInstanceData>>();
            Dictionary<int, List<ChunkInfoBuffer>> chunkInfosByPrototype = new Dictionary<int, List<ChunkInfoBuffer>>();
            Dictionary<int, int> singleChunkMaxCountsByPrototype = new Dictionary<int, int>();
            List<ChunkInfoForJob> chunkInfosForJob = new List<ChunkInfoForJob>();

            BuildChunkData(
                treeDatas,
                instanceDatasByPrototype,
                chunkInfosByPrototype,
                singleChunkMaxCountsByPrototype,
                chunkInfosForJob);

            runtimeData.ChunkInfosForJob =
                new NativeArray<ChunkInfoForJob>(chunkInfosForJob.ToArray(), Allocator.Persistent);

            for (int i = 0; i < treeDatas.prefabPath.Count; i++)
            {
                int prototypeIndex = i;
                if (!instanceDatasByPrototype.ContainsKey(prototypeIndex))
                {
                    continue;
                }

                VegetationRenderData renderData = CreateRenderData(
                    prototypeIndex,
                    treeDatas.prefabPath[i],
                    instanceDatasByPrototype[prototypeIndex],
                    chunkInfosByPrototype[prototypeIndex],
                    singleChunkMaxCountsByPrototype[prototypeIndex],
                    terrain,
                    renderLayer);

                runtimeData.VegetationRenderDataList.Add(renderData);
            }
        }

        private void BuildChunkData(
            TerrainTreeDatas treeDatas,
            Dictionary<int, List<GrassInstanceData>> instanceDatasByPrototype,
            Dictionary<int, List<ChunkInfoBuffer>> chunkInfosByPrototype,
            Dictionary<int, int> singleChunkMaxCountsByPrototype,
            List<ChunkInfoForJob> chunkInfosForJob)
        {
            foreach (var chunk in treeDatas.chunkDatas)
            {
                int guid = chunk.GetHashCode();
                Dictionary<int, StartIndex2Count> startIndexByPrototype = new Dictionary<int, StartIndex2Count>();
                foreach (var tree in chunk.trees)
                {
                    if (!startIndexByPrototype.ContainsKey(tree.prototypeIndex))
                    {
                        StartIndex2Count startIndex2Count = new StartIndex2Count
                        {
                            startIndex = instanceDatasByPrototype.TryGetValue(tree.prototypeIndex, out var existingInstances)
                                ? existingInstances.Count
                                : 0,
                            count = 1
                        };
                        startIndexByPrototype.Add(tree.prototypeIndex, startIndex2Count);
                    }
                    else
                    {
                        var startIndex2Count = startIndexByPrototype[tree.prototypeIndex];
                        startIndex2Count.count++;
                        startIndexByPrototype[tree.prototypeIndex] = startIndex2Count;
                    }

                    if (!instanceDatasByPrototype.ContainsKey(tree.prototypeIndex))
                    {
                        instanceDatasByPrototype.Add(tree.prototypeIndex, new List<GrassInstanceData>());
                    }

                    instanceDatasByPrototype[tree.prototypeIndex].Add(ConvertToGrassInstanceData(tree));
                }

                foreach (var entry in startIndexByPrototype)
                {
                    int prototypeIndex = entry.Key;
                    int startIndex = entry.Value.startIndex;
                    int count = entry.Value.count;
                    ChunkInfoBuffer chunkInfoBuffer = new ChunkInfoBuffer
                    {
                        guid = (uint)guid,
                        center = chunk.aabb.center,
                        extents = chunk.aabb.extents,
                        startIndex = (uint)startIndex,
                        count = (uint)count,
                    };

                    if (!chunkInfosByPrototype.ContainsKey(prototypeIndex))
                    {
                        chunkInfosByPrototype.Add(prototypeIndex, new List<ChunkInfoBuffer>());
                    }
                    chunkInfosByPrototype[prototypeIndex].Add(chunkInfoBuffer);

                    if (!singleChunkMaxCountsByPrototype.ContainsKey(prototypeIndex))
                    {
                        singleChunkMaxCountsByPrototype.Add(prototypeIndex, 0);
                    }

                    if (singleChunkMaxCountsByPrototype[prototypeIndex] < count)
                    {
                        singleChunkMaxCountsByPrototype[prototypeIndex] = count;
                    }
                }

                chunkInfosForJob.Add(new ChunkInfoForJob
                {
                    guid = (uint)guid,
                    center = chunk.aabb.center,
                    extents = chunk.aabb.extents
                });
            }
        }

        private VegetationRenderData CreateRenderData(
            int prototypeIndex,
            string prefabPath,
            List<GrassInstanceData> allInstances,
            List<ChunkInfoBuffer> allChunkInfos,
            int chunkMaxCount,
            Terrain terrain,
            int renderLayer)
        {
            var prefab = Resources.Load<GameObject>(prefabPath);
#if UNITY_EDITOR
            prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
#endif
            var meshRenderer = prefab.GetComponentInChildren<MeshRenderer>();
            var shadowMode = meshRenderer.shadowCastingMode;
            Mesh mesh = prefab.GetComponentInChildren<MeshFilter>().sharedMesh;

            VegetationRenderData data = new VegetationRenderData
            {
                prototypeIndex = prototypeIndex,
                mesh = mesh,
                instanceMaxCount = allInstances.Count,
                chunkMaxCount = chunkMaxCount,
                visibleChunkCount = allChunkInfos.Count,
                AllInstanceDatas = allInstances,
                allChunkInfos = allChunkInfos,
                visibleChunkInfos = allChunkInfos,
            };

            GraphicsBuffer allInstanceBuffer =
                new GraphicsBuffer(GraphicsBuffer.Target.Structured, data.instanceMaxCount, _instanceStride);
            allInstanceBuffer.SetData(data.AllInstanceDatas);
            data.AllInstanceBuffer = allInstanceBuffer;

            data.VisibleInstanceBuffer =
                new GraphicsBuffer(GraphicsBuffer.Target.Append, data.instanceMaxCount, _instanceStride);
            data.VisibleInstanceCountBuffer =
                new GraphicsBuffer(GraphicsBuffer.Target.Structured, 1, sizeof(uint));
            data.VisibleChunkBuffer =
                new GraphicsBuffer(GraphicsBuffer.Target.Structured, data.chunkMaxCount, _chunkInfoStride);

            PopulateLodData(ref data, prefab, meshRenderer, mesh, shadowMode, terrain, renderLayer);
            return data;
        }

        private void PopulateLodData(
            ref VegetationRenderData data,
            GameObject prefab,
            MeshRenderer meshRenderer,
            Mesh mesh,
            ShadowCastingMode shadowMode,
            Terrain terrain,
            int renderLayer)
        {
            var lodGroup = prefab.GetComponentInChildren<LODGroup>();
            if (lodGroup == null)
            {
                throw new Exception($"Prefab:{prefab.name} 不包含LODGroup组件，这是不合法！！！！");
            }

            var lods = lodGroup.GetLODs();
            if (lods == null || lods.Length == 0)
            {
                throw new Exception($"Prefab:{prefab.name} 的 LODGroup 没有可用的 LOD 数据。");
            }

            data.activeLodCount = lods.Length;
            data.lodScreenHeights = new float[data.activeLodCount];
            data.LodDatas = new VegetaionRenderLodData[data.activeLodCount];
            data.lodReferenceHeight = Mathf.Max(lodGroup.size, mesh.bounds.size.y);
            Bounds mergedBounds = mesh.bounds;

            int targetLayer = renderLayer >= 0 ? renderLayer : prefab.layer;
            for (int j = 0; j < data.activeLodCount; j++)
            {
                var selectedLod = lods[j];
                data.lodScreenHeights[j] = selectedLod.screenRelativeTransitionHeight;

                var lodRender = selectedLod.renderers[0];
                var lodMesh = lodRender.GetComponent<MeshFilter>().sharedMesh;
                mergedBounds.Encapsulate(lodMesh.bounds);
                VegetaionRenderLodData lodData = new VegetaionRenderLodData
                {
                    mesh = lodMesh,
                    SubMeshDatas = new VegetationRenderSubMeshData[lodMesh.subMeshCount],
                    VisibleInstanceBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append,
                        data.instanceMaxCount, _instanceStride),
                    ShadowVisibleInstanceBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append,
                        data.instanceMaxCount, _instanceStride)
                };

                for (int n = 0; n < lodMesh.subMeshCount; n++)
                {
                    lodData.SubMeshDatas[n] = CreateSubMeshData(
                        lodRender.sharedMaterials[n],
                        n,
                        targetLayer,
                        lodRender.renderingLayerMask,
                        lodRender.shadowCastingMode,
                        lodMesh,
                        lodData.VisibleInstanceBuffer,
                        terrain);
                }

                data.LodDatas[j] = lodData;
            }

            data.boundsCenterOS = mergedBounds.center;
            data.boundsExtentsOS = mergedBounds.extents;

            data.SubMeshDatas = new VegetationRenderSubMeshData[mesh.subMeshCount];
            for (int k = 0; k < mesh.subMeshCount; k++)
            {
                data.SubMeshDatas[k] = CreateSubMeshData(
                    meshRenderer.sharedMaterials[k],
                    k,
                    targetLayer,
                    meshRenderer.renderingLayerMask,
                    shadowMode,
                    mesh,
                    data.VisibleInstanceBuffer,
                    terrain);
            }
        }

        private static GrassInstanceData ConvertToGrassInstanceData(TreeInstanceData treeInstanceData)
        {
            return new GrassInstanceData
            {
                position = treeInstanceData.position,
                rotationY = treeInstanceData.rotation,
                scale = treeInstanceData.scale
            };
        }

        private VegetationRenderSubMeshData CreateSubMeshData(
            Material material,
            int subMesh,
            int layer,
            uint renderingLayerMask,
            ShadowCastingMode shadowMode,
            Mesh mesh,
            GraphicsBuffer visibleBuffer,
            Terrain terrain)
        {
            var subMat = new Material(material);
            var shadowMat = new Material(material);
            RenderParams subRp = new RenderParams(subMat)
            {
                worldBounds = new Bounds(Vector3.zero, Vector3.one * 5000f),
                layer = layer,
                shadowCastingMode = shadowMode,
                renderingLayerMask = renderingLayerMask,
                receiveShadows = true
            };

            RenderParams shadowRp = new RenderParams(shadowMat)
            {
                worldBounds = new Bounds(Vector3.zero, Vector3.one * 5000f),
                layer = layer,
                shadowCastingMode = shadowMode,
                renderingLayerMask = renderingLayerMask,
                receiveShadows = false
            };

            VegetationRenderSubMeshData subMeshData = new VegetationRenderSubMeshData
            {
                subMesh = subMesh,
                argsBuffer = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, 1, sizeof(uint) * 5),
                shadowArgsBuffer = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, 1, sizeof(uint) * 5),
                rp = subRp,
                shadowRp = shadowRp
            };

            uint[] subArgs = new uint[5];
            subArgs[0] = mesh.GetIndexCount(subMesh);
            subArgs[1] = 0u;
            subArgs[2] = mesh.GetIndexStart(subMesh);
            subArgs[3] = mesh.GetBaseVertex(subMesh);
            subArgs[4] = 0u;
            subMeshData.argsBuffer.SetData(subArgs);
            subMeshData.shadowArgsBuffer.SetData(subArgs);

            subMeshData.rp.material.EnableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
            subMeshData.rp.material.SetBuffer(VgConstantProperty.INSTANCEBUFFER, visibleBuffer);
            ApplyTerrainBlendProperties(subMeshData.rp.material, terrain);

            subMeshData.shadowRp.material.EnableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
            ApplyTerrainBlendProperties(subMeshData.shadowRp.material, terrain);
            return subMeshData;
        }

        private static void ApplyTerrainBlendProperties(Material material, Terrain terrain)
        {
            VegetationTerrainBlendData.ApplyTerrainBlendProperties(material, terrain);
        }
    }
}

using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;

namespace VegetationSystem
{
    public static class VgConstantProperty
    {
        public static readonly int INSTANCEBUFFER = Shader.PropertyToID("_InstanceBuffer");
        public static readonly int ALLINSTANCES = Shader.PropertyToID("_AllInstances");
        public static readonly int VISIBLEINSTANCES = Shader.PropertyToID("_VisibleInstances");
        public static readonly int CULLEDVISIBLEINSTANCES = Shader.PropertyToID("_CulledVisibleInstances");
        public static readonly int CULLEDVISIBLEINSTANCESINPUT = Shader.PropertyToID("_CulledVisibleInstancesInput");
        public static readonly int VISIBLEINSTANCECOUNT = Shader.PropertyToID("_VisibleInstanceCount");
        public static readonly int ARGSBUFFER = Shader.PropertyToID("_ArgsBuffer");
        public static readonly int FRUSTUMPLANES = Shader.PropertyToID("_FrustumPlanes");
        public static readonly int ENABLECULLING = Shader.PropertyToID("EnableFrustumCulling");
        public static readonly int VISIBLECHUNINFOS = Shader.PropertyToID("_VisibleChunkInfos");
        public static readonly int CHUNKCOUNT = Shader.PropertyToID("_ChunkCount");
        public static readonly int CAMERAPOSITION = Shader.PropertyToID("_CameraPosition");
        public static readonly int LODDISTANCERANGE = Shader.PropertyToID("_LodDistanceRange");
        public static readonly int BOUNDSEXTENTS = Shader.PropertyToID("_Extents");
        public static readonly int BOUNDSCENTEROS = Shader.PropertyToID("_BoundsCenterOS");
        public const string KW_GPUINSTANCEON = "GRAPHICDRAW_ON";
    }

    public struct VegetationRenderData
    {
        public int prototypeIndex;
        public int instanceMaxCount;
        public int chunkMaxCount;
        public int visibleChunkCount;
        public int activeLodCount;

        public Mesh mesh;
        public GraphicsBuffer AllInstanceBuffer;
        public GraphicsBuffer VisibleChunkBuffer;
        public GraphicsBuffer VisibleInstanceBuffer;
        public GraphicsBuffer VisibleInstanceCountBuffer;

        public List<GrassInstanceData> AllInstanceDatas;
        public List<ChunkInfoBuffer> allChunkInfos;
        public List<ChunkInfoBuffer> visibleChunkInfos;

        public VegetationRenderSubMeshData[] SubMeshDatas;
        public float[] lodScreenHeights;
        public VegetaionRenderLodData[] LodDatas;
        public Vector3 boundsCenterOS;
        public Vector3 boundsExtentsOS;
        public float lodReferenceHeight;
    }

    public struct VegetaionRenderLodData
    {
        public GraphicsBuffer VisibleInstanceBuffer;
        public GraphicsBuffer ShadowVisibleInstanceBuffer;
        public Mesh mesh;
        public VegetationRenderSubMeshData[] SubMeshDatas;
    }

    public struct VegetationRenderSubMeshData
    {
        public int subMesh;
        public RenderParams rp;
        public RenderParams shadowRp;
        public GraphicsBuffer argsBuffer;
        public GraphicsBuffer shadowArgsBuffer;
    }

    public struct GrassInstanceData
    {
        public Vector3 position;
        public float rotationY;
        public Vector2 scale;
    }

    public struct ChunkInfoForJob
    {
        public uint guid;
        public Vector3 center;
        public Vector3 extents;
    }

    public struct ChunkInfoBuffer
    {
        public uint guid;
        public Vector3 center;
        public Vector3 extents;
        public uint startIndex;
        public uint count;
    }

    public struct StartIndex2Count
    {
        public int startIndex;
        public int count;
    }

    public sealed class VgRender
    {
        private const int InstanceStride = sizeof(float) * (3 + 1 + 2);
        private const int ChunkInfoStride = sizeof(float) * (3 + 3) + sizeof(uint) * 3;

        private readonly VegetationRuntimeData _runtimeData = new VegetationRuntimeData();
        private readonly VegetationLodUtility _lodUtility = new VegetationLodUtility();
        private readonly VegetationVisibleChunkUpdater _visibleChunkUpdater = new VegetationVisibleChunkUpdater();
        private readonly VegetationRenderDataDisposer _runtimeDisposer = new VegetationRenderDataDisposer();
        private readonly VegetationRenderDataBuilder _renderDataBuilder;

        public VgRender()
        {
            _renderDataBuilder = new VegetationRenderDataBuilder(InstanceStride, ChunkInfoStride);
        }

        public List<VegetationRenderData> vegetationRenderDataList => _runtimeData.VegetationRenderDataList;
        public NativeArray<ChunkInfoForJob> vegetationChunkForJobDataNativeList => _runtimeData.ChunkInfosForJob;
        public HashSet<uint> visibleChunkGuidHashset => _runtimeData.VisibleChunkGuidSet;

        public float CaculateLodDistance(float n, float h1, float y, float H)
        {
            return _lodUtility.CalculateLodDistance(n, h1, y, H);
        }

        public float CaculateLodDistance(Camera camera, float objectHalfHeight, float transitionHeight)
        {
            return _lodUtility.CalculateLodDistance(camera, objectHalfHeight, transitionHeight);
        }

        public float GetLodDistance(VegetationRenderData data, int lodIndex, Camera camera, float lodBias)
        {
            return _lodUtility.GetLodDistance(data, lodIndex, camera, lodBias);
        }

        public bool TryGetLodDistanceRange(
            VegetationRenderData data,
            int lodIndex,
            Camera camera,
            float lodBias,
            int maximumLodLevel,
            out Vector2 distanceRange)
        {
            return _lodUtility.TryGetLodDistanceRange(
                data,
                lodIndex,
                camera,
                lodBias,
                maximumLodLevel,
                out distanceRange);
        }

        public void InitVegetationRenderData(
            TerrainTreeDatas treeDatas,
            Vector3 terrainSize,
            Terrain terrain = null,
            int renderLayer = -1)
        {
            _renderDataBuilder.Build(_runtimeData, treeDatas, terrainSize, terrain, renderLayer);
        }

        public void RefreshVisibleChunkBuffer()
        {
            _visibleChunkUpdater.Refresh(_runtimeData, ChunkInfoStride);
        }

        public void Dispose()
        {
            _runtimeDisposer.Dispose(_runtimeData);
        }
    }
}

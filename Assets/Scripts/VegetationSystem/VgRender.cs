using System;
using System.Collections.Generic;
using System.Drawing;
using Extension;
using Unity.Collections;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

//1.从json中获取所有chunkinfolist
//2.利用job粗粒度剔除不可见的chunk，得到visibleChunkinfolist
//3.利用visibleChunkinfolist生成不同protetypeIndex的ChunkInfoBuffer的list给computeshader剔除使用
//4.在cs中将剔除过的grassInstanceData数据存到对应的visibleBuffer中
//5.将对应的visiblebuffer指定给对应的材质球

namespace VegetationSystem
{
    public class VgConstantProperty
    {
        public static int    INSTANCEBUFFER       = Shader.PropertyToID("_InstanceBuffer");
        public static int    ALLINSTANCES         = Shader.PropertyToID("_AllInstances");
        public static int    VISIBLEINSTANCES     = Shader.PropertyToID("_VisibleInstances");
        public static int    CULLEDVISIBLEINSTANCES = Shader.PropertyToID("_CulledVisibleInstances");
        public static int    CULLEDVISIBLEINSTANCESINPUT = Shader.PropertyToID("_CulledVisibleInstancesInput");
        public static int    VISIBLEINSTANCECOUNT = Shader.PropertyToID("_VisibleInstanceCount");
        public static int    ARGSBUFFER           = Shader.PropertyToID("_ArgsBuffer");
        public static int    FRUSTUMPLANES        = Shader.PropertyToID("_FrustumPlanes");
        public static int    ENABLECULLING        = Shader.PropertyToID("EnableFrustumCulling");
        public static int    VISIBLECHUNINFOS     = Shader.PropertyToID("_VisibleChunkInfos");
        public static int    CHUNKCOUNT           = Shader.PropertyToID("_ChunkCount");
        public static int    CAMERAPOSITION       = Shader.PropertyToID("_CameraPosition");
        public static int    LODDISTANCERANGE     = Shader.PropertyToID("_LodDistanceRange");
        public static int    BOUNDSEXTENTS        = Shader.PropertyToID("_Extents");
        public static int    BOUNDSCENTEROS       = Shader.PropertyToID("_BoundsCenterOS");
        public static string KW_GPUINSTANCEON     = "GRAPHICDRAW_ON";
    }
        
    #region StructData
    public struct VgRenderData
    {
        public int            grassCount;
        public RenderParams   rp;
        public Mesh           mesh;
        public GraphicsBuffer args;
        public GraphicsBuffer allInstanceBuffer;
        public GraphicsBuffer visibleBuffer;
        public VgtationType   vgType;
        public int            prototypeIndex;
        public int            subMesh;
    }

    public struct VegetationRenderData
    {
        public int prototypeIndex;
        public int instanceMaxCount;
        public int chunkMaxCount;
        public int visibleChunkCount;
        public int activeLodCount;

        // public RenderParams   rp;
        public Mesh           mesh;
        public GraphicsBuffer AllInstanceBuffer;
        public GraphicsBuffer VisibleChunkBuffer;
        public GraphicsBuffer VisibleInstanceBuffer;
        public GraphicsBuffer VisibleInstanceCountBuffer;
        // public GraphicsBuffer argsBuffer;

        public List<GrassInstanceData>       AllInstanceDatas;
        public List<ChunkInfoBuffer>         allChunkInfos;
        public List<ChunkInfoBuffer>         visibleChunkInfos;
        
        public VegetationRenderSubMeshData[] SubMeshDatas;
        public float[]                       lodScreenHeights;
        public VegetaionRenderLodData[]      LodDatas;
        public Vector3                       boundsCenterOS;
        public Vector3                       boundsExtentsOS;
        public float                         lodReferenceHeight;
    }

    public struct VegetaionRenderLodData
    {
        public GraphicsBuffer VisibleInstanceBuffer;
        public  Mesh           mesh;

        public VegetationRenderSubMeshData[] SubMeshDatas;
    }

    public struct VegetationRenderSubMeshData
    {
        public int            subMesh;
        public RenderParams   rp;
        public GraphicsBuffer argsBuffer;
    }
    
    public struct GrassInstanceData
    {
        public Vector3 position;
        public float   rotationY;
        public Vector2 scale;
    }

    public struct OldChunkInfo
    {
        public uint    startIndex;
        public uint    count;
        public Vector3 center;
        public Vector3 size;
    }

    public struct InstanceRenderData
    {
        public int            prototypeIndex;
        public int            count;
        public RenderParams   rp;
        public Mesh           mesh;
        public GraphicsBuffer argsBuffer;
        public GraphicsBuffer allInstanceBuffer;
        public GraphicsBuffer visibleChunkBuffer;
        public GraphicsBuffer visibleInstanceBuffer;
        public int            perChnkInstanceMaxCount;
        public int            ChunkCount;
    }

    public struct ChunkInfoForJob
    {
        public uint    guid;
        public Vector3 center;
        public Vector3 extents;
    }

    /// <summary>
    /// 单独一个Chunk中单独一个prototypeIndex的信息
    /// </summary>
    public struct ChunkInfoBuffer
    {
        public uint    guid;
        public Vector3 center;
        public Vector3 extents;
        public uint    startIndex;
        public uint    count;
    }

    public struct ChunkInfo
    {
        public uint                                     guid;
        public Vector3                                  center;
        public Vector3                                  extents;
        /// <summary>
        /// key值为对应的prototypeIndex值 value1:startIndex,value2:count,value3:perChunkMaxCount
        /// </summary>
        public Dictionary<int, (uint, uint)>            start2count;
        // public Dictionary<int, List<GrassInstanceData>> instanceDatas;
    }

    public struct StartIndex2Count
    {
        public int startIndex;
        public int count;
    }
    
    #endregion
    
    //默认情形：使用的Terrain上的Tree数据
    //同一套TRS使用不同的mesh和材质球
    //material和positionbuffer绑定，Graphics接口中只需要设置对应的rp、mesh和argsbuffer
    //将一个Terrain与一个Renderer类绑定，可以比较方便的处理一个场景中存在多个Terrain多套Vegetation的情形（层级有一个需求是一个超大的场景中分布稀稀疏疏的几个岛屿，出于性能考虑每个岛都一个vegetation的系统）
    public class VgRender
    {
        private static readonly int ControlId = Shader.PropertyToID("_Control");
        private static readonly int Splat0Id = Shader.PropertyToID("_Splat0");
        private static readonly int Splat1Id = Shader.PropertyToID("_Splat1");
        private static readonly int Splat2Id = Shader.PropertyToID("_Splat2");
        private static readonly int Splat3Id = Shader.PropertyToID("_Splat3");
        private static readonly int Splat0StId = Shader.PropertyToID("_Splat0_ST");
        private static readonly int Splat1StId = Shader.PropertyToID("_Splat1_ST");
        private static readonly int Splat2StId = Shader.PropertyToID("_Splat2_ST");
        private static readonly int Splat3StId = Shader.PropertyToID("_Splat3_ST");
        private static readonly int DiffuseRemapScale0Id = Shader.PropertyToID("_DiffuseRemapScale0");
        private static readonly int DiffuseRemapScale1Id = Shader.PropertyToID("_DiffuseRemapScale1");
        private static readonly int DiffuseRemapScale2Id = Shader.PropertyToID("_DiffuseRemapScale2");
        private static readonly int DiffuseRemapScale3Id = Shader.PropertyToID("_DiffuseRemapScale3");
        private static readonly int TerrainTransformDataId = Shader.PropertyToID("_TerrainTransformData");
        private static readonly int TerrainRoughnessId = Shader.PropertyToID("_TerrainRoughness");
        private static readonly int TerrainColorId = Shader.PropertyToID("_TerrainColor");
        private const string TerrainBlendBakedKeyword = "_TERRAIN_BLEND_BAKED";

        private static readonly int[] SplatTextureIds =
        {
            Splat0Id,
            Splat1Id,
            Splat2Id,
            Splat3Id
        };

        private static readonly int[] SplatStIds =
        {
            Splat0StId,
            Splat1StId,
            Splat2StId,
            Splat3StId
        };

        private static readonly int[] DiffuseRemapScaleIds =
        {
            DiffuseRemapScale0Id,
            DiffuseRemapScale1Id,
            DiffuseRemapScale2Id,
            DiffuseRemapScale3Id
        };

        public List<VgRenderData>                  vgDataList = new List<VgRenderData>();
        public Dictionary<int, List<VgRenderData>> vgDataDic  = new Dictionary<int, List<VgRenderData>>();
        
        Dictionary<int, List<GrassInstanceData>> treesData       = new Dictionary<int, List<GrassInstanceData>>();
        public int                               stride          = sizeof(float) * (3 + 1 + 2);
        public int                               instanceStride  = sizeof(float) * (3 + 1 + 2);
        public int                               chunkinfoStride = sizeof(float) * (3 + 3) + sizeof(uint) * (1 + 1 + 1);
        public int                               grassCount;
        public bool                              isCulling;
        public List<ChunkInfo>                   allChunkInfoList = new List<ChunkInfo>();
        /// <summary>
        /// key:guid
        /// </summary>
        public Dictionary<uint, ChunkInfo> allChunkInfoDic     = new Dictionary<uint, ChunkInfo>();
        /// <summary>
        /// key:guid value1:startIndex value2:count
        /// </summary>
        public Dictionary<uint, (int, int)> allChunkInfo;
        public List<ChunkInfoForJob>        AllChunkInfoForJobs = new List<ChunkInfoForJob>();
        /// <summary>
        /// 每个chunk中最大的instance数量
        /// </summary>
        public Dictionary<int, int> chunkPreMaxCount = new Dictionary<int, int>();

        public HashSet<uint>                       visibleChunkGuidHashset = new HashSet<uint>();
        public Dictionary<int, List<VgRenderData>> allVgDataDic         = new Dictionary<int, List<VgRenderData>>();

        [Obsolete("旧版本没有使用Chunk加速")]
        public void InitVgDatas(TerrainTreeData treedata,Vector3 terrainSize/*,Mesh mesh,Material material*/)
        {
            Dictionary<int, List<GrassInstanceData>> treesData = new Dictionary<int, List<GrassInstanceData>>();
            for (int k = 0; k < treedata.trees.Count; k++)
            {
                var data = treedata.trees[k];
                var grassInstance = new GrassInstanceData()
                {
                    position  = treedata.trees[k].position.Multiply(terrainSize),
                    rotationY = treedata.trees[k].rotation,
                    scale     = treedata.trees[k].scale
                };
                if (!treesData.ContainsKey(data.prototypeIndex))
                {
                    treesData.Add(data.prototypeIndex, new List<GrassInstanceData>());
                }
                treesData[data.prototypeIndex].Add(grassInstance);
            }
            for (int i = 0; i < treedata.prefabPath.Count; i++)
            {
                grassCount = treesData[i].Count;
                var positionBuffer =
                    new GraphicsBuffer(GraphicsBuffer.Target.Structured, grassCount, stride);
                positionBuffer.SetData(treesData[i]);
                var visibleBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append, grassCount, stride);

                // var vgRenderDatas = InitVgRenderData(treedata.prefabPath[i], i, terrainSize, positionBuffer, visibleBuffer);
                // vgDataList.AddRange(vgRenderDatas);
                
                var prefab        = Resources.Load<GameObject>(treedata.prefabPath[i]);
#if UNITY_EDITOR
                prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(treedata.prefabPath[i]);
#endif
                
                var          lodGroup = prefab.GetComponentInChildren<LODGroup>();
                var          lod      = lodGroup.GetLODs()[0];
                var          render   = lod.renderers[0];
                var          mesh     = render.GetComponent<MeshFilter>().sharedMesh;
                for (int j = 0; j < mesh.subMeshCount; j++)
                {
                     VgRenderData data = new VgRenderData();
                     data.grassCount = grassCount;
                     data.vgType     = VgtationType.Grass;
                     data.rp = new RenderParams(render.sharedMaterials[j])
                     {
                         layer             = prefab.layer,
                         shadowCastingMode = ShadowCastingMode.On,
                         receiveShadows    = true,
                         worldBounds       = new Bounds(Vector3.zero, Vector3.one.Multiply(terrainSize) * 2)
                     };
                     // data.rp.material.SetBuffer(VgConstantProperty.INSTANCEBUFFER,positionBuffer);
                     data.mesh = mesh;
                     data.args = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, 1,
                         GraphicsBuffer.IndirectDrawIndexedArgs.size);
                     uint[] args = new uint[5];
                     args[0] = mesh.GetIndexCount(j);
                     args[1] = (uint)grassCount;
                     args[2] = mesh.GetIndexStart(j);
                     args[3] = mesh.GetBaseVertex(j);
                     args[4] = 0;
                     data.args.SetData(args);
                     data.allInstanceBuffer = positionBuffer;
                     data.visibleBuffer     = visibleBuffer;
                     data.rp.material.SetBuffer(VgConstantProperty.INSTANCEBUFFER, data.visibleBuffer);
                     data.rp.material.EnableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                     data.prototypeIndex = i;
                     data.subMesh        = j;
                     vgDataList.Add(data);
                }
            }
        }

        /// <summary>
        /// SubMesh
        /// </summary>
        /// <param name="prefabPath"></param>
        /// <param name="prototypeIndex"></param>
        /// <param name="terrainSize"></param>
        /// <param name="positionBuffer"></param>
        /// <param name="visibleBuffer"></param>
        /// <returns></returns>
        private List<VgRenderData> InitVgRenderData(string prefabPath, int prototypeIndex,Vector3 terrainSize,GraphicsBuffer positionBuffer,GraphicsBuffer visibleBuffer)
        {
            List<VgRenderData> datas  = new List<VgRenderData>();

            var prefab = Resources.Load<GameObject>(prefabPath);
#if UNITY_EDITOR
                prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
#endif
                
            var          lodGroup = prefab.GetComponentInChildren<LODGroup>();
            var          lod      = lodGroup.GetLODs()[0];
            var          render   = lod.renderers[0];
            var          mesh     = render.GetComponent<MeshFilter>().sharedMesh;
            for (int j = 0; j < mesh.subMeshCount; j++)
            {
                 VgRenderData data = new VgRenderData();
                 data.grassCount = grassCount;
                 data.vgType     = VgtationType.Grass;
                 data.rp = new RenderParams(render.sharedMaterials[j])
                 {
                     layer             = prefab.layer,
                     shadowCastingMode = ShadowCastingMode.On,
                     receiveShadows    = true,
                     worldBounds       = new Bounds(Vector3.zero, Vector3.one.Multiply(terrainSize) * 2)
                 };
                 // data.rp.material.SetBuffer(VgConstantProperty.INSTANCEBUFFER,positionBuffer);
                 data.mesh = mesh;
                 data.args = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, 1,
                     GraphicsBuffer.IndirectDrawIndexedArgs.size);
                 uint[] args = new uint[5];
                 args[0] = mesh.GetIndexCount(j);
                 args[1] = (uint)grassCount;
                 args[2] = mesh.GetIndexStart(j);
                 args[3] = mesh.GetBaseVertex(j);
                 args[4] = 0;
                 data.args.SetData(args);
                 data.allInstanceBuffer = positionBuffer;
                 data.visibleBuffer     = visibleBuffer;
                 data.rp.material.SetBuffer(VgConstantProperty.INSTANCEBUFFER, data.visibleBuffer);
                 data.rp.material.EnableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                 data.prototypeIndex = prototypeIndex;
                 data.subMesh        = j;
                 datas.Add(data);
            }
            return datas;
        }

        public void InitVgDatas(TerrainTreeDatas treeDatas, Vector3 terrainSize)
        {
           
            allChunkInfoList = new List<ChunkInfo>();
            int index = 0;
            foreach (var chunk in treeDatas.chunkDatas)
            {
                index++;
                //记录当前数据中每个chunk的起始偏移值
                Dictionary<int, int> prototypeIndexCount = new Dictionary<int, int>();
                foreach (var tree in treesData)
                {
                    if (!prototypeIndexCount.ContainsKey(tree.Key))
                    {
                        prototypeIndexCount.Add(tree.Key,0);
                    }
                    else
                    {
                        prototypeIndexCount[tree.Key] = tree.Value.Count;
                    }
                }
                foreach (var instance in chunk.trees)
                {
                    GrassInstanceData data = new GrassInstanceData()
                    {
                        position  = instance.position,
                        rotationY = instance.rotation,
                        scale     = instance.scale,
                    };
                    if (!treesData.ContainsKey(instance.prototypeIndex))
                    {
                        treesData.Add(instance.prototypeIndex,new List<GrassInstanceData>());
                    }
                    treesData[instance.prototypeIndex].Add(data);
                }
                foreach (var tree in treesData)
                {
                    int prototypeIndex = tree.Key;
                    int startIndex     = 0;
                    if (prototypeIndexCount.TryGetValue(prototypeIndex, out var value))
                    {
                        startIndex = value;
                    }

                    int  count = tree.Value.Count - startIndex;
                    uint guid  = (uint)(index << 4 | prototypeIndex);
                    ChunkInfo chunkInfo = new ChunkInfo()
                    {
                        guid    = guid,
                        center  = chunk.aabb.size,
                        extents = chunk.aabb.extents,
                        start2count = new Dictionary<int, (uint, uint)>
                        {
                            { prototypeIndex, ((uint)startIndex, (uint)count) },  
                        },
                    };
                    ChunkInfoForJob chunkInfoForJob = new ChunkInfoForJob()
                    {
                        guid = guid,
                        center = chunk.aabb.center,
                        extents = chunk.aabb.extents
                    };
                    allChunkInfoList.Add(chunkInfo);
                    allChunkInfoDic.Add(guid,chunkInfo);
                    AllChunkInfoForJobs.Add(chunkInfoForJob);
                    if(chunkPreMaxCount.TryGetValue(prototypeIndex,out int maxCount))
                    {
                        if (maxCount < count)
                        {
                            chunkPreMaxCount[prototypeIndex] = count;
                        }
                    }
                    else
                    {
                        chunkPreMaxCount.Add(prototypeIndex, count);
                    }
                }
            }

            for (int i = 0; i < treeDatas.prefabPath.Count; i++)
            {
                int maxCount       = treesData[i].Count;
                var positionBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, maxCount, stride);
                var visibleBuffer  = new GraphicsBuffer(GraphicsBuffer.Target.Append, maxCount, stride);

                var vgRenderdatas =
                    InitVgRenderData(treeDatas.prefabPath[i], i, terrainSize, positionBuffer, visibleBuffer);
                vgDataDic.Add(i,vgRenderdatas);
            }
        }

        /// <summary>
        /// 所有数据存放处，每个VegetationRenderData都包含了一种类型植被的所有数据，其中visibleChunkBuffer需要在job时剔除后根据具体数据去设置
        /// </summary>
        public List<VegetationRenderData> vegetationRenderDataList       = new List<VegetationRenderData>();
        /// <summary>
        /// 为了便于Job计算而使用的数组，再job时计算完后返回guid即可
        /// </summary>
        public NativeArray<ChunkInfoForJob> vegetationChunkForJobDataNativeList;

        public GrassInstanceData ConvertToGrassInstanceData(TreeInstanceData treeInstanceData,Vector3 terrainSize)
        {
            GrassInstanceData instanceData = new GrassInstanceData()
            {
                position  = treeInstanceData.position,
                rotationY = treeInstanceData.rotation,
                scale     = treeInstanceData.scale
            };
            return instanceData;
        }

        public VegetationRenderSubMeshData ConverToSubMeshData(
            Material material,
            int subMesh,
            int layer,
            uint renderingLayerMask,
            ShadowCastingMode shadowMode,
            Mesh mesh,
            GraphicsBuffer visibleBuffer,
            Terrain terrain)
        {
            var subMat          = new Material(material);
            RenderParams subRp = new RenderParams(subMat)
            {
                worldBounds       = new Bounds(Vector3.zero, Vector3.one * 5000f),
                layer             = layer,
                shadowCastingMode = shadowMode,
                renderingLayerMask = renderingLayerMask,
                receiveShadows = true
            };
                    
            VegetationRenderSubMeshData subMeshData = new VegetationRenderSubMeshData();
            subMeshData.subMesh = subMesh;
            subMeshData.argsBuffer = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, 1,
                sizeof(uint) * 5);
            uint[] subArgs = new uint[5];
            subArgs[0] = mesh.GetIndexCount(subMesh);
            subArgs[1] = (uint)0;
            subArgs[2] = mesh.GetIndexStart(subMesh);
            subArgs[3] = mesh.GetBaseVertex(subMesh);
            subArgs[4] = 0;
            subMeshData.argsBuffer.SetData(subArgs);
                   
            subMeshData.rp = subRp;
            subMeshData.rp.material.EnableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
            subMeshData.rp.material.SetBuffer(VgConstantProperty.INSTANCEBUFFER, visibleBuffer);
            ApplyTerrainBlendProperties(subMeshData.rp.material, terrain);
            return subMeshData;
        }

        private static void ApplyTerrainBlendProperties(Material material, Terrain terrain)
        {
            if (material == null || terrain == null || terrain.terrainData == null)
            {
                return;
            }

            if (!material.HasProperty(TerrainTransformDataId))
            {
                return;
            }

            TerrainData terrainData = terrain.terrainData;
            Vector3 terrainPosition = terrain.transform.position;
            Vector3 terrainSize = terrainData.size;
            material.SetVector(
                TerrainTransformDataId,
                new Vector4(
                    terrainPosition.x,
                    terrainPosition.z,
                    Mathf.Max(terrainSize.x, 0.0001f),
                    Mathf.Max(terrainSize.z, 0.0001f)));

            TerrainLayer[] terrainLayers = terrainData.terrainLayers;
            material.SetFloat(TerrainRoughnessId, CalculateTerrainRoughness(terrainLayers));

            Texture bakedBlendTexture = null;
            var terrainBlendData = terrain.GetComponent<VegetationTerrainBlendData>();
            if (terrainBlendData != null)
            {
                bakedBlendTexture = terrainBlendData.BakedBlendTexture;
            }

            if (bakedBlendTexture != null)
            {
                material.SetTexture(TerrainColorId, bakedBlendTexture);
                material.EnableKeyword(TerrainBlendBakedKeyword);
            }
            else
            {
                material.DisableKeyword(TerrainBlendBakedKeyword);
            }

            Texture2D[] alphaMaps = terrainData.alphamapTextures;
            if (material.HasProperty(ControlId) && alphaMaps != null && alphaMaps.Length > 0 && alphaMaps[0] != null)
            {
                material.SetTexture(ControlId, alphaMaps[0]);
            }

            if (material.HasProperty(TerrainColorId))
            {
                Texture terrainColor = null;
                if (bakedBlendTexture != null)
                {
                    terrainColor = bakedBlendTexture;
                }
                else if (terrainLayers != null && terrainLayers.Length > 0 && terrainLayers[0] != null)
                {
                    terrainColor = terrainLayers[0].diffuseTexture;
                }

                material.SetTexture(TerrainColorId, terrainColor != null ? terrainColor : Texture2D.whiteTexture);
            }

            for (int i = 0; i < 4; i++)
            {
                TerrainLayer layer = terrainLayers != null && i < terrainLayers.Length ? terrainLayers[i] : null;

                if (material.HasProperty(SplatTextureIds[i]))
                {
                    Texture diffuseTexture = layer != null && layer.diffuseTexture != null
                        ? layer.diffuseTexture
                        : Texture2D.whiteTexture;
                    material.SetTexture(SplatTextureIds[i], diffuseTexture);
                }

                if (material.HasProperty(SplatStIds[i]))
                {
                    material.SetVector(SplatStIds[i], CalculateSplatSt(layer, terrainSize));
                }

                if (material.HasProperty(DiffuseRemapScaleIds[i]))
                {
                    material.SetVector(DiffuseRemapScaleIds[i], CalculateDiffuseRemapScale(layer));
                }
            }
        }

        private static float CalculateTerrainRoughness(TerrainLayer[] terrainLayers)
        {
            if (terrainLayers == null || terrainLayers.Length == 0)
            {
                return 1.0f;
            }

            float smoothness = 0.0f;
            int count = Mathf.Min(terrainLayers.Length, 4);
            int validCount = 0;
            for (int i = 0; i < count; i++)
            {
                if (terrainLayers[i] == null)
                {
                    continue;
                }

                smoothness += terrainLayers[i].smoothness;
                validCount++;
            }

            smoothness /= Mathf.Max(1, validCount);
            return 1.0f - Mathf.Clamp01(smoothness);
        }

        private static Vector4 CalculateSplatSt(TerrainLayer layer, Vector3 terrainSize)
        {
            if (layer == null)
            {
                return new Vector4(1, 1, 0, 0);
            }

            float tileX = Mathf.Max(layer.tileSize.x, 0.0001f);
            float tileY = Mathf.Max(layer.tileSize.y, 0.0001f);
            float scaleX = terrainSize.x / tileX;
            float scaleY = terrainSize.z / tileY;
            float offsetX = layer.tileOffset.x / tileX;
            float offsetY = layer.tileOffset.y / tileY;
            return new Vector4(scaleX, scaleY, offsetX, offsetY);
        }

        private static Vector4 CalculateDiffuseRemapScale(TerrainLayer layer)
        {
            if (layer == null)
            {
                return Vector4.one;
            }

            Vector4 remap = layer.diffuseRemapMax;
            if (remap == Vector4.zero)
            {
                return Vector4.one;
            }

            return remap;
        }

        public float CaculateLodDistance(float n, float h1, float y,float H)
        {
            return (n * y) / (h1 * H) - n;
        }

        public float CaculateLodDistance(Camera camera, float objectHalfHeight, float transitionHeight)
        {
            if (camera == null || transitionHeight <= 0f)
            {
                return float.PositiveInfinity;
            }

            if (camera.orthographic)
            {
                return objectHalfHeight / (Mathf.Max(camera.orthographicSize, 0.0001f) * transitionHeight);
            }

            float near = camera.nearClipPlane;
            float halfFrustumHeightAtNear = Mathf.Tan(camera.fieldOfView * 0.5f * Mathf.Deg2Rad) * near;
            return CaculateLodDistance(near, halfFrustumHeightAtNear, objectHalfHeight, transitionHeight);
        }

        public float GetLodDistance(VegetationRenderData data, int lodIndex, Camera camera, float lodBias)
        {
            if (lodIndex < 0 || lodIndex >= data.activeLodCount)
            {
                return -1f;
            }

            float halfHeight = Mathf.Max(data.lodReferenceHeight * 0.5f, 0.0001f);
            float distance = CaculateLodDistance(camera, halfHeight, data.lodScreenHeights[lodIndex]);
            return float.IsInfinity(distance) ? float.PositiveInfinity : distance * lodBias;
        }

        public bool TryGetLodDistanceRange(
            VegetationRenderData data,
            int lodIndex,
            Camera camera,
            float lodBias,
            int maximumLodLevel,
            out Vector2 distanceRange)
        {
            distanceRange = default;
            if (lodIndex < maximumLodLevel || lodIndex < 0 || lodIndex >= data.activeLodCount)
            {
                return false;
            }

            int firstEnabledLod = Mathf.Clamp(maximumLodLevel, 0, Mathf.Max(0, data.activeLodCount - 1));
            float minDistance = 0f;
            if (lodIndex > firstEnabledLod)
            {
                minDistance = GetLodDistance(data, lodIndex - 1, camera, lodBias);
            }

            float maxDistance = GetLodDistance(data, lodIndex, camera, lodBias);
            if (maxDistance <= minDistance)
            {
                return false;
            }

            distanceRange = new Vector2(minDistance, maxDistance);
            return true;
        }
        
        public void InitVegetationRenderData(TerrainTreeDatas treeDatas, Vector3 terrainSize, Terrain terrain = null, int renderLayer = -1)
        {
            Dictionary<int, List<GrassInstanceData>> dicInstanceDatas = new Dictionary<int, List<GrassInstanceData>>();
            Dictionary<int, List<ChunkInfoBuffer>>   dicChunkInfoBuffer = new Dictionary<int, List<ChunkInfoBuffer>>();
            Dictionary<int, int>                     dicSingleChunkMaxCount = new Dictionary<int, int>();
            
            List<ChunkInfoForJob>                    vegetaionChunkForJobDataList = new List<ChunkInfoForJob>();
            foreach (var chunk in treeDatas.chunkDatas)
            {
                int guid = chunk.GetHashCode();
                
                //每个prototypeIndex对应的startIndex和 count
                Dictionary<int, StartIndex2Count> prototypeIndexStart2Count = new Dictionary<int, StartIndex2Count>();
                foreach (var tree in chunk.trees)
                {
                    if (!prototypeIndexStart2Count.ContainsKey(tree.prototypeIndex))
                    {
                        int startIndex = 0;

                        StartIndex2Count s2c = new StartIndex2Count()
                        {
                            startIndex = 0,
                            count = 1
                        };
                        if (dicInstanceDatas.TryGetValue(tree.prototypeIndex, out List<GrassInstanceData> value))
                        {
                            s2c.startIndex = value.Count;
                            s2c.count      = 1;
                        }
                        prototypeIndexStart2Count.Add(tree.prototypeIndex,s2c);
                    }
                    else
                    {
                        var tS2C = prototypeIndexStart2Count[tree.prototypeIndex];
                        tS2C.count++;
                        prototypeIndexStart2Count[tree.prototypeIndex] = tS2C;
                    }
                    
                    GrassInstanceData instanceData = ConvertToGrassInstanceData(tree, terrainSize);
                    if (!dicInstanceDatas.ContainsKey(tree.prototypeIndex))
                    {
                        dicInstanceDatas.Add(tree.prototypeIndex,new List<GrassInstanceData>());
                    }
                    dicInstanceDatas[tree.prototypeIndex].Add(instanceData);
                }

                foreach (var pStartIndex2Count in prototypeIndexStart2Count)
                {
                    int prototypeIndex = pStartIndex2Count.Key;
                    int startIndex     = pStartIndex2Count.Value.startIndex;
                    int count          = pStartIndex2Count.Value.count;
                    ChunkInfoBuffer chunkInfoBuffer = new ChunkInfoBuffer()
                    {
                        guid       = (uint)guid,
                        center     = chunk.aabb.center,
                        extents    = chunk.aabb.extents,
                        startIndex = (uint)startIndex,
                        count      = (uint)count,
                    };
                    if(!dicChunkInfoBuffer.ContainsKey(prototypeIndex))
                    {
                        dicChunkInfoBuffer.Add(prototypeIndex,new List<ChunkInfoBuffer>());
                    }
                    dicChunkInfoBuffer[prototypeIndex].Add(chunkInfoBuffer);

                    if (!dicSingleChunkMaxCount.ContainsKey(prototypeIndex))
                    {
                        dicSingleChunkMaxCount.Add(prototypeIndex, 0);
                    }
                    if (dicSingleChunkMaxCount[prototypeIndex] < count)
                    {
                        dicSingleChunkMaxCount[prototypeIndex] = count;
                    }
                }

                ChunkInfoForJob chunkInfoForJob = new ChunkInfoForJob()
                {
                    guid    = (uint)guid,
                    center  = chunk.aabb.center,
                    extents = chunk.aabb.extents
                };
                vegetaionChunkForJobDataList.Add(chunkInfoForJob);
            }

            vegetationChunkForJobDataNativeList =
                new NativeArray<ChunkInfoForJob>(vegetaionChunkForJobDataList.ToArray(), Allocator.Persistent);
            
            for (int i = 0; i < treeDatas.prefabPath.Count; i++)
            {
                int prototypeIndex = i;
                if(!dicInstanceDatas.ContainsKey(prototypeIndex))continue;
                var prefabPath     = treeDatas.prefabPath[i];
                var prefab         = Resources.Load<GameObject>(prefabPath);
#if UNITY_EDITOR
                prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
#endif
                var      meshRenderer   = prefab.GetComponentInChildren<MeshRenderer>();
                // var      sharedMaterial = meshRenderer.sharedMaterial;
                var      shadowMode   = meshRenderer.shadowCastingMode;
                Mesh     mesh         = prefab.GetComponentInChildren<MeshFilter>().sharedMesh;

                // RenderParams rp = new RenderParams(mat)
                // {
                //     worldBounds       = new Bounds(Vector3.zero, Vector3.one * 5000f),
                //     layer             = prefab.layer,
                //     shadowCastingMode = shadowMode
                // };
                VegetationRenderData data = new VegetationRenderData();
                
                data.prototypeIndex = prototypeIndex;
                // data.rp             = rp;
                data.mesh           = mesh;
                // data.argsBuffer = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, 1,
                //     sizeof(uint) * 5);
                // uint[] args = new uint[5];
                // args[0] = mesh.GetIndexCount(0);
                // args[1] = (uint)dicInstanceDatas[prototypeIndex].Count;
                // args[2] = mesh.GetIndexStart(0);
                // args[3] = mesh.GetBaseVertex(0);
                // args[4] = 0;
                // data.argsBuffer.SetData(args);

                data.instanceMaxCount  = dicInstanceDatas[prototypeIndex].Count;
                data.chunkMaxCount     = dicSingleChunkMaxCount[prototypeIndex];
                data.visibleChunkCount = dicChunkInfoBuffer[prototypeIndex].Count;
                data.AllInstanceDatas  = dicInstanceDatas[prototypeIndex];
                data.allChunkInfos     = dicChunkInfoBuffer[prototypeIndex];
                data.visibleChunkInfos = dicChunkInfoBuffer[prototypeIndex];

                GraphicsBuffer allInstanceBuffer =
                    new GraphicsBuffer(GraphicsBuffer.Target.Structured, data.instanceMaxCount, instanceStride);
                allInstanceBuffer.SetData(data.AllInstanceDatas);
                data.AllInstanceBuffer = allInstanceBuffer;

                GraphicsBuffer visibleInstanceBuffer =
                    new GraphicsBuffer(GraphicsBuffer.Target.Append, data.instanceMaxCount, instanceStride);
                data.VisibleInstanceBuffer = visibleInstanceBuffer;
                data.VisibleInstanceCountBuffer =
                    new GraphicsBuffer(GraphicsBuffer.Target.Structured, 1, sizeof(uint));
                data.VisibleChunkBuffer =
                    new GraphicsBuffer(GraphicsBuffer.Target.Structured, data.chunkMaxCount, chunkinfoStride);

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
                    float transitionHeight = selectedLod.screenRelativeTransitionHeight;
                    data.lodScreenHeights[j] = transitionHeight;

                    var lodRender = selectedLod.renderers[0];
                    var lodMesh = lodRender.GetComponent<MeshFilter>().sharedMesh;
                    mergedBounds.Encapsulate(lodMesh.bounds);
                    VegetaionRenderLodData lodData = new VegetaionRenderLodData();
                    lodData.mesh = lodMesh;

                    lodData.SubMeshDatas    = new VegetationRenderSubMeshData[lodMesh.subMeshCount];
                    lodData.VisibleInstanceBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append,
                        data.instanceMaxCount, instanceStride);
                    for (int n = 0; n < lodMesh.subMeshCount; n++)
                    {
                        lodData.SubMeshDatas[n] = ConverToSubMeshData(
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
                    data.SubMeshDatas[k] = ConverToSubMeshData(
                        meshRenderer.sharedMaterials[k],
                        k,
                        targetLayer,
                        meshRenderer.renderingLayerMask,
                        shadowMode,
                        mesh,
                        data.VisibleInstanceBuffer,
                        terrain);
                }
                
                // data.rp.material.EnableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                // data.rp.material.SetBuffer(VgConstantProperty.INSTANCEBUFFER, data.VisibleInstanceBuffer);
                vegetationRenderDataList.Add(data);
            }
        }
        
        List<ChunkInfoBuffer> visibleChunkInfos = new List<ChunkInfoBuffer>();
        /// <summary>
        /// 刷新每种植被可见Chunk的信息
        /// </summary>
        public void RefreshVisibleChunkBuffer()
        {
            for (int i = 0; i < vegetationRenderDataList.Count; i++)
            {
                var data = vegetationRenderDataList[i];
                visibleChunkInfos.Clear();
                foreach (var chunk in data.allChunkInfos)
                {
                    if (visibleChunkGuidHashset.Contains(chunk.guid))
                    {
                        visibleChunkInfos.Add(chunk);
                    }
                }
                data.visibleChunkInfos  = visibleChunkInfos;
                data.visibleChunkCount  = visibleChunkInfos.Count;
                data.VisibleChunkBuffer.Dispose();
                data.VisibleChunkBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, data.visibleChunkCount,
                    chunkinfoStride);
                data.VisibleChunkBuffer.SetData(data.visibleChunkInfos);
                vegetationRenderDataList[i] = data;
            }
        }
        
        
        public void Render()
        {
            foreach (var data in vgDataList)
            {
                Graphics.RenderMeshIndirect(data.rp,data.mesh,data.args);
            }
        }

        public void Dispose()
        {
            if (vegetationChunkForJobDataNativeList.IsCreated)
            {
                vegetationChunkForJobDataNativeList.Dispose();
            }
            // foreach (var data in vgDataList)
            // {
            //     data.rp.material.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
            // }
            foreach (var renderData in vegetationRenderDataList)
            {
                // renderData.rp.material.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                renderData.AllInstanceBuffer.Dispose();
                // renderData.argsBuffer.Dispose();
                renderData.VisibleChunkBuffer.Dispose();
                renderData.VisibleInstanceBuffer.Dispose();
                renderData.VisibleInstanceCountBuffer.Dispose();
                foreach (var subMeshData in renderData.SubMeshDatas)
                {
                    subMeshData.argsBuffer.Dispose();
                    subMeshData.rp.material.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                }

                foreach (var lodData in renderData.LodDatas)
                {
                    lodData.VisibleInstanceBuffer?.Dispose();
                    if (lodData.SubMeshDatas == null)
                    {
                        continue;
                    }

                    foreach (var subMeshData in lodData.SubMeshDatas)
                    {
                        subMeshData.argsBuffer?.Dispose();
                        subMeshData.rp.material?.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                    }
                }
            }
        }
    }
}

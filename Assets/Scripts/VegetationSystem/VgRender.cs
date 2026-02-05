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
        public static int    ARGSBUFFER           = Shader.PropertyToID("_ArgsBuffer");
        public static int    FRUSTUMPLANES        = Shader.PropertyToID("_FrustumPlanes");
        public static int    ENABLECULLING        = Shader.PropertyToID("EnableFrustumCulling");
        public static int    VISIBLECHUNINFOS     = Shader.PropertyToID("_VisibleChunkInfos");
        public static int    CHUNKCOUNT           = Shader.PropertyToID("_ChunkCount");
        public static int    LOD0VISIBLEINSTANCES = Shader.PropertyToID("_Lod0VisibleInstances");
        public static int    LOD1VISIBLEINSTANCES = Shader.PropertyToID("_Lod1VisibleInstances");
        public static int    LOD2VISIBLEINSTANCES = Shader.PropertyToID("_Lod2VisibleInstances");
        public static int    LOD0ARGSBUFFER       = Shader.PropertyToID("_Lod0ArgsBuffer");
        public static int    LOD1ARGSBUFFER       = Shader.PropertyToID("_Lod1ArgsBuffer");
        public static int    LOD2ARGSBUFFER       = Shader.PropertyToID("_Lod2ArgsBuffer");
        public static int    CAMERAPOSITION       = Shader.PropertyToID("_CameraPosition");
        public static int    LODDISTANCE          = Shader.PropertyToID("_LodDistance");
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
            
        // public RenderParams   rp;
        public Mesh           mesh;
        public GraphicsBuffer AllInstanceBuffer;
        public GraphicsBuffer VisibleChunkBuffer;
        public GraphicsBuffer VisibleInstanceBuffer;
        // public GraphicsBuffer argsBuffer;

        public List<GrassInstanceData>       AllInstanceDatas;
        public List<ChunkInfoBuffer>         allChunkInfos;
        public List<ChunkInfoBuffer>         visibleChunkInfos;
        
        public VegetationRenderSubMeshData[] SubMeshDatas;
        public Vector4                       lodScreenHeigh;
        public Vector4                       lodDistance;
        public VegetaionRenderLodData[]      LodDatas;
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
                rotationY = 0,
                scale     = treeInstanceData.scale
            };
            return instanceData;
        }

        public VegetationRenderSubMeshData ConverToSubMeshData(Material material, int subMesh, int layer,
            ShadowCastingMode shadowMode, Mesh mesh, GraphicsBuffer visibleBuffer)
        {
            var subMat          = new Material(material);
            RenderParams subRp = new RenderParams(subMat)
            {
                worldBounds       = new Bounds(Vector3.zero, Vector3.one * 5000f),
                layer             = layer,
                shadowCastingMode = shadowMode
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
            return subMeshData;
        }

        public float CaculateLodDistance(float n, float h1, float y,float H)
        {
            return (n * y) / (h1 * H) - n;
        }
        
        public void InitVegetationRenderData(TerrainTreeDatas treeDatas, Vector3 terrainSize)
        {
            Dictionary<int, List<GrassInstanceData>> dicInstanceDatas = new Dictionary<int, List<GrassInstanceData>>();
            Dictionary<int, List<ChunkInfoBuffer>>   dicChunkInfoBuffer = new Dictionary<int, List<ChunkInfoBuffer>>();
            Dictionary<int, int>                     dicSingleChunkMaxCount = new Dictionary<int, int>();
            
            List<ChunkInfoForJob>                    vegetaionChunkForJobDataList = new List<ChunkInfoForJob>();
            foreach (var chunk in treeDatas.chunkDatas)
            {
                int guid = chunk.GetHashCode();
                
                Debug.Log($"guid:{guid} to uint :{(uint)guid}");

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
                data.VisibleChunkBuffer =
                    new GraphicsBuffer(GraphicsBuffer.Target.Structured, data.chunkMaxCount, chunkinfoStride);

                data.lodScreenHeigh = Vector3.one;
                var lodGroup = prefab.GetComponentInChildren<LODGroup>();
                if (lodGroup == null)
                {
                    throw new Exception($"Prefab:{prefab.name} 不包含LODGroup组件，这是不合法！！！！");
                }
                var lods     = lodGroup.GetLODs();
                data.LodDatas = new VegetaionRenderLodData[3];  //默认就是三级LOD
                float near   = Camera.main.nearClipPlane;
                var   tanfov = MathF.Tan(Camera.main.fieldOfView * 0.5f * 3.14159f / 180f);
                var   h1     = tanfov * near;
                var   tan25  = Mathf.Tan(Mathf.PI * 0.1389f);
                for (int j = 0; j < lods.Length && j < 3; j++)
                {
                    float H =  lods[j].screenRelativeTransitionHeight;
                    float y = mesh.bounds.extents.y;
                    float lodDistance = CaculateLodDistance(near, h1, y, H);
                    if (j == 0)
                    {
                        // data.lodScreenHeigh.x = lods[j].screenRelativeTransitionHeight;
                        data.lodDistance.x = lodDistance;
                    }

                    if (j == 1)
                    {
                        data.lodScreenHeigh.y = lods[j].screenRelativeTransitionHeight;
                        data.lodDistance.y    = lodDistance;
                    }

                    if (j == 2)
                    {
                        data.lodScreenHeigh.z = lods[j].screenRelativeTransitionHeight;
                        data.lodDistance.z    = lodDistance;
                    }
                    var                    lodRender  = lods[j].renderers[0];
                    var                    lodMesh    = lodRender.GetComponent<MeshFilter>().sharedMesh;
                    VegetaionRenderLodData lodData    = new VegetaionRenderLodData();
                    lodData.mesh            = lodMesh;

                    lodData.SubMeshDatas    = new VegetationRenderSubMeshData[lodMesh.subMeshCount];
                    lodData.VisibleInstanceBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append,
                        data.instanceMaxCount, instanceStride);
                    for (int n = 0; n < lodMesh.subMeshCount; n++)
                    {
                        lodData.SubMeshDatas[n] = ConverToSubMeshData(lodRender.sharedMaterials[n], n, prefab.layer,
                            j < 1 ? lodRender.shadowCastingMode : ShadowCastingMode.Off, lodMesh,lodData.VisibleInstanceBuffer);
                    }
                    data.LodDatas[j] = lodData;
                }
                
                data.SubMeshDatas = new VegetationRenderSubMeshData[mesh.subMeshCount];
                for (int k = 0; k < mesh.subMeshCount; k++)
                {
                    data.SubMeshDatas[k] = ConverToSubMeshData(meshRenderer.sharedMaterials[k], k, prefab.layer,
                        shadowMode, mesh, data.VisibleInstanceBuffer);
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
            vegetationChunkForJobDataNativeList.Dispose();
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
                foreach (var subMeshData in renderData.SubMeshDatas)
                {
                    subMeshData.argsBuffer.Dispose();
                    subMeshData.rp.material.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                }
            }
        }
    }
}
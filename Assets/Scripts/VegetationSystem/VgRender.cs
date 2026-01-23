using System.Collections.Generic;
using Extension;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UI;

namespace VegetationSystem
{
    public class VgConstantProperty
    {
        public static int    INSTANCEBUFFER   = Shader.PropertyToID("_InstanceBuffer");
        public static int    ALLINSTANCES     = Shader.PropertyToID("_AllInstances");
        public static int    VISIBLEINSTANCES = Shader.PropertyToID("_VisibleInstances");
        public static int    ARGSBUFFER       = Shader.PropertyToID("_ArgsBuffer");
        public static int    FRUSTUMPLANES    = Shader.PropertyToID("_FrustumPlanes");
        public static int    ENABLECULLING    = Shader.PropertyToID("EnableFrustumCulling");
        public static int    VISIBLECHUNINFOS = Shader.PropertyToID("_VisibleChunkInfos");
        public static int    CHUNKCOUNT       = Shader.PropertyToID("_ChunkCount");
        public static string KW_GPUINSTANCEON = "GRAPHICDRAW_ON";
    }
        
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
        public　int           subMesh;
    }
    
    struct GrassInstanceData
    {
        public Vector3 position;
        public float   rotationY;
        public Vector2 scale;
    }

    public struct ChunkInfo
    {
        public uint    startIndex;
        public uint    count;
        public Vector3 center;
        public Vector3 size;
    }
    
    //默认情形：使用的Terrain上的Tree数据
    //同一套TRS使用不同的mesh和材质球
    //material和positionbuffer绑定，Graphics接口中只需要设置对应的rp、mesh和argsbuffer
    //将一个Terrain与一个Renderer类绑定，可以比较方便的处理一个场景中存在多个Terrain多套Vegetation的情形（层级有一个需求是一个超大的场景中分布稀稀疏疏的几个岛屿，出于性能考虑每个岛都一个vegetation的系统）
    public class VgRender
    {
        public List<VgRenderData> vgDataList = new List<VgRenderData>();
        public int                stride     = sizeof(float) * (3 + 1 + 2);
        //public GraphicsBuffer     positionBuffer;
        public int                grassCount;
        public bool               isCulling;

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
        
        
        public void Render()
        {
            foreach (var data in vgDataList)
            {
                Graphics.RenderMeshIndirect(data.rp,data.mesh,data.args);
            }
        }

        public void Dispose()
        {
            foreach (var data in vgDataList)
            {
                data.rp.material.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
            }
        }
    }
}
using System.Collections.Generic;
using System.Diagnostics;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;
using UnityEngine.Rendering;
using Debug = UnityEngine.Debug;
using VGC = VegetationSystem.VgConstantProperty;

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
        public  TextAsset        chunkDatas;
        public  Mesh             renderMesh;
        public  Material         renderMaterial;
        public  ComputeShader    cullingCS;
        public  Camera           cullingCamera;
        public  bool             ShowGizmos;
        private TerrainTreeDatas treeDatas;

        private List<ChunkInfo> allChunkInfos;
        private List<ChunkInfo> visibleChunkInfos;
        private Plane[]         planes = new Plane[6];

        private GraphicsBuffer argsBuffer;
        private GraphicsBuffer allInstanceBuffer;
        private GraphicsBuffer visibleInstanceBuffer;
        private GraphicsBuffer visibleChunkBuffer;
        private int            preChunkInstanceMaxCount = 0;
        private int            chunkCount               = 0;

        private void Awake()
        {
            InitData();
            if (cullingCamera == null)
            {
                cullingCamera = Camera.main;
            }
        }

        private void Update()
        {
            ChunkCullingOnCPU();
            CSDispatch();
            Render();
        }

        public void InitData()
        {
            if (chunkDatas == null) return;
            treeDatas = JsonUtility.FromJson<TerrainTreeDatas>(chunkDatas.text);
            InitBuffer();
            SetMaterialData();
        }

        public void InitBuffer()
        {
            List<GrassInstanceData> datas = new List<GrassInstanceData>();
            allChunkInfos = new List<ChunkInfo>();
            foreach (var chunkData in treeDatas.chunkDatas)
            {
                int chunkOffset = datas.Count;
                foreach (var tree in chunkData.trees)
                {
                    var grassData = new GrassInstanceData
                    {
                        position  = tree.position,
                        rotationY = tree.rotation,
                        scale     = tree.scale
                    };
                    datas.Add(grassData);
                }

                int instanceCount = chunkData.trees.Count;
                preChunkInstanceMaxCount = instanceCount > preChunkInstanceMaxCount
                    ? instanceCount
                    : preChunkInstanceMaxCount;
                var chunk = new ChunkInfo
                {
                    startIndex = (uint)chunkOffset,
                    count      = (uint)instanceCount,
                    center = chunkData.aabb.center,
                    size = chunkData.aabb.size,
                };
                allChunkInfos.Add(chunk);
            }
            int stride = sizeof(float) * (3 + 1 + 2);
            
            allInstanceBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, datas.Count, stride);
            allInstanceBuffer.SetData(datas);
            visibleInstanceBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append, datas.Count, stride);
            argsBuffer = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, 1,
                sizeof(uint) * 5);
        }

        public void SetMaterialData()
        {
            renderMaterial.SetBuffer(VgConstantProperty.INSTANCEBUFFER, visibleInstanceBuffer);
        }

        /// <summary>
        /// cpu端先对Chunk进行一波剔除
        /// </summary>
        public void ChunkCullingOnCPU()
        {
            Stopwatch sp = new Stopwatch();
            sp.Start();
            visibleChunkInfos = new List<ChunkInfo>();

            planes = GeometryUtility.CalculateFrustumPlanes(cullingCamera);
            
            // foreach (var chunk in allChunkInfos)
            // {
            //     if (GeometryUtility.TestPlanesAABB(planes, new Bounds(chunk.center, chunk.size)))
            //     {
            //         visibleChunkInfos.Add(chunk);
            //     }
            // }
            
            NativeArray<Plane> planesArry = new NativeArray<Plane>(planes, Allocator.TempJob);
            NativeArray<ChunkInfo> allChunkInfosArry =
                new NativeArray<ChunkInfo>(allChunkInfos.ToArray(), Allocator.TempJob);
            NativeList<ChunkInfo> visibleChunkInfoList = new NativeList<ChunkInfo>(allChunkInfos.Count, Allocator.TempJob);
            FrustumCullingJob cullingJob = new FrustumCullingJob()
            {
                planes            = planesArry,
                allChunkInfos     = allChunkInfosArry,
                visibleChunkInfos = visibleChunkInfoList.AsParallelWriter()
            };
            
            JobHandle handle = cullingJob.Schedule(allChunkInfos.Count, 256);
            handle.Complete();
            for (int k = 0; k < visibleChunkInfoList.Length; k++)
            {
                visibleChunkInfos.Add(visibleChunkInfoList[k]);
            }
            //visibleChunkInfos.AddRange(visibleChunkInfoList.ToList());
            planesArry.Dispose();
            allChunkInfosArry.Dispose();
            visibleChunkInfoList.Dispose();
            
           
            chunkCount = visibleChunkInfos.Count;
            int chunkStride = sizeof(uint) * 2 + sizeof(float) * (3 + 3);
            visibleChunkBuffer =
                new GraphicsBuffer(GraphicsBuffer.Target.Structured, visibleChunkInfos.Count, chunkStride);
            visibleChunkBuffer.SetData(visibleChunkInfos);
            
            sp.Stop();
            Debug.Log($"ChunkCullingOnCPU耗时: {sp.Elapsed.TotalMilliseconds}ms");
        }

        /// <summary>
        /// 设置CS上的数据，并执行对应对应的cs
        /// </summary>
        public void CSDispatch()
        {
            uint[] args = new uint[5];
            args[0] = renderMesh.GetIndexCount(0);
            args[1] = (uint)0;
            args[2] = renderMesh.GetIndexStart(0);
            args[3] = renderMesh.GetBaseVertex(0);
            args[4] = 0;
            argsBuffer.SetData(args);
            visibleInstanceBuffer.SetCounterValue(0);
            
            int kernel = cullingCS.FindKernel("CullInstances");
            cullingCS.SetBuffer(kernel, VGC.ALLINSTANCES, allInstanceBuffer);
            cullingCS.SetBuffer(kernel,VGC.VISIBLEINSTANCES,visibleInstanceBuffer);
            cullingCS.SetBuffer(kernel, VGC.ARGSBUFFER, argsBuffer);
            cullingCS.SetBuffer(kernel, VGC.VISIBLECHUNINFOS, visibleChunkBuffer);
            cullingCS.SetInt(VGC.CHUNKCOUNT,chunkCount);
            
            Vector4[] planeData = new Vector4[6];
            for (int i = 0; i < 6; i++)
            {
                var normal   = planes[i].normal;
                var distance = planes[i].distance;
                planeData[i] = new Vector4(
                    normal.x,
                    normal.y,
                    normal.z,
                    distance
                );
            }
            cullingCS.SetVectorArray(VGC.FRUSTUMPLANES, planeData);

            int groupX = chunkCount;
            int groupY = Mathf.CeilToInt(preChunkInstanceMaxCount / 64f);
            cullingCS.Dispatch(kernel, groupX, groupY, 1);
        }
        
        public void Render()
        {
            RenderParams rp = new RenderParams(renderMaterial)
            {
                layer             = gameObject.layer,
                shadowCastingMode = ShadowCastingMode.On,
                receiveShadows    = true,
                worldBounds       = new Bounds(Vector3.zero,Vector3.one * 5000),
            };
            Graphics.RenderMeshIndirect(rp,renderMesh,argsBuffer);
        }

        public void OnDrawGizmos()
        {
            if (!Application.isPlaying || !ShowGizmos)
            {
                return;
            }

            if (allChunkInfos != null)
            {
                foreach (var chunk in allChunkInfos)
                {
                    Gizmos.color = Color.red;
                    Gizmos.DrawWireCube(chunk.center,chunk.size - Vector3.one);
                }

                foreach (var chunk in visibleChunkInfos)
                {
                    Gizmos.color = Color.green;
                    Gizmos.DrawWireCube(chunk.center,chunk.size - Vector3.one);
                }
            }
        }
    }
}
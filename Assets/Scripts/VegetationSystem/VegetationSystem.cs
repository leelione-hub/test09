using System;
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
        public  Terrain          terrain;
        public  TextAsset        chunkDatas;
        public  Mesh             renderMesh;
        public  Material         renderMaterial;
        public  ComputeShader    cullingCS;
        public  Camera           cullingCamera;
        public  bool             ShowGizmos;
        private TerrainTreeDatas treeDatas;

        private List<OldChunkInfo> allChunkInfos;
        private List<OldChunkInfo> visibleChunkInfos;
        private Plane[]         planes = new Plane[6];

        private GraphicsBuffer argsBuffer;
        private GraphicsBuffer allInstanceBuffer;
        private GraphicsBuffer visibleInstanceBuffer;
        private GraphicsBuffer visibleChunkBuffer;
        private int            preChunkInstanceMaxCount = 0;
        private int            chunkCount               = 0;

        private VgCulling vgCulling;
        private VgRender  vgRender;

        private void Awake()
        {
            if (cullingCamera == null)
            {
                cullingCamera = Camera.main;
            }

            if (terrain == null)
            {
                terrain                     = this.GetComponent<Terrain>();
            }
            terrain.drawTreesAndFoliage = false;
            InitData();
        }

        void Update()
        {
            ChunkCullingOnCPU();
            CSDispatch();
            Render();
        }

        public void InitData()
        {
            if (chunkDatas == null) return;
            treeDatas = JsonUtility.FromJson<TerrainTreeDatas>(chunkDatas.text);
            
            vgRender  = new VgRender();
            vgRender.InitVegetationRenderData(treeDatas, terrain.terrainData.size);
            vgCulling = new VgCulling(vgRender, cullingCS);
            
            InitBuffer();
            SetMaterialData();
        }

        public void InitBuffer()
        {
            // List<GrassInstanceData> datas = new List<GrassInstanceData>();
            // allChunkInfos = new List<OldChunkInfo>();
            // foreach (var chunkData in treeDatas.chunkDatas)
            // {
            //     int chunkOffset = datas.Count;
            //     foreach (var tree in chunkData.trees)
            //     {
            //         var grassData = new GrassInstanceData
            //         {
            //             position  = tree.position,
            //             rotationY = tree.rotation,
            //             scale     = tree.scale
            //         };
            //         datas.Add(grassData);
            //     }
            //
            //     int instanceCount = chunkData.trees.Count;
            //     preChunkInstanceMaxCount = instanceCount > preChunkInstanceMaxCount
            //         ? instanceCount
            //         : preChunkInstanceMaxCount;
            //     var chunk = new OldChunkInfo
            //     {
            //         startIndex = (uint)chunkOffset,
            //         count      = (uint)instanceCount,
            //         center = chunkData.aabb.center,
            //         size = chunkData.aabb.size,
            //     };
            //     allChunkInfos.Add(chunk);
            // }
            // int stride = sizeof(float) * (3 + 1 + 2);
            //
            // allInstanceBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, datas.Count, stride);
            // allInstanceBuffer.SetData(datas);
            // visibleInstanceBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append, datas.Count, stride);
            // argsBuffer = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, 1,
            //     sizeof(uint) * 5);
        }

        public void SetMaterialData()
        {
            // renderMaterial.SetBuffer(VgConstantProperty.INSTANCEBUFFER, visibleInstanceBuffer);
        }

        /// <summary>
        /// cpu端先对Chunk进行一波剔除
        /// </summary>
        public void ChunkCullingOnCPU()
        {
            vgCulling.SetCullingCamera(cullingCamera);
            vgCulling.ScheduleCulling(ref vgRender.visibleChunkGuidHashset);
            vgRender.RefreshVisibleChunkBuffer();
        }

        /// <summary>
        /// 设置CS上的数据，并执行对应对应的cs
        /// </summary>
        public void CSDispatch()
        {
            int kernel = cullingCS.FindKernel("CullInstances");
            GeometryUtility.CalculateFrustumPlanes(cullingCamera, planes);
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
            
            //temp
            uint[] args       = new uint[5];
            //

            if (vgRender == null) return;

            for (int i = 0; i < vgRender.vegetationRenderDataList.Count; i++)
            {
                var    renderData = vgRender.vegetationRenderDataList[i];
                for (int j = 0; j < renderData.LodDatas.Length; j++)
                {
                    var lodData = renderData.LodDatas[j];
                    for (int k = 0; k < lodData.SubMeshDatas.Length; k++)
                    {
                        uint[] subArgs = new uint[5];
                        subArgs[0] = lodData.mesh.GetIndexCount(k);
                        subArgs[1] = (uint)0;
                        subArgs[2] = lodData.mesh.GetIndexStart(k);
                        subArgs[3] = lodData.mesh.GetBaseVertex(k);
                        subArgs[4] = 0;
                        lodData.SubMeshDatas[k].argsBuffer.SetData(subArgs);
                    }
                    lodData.VisibleInstanceBuffer.SetCounterValue(0);
                }
                cullingCS.SetBuffer(kernel, VGC.ALLINSTANCES, renderData.AllInstanceBuffer);
                // cullingCS.SetBuffer(kernel,VGC.VISIBLEINSTANCES,lodData.VisibleInstanceBuffer);
                // cullingCS.SetBuffer(kernel, VGC.ARGSBUFFER, lodData.SubMeshDatas[0].argsBuffer);
                cullingCS.SetBuffer(kernel, VGC.VISIBLECHUNINFOS, renderData.VisibleChunkBuffer);
                cullingCS.SetInt(VGC.CHUNKCOUNT,renderData.visibleChunkCount);
                
                cullingCS.SetVector(VGC.CAMERAPOSITION,cullingCamera.gameObject.transform.position);

                cullingCS.SetBuffer(kernel, VGC.LOD0VISIBLEINSTANCES, renderData.LodDatas[0].VisibleInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD1VISIBLEINSTANCES, renderData.LodDatas[1].VisibleInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD2VISIBLEINSTANCES, renderData.LodDatas[2].VisibleInstanceBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD0ARGSBUFFER, renderData.LodDatas[0].SubMeshDatas[0].argsBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD1ARGSBUFFER, renderData.LodDatas[1].SubMeshDatas[0].argsBuffer);
                cullingCS.SetBuffer(kernel, VGC.LOD2ARGSBUFFER, renderData.LodDatas[2].SubMeshDatas[0].argsBuffer);
                    

                if (renderData.visibleChunkCount < 1)
                {
                    continue;
                }
                
                int groupX = renderData.visibleChunkCount;
                int groupY = Mathf.CeilToInt(renderData.chunkMaxCount / 64f);
                cullingCS.Dispatch(kernel, groupX, groupY, 1);

                for (int n = 0; n < renderData.LodDatas.Length; n++)
                {
                    for (int k = 0; k < renderData.LodDatas[n].SubMeshDatas.Length; k++)
                    {
                        GraphicsBuffer.CopyCount(renderData.LodDatas[n].VisibleInstanceBuffer,renderData.LodDatas[n].SubMeshDatas[k].argsBuffer,sizeof(uint) * 1);
                    }
                }
                
                // 方法2a: 使用GraphicsFence
                var fence = Graphics.CreateGraphicsFence(GraphicsFenceType.AsyncQueueSynchronisation, SynchronisationStageFlags.ComputeProcessing);
                Graphics.WaitOnAsyncGraphicsFence(fence);

                foreach (var lodData in renderData.LodDatas)
                {
                    foreach (var subMeshData in lodData.SubMeshDatas)
                    {
                        subMeshData.argsBuffer.GetData(args);
                        Debug.Log($"subMeshData {subMeshData.rp.material.name}修改后的值: args[1] = {args[1]}");
                    }
                }

                foreach (var lodData in renderData.LodDatas)
                {
                    foreach (var subMeshData in lodData.SubMeshDatas)
                    {
                        // 3. 同步读取数据
                        subMeshData.argsBuffer.GetData(args);
                        Debug.Log($"{subMeshData.rp.material.name}修改后的值: args[1] = {args[1]}");
                    }
                }
                Debug.Log("------------------------------------------");
                
                // uint[] args       = new uint[5];
                // args[0] = renderData.mesh.GetIndexCount(0);
                // args[1] = (uint)0;
                // args[2] = renderData.mesh.GetIndexStart(0);
                // args[3] = renderData.mesh.GetBaseVertex(0);
                // args[4] = 0;
                // renderData.argsBuffer.SetData(args);
                // for (int k = 0; k < renderData.SubMeshDatas.Length; k++)
                // {
                //     uint[] subArgs = new uint[5];
                //     subArgs[0] = renderData.mesh.GetIndexCount(k);
                //     subArgs[1] = (uint)0;
                //     subArgs[2] = renderData.mesh.GetIndexStart(k);
                //     subArgs[3] = renderData.mesh.GetBaseVertex(k);
                //     subArgs[4] = 0;
                //     renderData.SubMeshDatas[k].argsBuffer.SetData(subArgs);
                // }
                // renderData.VisibleInstanceBuffer.SetCounterValue(0);
                //
                // cullingCS.SetBuffer(kernel, VGC.ALLINSTANCES, renderData.AllInstanceBuffer);
                // cullingCS.SetBuffer(kernel,VGC.VISIBLEINSTANCES,renderData.VisibleInstanceBuffer);
                // cullingCS.SetBuffer(kernel, VGC.ARGSBUFFER, renderData.SubMeshDatas[0].argsBuffer);
                // cullingCS.SetBuffer(kernel, VGC.VISIBLECHUNINFOS, renderData.VisibleChunkBuffer);
                // cullingCS.SetInt(VGC.CHUNKCOUNT,renderData.visibleChunkCount);
                //
                // if (renderData.visibleChunkCount < 1)
                // {
                //     continue;
                // }
                //
                // int groupX = renderData.visibleChunkCount;
                // int groupY = Mathf.CeilToInt(renderData.chunkMaxCount / 64f);
                // cullingCS.Dispatch(kernel, groupX, groupY, 1);
                //
                // for (int k = 0; k < renderData.SubMeshDatas.Length; k++)
                // {
                //     GraphicsBuffer.CopyCount(renderData.VisibleInstanceBuffer,renderData.SubMeshDatas[k].argsBuffer,sizeof(uint) * 1);
                // }
                
                // // 方法2a: 使用GraphicsFence
                // var fence = Graphics.CreateGraphicsFence(GraphicsFenceType.AsyncQueueSynchronisation, SynchronisationStageFlags.ComputeProcessing);
                // Graphics.WaitOnAsyncGraphicsFence(fence);
                //
                // foreach (var subMeshData in renderData.SubMeshDatas)
                // {
                //     subMeshData.argsBuffer.GetData(args);
                //     Debug.Log($"subMeshData {renderData.rp.material.name}修改后的值: args[1] = {args[1]}");
                // }
                //
                // // 3. 同步读取数据
                // renderData.argsBuffer.GetData(args);
                // Debug.Log($"{renderData.rp.material.name}修改后的值: args[1] = {args[1]}");
                //
                // Debug.Log("------------------------------------------");
            }
        }
        
        public void Render()
        {
           
            if (vgRender == null) return;
            foreach (var renderData in vgRender.vegetationRenderDataList)
            {
                // for (int i = 0; i < renderData.SubMeshDatas.Length; i++)
                // {
                //     Graphics.RenderMeshIndirect(renderData.SubMeshDatas[i].rp,renderData.mesh,renderData.SubMeshDatas[i].argsBuffer);
                // }
                for (int i = 0; i < renderData.LodDatas.Length; i++)
                {
                    var lodData = renderData.LodDatas[i];
                    for (int j = 0; j < lodData.SubMeshDatas.Length; j++)
                    {
                        Graphics.RenderMeshIndirect(lodData.SubMeshDatas[j].rp, lodData.mesh,
                            lodData.SubMeshDatas[j].argsBuffer);
                    }
                }
            }
        }

        public void OnDrawGizmos()
        {
            if (!Application.isPlaying || !ShowGizmos)
            {
                return;
            }

            if (vgRender != null)
            {
                var visibleChunkList = new List<ChunkInfoForJob>();
                foreach (var chunk in vgRender.vegetationChunkForJobDataNativeList)
                {
                    if (vgRender.visibleChunkGuidHashset.Contains(chunk.guid))
                    {
                        visibleChunkList.Add(chunk);
                    }
                    Gizmos.color = Color.red;
                    Gizmos.DrawWireCube(chunk.center,chunk.extents * 2f - Vector3.one);
                }

                foreach (var chunk in visibleChunkList)
                {
                    Gizmos.color = Color.green;
                    Gizmos.DrawWireCube(chunk.center,chunk.extents * 2f - Vector3.one);
                }
            }
        }

        public void OnDestroy()
        {
            vgRender?.Dispose();
            vgCulling?.Dispose();
            if (terrain != null)
            {
                terrain.drawTreesAndFoliage = true;
            }
        }
    }
}
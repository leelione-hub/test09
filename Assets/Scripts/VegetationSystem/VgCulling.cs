using System.Collections.Generic;
using Unity.Collections;
using Unity.Collections.NotBurstCompatible;
using Unity.Jobs;
using UnityEngine;

namespace VegetationSystem
{
    public class VgCulling
    {
        private VgRender                     _vgRender;
        private ComputeShader                _cullingCS;
        private Camera                       _cullingCamera;
        private VgFrustumCullingJob          _cullingJob;
        private NativeArray<ChunkInfoForJob> allChunkInfos;
        public VgCulling(VgRender vgRender,ComputeShader cs)
        {
            _vgRender = vgRender;
            _cullingCS = cs;
        }

        public void SetCullingCamera(Camera camera)
        {
            _cullingCamera = camera;
        }

        /// <summary>
        /// 设置jobculling中的allchunkList
        /// </summary>
        // public void SetAllChunkInfoArray(List<ChunkInfoForJob> allchunkList)
        // {
        //     if (allChunkInfos.IsCreated)
        //     {
        //         allChunkInfos.Dispose();
        //     }
        //     allChunkInfos = new NativeArray<ChunkInfoForJob>(allchunkList.ToArray(), Allocator.Persistent);
        // }
        
        void SetFrustumPlanes()
        {
            Plane[]   planes    = GeometryUtility.CalculateFrustumPlanes(_cullingCamera);
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
            _cullingCS.SetVectorArray(VgConstantProperty.FRUSTUMPLANES, planeData);
        }

        public void ScheduleCulling(ref HashSet<uint> outVisibleGuidList)
        {
            if (_vgRender == null) return;
            outVisibleGuidList.Clear();
            Plane[] planes = GeometryUtility.CalculateFrustumPlanes(_cullingCamera);
            NativeArray<Plane> planesArry = new NativeArray<Plane>(planes, Allocator.TempJob);
            
            NativeList<ChunkInfoForJob> visibleChunkInfoList =
                new NativeList<ChunkInfoForJob>( _vgRender.vegetationChunkForJobDataNativeList.Length, Allocator.TempJob);
            NativeList<uint> visibleGuidList = new NativeList<uint>(_vgRender.vegetationChunkForJobDataNativeList.Length, Allocator.TempJob);
            _cullingJob = new VgFrustumCullingJob()
            {
                planes              = planesArry,
                AllChunkInfoForJobs = _vgRender.vegetationChunkForJobDataNativeList,
                visibleGuidList     = visibleGuidList.AsParallelWriter()
            };
            JobHandle handle = _cullingJob.Schedule(_vgRender.vegetationChunkForJobDataNativeList.Length, 256);
            handle.Complete();
            
            for (int i = 0; i < visibleGuidList.Length; i++)
            {
                outVisibleGuidList.Add(visibleGuidList[i]);
            }

            planesArry.Dispose();
            visibleChunkInfoList.Dispose();
            visibleGuidList.Dispose();
        }
        
        public void DispatchCulling(List<VgRenderData> vgDataList)
        {
            SetFrustumPlanes();
            for (int i = 0; i < vgDataList.Count; i++)
            {
                var    mesh = vgDataList[i].mesh;
                uint[] args = new uint[5];
                args[0] = mesh.GetIndexCount(vgDataList[i].subMesh);
                args[1] = 0;
                args[2] = mesh.GetIndexStart(vgDataList[i].subMesh);
                args[3] = mesh.GetBaseVertex(vgDataList[i].subMesh);
                args[4] = 0;
                vgDataList[i].args.SetData(args);
                
                vgDataList[i].visibleBuffer.SetCounterValue(0);
                int kernel = 0;
                _cullingCS.SetBuffer(kernel, VgConstantProperty.ALLINSTANCES, vgDataList[i].allInstanceBuffer);
                _cullingCS.SetBuffer(kernel, VgConstantProperty.VISIBLEINSTANCES, vgDataList[i].visibleBuffer);
                _cullingCS.SetBuffer(kernel, VgConstantProperty.ARGSBUFFER, vgDataList[i].args);
                _cullingCS.SetBool(VgConstantProperty.ENABLECULLING, true);
                
                int threadGroup = Mathf.CeilToInt(vgDataList[i].grassCount / 64.0f);
                _cullingCS.Dispatch(kernel, threadGroup, 1, 1);
            }
        }

        public void Dispose()
        {
            allChunkInfos.Dispose();
        }
    }
}
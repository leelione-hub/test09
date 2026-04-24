using System.Collections.Generic;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;

namespace VegetationSystem
{
    public class VgCulling
    {
        private readonly VgRender _vgRender;
        private Camera _cullingCamera;
        private VgFrustumCullingJob _cullingJob;
        private NativeArray<ChunkInfoForJob> allChunkInfos;

        public VgCulling(VgRender vgRender)
        {
            _vgRender = vgRender;
        }

        public void SetCullingCamera(Camera camera)
        {
            _cullingCamera = camera;
        }

        public void ScheduleCulling(HashSet<uint> outVisibleGuidList)
        {
            if (_vgRender == null || _cullingCamera == null || outVisibleGuidList == null)
            {
                return;
            }

            outVisibleGuidList.Clear();

            Plane[] planes = GeometryUtility.CalculateFrustumPlanes(_cullingCamera);
            NativeArray<Plane> planeArray = new NativeArray<Plane>(planes, Allocator.TempJob);
            NativeList<uint> visibleGuidList =
                new NativeList<uint>(_vgRender.vegetationChunkForJobDataNativeList.Length, Allocator.TempJob);

            _cullingJob = new VgFrustumCullingJob
            {
                planes = planeArray,
                AllChunkInfoForJobs = _vgRender.vegetationChunkForJobDataNativeList,
                visibleGuidList = visibleGuidList.AsParallelWriter()
            };

            JobHandle handle = _cullingJob.Schedule(_vgRender.vegetationChunkForJobDataNativeList.Length, 256);
            handle.Complete();

            for (int i = 0; i < visibleGuidList.Length; i++)
            {
                outVisibleGuidList.Add(visibleGuidList[i]);
            }

            planeArray.Dispose();
            visibleGuidList.Dispose();
        }

        public void Dispose()
        {
            if (allChunkInfos.IsCreated)
            {
                allChunkInfos.Dispose();
            }
        }
    }
}

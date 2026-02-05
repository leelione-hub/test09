using System;
using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;


namespace VegetationSystem
{
    [BurstCompile]
    public struct VgFrustumCullingJob : IJobParallelFor
    {
        [ReadOnly] public NativeArray<Plane>           planes;
        // [ReadOnly] public NativeArray<OldChunkInfo>    allChunkInfos;
        [ReadOnly] public NativeArray<ChunkInfoForJob> AllChunkInfoForJobs;
       

        // public NativeList<OldChunkInfo>.ParallelWriter    visibleChunkInfos;
        // public NativeList<ChunkInfoForJob>.ParallelWriter VisibleChunkInfoForJobs;
        public NativeList<uint>.ParallelWriter             visibleGuidList;
        public void Execute(int index)
        {
            bool inside = true;
            var  chunk  = AllChunkInfoForJobs[index];
            uint guid   = chunk.guid;
            for (int i = 0; i < 6; i++)
            {
                float dist   = Vector3.Dot(planes[i].normal, chunk.center) + planes[i].distance;
                float radius = Mathf.Abs(planes[i].normal.x) * chunk.extents.x +
                               Mathf.Abs(planes[i].normal.y) * chunk.extents.y +
                               Mathf.Abs(planes[i].normal.z) * chunk.extents.z;
                if (dist + radius < 0.0f)
                {
                    inside = false;
                    break;
                }
            }

            if (inside)
            {
                var   near       = planes[4];
                float signedDist = Vector3.Dot(near.normal, chunk.center) + near.distance;
                if (signedDist < 500)
                {
                    visibleGuidList.AddNoResize(guid);
                }
            }
        }
    }
}
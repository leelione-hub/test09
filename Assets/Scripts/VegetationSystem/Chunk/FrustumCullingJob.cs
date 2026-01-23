using System;
using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;


namespace VegetationSystem
{
    [BurstCompile]
    public struct FrustumCullingJob : IJobParallelFor
    {
        [ReadOnly]public            NativeArray<Plane>     planes;
        [ReadOnly] public NativeArray<ChunkInfo> allChunkInfos;

        public NativeList<ChunkInfo>.ParallelWriter visibleChunkInfos;
        public void Execute(int index)
        {
            bool inside = true;
            var  chunk  = allChunkInfos[index];
            for (int i = 0; i < 6; i++)
            {
                float dist   = Vector3.Dot(planes[i].normal, chunk.center) + planes[i].distance;
                float radius = Mathf.Abs(planes[i].normal.x) * chunk.size.x +
                               Mathf.Abs(planes[i].normal.y) * chunk.size.y +
                               Mathf.Abs(planes[i].normal.z) * chunk.size.z;
                if (dist + radius < 0.0f)
                {
                    inside = false;
                    break;
                }
            }

            if (inside)
            {
                visibleChunkInfos.AddNoResize(chunk);
            }
        }
    }
}
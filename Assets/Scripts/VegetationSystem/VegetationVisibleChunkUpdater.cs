using System.Collections.Generic;
using UnityEngine;

namespace VegetationSystem
{
    public sealed class VegetationVisibleChunkUpdater
    {
        private readonly List<ChunkInfoBuffer> _visibleChunkInfos = new List<ChunkInfoBuffer>();

        public void Refresh(VegetationRuntimeData runtimeData, int chunkInfoStride)
        {
            for (int i = 0; i < runtimeData.VegetationRenderDataList.Count; i++)
            {
                var data = runtimeData.VegetationRenderDataList[i];
                _visibleChunkInfos.Clear();
                foreach (var chunk in data.allChunkInfos)
                {
                    if (runtimeData.VisibleChunkGuidSet.Contains(chunk.guid))
                    {
                        _visibleChunkInfos.Add(chunk);
                    }
                }

                data.visibleChunkInfos = new List<ChunkInfoBuffer>(_visibleChunkInfos);
                data.visibleChunkCount = data.visibleChunkInfos.Count;

                data.VisibleChunkBuffer?.Dispose();

                int bufferCount = Mathf.Max(1, data.visibleChunkCount);
                data.VisibleChunkBuffer = new GraphicsBuffer(
                    GraphicsBuffer.Target.Structured,
                    bufferCount,
                    chunkInfoStride);

                if (data.visibleChunkCount > 0)
                {
                    data.VisibleChunkBuffer.SetData(data.visibleChunkInfos);
                }

                runtimeData.VegetationRenderDataList[i] = data;
            }
        }
    }
}

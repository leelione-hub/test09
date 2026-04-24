using System.Collections.Generic;
using Unity.Collections;

namespace VegetationSystem
{
    public sealed class VegetationRuntimeData
    {
        public List<VegetationRenderData> VegetationRenderDataList { get; } = new List<VegetationRenderData>();

        public HashSet<uint> VisibleChunkGuidSet { get; } = new HashSet<uint>();

        public NativeArray<ChunkInfoForJob> ChunkInfosForJob { get; set; }
    }
}
using UnityEngine;

namespace VegetationSystem
{
    public sealed class VegetationRenderDataDisposer
    {
        public void Dispose(VegetationRuntimeData runtimeData)
        {
            if (runtimeData.ChunkInfosForJob.IsCreated)
            {
                runtimeData.ChunkInfosForJob.Dispose();
            }

            foreach (var renderData in runtimeData.VegetationRenderDataList)
            {
                renderData.AllInstanceBuffer.Dispose();
                renderData.VisibleChunkBuffer.Dispose();
                renderData.VisibleInstanceBuffer.Dispose();
                renderData.VisibleInstanceCountBuffer.Dispose();

                foreach (var subMeshData in renderData.SubMeshDatas)
                {
                    subMeshData.argsBuffer.Dispose();
                    subMeshData.shadowArgsBuffer?.Dispose();
                    subMeshData.rp.material.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                    subMeshData.shadowRp.material?.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                }

                foreach (var lodData in renderData.LodDatas)
                {
                    lodData.VisibleInstanceBuffer?.Dispose();
                    lodData.ShadowVisibleInstanceBuffer?.Dispose();
                    if (lodData.SubMeshDatas == null)
                    {
                        continue;
                    }

                    foreach (var subMeshData in lodData.SubMeshDatas)
                    {
                        subMeshData.argsBuffer?.Dispose();
                        subMeshData.shadowArgsBuffer?.Dispose();
                        subMeshData.rp.material?.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                        subMeshData.shadowRp.material?.DisableKeyword(VgConstantProperty.KW_GPUINSTANCEON);
                    }
                }
            }

            runtimeData.VegetationRenderDataList.Clear();
            runtimeData.VisibleChunkGuidSet.Clear();
        }
    }
}

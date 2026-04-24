using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace VegetationSystem
{
    public sealed class VgRuntimeRenderer
    {
        private readonly Dictionary<int, int> _forwardPassIndexCache = new Dictionary<int, int>();

        public void RenderDirect(IReadOnlyList<VegetationRenderData> renderDataList)
        {
            for (int i = 0; i < renderDataList.Count; i++)
            {
                var renderData = renderDataList[i];
                for (int lodIndex = 0; lodIndex < renderData.activeLodCount; lodIndex++)
                {
                    var lodData = renderData.LodDatas[lodIndex];
                    for (int subMeshIndex = 0; subMeshIndex < lodData.SubMeshDatas.Length; subMeshIndex++)
                    {
                        lodData.SubMeshDatas[subMeshIndex].rp.material.SetBuffer(
                            VgConstantProperty.INSTANCEBUFFER,
                            lodData.VisibleInstanceBuffer);
                        Graphics.RenderMeshIndirect(lodData.SubMeshDatas[subMeshIndex].rp, lodData.mesh,
                            lodData.SubMeshDatas[subMeshIndex].argsBuffer);
                    }
                }
            }
        }

        public void RenderWithCommandBuffer(CommandBuffer cmd, IReadOnlyList<VegetationRenderData> renderDataList)
        {
            if (cmd == null)
            {
                return;
            }

            for (int i = 0; i < renderDataList.Count; i++)
            {
                var renderData = renderDataList[i];
                for (int lodIndex = 0; lodIndex < renderData.activeLodCount; lodIndex++)
                {
                    var lodData = renderData.LodDatas[lodIndex];
                    if (lodData.mesh == null)
                    {
                        continue;
                    }

                    for (int subMeshIndex = 0; subMeshIndex < lodData.SubMeshDatas.Length; subMeshIndex++)
                    {
                        var subMeshData = lodData.SubMeshDatas[subMeshIndex];
                        Material material = subMeshData.rp.material;
                        if (material == null || subMeshData.argsBuffer == null)
                        {
                            continue;
                        }

                        material.SetBuffer(VgConstantProperty.INSTANCEBUFFER, lodData.VisibleInstanceBuffer);
                        cmd.DrawMeshInstancedIndirect(
                            lodData.mesh,
                            subMeshData.subMesh,
                            material,
                            ResolveForwardPassIndex(material),
                            subMeshData.argsBuffer,
                            0,
                            null);
                    }
                }
            }
        }

        public void SubmitShadowCasters(IReadOnlyList<VegetationRenderData> renderDataList)
        {
            for (int i = 0; i < renderDataList.Count; i++)
            {
                var renderData = renderDataList[i];
                for (int lodIndex = 0; lodIndex < renderData.activeLodCount; lodIndex++)
                {
                    var lodData = renderData.LodDatas[lodIndex];
                    if (lodData.mesh == null)
                    {
                        continue;
                    }

                    for (int subMeshIndex = 0; subMeshIndex < lodData.SubMeshDatas.Length; subMeshIndex++)
                    {
                        var subMeshData = lodData.SubMeshDatas[subMeshIndex];
                        if (subMeshData.shadowArgsBuffer == null || subMeshData.shadowRp.material == null)
                        {
                            continue;
                        }

                        RenderParams shadowRp = subMeshData.shadowRp;
                        if (shadowRp.shadowCastingMode == ShadowCastingMode.Off)
                        {
                            continue;
                        }

                        shadowRp.shadowCastingMode = ShadowCastingMode.ShadowsOnly;
                        shadowRp.receiveShadows = false;

                        if (shadowRp.worldBounds.extents == Vector3.zero)
                        {
                            shadowRp.worldBounds = new Bounds(Vector3.zero, Vector3.one * 5000f);
                        }

                        shadowRp.material.SetBuffer(VgConstantProperty.INSTANCEBUFFER, lodData.ShadowVisibleInstanceBuffer);
                        Graphics.RenderMeshIndirect(shadowRp, lodData.mesh, subMeshData.shadowArgsBuffer);
                    }
                }
            }
        }

        private int ResolveForwardPassIndex(Material material)
        {
            int materialId = material.GetInstanceID();
            if (_forwardPassIndexCache.TryGetValue(materialId, out int cachedPassIndex))
            {
                return cachedPassIndex;
            }

            int passIndex = material.FindPass("ForwardLit");
            if (passIndex < 0)
            {
                passIndex = material.FindPass("UniversalForward");
            }
            if (passIndex < 0)
            {
                passIndex = material.FindPass("UniversalForwardOnly");
            }
            if (passIndex < 0)
            {
                passIndex = material.FindPass("SRPDefaultUnlit");
            }
            if (passIndex < 0)
            {
                passIndex = 0;
            }

            _forwardPassIndexCache[materialId] = passIndex;
            return passIndex;
        }
    }
}

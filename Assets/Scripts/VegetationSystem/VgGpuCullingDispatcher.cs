using System;
using UnityEngine;
using UnityEngine.Rendering;
using VGC = VegetationSystem.VgConstantProperty;

namespace VegetationSystem
{
    public sealed class VgGpuCullingDispatcher
    {
        private readonly Plane[] _planes = new Plane[6];
        private static readonly uint[] VisibleCountReset = { 0u };

        public bool Dispatch(
            ComputeShader cullingCS,
            Camera cullingCamera,
            VgRender vgRender,
            int cullKernel,
            int classifyKernel,
            float maxShadowDistance,
            Action<ComputeShader, int, Camera> configureCullKernel = null)
        {
            if (cullingCS == null || cullingCamera == null || vgRender == null)
            {
                return false;
            }

            if (cullKernel < 0 || classifyKernel < 0)
            {
                return false;
            }

            GeometryUtility.CalculateFrustumPlanes(cullingCamera, _planes);
            cullingCS.SetVectorArray(VGC.FRUSTUMPLANES, ConvertFrustumPlanes(_planes));
            cullingCS.SetVector(VGC.CAMERAPOSITION, cullingCamera.transform.position);

            configureCullKernel?.Invoke(cullingCS, cullKernel, cullingCamera);

            for (int i = 0; i < vgRender.vegetationRenderDataList.Count; i++)
            {
                var renderData = vgRender.vegetationRenderDataList[i];
                ResetDrawState(renderData);
                BindCullBuffers(cullingCS, cullKernel, renderData, cullingCamera.transform.position);

                if (renderData.visibleChunkCount < 1)
                {
                    continue;
                }

                int groupX = renderData.visibleChunkCount;
                int groupY = Mathf.CeilToInt(renderData.chunkMaxCount / 64f);
                cullingCS.Dispatch(cullKernel, groupX, groupY, 1);

                DispatchLodClassification(cullingCS, classifyKernel, vgRender, renderData, cullingCamera, maxShadowDistance);
            }

            return true;
        }

        private static Vector4[] ConvertFrustumPlanes(Plane[] planes)
        {
            Vector4[] planeData = new Vector4[6];
            for (int i = 0; i < 6; i++)
            {
                Vector3 normal = planes[i].normal;
                planeData[i] = new Vector4(normal.x, normal.y, normal.z, planes[i].distance);
            }

            return planeData;
        }

        private static void ResetDrawState(VegetationRenderData renderData)
        {
            int activeLodCount = renderData.activeLodCount;
            for (int i = 0; i < activeLodCount; i++)
            {
                var lodData = renderData.LodDatas[i];
                ResetLodArgs(lodData);
                lodData.VisibleInstanceBuffer.SetCounterValue(0);
                lodData.ShadowVisibleInstanceBuffer.SetCounterValue(0);
            }

            renderData.VisibleInstanceBuffer.SetCounterValue(0);
            renderData.VisibleInstanceCountBuffer.SetData(VisibleCountReset);
        }

        private static void ResetLodArgs(VegetaionRenderLodData lodData)
        {
            for (int i = 0; i < lodData.SubMeshDatas.Length; i++)
            {
                uint[] subArgs = new uint[5];
                subArgs[0] = lodData.mesh.GetIndexCount(i);
                subArgs[1] = 0u;
                subArgs[2] = lodData.mesh.GetIndexStart(i);
                subArgs[3] = lodData.mesh.GetBaseVertex(i);
                subArgs[4] = 0u;
                lodData.SubMeshDatas[i].argsBuffer.SetData(subArgs);
                lodData.SubMeshDatas[i].shadowArgsBuffer.SetData(subArgs);
            }
        }

        private static void BindCullBuffers(
            ComputeShader cullingCS,
            int cullKernel,
            VegetationRenderData renderData,
            Vector3 cameraPosition)
        {
            cullingCS.SetBuffer(cullKernel, VGC.ALLINSTANCES, renderData.AllInstanceBuffer);
            cullingCS.SetBuffer(cullKernel, VGC.VISIBLECHUNINFOS, renderData.VisibleChunkBuffer);
            cullingCS.SetInt(VGC.CHUNKCOUNT, renderData.visibleChunkCount);
            cullingCS.SetVector(VGC.CAMERAPOSITION, cameraPosition);
            cullingCS.SetVector(VGC.BOUNDSEXTENTS, renderData.boundsExtentsOS);
            cullingCS.SetVector(VGC.BOUNDSCENTEROS, renderData.boundsCenterOS);
            cullingCS.SetBuffer(cullKernel, VGC.CULLEDVISIBLEINSTANCES, renderData.VisibleInstanceBuffer);
            cullingCS.SetBuffer(cullKernel, VGC.VISIBLEINSTANCECOUNT, renderData.VisibleInstanceCountBuffer);
        }

        private static void DispatchLodClassification(
            ComputeShader cullingCS,
            int classifyKernel,
            VgRender vgRender,
            VegetationRenderData renderData,
            Camera cullingCamera,
            float maxShadowDistance)
        {
            int classifyGroupX = Mathf.CeilToInt(renderData.instanceMaxCount / 64f);
            cullingCS.SetBuffer(classifyKernel, VGC.CULLEDVISIBLEINSTANCESINPUT, renderData.VisibleInstanceBuffer);
            cullingCS.SetBuffer(classifyKernel, VGC.VISIBLEINSTANCECOUNT, renderData.VisibleInstanceCountBuffer);
            cullingCS.SetVector(VGC.CAMERAPOSITION, cullingCamera.transform.position);

            for (int lodIndex = 0; lodIndex < renderData.activeLodCount; lodIndex++)
            {
                if (!vgRender.TryGetLodDistanceRange(
                        renderData,
                        lodIndex,
                        cullingCamera,
                        QualitySettings.lodBias,
                        QualitySettings.maximumLODLevel,
                        out Vector2 distanceRange))
                {
                    continue;
                }

                var lodData = renderData.LodDatas[lodIndex];
                cullingCS.SetVector(VGC.LODDISTANCERANGE, distanceRange);
                cullingCS.SetBuffer(classifyKernel, VGC.VISIBLEINSTANCES, lodData.VisibleInstanceBuffer);
                cullingCS.SetBuffer(classifyKernel, VGC.ARGSBUFFER, lodData.SubMeshDatas[0].argsBuffer);
                cullingCS.Dispatch(classifyKernel, classifyGroupX, 1, 1);

                for (int i = 0; i < lodData.SubMeshDatas.Length; i++)
                {
                    GraphicsBuffer.CopyCount(
                        lodData.VisibleInstanceBuffer,
                        lodData.SubMeshDatas[i].argsBuffer,
                        sizeof(uint));
                }

                if (!TryGetShadowDistanceRange(distanceRange, maxShadowDistance, out Vector2 shadowDistanceRange))
                {
                    continue;
                }

                cullingCS.SetVector(VGC.LODDISTANCERANGE, shadowDistanceRange);
                cullingCS.SetBuffer(classifyKernel, VGC.VISIBLEINSTANCES, lodData.ShadowVisibleInstanceBuffer);
                cullingCS.SetBuffer(classifyKernel, VGC.ARGSBUFFER, lodData.SubMeshDatas[0].shadowArgsBuffer);
                cullingCS.Dispatch(classifyKernel, classifyGroupX, 1, 1);

                for (int i = 0; i < lodData.SubMeshDatas.Length; i++)
                {
                    GraphicsBuffer.CopyCount(
                        lodData.ShadowVisibleInstanceBuffer,
                        lodData.SubMeshDatas[i].shadowArgsBuffer,
                        sizeof(uint));
                }
            }
        }

        private static bool TryGetShadowDistanceRange(Vector2 renderDistanceRange, float maxShadowDistance, out Vector2 shadowDistanceRange)
        {
            float shadowMax = maxShadowDistance > 0f ? Mathf.Min(renderDistanceRange.y, maxShadowDistance) : renderDistanceRange.y;
            if (shadowMax <= renderDistanceRange.x)
            {
                shadowDistanceRange = default;
                return false;
            }

            shadowDistanceRange = new Vector2(renderDistanceRange.x, shadowMax);
            return true;
        }
    }
}

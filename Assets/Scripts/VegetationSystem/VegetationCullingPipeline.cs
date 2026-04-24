using System;
using UnityEngine;

namespace VegetationSystem
{
    public sealed class VegetationCullingPipeline
    {
        private readonly VgGpuCullingDispatcher _gpuCullingDispatcher;
        private VgCulling _cpuCulling;

        public VegetationCullingPipeline(VgGpuCullingDispatcher gpuCullingDispatcher)
        {
            _gpuCullingDispatcher = gpuCullingDispatcher;
        }

        public void Initialize(VgRender vgRender)
        {
            _cpuCulling = new VgCulling(vgRender);
        }

        public void ExecuteCpuCulling(Camera cullingCamera, VgRender vgRender)
        {
            if (_cpuCulling == null || cullingCamera == null || vgRender == null)
            {
                return;
            }

            _cpuCulling.SetCullingCamera(cullingCamera);
            _cpuCulling.ScheduleCulling(vgRender.visibleChunkGuidHashset);
            vgRender.RefreshVisibleChunkBuffer();
        }

        public bool ExecuteGpuCulling(
            ComputeShader cullingShader,
            Camera cullingCamera,
            VgRender vgRender,
            int cullKernel,
            int classifyKernel,
            float maxShadowDistance,
            Action<ComputeShader, int, Camera> configureCullKernel = null)
        {
            return _gpuCullingDispatcher.Dispatch(
                cullingShader,
                cullingCamera,
                vgRender,
                cullKernel,
                classifyKernel,
                maxShadowDistance,
                configureCullKernel);
        }

        public void Dispose()
        {
            _cpuCulling?.Dispose();
        }
    }
}

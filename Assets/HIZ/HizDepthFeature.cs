using System;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Acaelum.RenderFramework
{
    [Serializable]
    public class HizSettings
    {
        public bool toggle;
        public ComputeShader mipmapCs;
    }
    public class HizDepthFeature : ScriptableRendererFeature
    {
        public HizSettings settings = new HizSettings();

        private HizDepthPass _hizDepthPass;

        public override void Create()
        {
            _hizDepthPass = new HizDepthPass
            {
                renderPassEvent = RenderPassEvent.AfterRenderingPrePasses + 1
            };
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (_hizDepthPass.Setup(settings))
            {
                renderer.EnqueuePass(_hizDepthPass);
            }
        }
    }

    public class HizDepthPass : ScriptableRenderPass
    {
        private HizSettings _settings;
        private RenderTexture _mipmapDepthTex;
        private int2 _mipmapTextureBaseSize;

        private static readonly int CAMERA_DEPTH_TEXTURE_NAME_ID = Shader.PropertyToID("_CameraDepthTexture");
        
        private int HizDepthTextureId = Shader.PropertyToID("_HizDepthTexture");

        public HizDepthPass()
        {
            base.profilingSampler = new ProfilingSampler(nameof(HizDepthPass));
        }

        public bool Setup(HizSettings settings)
        {
            ConfigureInput(ScriptableRenderPassInput.None);
            _settings = settings;
            
            if (!_settings.toggle)
            {
                return false;
            }

            ConfigureInput(ScriptableRenderPassInput.Depth);
            return true;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var cameraDepthTexture = (renderingData.cameraData.renderer as UniversalRenderer).DepthTexture;
            ConfigureTarget(cameraDepthTexture);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_settings.mipmapCs == null)
            {
                return;
            }
            
            var cameraDepthTexture = (renderingData.cameraData.renderer as UniversalRenderer).DepthTexture;
            if (cameraDepthTexture == null || !Filter(renderingData.cameraData.camera))
            {
                return;
            }
            MatchHiz(cameraDepthTexture);
            
            var cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, profilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                
                GenMipmapDepth(cmd, cameraDepthTexture);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void GenMipmapDepth(CommandBuffer cmd, RenderTexture cameraDepthTexture)
        {
            var cs = _settings.mipmapCs;
            
            var depthBlitKernel = cs.FindKernel("DepthBlit");
            cmd.SetComputeTextureParam(cs, depthBlitKernel, "_CameraDepthTexture", cameraDepthTexture);
            cmd.SetComputeTextureParam(cs, depthBlitKernel, "_HizMipmapTexture", _mipmapDepthTex);
            cmd.SetComputeIntParam(cs, "_CameraDepthTextureWidth", cameraDepthTexture.width);
            cmd.SetComputeIntParam(cs, "_CameraDepthTextureHeight", cameraDepthTexture.height);
            cmd.SetGlobalInt("_HizDepthTextureBaseWidth", _mipmapTextureBaseSize.x);
            cmd.SetGlobalInt("_HizDepthTextureBaseHeight", _mipmapTextureBaseSize.y);
            //Debug.Log(_mipmapTextureBaseSize);
            cmd.DispatchCompute(
                cs, 
                depthBlitKernel, 
                Mathf.CeilToInt(_mipmapTextureBaseSize.x / 8f),
                Mathf.CeilToInt(_mipmapTextureBaseSize.y / 8f),
                1);

            var genMipmapKernel = cs.FindKernel("GenMipmap");
            cmd.SetComputeTextureParam(cs, genMipmapKernel, HizDepthTextureId, _mipmapDepthTex);
            var mipmapLevel = 0;
            while (true)
            {
                mipmapLevel++;
                var curWidth = _mipmapTextureBaseSize.x >> mipmapLevel;
                var curHeight = _mipmapTextureBaseSize.y >> mipmapLevel;
                if (curWidth == 0 || curHeight == 0)
                {
                    break;
                }
                
                cmd.SetComputeIntParam(cs, "_HizMipmapLevel", mipmapLevel);
                cmd.DispatchCompute(
                    cs, 
                    genMipmapKernel,
                    Mathf.CeilToInt(curWidth / 8f),
                    Mathf.CeilToInt(curHeight / 8f),
                    1);
            }
        }
        
        private void MatchHiz(RenderTexture cameraDepthTexture)
        {
            if (cameraDepthTexture == null)
            {
                return;
            }
            
            var mipmapDepthDes = cameraDepthTexture.descriptor;
            _mipmapTextureBaseSize.y = FloorToSecondPower(mipmapDepthDes.height);
            int width = Mathf.CeilToInt((float)mipmapDepthDes.width / (float)mipmapDepthDes.height * _mipmapTextureBaseSize.y);
            _mipmapTextureBaseSize.x = width;////FloorToSecondPower(mipmapDepthDes.width);
            var mipmapTextureRealSize = new int2(
                _mipmapTextureBaseSize.x + (_mipmapTextureBaseSize.x >> 1),
                _mipmapTextureBaseSize.y);
            if (_mipmapDepthTex == null || _mipmapDepthTex.width != mipmapTextureRealSize.x || _mipmapDepthTex.height != mipmapTextureRealSize.y)
            {
                ReleaseHiz();
                mipmapDepthDes.width = mipmapTextureRealSize.x;
                mipmapDepthDes.height = mipmapTextureRealSize.y;
                mipmapDepthDes.graphicsFormat = GraphicsFormat.R32_SFloat;
                mipmapDepthDes.enableRandomWrite = true;
                _mipmapDepthTex = new RenderTexture(mipmapDepthDes)
                {
                    name = "_HizDepthTexture", 
                    filterMode = FilterMode.Point
                };
                _mipmapDepthTex.Create();

                Shader.SetGlobalTexture(HizDepthTextureId, _mipmapDepthTex);
            }
        }

        private void ReleaseHiz()
        {
            if (_mipmapDepthTex == null) return;
            _mipmapDepthTex.Release();
            _mipmapDepthTex = null;
        }

        private static int FloorToSecondPower(int input)
        {
            var n = input; // floor就不减1了，得到的是一定大于input的最小二次幂
            n |= n >> 1;
            n |= n >> 2;
            n |= n >> 4;
            n |= n >> 8;
            n |= n >> 16;
            n = (n + 1) >> 1; // 右移一位就是小于或等于input的最大二次幂
            return n;
        }
        
        private static bool Filter(Camera cam)
        {
            return CameraUtils.MainCamera(cam);
        }
    }
}

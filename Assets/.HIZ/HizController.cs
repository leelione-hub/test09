using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.UI;
using Debug = System.Diagnostics.Debug;

namespace Acaelum.RenderFramework
{

    public class HizController : MonoBehaviour
    {
        public ComputeShader cullingCS;
        public List<GameObject> gos = new List<GameObject>();
        public int notRenderingLayer = 31;

        
        private int allCentersId = Shader.PropertyToID("_AllCenters");
        private int allExtentsId = Shader.PropertyToID("_AllExtents");
        private int cullingResultBufferId = Shader.PropertyToID("_CullingResultBuffer");
        
        private ComputeBuffer cullingResultBuffer;
        private ComputeBuffer allCenters;
        private float3[] allCentersData;
        private ComputeBuffer allExtends;
        private float3[] allExtentsData;
        private int[] allOriLayer;
        private float[] readbackData;

        private int frameCount = 0;
        private bool hasRequest = false;
        private bool hasInit = false;
        private int kernelIndex = 0;
        private int threadNum = -1;

        private bool supportCS = false;
        private bool canUseSSBO = false;
        
        //Debug
        public bool openDebug = false;
        public RawImage rawImage;
        public int debugNum = 0;
        public Vector2Int debugRtSize = new Vector2Int(480, 270);
        private RenderTexture readbackRT;
        private int debugRTId = Shader.PropertyToID("_DebugRT");
        private int debugRTSizeId = Shader.PropertyToID("_DebugRTSize");
        private int debugNumId = Shader.PropertyToID("_DebugNumSize");
        
        private (int kernel, int threadNum) CheckThreadKernel(ComputeShader cs, int min, int max, int stride)
        {
            try
            {
                var maxSupport = SystemInfo.maxComputeWorkGroupSizeX;
                if (maxSupport < min)
                {
                    return (-1, 0);
                }

                var kernel = min;
                max = Mathf.Min(maxSupport, max);
                while (true)
                {
                    if (kernel == max)
                    {
                        break;
                    }

                    if (kernel > max)
                    {
                        kernel >>= stride;
                        break;
                    }

                    kernel <<= stride;
                }

                return (cs.FindKernel($"CSMain{kernel}"), kernel);
            }
            catch (Exception e)
            {
                UnityEngine.Debug.LogError(e);
                return (-1, 0);
            }
        }

        private void Awake()
        {
            supportCS = SystemInfo.supportsComputeShaders;
            canUseSSBO = SystemInfo.maxComputeBufferInputsCompute >= 1;
        }
        private void OnEnable()
        {
            if (!supportCS || !canUseSSBO)
            {
                return;
            }

            RenderPipelineManager.endCameraRendering += Process;
        }

        private void OnDisable()
        {
            ResetVisibleState();
            RenderPipelineManager.endCameraRendering += Process;
            hasInit = false;
            hasRequest = false;
            frameCount = 0;
        }
        
        private void OnDestroy()
        {
            if (cullingResultBuffer != null)
            {
                cullingResultBuffer.Dispose();
                cullingResultBuffer = null;
            }

            if (allCenters != null)
            {
                allCenters.Dispose();
                allCenters = null;
            }

            if (allExtends != null)
            {
                allExtends.Dispose();
                allExtends = null;
            }

            if (readbackRT != null)
            {
                Destroy(readbackRT);
                readbackRT = null;
            }
        }

        private void ResetVisibleState()
        {
            if (!hasInit)
            {
                return;
            }

            for (int i = 0; i < gos.Count; i++)
            {
                if (gos[i] != null && !gos[i].Equals(null))
                {
                    gos[i].layer = allOriLayer[i];
                }
            }
        }

        private void DealDebug()
        {
            if (openDebug)
            {
                readbackRT = new RenderTexture(debugRtSize.x, debugRtSize.y, 0);
                readbackRT.enableRandomWrite = true;
                readbackRT.graphicsFormat = GraphicsFormat.R8G8B8A8_UNorm;
                readbackRT.filterMode = FilterMode.Point;
                
                if (rawImage != null)
                {
                    rawImage.texture = readbackRT;
                }
                cullingCS.SetTexture(kernelIndex, debugRTId, readbackRT);
                cullingCS.SetVector(debugRTSizeId, new Vector4(debugRtSize.x, debugRtSize.y, 0, 0));
                cullingCS.SetInt(debugNumId, debugNum);
                
                cullingCS.EnableKeyword("_DEBUG");
            }
        }

        [ContextMenu("点我初始化！")]
        public void Init()
        {
            if (hasInit || cullingCS == null || !supportCS || !canUseSSBO)
            {
                return;
            }

            var (index, num) = CheckThreadKernel(cullingCS, 1, 512, 3);
            kernelIndex = index;
            threadNum = num;
            
            RefreshBuffer();
            DealDebug();

            hasInit = true;
        }

        private void UpdateGosLayer()
        {
            allOriLayer = new int[gos.Count];
            for (int i = 0; i < allOriLayer.Length; i++)
            {
                allOriLayer[i] = gos[i].layer;
            }
        }

        private void UpdateGosCenter(bool newOne)
        {
            if (newOne)
            {
                if (allCenters != null)
                {
                    allCenters.Dispose();
                    allCenters = null;
                }

                allCentersData = new float3[gos.Count];
                allCenters = new ComputeBuffer(gos.Count, 3 * sizeof(float));
            }
            for (int i = 0; i < allCentersData.Length; i++)
            {
                //UnityEngine.Debug.Log(gos[i].name + "    " + gos[i].transform.position);
                allCentersData[i] = gos[i].transform.position;
            }
            allCenters.SetData(allCentersData);
            cullingCS.SetBuffer(kernelIndex, allCentersId, allCenters);
        }

        private void UpdateGosExtends()
        {
            allExtentsData = new float3[gos.Count];
            allExtends = new ComputeBuffer(gos.Count, 3 * sizeof(float));
            for (int i = 0; i < allExtentsData.Length; i++)
            {
                var renderers = gos[i].GetComponentsInChildren<Renderer>();
                float maxX = -10000;
                float maxY = -10000;
                float maxZ = -10000;
                for (int j = 0; j < renderers.Length; j++)
                {
                    var curExtents = renderers[j].bounds.extents;
                    if (maxX < curExtents.x)
                    {
                        maxX = curExtents.x;
                    }
                    if (maxY < curExtents.y)
                    {
                        maxY = curExtents.y;
                    }
                    if (maxZ < curExtents.z)
                    {
                        maxZ = curExtents.z;
                    }
                }
                allExtentsData[i] = new float3(maxX, maxY, maxZ);
            }
            allExtends.SetData(allExtentsData);
            cullingCS.SetBuffer(kernelIndex, allExtentsId, allExtends);
        }

        /// <summary>
        /// 当gos改变的时候，可以调用这个方法刷新参与HIZ的物体列表。
        /// </summary>
        public void RefreshBuffer()
        {
            var gosNum = gos.Count;
            cullingResultBuffer = new ComputeBuffer(gosNum, sizeof(float));
            cullingResultBuffer.SetData(new float[gosNum]);
            cullingCS.SetBuffer(kernelIndex, cullingResultBufferId, cullingResultBuffer);

            UpdateGosLayer();
            UpdateGosCenter(true);
            UpdateGosExtends();
            readbackData = new float[gosNum];
        }

        /// <summary>
        /// 只更新center，如果物体发生了放大缩小，则需要把extents也更新了。
        /// </summary>
        private void CalculateComputeShaderParams()
        {
            UpdateGosCenter(false);
        }

        private void Process(ScriptableRenderContext context, Camera camera)
        {
            var additionalCameraData = camera.GetUniversalAdditionalCameraData();
            if (!additionalCameraData.LastOneBeforeUI || camera.cameraType == CameraType.SceneView)
            {
                return;
            }
            
            if (kernelIndex < 0)
            {
                return;
            }
            
            if (hasInit)
            {
                frameCount++;
                //15帧执行一次，如果有需要更改频率，就改这里。
                if (!hasRequest && frameCount >= 15)
                {
                    CalculateComputeShaderParams();
                    cullingCS.SetMatrix("_VP",GL.GetGPUProjectionMatrix(camera.projectionMatrix,false) *  camera.worldToCameraMatrix);
                    cullingCS.Dispatch(kernelIndex, threadNum, 1, 1);
                    if (cullingResultBuffer != null)
                    {
                        AsyncGPUReadback.Request(cullingResultBuffer, Callback);   
                    }
                    hasRequest = true;
                    frameCount = 0;
                }
            }
        }

        void Callback(AsyncGPUReadbackRequest data)
        {
            if(!hasRequest)
            {
                return;
            }
            hasRequest = false;
            if (!hasInit)
            {
                return;
            }
            data.GetData<float>().CopyTo(readbackData);
            for (int i = 0; i < gos.Count; i++)
            {
                //UnityEngine.Debug.Log(gos[i].name + " " + readbackData[i]);
                if(readbackData[i] > 0)
                {
                    gos[i].layer = notRenderingLayer;
                }
                else
                {
                    gos[i].layer = allOriLayer[i];
                }
            }
        }
    }
}
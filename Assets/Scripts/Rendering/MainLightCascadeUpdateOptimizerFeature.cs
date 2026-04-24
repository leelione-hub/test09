using System;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

namespace Project.Rendering
{
    [Serializable]
    public sealed class MainLightCascadeUpdateOptimizerFeature : ScriptableRendererFeature
    {
        [SerializeField]
        bool m_EnableOptimization = true;

        [SerializeField]
        int m_Cascade0Interval = 1;

        [SerializeField]
        int m_Cascade1Interval = 2;

        [SerializeField]
        int m_Cascade2Interval = 4;

        [SerializeField]
        int m_Cascade3Interval = 8;

        public bool enableOptimization
        {
            get => m_EnableOptimization;
            set => m_EnableOptimization = value;
        }

        public int cascade0Interval
        {
            get => m_Cascade0Interval;
            set => m_Cascade0Interval = Mathf.Max(1, value);
        }

        public int cascade1Interval
        {
            get => m_Cascade1Interval;
            set => m_Cascade1Interval = Mathf.Max(1, value);
        }

        public int cascade2Interval
        {
            get => m_Cascade2Interval;
            set => m_Cascade2Interval = Mathf.Max(1, value);
        }

        public int cascade3Interval
        {
            get => m_Cascade3Interval;
            set => m_Cascade3Interval = Mathf.Max(1, value);
        }

        public override void Create()
        {
            ClampIntervals();
        }

        public override void OnCameraPreCull(ScriptableRenderer renderer, in CameraData cameraData)
        {
            ClampIntervals();
            MainLightShadowCasterPass.SetStaggeredCascadeUpdateSettings(
                m_EnableOptimization,
                m_Cascade0Interval,
                m_Cascade1Interval,
                m_Cascade2Interval,
                m_Cascade3Interval);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
        }

        protected override void Dispose(bool disposing)
        {
            MainLightShadowCasterPass.SetStaggeredCascadeUpdateSettings(false, 1, 2, 4, 8);
        }

        void ClampIntervals()
        {
            m_Cascade0Interval = Mathf.Max(1, m_Cascade0Interval);
            m_Cascade1Interval = Mathf.Max(1, m_Cascade1Interval);
            m_Cascade2Interval = Mathf.Max(1, m_Cascade2Interval);
            m_Cascade3Interval = Mathf.Max(1, m_Cascade3Interval);
        }
    }
}

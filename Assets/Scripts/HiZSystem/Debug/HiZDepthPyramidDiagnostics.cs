using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using HiZTechnique;

namespace HiZTechnique.Debugger
{
    /// <summary>
    /// HiZ深度金字塔诊断工具
    /// 检查深度金字塔是否正确生成
    /// </summary>
    public class HiZDepthPyramidDiagnostics : MonoBehaviour
    {
        [Header("诊断设置")]
        [Tooltip("检查间隔（秒）")]
        public float checkInterval = 1.0f;
        
        [Tooltip("显示详细日志")]
        public bool verboseLogging = true;
        
        private float _lastCheckTime;
        private HizSystem _hizSystem;
        
        private void Start()
        {
            _hizSystem = HizSystem.Instance;
            if (_hizSystem == null)
            {
                Debug.LogError("[HiZ Diagnostics] HizSystem 未找到!");
                return;
            }
            
            Debug.Log("[HiZ Diagnostics] 诊断工具已启动");
            Debug.Log($"[HiZ Diagnostics] 系统状态: {_hizSystem.State}");
            Debug.Log($"[HiZ Diagnostics] 是否激活: {_hizSystem.IsActive}");
        }
        
        private void Update()
        {
            if (Time.time - _lastCheckTime < checkInterval)
                return;
                
            _lastCheckTime = Time.time;
            
            if (_hizSystem == null || !_hizSystem.IsActive)
                return;
                
            RunDiagnostics();
        }
        
        [ContextMenu("运行诊断")]
        public void RunDiagnostics()
        {
            var depthPyramid = _hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
            {
                Debug.LogError("[HiZ Diagnostics] DepthPyramid 为 null");
                return;
            }
            
            var depthTexture = depthPyramid.DepthPyramidTexture;
            if (depthTexture == null)
            {
                Debug.LogError("[HiZ Diagnostics] DepthTexture 为 null");
                return;
            }
            
            Debug.Log("========== HiZ 深度金字塔诊断 ==========");
            Debug.Log($"纹理尺寸: {depthTexture.width}x{depthTexture.height}");
            Debug.Log($"纹理格式: {depthTexture.graphicsFormat}");
            Debug.Log($"Mip数量: {depthPyramid.MipCount}");
            Debug.Log($"基础尺寸: {depthPyramid.BaseSize}");
            
            // 检查每个 Mip 层级
            for (int mip = 0; mip < depthPyramid.MipCount; mip++)
            {
                CheckMipLevel(depthPyramid, mip);
            }
            
            Debug.Log("========== 诊断完成 ==========");
        }
        
        private void CheckMipLevel(HizDepthPyramid depthPyramid, int mipLevel)
        {
            var depthTexture = depthPyramid.DepthPyramidTexture;
            var mipSize = depthPyramid.GetMipSize(mipLevel);
            depthPyramid.GetMipCoord(mipLevel, out int srcX, out int srcY);
            
            // 创建临时纹理
            RenderTexture tempRT = new RenderTexture(mipSize.x, mipSize.y, 0, depthTexture.graphicsFormat);
            tempRT.Create();
            
            // 拷贝数据
            Graphics.CopyTexture(depthTexture, 0, 0, srcX, srcY, mipSize.x, mipSize.y, tempRT, 0, 0, 0, 0);
            
            // 读取数据
            RenderTexture.active = tempRT;
            Texture2D tex2D = new Texture2D(mipSize.x, mipSize.y, TextureFormat.RFloat, false);
            tex2D.ReadPixels(new Rect(0, 0, mipSize.x, mipSize.y), 0, 0);
            tex2D.Apply();
            RenderTexture.active = null;
            
            // 分析数据
            float[] pixels = tex2D.GetPixels().Select(c => c.r).ToArray();
            float minDepth = float.MaxValue;
            float maxDepth = float.MinValue;
            float sumDepth = 0;
            int nonZeroCount = 0;
            
            for (int i = 0; i < pixels.Length; i++)
            {
                float d = pixels[i];
                minDepth = Mathf.Min(minDepth, d);
                maxDepth = Mathf.Max(maxDepth, d);
                sumDepth += d;
                if (d > 0.001f) nonZeroCount++;
            }
            
            float avgDepth = pixels.Length > 0 ? sumDepth / pixels.Length : 0;
            
            Debug.Log($"Mip {mipLevel} ({mipSize.x}x{mipSize.y}) @ ({srcX},{srcY}):");
            Debug.Log($"  非零像素: {nonZeroCount}/{pixels.Length} ({100f * nonZeroCount / pixels.Length:F1}%)");
            Debug.Log($"  深度范围: [{minDepth:F6}, {maxDepth:F6}]");
            Debug.Log($"  平均深度: {avgDepth:F6}");
            
            // 采样中心点
            if (pixels.Length > 0)
            {
                int centerIdx = (mipSize.y / 2) * mipSize.x + (mipSize.x / 2);
                if (centerIdx < pixels.Length)
                {
                    Debug.Log($"  中心点深度: {pixels[centerIdx]:F6}");
                }
            }
            
            // 清理
            Destroy(tex2D);
            tempRT.Release();
            Destroy(tempRT);
        }
        
        private void OnGUI()
        {
            GUILayout.BeginArea(new Rect(10, 500, 250, 100));
            GUILayout.BeginVertical("box");
            
            GUILayout.Label("HiZ 深度金字塔诊断");
            
            if (GUILayout.Button("运行诊断"))
            {
                RunDiagnostics();
            }
            
            GUILayout.EndVertical();
            GUILayout.EndArea();
        }
    }
}

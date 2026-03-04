using UnityEngine;
using HiZTechnique;

namespace HiZTechnique.Debugger
{
    /// <summary>
    /// 验证HiZ坐标计算的一致性
    /// </summary>
    public class HiZCoordValidation : MonoBehaviour
    {
        [Header("测试设置")]
        public int baseWidth = 1024;
        public int baseHeight = 1024;
        public int mipCount = 8;
        
        [ContextMenu("验证坐标计算")]
        public void ValidateCoords()
        {
            Debug.Log("========== HiZ 坐标验证 ==========");
            Debug.Log($"基础尺寸: {baseWidth}x{baseHeight}");
            Debug.Log($"Mip数量: {mipCount}");
            
            // 计算总宽度
            int totalWidth = baseWidth;
            for (int i = 1; i < mipCount; i++)
            {
                totalWidth += Mathf.Max(1, baseWidth >> i);
            }
            Debug.Log($"纹理总宽度: {totalWidth}");
            
            // 验证每个 Mip 层级的坐标
            for (int mip = 0; mip < mipCount; mip++)
            {
                int mipW = Mathf.Max(1, baseWidth >> mip);
                int mipH = Mathf.Max(1, baseHeight >> mip);
                
                // 计算起始坐标
                int xOffset = 0;
                if (mip > 0)
                {
                    xOffset = baseWidth;
                    for (int i = 1; i < mip; i++)
                    {
                        xOffset += Mathf.Max(1, baseWidth >> i);
                    }
                }
                
                Debug.Log($"Mip {mip}: 大小={mipW}x{mipH}, 起始X={xOffset}, 结束X={xOffset + mipW}");
                
                // 验证不越界
                if (xOffset + mipW > totalWidth)
                {
                    Debug.LogError($"  ❌ Mip {mip} 越界!");
                }
                else
                {
                    Debug.Log($"  ✓ 坐标正确");
                }
            }
            
            Debug.Log("========== 验证完成 ==========");
        }
        
        [ContextMenu("与系统对比")]
        public void CompareWithSystem()
        {
            var hizSystem = HizSystem.Instance;
            if (hizSystem == null)
            {
                Debug.LogError("HizSystem 未找到");
                return;
            }
            
            var depthPyramid = hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
            {
                Debug.LogError("DepthPyramid 为 null");
                return;
            }
            
            Debug.Log("========== 与系统对比 ==========");
            Debug.Log($"系统基础尺寸: {depthPyramid.BaseSize}");
            Debug.Log($"系统 Mip 数量: {depthPyramid.MipCount}");
            
            var depthTexture = depthPyramid.DepthPyramidTexture;
            Debug.Log($"纹理实际尺寸: {depthTexture.width}x{depthTexture.height}");
            
            // 验证每个 Mip
            for (int mip = 0; mip < depthPyramid.MipCount; mip++)
            {
                var mipSize = depthPyramid.GetMipSize(mip);
                depthPyramid.GetMipCoord(mip, out int srcX, out int srcY);
                
                Debug.Log($"Mip {mip}: 系统计算的起始=({srcX},{srcY}), 大小={mipSize}");
            }
            
            Debug.Log("========== 对比完成 ==========");
        }
        
        private void OnGUI()
        {
            GUILayout.BeginArea(new Rect(10, 600, 250, 100));
            GUILayout.BeginVertical("box");
            
            GUILayout.Label("HiZ 坐标验证");
            
            if (GUILayout.Button("验证坐标计算"))
            {
                ValidateCoords();
            }
            
            if (GUILayout.Button("与系统对比"))
            {
                CompareWithSystem();
            }
            
            GUILayout.EndVertical();
            GUILayout.EndArea();
        }
    }
}

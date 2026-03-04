using UnityEngine;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ快速测试工具
    /// 用于验证深度金字塔的基本功能
    /// </summary>
    public class HiZQuickTest : MonoBehaviour
    {
        [Header("测试设置")]
        [Tooltip("基础尺寸")]
        public int baseWidth = 1024;
        public int baseHeight = 1024;
        
        [Tooltip("Mip层级数")]
        public int mipCount = 10;
        
        [ContextMenu("测试坐标计算")]
        void TestCoordCalculation()
        {
            Debug.Log($"=== 测试坐标计算 (Base: {baseWidth}x{baseHeight}) ===");
            
            for (int mip = 0; mip < mipCount; mip++)
            {
                // C# 计算
                GetMipCoordCS(mip, out int csX, out int csY);
                var csSize = GetMipSize(mip);
                
                // Shader 模拟计算
                GetMipCoordShader(mip, out int shaderX, out int shaderY);
                
                bool match = (csX == shaderX) && (csY == shaderY);
                string status = match ? "✓" : "✗ MISMATCH!";
                
                Debug.Log($"Mip {mip}: C#=({csX,5},{csY}) Shader=({shaderX,5},{shaderY}) {status} | 大小={csSize.x}x{csSize.y}");
            }
        }
        
        [ContextMenu("打印Shader公式")]
        void PrintShaderFormula()
        {
            Debug.Log(@"
=== Shader 坐标计算公式 ===

// 计算 Mip K 的起始 X 坐标 (K >= 1)
int GetMipStartX(int mipmapLevel, int baseWidth) {
    if (mipmapLevel == 0) return 0;
    
    int xOffset = baseWidth;  // Mip 0 的宽度
    for (int i = 1; i < mipmapLevel; i++) {
        xOffset += max(1, baseWidth >> i);
    }
    return xOffset;
}

// 示例: BaseWidth = 1024
// Mip 0: xOffset = 0
// Mip 1: xOffset = 1024
// Mip 2: xOffset = 1024 + 512 = 1536
// Mip 3: xOffset = 1024 + 512 + 256 = 1792
");
        }
        
        /// <summary>
        /// C# 版本的坐标计算
        /// </summary>
        void GetMipCoordCS(int mipLevel, out int startX, out int startY)
        {
            if (mipLevel == 0)
            {
                startX = 0;
                startY = 0;
                return;
            }
            
            int xOffset = baseWidth;
            for (int i = 1; i < mipLevel; i++)
            {
                xOffset += Mathf.Max(1, baseWidth >> i);
            }
            
            startX = xOffset;
            startY = 0;
        }
        
        /// <summary>
        /// 模拟Shader版本的坐标计算
        /// </summary>
        void GetMipCoordShader(int mipLevel, out int startX, out int startY)
        {
            // 直接翻译Shader代码到C#
            if (mipLevel == 0)
            {
                startX = 0;
                startY = 0;
                return;
            }
            
            int xOffset = baseWidth;
            for (int i = 1; i < mipLevel; i++)
            {
                xOffset += Mathf.Max(1, baseWidth >> i);
            }
            
            startX = xOffset;
            startY = 0;
        }
        
        Vector2Int GetMipSize(int mipLevel)
        {
            return new Vector2Int(
                Mathf.Max(1, baseWidth >> mipLevel),
                Mathf.Max(1, baseHeight >> mipLevel)
            );
        }
        
        void Start()
        {
            TestCoordCalculation();
        }
    }
}

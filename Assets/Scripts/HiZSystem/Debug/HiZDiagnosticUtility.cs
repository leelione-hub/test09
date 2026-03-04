using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEngine;
using UnityEngine.Rendering;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ诊断工具 - 用于验证坐标计算和深度金字塔内容
    /// </summary>
    public static class HiZDiagnosticUtility
    {
        /// <summary>
        /// 验证坐标计算的一致性
        /// </summary>
        public static string ValidateCoordCalculation(int baseWidth, int baseHeight, int mipCount)
        {
            var sb = new StringBuilder();
            sb.AppendLine($"=== HiZ 坐标计算验证 (Base: {baseWidth}x{baseHeight}, Mips: {mipCount}) ===");
            sb.AppendLine();
            
            // 打印每个mip层级的坐标
            sb.AppendLine("C# 坐标计算:");
            for (int i = 0; i < mipCount; i++)
            {
                GetMipCoordCS(baseWidth, i, out int startX, out int startY);
                var mipSize = GetMipSize(baseWidth, baseHeight, i);
                
                sb.AppendLine($"  Mip {i}: 起始=({startX,5}, {startY}), 大小={mipSize.x,4}x{mipSize.y}");
            }
            
            // 打印Shader公式
            sb.AppendLine();
            sb.AppendLine("Shader 公式:");
            sb.AppendLine("  // 计算 Mip K 的起始 X 坐标");
            sb.AppendLine("  int xOffset = baseWidth;  // Mip 0 宽度");
            sb.AppendLine("  for (int i = 1; i < mipmapLevel; i++) {");
            sb.AppendLine("      xOffset += max(1, baseWidth >> i);");
            sb.AppendLine("  }");
            
            // 打印示例计算
            sb.AppendLine();
            sb.AppendLine("示例计算 (Mip 2):");
            sb.AppendLine($"  xOffset = {baseWidth} + ({baseWidth} >> 1) = {baseWidth} + {baseWidth >> 1} = {baseWidth + (baseWidth >> 1)}");
            
            return sb.ToString();
        }
        
        /// <summary>
        /// C# 版本的 GetMipCoord
        /// </summary>
        private static void GetMipCoordCS(int baseWidth, int mipLevel, out int startX, out int startY)
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
        /// 获取mip层级尺寸
        /// </summary>
        private static Vector2Int GetMipSize(int baseWidth, int baseHeight, int mipLevel)
        {
            return new Vector2Int(
                Mathf.Max(1, baseWidth >> mipLevel),
                Mathf.Max(1, baseHeight >> mipLevel)
            );
        }
        
        /// <summary>
        /// 分析深度金字塔内容
        /// </summary>
        public static IEnumerator AnalyzeDepthPyramid(
            RenderTexture depthPyramid, 
            int baseWidth, 
            int baseHeight, 
            int mipCount,
            System.Action<string> onResult)
        {
            if (depthPyramid == null)
            {
                onResult?.Invoke("深度金字塔纹理为空");
                yield break;
            }
            
            var sb = new StringBuilder();
            sb.AppendLine($"=== 深度金字塔内容分析 ({baseWidth}x{baseHeight}, {mipCount} mips) ===");
            sb.AppendLine($"纹理尺寸: {depthPyramid.width}x{depthPyramid.height}");
            sb.AppendLine($"格式: {depthPyramid.format}");
            sb.AppendLine();
            
            // 创建临时纹理用于读取
            var tempTex = new Texture2D(depthPyramid.width, depthPyramid.height, 
                TextureFormat.RFloat, false);
            
            // 异步读取
            var request = AsyncGPUReadback.Request(depthPyramid, 0);
            while (!request.done)
            {
                yield return null;
            }
            
            if (request.hasError)
            {
                onResult?.Invoke("GPU读取失败");
                Object.Destroy(tempTex);
                yield break;
            }
            
            // 获取数据
            var data = request.GetData<float>();
            tempTex.LoadRawTextureData(data);
            tempTex.Apply();
            
            // 分析每个mip层级
            for (int mip = 0; mip < mipCount; mip++)
            {
                GetMipCoordCS(baseWidth, mip, out int startX, out int startY);
                var mipSize = GetMipSize(baseWidth, baseHeight, mip);
                
                // 采样该mip层级的像素
                var samples = new List<float>();
                int sampleCount = Mathf.Min(100, mipSize.x * mipSize.y);
                
                for (int i = 0; i < sampleCount; i++)
                {
                    int x = startX + (i % mipSize.x);
                    int y = startY + (i / mipSize.x);
                    
                    if (x < depthPyramid.width && y < depthPyramid.height)
                    {
                        samples.Add(tempTex.GetPixel(x, y).r);
                    }
                }
                
                if (samples.Count > 0)
                {
                    float minVal = samples.Min();
                    float maxVal = samples.Max();
                    float avgVal = samples.Average();
                    int zeroCount = samples.Count(v => v == 0);
                    int oneCount = samples.Count(v => v == 1);
                    
                    sb.AppendLine($"Mip {mip}: 范围=[{minVal:F6}, {maxVal:F6}], 均值={avgVal:F6}, " +
                                  $"零值={zeroCount}/{samples.Count}, 一值={oneCount}/{samples.Count}");
                }
                else
                {
                    sb.AppendLine($"Mip {mip}: 无法采样");
                }
            }
            
            Object.Destroy(tempTex);
            onResult?.Invoke(sb.ToString());
        }
        
        /// <summary>
        /// 创建可视化纹理
        /// </summary>
        public static IEnumerator CreateVisualizationTexture(
            RenderTexture depthPyramid,
            int baseWidth,
            int baseHeight,
            int mipCount,
            System.Action<Texture2D> onResult)
        {
            // 创建输出纹理
            var visTex = new Texture2D(depthPyramid.width, depthPyramid.height, TextureFormat.RGBA32, false);
            
            // 清空为黑色
            var clearColors = new Color[depthPyramid.width * depthPyramid.height];
            for (int i = 0; i < clearColors.Length; i++)
                clearColors[i] = Color.black;
            visTex.SetPixels(clearColors);
            
            // 异步读取
            var request = AsyncGPUReadback.Request(depthPyramid, 0);
            while (!request.done)
            {
                yield return null;
            }
            
            if (request.hasError)
            {
                onResult?.Invoke(null);
                yield break;
            }
            
            // 获取数据
            var data = request.GetData<float>();
            
            // 为每个mip层级使用不同颜色
            Color[] mipColors = { Color.red, Color.green, Color.blue, Color.yellow, Color.cyan, Color.magenta };
            
            // 填充每个mip层级的区域
            for (int mip = 0; mip < mipCount; mip++)
            {
                GetMipCoordCS(baseWidth, mip, out int startX, out int startY);
                var mipSize = GetMipSize(baseWidth, baseHeight, mip);
                Color mipColor = mipColors[mip % mipColors.Length];
                
                for (int y = 0; y < mipSize.y; y++)
                {
                    for (int x = 0; x < mipSize.x; x++)
                    {
                        int texX = startX + x;
                        int texY = startY + y;
                        
                        if (texX < depthPyramid.width && texY < depthPyramid.height)
                        {
                            // 读取深度值
                            int index = texY * depthPyramid.width + texX;
                            float depth = data[index];
                            
                            // 将深度值映射到颜色亮度
                            Color pixelColor = mipColor * (1 - depth);
                            visTex.SetPixel(texX, texY, pixelColor);
                        }
                    }
                }
            }
            
            visTex.Apply();
            onResult?.Invoke(visTex);
        }
    }
}

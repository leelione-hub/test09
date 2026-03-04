using UnityEngine;
using HiZTechnique;

namespace HiZTechnique.Examples
{
    /// <summary>
    /// HiZ剔除简单测试
    /// 创建一个测试对象并检查是否被正确剔除
    /// </summary>
    public class HiZCullingTest : MonoBehaviour
    {
        [Header("测试设置")]
        [Tooltip("测试对象位置")]
        public Vector3 testPosition = new Vector3(0, 0, 20);
        
        [Tooltip("测试对象大小")]
        public Vector3 testExtents = new Vector3(2, 2, 2);
        
        [Tooltip("是否在相机后面")]
        public bool placeBehindCamera = false;
        
        [Tooltip("是否在遮挡物后面")]
        public bool placeBehindOccluder = true;
        
        private void OnDrawGizmos()
        {
            // 绘制测试包围盒
            Gizmos.color = Color.yellow;
            Gizmos.DrawWireCube(testPosition, testExtents * 2);
            
            // 绘制标签
            #if UNITY_EDITOR
            UnityEditor.Handles.Label(testPosition + Vector3.up * 3, "HiZ Test Object");
            #endif
        }
        
        [ContextMenu("运行HiZ测试")]
        public void RunTest()
        {
            var hizSystem = HiZTechnique.HizSystem.Instance;
            if (hizSystem == null)
            {
                Debug.LogError("[HiZ Test] HiZSystem 未找到!");
                return;
            }
            
            if (!hizSystem.IsActive)
            {
                Debug.LogError("[HiZ Test] HiZSystem 未激活!");
                return;
            }
            
            var camera = Camera.main;
            if (camera == null)
            {
                Debug.LogError("[HiZ Test] 主相机未找到!");
                return;
            }
            
            // 计算 VP 矩阵
            Matrix4x4 vp = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false) * 
                          camera.worldToCameraMatrix;
            
            // 测试位置
            Vector3 center = testPosition;
            Vector3 extents = testExtents;
            
            Debug.Log($"========== HiZ 剔除测试 ==========");
            Debug.Log($"测试对象位置: {center}");
            Debug.Log($"测试对象大小: {extents}");
            Debug.Log($"相机位置: {camera.transform.position}");
            Debug.Log($"相机朝向: {camera.transform.forward}");
            
            // 计算到相机的距离
            float distanceToCamera = Vector3.Distance(center, camera.transform.position);
            Debug.Log($"到相机距离: {distanceToCamera:F2}");
            
            // 计算 8 个角点在裁剪空间的坐标
            Vector3[] corners = new Vector3[8];
            int idx = 0;
            for (int x = -1; x <= 1; x += 2)
            {
                for (int y = -1; y <= 1; y += 2)
                {
                    for (int z = -1; z <= 1; z += 2)
                    {
                        corners[idx++] = center + new Vector3(x * extents.x, y * extents.y, z * extents.z);
                    }
                }
            }
            
            // 计算屏幕空间包围盒
            Vector2 minUV = new Vector2(float.MaxValue, float.MaxValue);
            Vector2 maxUV = new Vector2(float.MinValue, float.MinValue);
            float minZ = float.MaxValue;
            float maxZ = float.MinValue;
            bool anyInFront = false;
            
            foreach (var corner in corners)
            {
                Vector4 clipPos = vp * new Vector4(corner.x, corner.y, corner.z, 1);
                
                if (clipPos.w <= 0)
                    continue;
                
                anyInFront = true;
                
                clipPos.x /= clipPos.w;
                clipPos.y /= clipPos.w;
                clipPos.z /= clipPos.w;
                
                Vector2 uv = new Vector2(clipPos.x * 0.5f + 0.5f, clipPos.y * 0.5f + 0.5f);
                float depth = clipPos.z * 0.5f + 0.5f;
                
                minUV = Vector2.Min(minUV, uv);
                maxUV = Vector2.Max(maxUV, uv);
                minZ = Mathf.Min(minZ, depth);
                maxZ = Mathf.Max(maxZ, depth);
                
                Debug.Log($"  角点: {corner} -> UV: {uv}, Depth: {depth:F6}");
            }
            
            if (!anyInFront)
            {
                Debug.Log("结果: 对象在相机后面，应该被剔除");
                return;
            }
            
            Debug.Log($"屏幕空间包围盒:");
            Debug.Log($"  MinUV: {minUV}, MaxUV: {maxUV}");
            Debug.Log($"  MinZ: {minZ:F6}, MaxZ: {maxZ:F6}");
            Debug.Log($"  包围盒大小: {maxUV - minUV}");
            
            // 检查是否在屏幕内
            if (maxUV.x < 0 || minUV.x > 1 || maxUV.y < 0 || minUV.y > 1)
            {
                Debug.Log("结果: 对象在屏幕外，应该被视锥体剔除");
                return;
            }
            
            // 获取深度金字塔
            var depthPyramid = hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
            {
                Debug.LogError("[HiZ Test] DepthPyramid 为 null");
                return;
            }
            
            // 异步读取深度并比较
            StartCoroutine(CompareDepthAsync(minUV, maxUV, minZ, maxZ));
        }
        
        private System.Collections.IEnumerator CompareDepthAsync(Vector2 minUV, Vector2 maxUV, float minZ, float maxZ)
        {
            var depthPyramid = HiZTechnique.HizSystem.Instance.GetDepthPyramid();
            
            // 计算 Mip 级别
            Vector2 boundsSize = maxUV - minUV;
            float maxSize = Mathf.Max(boundsSize.x, boundsSize.y);
            int mipLevel = 0;
            
            if (maxSize > 0.0001f)
            {
                int targetTexelCount = Mathf.NextPowerOfTwo(Mathf.RoundToInt(1.0f / maxSize));
                int mipmapPower2 = Mathf.RoundToInt(Mathf.Log(Mathf.Min(depthPyramid.BaseSize.x, depthPyramid.BaseSize.y), 2));
                int expectedPower2 = Mathf.RoundToInt(Mathf.Log(targetTexelCount, 2));
                mipLevel = Mathf.Clamp(mipmapPower2 - expectedPower2, 0, depthPyramid.MipCount - 1);
            }
            
            Debug.Log($"选择 Mip 级别: {mipLevel}");
            
            depthPyramid.GetMipCoord(mipLevel, out int srcX, out int srcY);
            var mipSize = depthPyramid.GetMipSize(mipLevel);
            
            Debug.Log($"Mip 信息: 起始=({srcX},{srcY}), 大小={mipSize}");
            
            // 创建临时纹理（使用与源纹理相同的格式）
            var sourceTexture = depthPyramid.DepthPyramidTexture;
            Debug.Log($"源纹理信息: {sourceTexture.width}x{sourceTexture.height}, Format: {sourceTexture.graphicsFormat}");
            
            RenderTexture tempRT = new RenderTexture(mipSize.x, mipSize.y, 0, sourceTexture.graphicsFormat);
            tempRT.Create();
            
            // 拷贝数据
            Debug.Log($"拷贝区域: 源=({srcX},{srcY}, {mipSize.x}x{mipSize.y}) -> 目标=(0,0)");
            Graphics.CopyTexture(sourceTexture, 0, 0, srcX, srcY, mipSize.x, mipSize.y, tempRT, 0, 0, 0, 0);
            
            // 异步读取
            var request = UnityEngine.Rendering.AsyncGPUReadback.Request(tempRT, 0);
            yield return new WaitUntil(() => request.done);
            
            if (!request.hasError)
            {
                var data = request.GetData<float>();
                
                // 采样 4 个角点
                Vector2[] sampleUVs = new Vector2[] { minUV, new Vector2(minUV.x, maxUV.y), 
                                                     new Vector2(maxUV.x, minUV.y), maxUV };
                
                float maxOccluderDepth = float.MinValue;
                float minOccluderDepth = float.MaxValue;
                int nonZeroCount = 0;
                
                // 先统计整个纹理
                for (int i = 0; i < data.Length; i++)
                {
                    float d = data[i];
                    if (d > 0.001f) nonZeroCount++;
                    maxOccluderDepth = Mathf.Max(maxOccluderDepth, d);
                    minOccluderDepth = Mathf.Min(minOccluderDepth, d);
                }
                
                Debug.Log($"纹理统计: 非零像素={nonZeroCount}/{data.Length}, 最小深度={minOccluderDepth:F6}, 最大深度={maxOccluderDepth:F6}");
                
                // 重置并采样4个角点
                maxOccluderDepth = float.MinValue;
                Debug.Log("采样 4 个角点:");
                
                for (int i = 0; i < 4; i++)
                {
                    int x = Mathf.Clamp(Mathf.RoundToInt(sampleUVs[i].x * mipSize.x), 0, mipSize.x - 1);
                    int y = Mathf.Clamp(Mathf.RoundToInt(sampleUVs[i].y * mipSize.y), 0, mipSize.y - 1);
                    int idx = y * mipSize.x + x;
                    
                    if (idx < data.Length)
                    {
                        float depth = data[idx];
                        maxOccluderDepth = Mathf.Max(maxOccluderDepth, depth);
                        Debug.Log($"  角点 {i} ({x},{y}): HiZ深度={depth:F6}");
                    }
                }
                
                Debug.Log($"遮挡者最大深度: {maxOccluderDepth:F6}");
                Debug.Log($"物体深度范围: [{minZ:F6}, {maxZ:F6}]");
                
                // 判断剔除
                bool usesReversedZ = HizPlatformCompatibility.UsesReversedZ();
                Debug.Log($"使用 Reversed Z: {usesReversedZ}");
                
                bool shouldCull;
                if (usesReversedZ)
                {
                    // Reversed Z: 0=远, 1=近
                    // 如果物体的最近深度（maxZ）小于遮挡者的最远深度，则被遮挡
                    shouldCull = maxZ < maxOccluderDepth;
                    Debug.Log($"Reversed Z 比较: {maxZ:F6} < {maxOccluderDepth:F6} = {shouldCull}");
                }
                else
                {
                    // 正常 Z: 0=近, 1=远
                    // 如果物体的最远深度（minZ）大于遮挡者的最远深度，则被遮挡
                    shouldCull = minZ > maxOccluderDepth;
                    Debug.Log($"正常 Z 比较: {minZ:F6} > {maxOccluderDepth:F6} = {shouldCull}");
                }
                
                Debug.Log($"最终结果: {(shouldCull ? "应该被剔除" : "可见")}");
            }
            else
            {
                Debug.LogError("读取深度数据失败");
            }
            
            tempRT.Release();
            Destroy(tempRT);
            
            Debug.Log("========== 测试结束 ==========");
        }
        
        private void OnGUI()
        {
            GUILayout.BeginArea(new Rect(10, 400, 250, 100));
            GUILayout.BeginVertical("box");
            
            GUILayout.Label("HiZ 剔除测试");
            
            if (GUILayout.Button("运行测试"))
            {
                RunTest();
            }
            
            GUILayout.EndVertical();
            GUILayout.EndArea();
        }
    }
}

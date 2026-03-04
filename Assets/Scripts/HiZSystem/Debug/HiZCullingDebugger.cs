using Extension;
using UnityEngine;
using UnityEngine.Rendering;
using HiZTechnique;

namespace HiZTechnique.Debugger
{
    /// <summary>
    /// HiZ剔除调试器
    /// 用于排查HiZ剔除不工作的问题
    /// </summary>
    public class HiZCullingDebugger : MonoBehaviour
    {
        [Header("调试设置")]
        [Tooltip("启用详细日志")]
        public bool enableVerboseLogging = true;
        
        [Tooltip("显示深度金字塔可视化")]
        public bool showDepthPyramid = false;
        
        [Tooltip("测试对象的世界坐标")]
        public Vector3 testObjectPosition = new Vector3(0, 0, 10);
        
        [Tooltip("测试对象的包围盒大小")]
        public Vector3 testObjectExtents = new Vector3(1, 1, 1);
        
        [Header("深度金字塔检查")]
        [Tooltip("要检查的Mip级别")]
        [Range(0, 10)]
        public int checkMipLevel = 0;
        
        [Tooltip("检查位置(UV坐标)")]
        public Vector2 checkUV = new Vector2(0.5f, 0.5f);
        
        private HizSystem _hizSystem;
        private Camera _mainCamera;
        private ComputeBuffer _debugTestedCount;
        private ComputeBuffer _debugCulledCount;
        private uint[] _testedCount = new uint[1];
        private uint[] _culledCount = new uint[1];
        
        private void Start()
        {
            _hizSystem = HizSystem.Instance;
            _mainCamera = Camera.main;
            
            if (_hizSystem == null)
            {
                UnityEngine.Debug.LogError("[HiZ Debugger] HiZSystem 未找到!");
                return;
            }
            
            // 创建调试计数器
            _debugTestedCount = new ComputeBuffer(1, sizeof(uint));
            _debugCulledCount = new ComputeBuffer(1, sizeof(uint));
            _debugTestedCount.SetData(new uint[] { 0 });
            _debugCulledCount.SetData(new uint[] { 0 });
        }
        
        private void OnDestroy()
        {
            _debugTestedCount?.Release();
            _debugCulledCount?.Release();
        }
        
        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.F5))
            {
                RunDiagnostics();
            }
            
            if (Input.GetKeyDown(KeyCode.F6))
            {
                TestSingleObject();
            }
            
            if (showDepthPyramid)
            {
                VisualizeDepthPyramid();
            }
        }
        
        /// <summary>
        /// 运行全面诊断
        /// </summary>
        [ContextMenu("运行诊断")]
        public void RunDiagnostics()
        {
            UnityEngine.Debug.Log("========== HiZ 剔除诊断 ==========");
            
            // 1. 检查 HiZ 系统状态
            if (_hizSystem == null)
            {
                UnityEngine.Debug.LogError("❌ HiZSystem 为 null");
                return;
            }
            
            UnityEngine.Debug.Log($"✓ HiZSystem 状态: {_hizSystem.State}");
            UnityEngine.Debug.Log($"✓ HiZSystem 激活: {_hizSystem.IsActive}");
            
            // 2. 检查深度金字塔
            var depthPyramid = _hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
            {
                UnityEngine.Debug.LogError("❌ DepthPyramid 为 null");
                return;
            }
            
            var depthTexture = depthPyramid.DepthPyramidTexture;
            if (depthTexture == null)
            {
                UnityEngine.Debug.LogError("❌ DepthTexture 为 null");
                return;
            }
            
            UnityEngine.Debug.Log($"✓ DepthTexture: {depthTexture.width}x{depthTexture.height}");
            UnityEngine.Debug.Log($"✓ MipCount: {depthPyramid.MipCount}");
            UnityEngine.Debug.Log($"✓ BaseSize: {depthPyramid.BaseSize}");
            
            // 3. 检查相机
            if (_mainCamera == null)
            {
                UnityEngine.Debug.LogError("❌ 主相机为 null");
                return;
            }
            
            UnityEngine.Debug.Log($"✓ 相机位置: {_mainCamera.transform.position}");
            UnityEngine.Debug.Log($"✓ 相机朝向: {_mainCamera.transform.forward}");
            UnityEngine.Debug.Log($"✓ 使用 Reversed Z: {HizPlatformCompatibility.UsesReversedZ()}");
            
            // 4. 检查深度纹理内容
            StartCoroutine(CheckDepthTextureContent());
            
            UnityEngine.Debug.Log("========== 诊断完成 ==========");
        }
        
        /// <summary>
        /// 测试单个对象的剔除
        /// </summary>
        [ContextMenu("测试单个对象")]
        public void TestSingleObject()
        {
            UnityEngine.Debug.Log("========== 测试单个对象 ==========");
            
            if (_hizSystem == null || !_hizSystem.IsActive)
            {
                UnityEngine.Debug.LogError("HiZSystem 未激活");
                return;
            }
            
            var depthPyramid = _hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
            {
                UnityEngine.Debug.LogError("DepthPyramid 为 null");
                return;
            }
            
            // 计算测试对象的屏幕空间包围盒
            Matrix4x4 vp = GL.GetGPUProjectionMatrix(_mainCamera.projectionMatrix, false) * 
                          _mainCamera.worldToCameraMatrix;
            
            Vector3 center = testObjectPosition;
            Vector3 extents = testObjectExtents;
            
            // 8个角点
            Vector3[] corners = new Vector3[8];
            int idx = 0;
            for (int x = -1; x <= 1; x += 2)
            {
                for (int y = -1; y <= 1; y += 2)
                {
                    for (int z = -1; z <= 1; z += 2)
                    {
                        corners[idx++] = center + new Vector3(x, y, z).Multiply(extents);
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
            }
            
            if (!anyInFront)
            {
                UnityEngine.Debug.Log("对象在相机后面");
                return;
            }
            
            UnityEngine.Debug.Log($"屏幕空间包围盒:");
            UnityEngine.Debug.Log($"  MinUV: {minUV}, MaxUV: {maxUV}");
            UnityEngine.Debug.Log($"  MinZ: {minZ}, MaxZ: {maxZ}");
            UnityEngine.Debug.Log($"  大小: {maxUV - minUV}");
            
            // 计算Mip级别
            Vector2 boundsSize = maxUV - minUV;
            int mipLevel = CalculateMipLevel(boundsSize, depthPyramid.BaseSize);
            UnityEngine.Debug.Log($"计算的 Mip 级别: {mipLevel}");
            
            // 采样深度金字塔
            StartCoroutine(SampleDepthPyramid(minUV, maxUV, mipLevel));
        }
        
        /// <summary>
        /// 可视化深度金字塔
        /// </summary>
        private void VisualizeDepthPyramid()
        {
            // 在 Scene 视图中绘制深度金字塔的边界
            var depthPyramid = _hizSystem?.GetDepthPyramid();
            if (depthPyramid == null) return;
            
            var baseSize = depthPyramid.BaseSize;
            
            // 绘制 Mip 0 区域
            Gizmos.color = Color.green;
            Gizmos.DrawWireCube(new Vector3(baseSize.x / 2, baseSize.y / 2, 0), 
                               new Vector3(baseSize.x, baseSize.y, 0));
            
            // 绘制其他 Mip 层级
            float xOffset = baseSize.x;
            for (int i = 1; i < depthPyramid.MipCount; i++)
            {
                int mipWidth = Mathf.Max(1, baseSize.x >> i);
                int mipHeight = Mathf.Max(1, baseSize.y >> i);
                
                Gizmos.color = Color.Lerp(Color.green, Color.red, i / (float)depthPyramid.MipCount);
                Gizmos.DrawWireCube(new Vector3(xOffset + mipWidth / 2, mipHeight / 2, 0),
                                   new Vector3(mipWidth, mipHeight, 0));
                
                xOffset += mipWidth;
            }
        }
        
        private System.Collections.IEnumerator CheckDepthTextureContent()
        {
            var depthPyramid = _hizSystem.GetDepthPyramid();
            var depthTexture = depthPyramid.DepthPyramidTexture;
            
            // 异步读取深度纹理
            var request = UnityEngine.Rendering.AsyncGPUReadback.Request(depthTexture, 0);
            yield return new WaitUntil(() => request.done);
            
            if (request.hasError)
            {
                UnityEngine.Debug.LogError("读取深度纹理失败");
                yield break;
            }
            
            var data = request.GetData<float>();
            if (data.Length == 0)
            {
                UnityEngine.Debug.LogError("深度纹理数据为空");
                yield break;
            }
            
            // 统计深度值
            float minDepth = float.MaxValue;
            float maxDepth = float.MinValue;
            float sumDepth = 0;
            int zeroCount = 0;
            int oneCount = 0;
            
            for (int i = 0; i < data.Length; i++)
            {
                float depth = data[i];
                minDepth = Mathf.Min(minDepth, depth);
                maxDepth = Mathf.Max(maxDepth, depth);
                sumDepth += depth;
                
                if (depth < 0.001f) zeroCount++;
                if (depth > 0.999f) oneCount++;
            }
            
            float avgDepth = sumDepth / data.Length;
            
            UnityEngine.Debug.Log($"深度纹理统计:");
            UnityEngine.Debug.Log($"  最小值: {minDepth:F6}");
            UnityEngine.Debug.Log($"  最大值: {maxDepth:F6}");
            UnityEngine.Debug.Log($"  平均值: {avgDepth:F6}");
            UnityEngine.Debug.Log($"  接近0的像素: {zeroCount} ({100f * zeroCount / data.Length:F1}%)");
            UnityEngine.Debug.Log($"  接近1的像素: {oneCount} ({100f * oneCount / data.Length:F1}%)");
            
            if (maxDepth < 0.001f)
            {
                UnityEngine.Debug.LogError("❌ 深度纹理全为0！检查相机深度图是否正确生成");
            }
            else if (avgDepth < 0.01f)
            {
                UnityEngine.Debug.LogWarning("⚠️ 深度纹理平均值过低，可能大部分区域没有深度信息");
            }
            else
            {
                UnityEngine.Debug.Log("✓ 深度纹理内容正常");
            }
        }
        
        private System.Collections.IEnumerator SampleDepthPyramid(Vector2 minUV, Vector2 maxUV, int mipLevel)
        {
            var depthPyramid = _hizSystem.GetDepthPyramid();
            var depthTexture = depthPyramid.DepthPyramidTexture;
            
            depthPyramid.GetMipCoord(mipLevel, out int srcX, out int srcY);
            var mipSize = depthPyramid.GetMipSize(mipLevel);
            
            UnityEngine.Debug.Log($"采样 Mip {mipLevel}:");
            UnityEngine.Debug.Log($"  纹理坐标: ({srcX}, {srcY})");
            UnityEngine.Debug.Log($"  Mip 尺寸: {mipSize.x}x{mipSize.y}");
            
            // 创建临时纹理读取数据
            RenderTexture tempRT = new RenderTexture(mipSize.x, mipSize.y, 0, RenderTextureFormat.RFloat);
            tempRT.Create();
            
            Graphics.CopyTexture(depthTexture, 0, 0, srcX, srcY, mipSize.x, mipSize.y, tempRT, 0, 0, 0, 0);
            
            var request = UnityEngine.Rendering.AsyncGPUReadback.Request(tempRT, 0);
            yield return new WaitUntil(() => request.done);
            
            if (!request.hasError)
            {
                var data = request.GetData<float>();
                
                // 采样4个角点
                Vector2[] sampleUVs = new Vector2[] { minUV, new Vector2(minUV.x, maxUV.y), 
                                                     new Vector2(maxUV.x, minUV.y), maxUV };
                
                UnityEngine.Debug.Log("采样深度值:");
                for (int i = 0; i < 4; i++)
                {
                    int x = Mathf.Clamp(Mathf.RoundToInt(sampleUVs[i].x * mipSize.x), 0, mipSize.x - 1);
                    int y = Mathf.Clamp(Mathf.RoundToInt(sampleUVs[i].y * mipSize.y), 0, mipSize.y - 1);
                    int idx = y * mipSize.x + x;
                    
                    if (idx < data.Length)
                    {
                        UnityEngine.Debug.Log($"  角点 {i} ({x},{y}): {data[idx]:F6}");
                    }
                }
                
                // 找到最大深度（遮挡者深度）
                float maxDepth = float.MinValue;
                for (int i = 0; i < data.Length; i++)
                {
                    maxDepth = Mathf.Max(maxDepth, data[i]);
                }
                UnityEngine.Debug.Log($"  该区域的遮挡者深度: {maxDepth:F6}");
            }
            
            tempRT.Release();
            Destroy(tempRT);
        }
        
        private int CalculateMipLevel(Vector2 boundsSize, Vector2Int baseSize)
        {
            float maxSize = Mathf.Max(boundsSize.x, boundsSize.y);
            if (maxSize <= 0.0001f) return 0;
            
            int targetTexelCount = Mathf.NextPowerOfTwo(Mathf.RoundToInt(1.0f / maxSize));
            int mipmapPower2 = Mathf.RoundToInt(Mathf.Log(Mathf.Min(baseSize.x, baseSize.y), 2));
            int expectedPower2 = Mathf.RoundToInt(Mathf.Log(targetTexelCount, 2));
            
            return Mathf.Clamp(mipmapPower2 - expectedPower2, 0, 10);
        }
        
        private void OnGUI()
        {
            GUILayout.BeginArea(new Rect(10, 300, 300, 150));
            GUILayout.BeginVertical("box");
            
            GUILayout.Label("HiZ 剔除调试器");
            
            if (GUILayout.Button("运行诊断 (F5)"))
            {
                RunDiagnostics();
            }
            
            if (GUILayout.Button("测试单个对象 (F6)"))
            {
                TestSingleObject();
            }
            
            showDepthPyramid = GUILayout.Toggle(showDepthPyramid, "显示深度金字塔");
            
            GUILayout.EndVertical();
            GUILayout.EndArea();
        }
    }
}

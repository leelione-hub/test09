using UnityEngine;
using UnityEngine.Rendering;
using HiZTechnique;

namespace HiZTechnique.Examples
{
    /// <summary>
    /// HiZ深度金字塔拷贝示例
    /// 展示如何正确地将HiZ深度金字塔数据拷贝到自定义RenderTexture
    /// </summary>
    public class HiZDepthPyramidCopyExample : MonoBehaviour
    {
        [Header("目标纹理设置")]
        [Tooltip("是否创建自动mipmap链的目标纹理")]
        [SerializeField]
        private bool _createAutoMipmapTexture = true;
        
        [Tooltip("手动管理的mipmap纹理数组（每个元素是一个层级）")]
        [SerializeField]
        private RenderTexture[] _manualMipTextures;
        
        [Tooltip("自动mipmap纹理（使用Unity自动mipmap链）")]
        [SerializeField]
        private RenderTexture _autoMipmapTexture;
        
        // 缓存
        private HizDepthPyramid _depthPyramid;
        private CommandBuffer _cmd;
        
        private void OnEnable()
        {
            _cmd = new CommandBuffer();
            _cmd.name = "HiZ Copy Example";
        }
        
        private void OnDisable()
        {
            _cmd?.Dispose();
            _cmd = null;
        }
        
        /// <summary>
        /// 方式1：拷贝所有mip层级到手动管理的纹理数组
        /// 每个纹理包含一个mip层级的数据
        /// </summary>
        public void CopyToManualTextures()
        {
            var hizSystem = HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
            {
                Debug.LogWarning("[HiZ Example] HiZ系统未激活");
                return;
            }
            
            var depthPyramid = hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
            {
                Debug.LogWarning("[HiZ Example] 深度金字塔为空");
                return;
            }
            
            var sourceTexture = depthPyramid.DepthPyramidTexture;
            if (sourceTexture == null)
            {
                Debug.LogError("[HiZ Example] 源深度纹理为空");
                return;
            }
            
            int mipCount = depthPyramid.MipCount;
            var baseSize = depthPyramid.BaseSize;
            
            Debug.Log($"[HiZ Example] 源纹理: {sourceTexture.width}x{sourceTexture.height}, Format: {sourceTexture.graphicsFormat}");
            Debug.Log($"[HiZ Example] 开始拷贝，Mip数量: {mipCount}, 基础尺寸: {baseSize.x}x{baseSize.y}");
            
            // 确保纹理数组足够大
            if (_manualMipTextures == null || _manualMipTextures.Length != mipCount)
            {
                // 清理旧纹理
                if (_manualMipTextures != null)
                {
                    foreach (var rt in _manualMipTextures)
                    {
                        if (rt != null)
                            rt.Release();
                    }
                }
                
                _manualMipTextures = new RenderTexture[mipCount];
            }
            
            // 立即执行拷贝（不在CommandBuffer中）
            for (int i = 0; i < mipCount; i++)
            {
                var mipSize = depthPyramid.GetMipSize(i);
                depthPyramid.GetMipCoord(i, out int srcX, out int srcY);
                
                // 创建或重建纹理
                if (_manualMipTextures[i] == null || 
                    _manualMipTextures[i].width != mipSize.x || 
                    _manualMipTextures[i].height != mipSize.y)
                {
                    if (_manualMipTextures[i] != null)
                        _manualMipTextures[i].Release();
                    
                    // 使用与源纹理相同的格式
                    _manualMipTextures[i] = new RenderTexture(mipSize.x, mipSize.y, 0, sourceTexture.graphicsFormat)
                    {
                        name = $"HiZ_Mip_{i}",
                        filterMode = FilterMode.Point,
                        wrapMode = TextureWrapMode.Clamp
                    };
                    _manualMipTextures[i].Create();
                    
                    Debug.Log($"[HiZ Example] 创建纹理 {i}: {mipSize.x}x{mipSize.y}, 源位置: ({srcX},{srcY})");
                }
                
                // 使用 Graphics.CopyTexture 直接拷贝
                Graphics.CopyTexture(
                    sourceTexture, 0, 0, srcX, srcY, mipSize.x, mipSize.y,
                    _manualMipTextures[i], 0, 0, 0, 0
                );
            }
            
            Debug.Log($"[HiZ Example] 已拷贝 {mipCount} 个mip层级到手动纹理数组");
            
            // 验证数据
            StartCoroutine(VerifyCopiedData());
        }
        
        private System.Collections.IEnumerator VerifyCopiedData()
        {
            yield return new WaitForEndOfFrame();
            
            if (_manualMipTextures != null && _manualMipTextures.Length > 0 && _manualMipTextures[0] != null)
            {
                // 异步读取像素数据验证
                var request = UnityEngine.Rendering.AsyncGPUReadback.Request(_manualMipTextures[0], 0);
                yield return new WaitUntil(() => request.done);
                
                if (!request.hasError)
                {
                    var data = request.GetData<float>();
                    if (data.Length > 0)
                    {
                        float firstPixel = data[0];
                        Debug.Log($"[HiZ Example] Mip 0 第一个像素值: {firstPixel}");
                        
                        if (firstPixel <= 0.001f)
                        {
                            Debug.LogWarning("[HiZ Example] 像素值接近0，可能数据未正确拷贝！");
                        }
                    }
                }
            }
        }
        
        /// <summary>
        /// 方式2：拷贝所有mip层级到自动mipmap纹理
        /// 这个纹理使用Unity的自动mipmap链
        /// </summary>
        public void CopyToAutoMipmapTexture()
        {
            var hizSystem = HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
                return;
            
            var depthPyramid = hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
                return;
            
            var baseSize = depthPyramid.BaseSize;
            int mipCount = depthPyramid.MipCount;
            
            // 创建或重建目标纹理
            if (_autoMipmapTexture == null ||
                _autoMipmapTexture.width != baseSize.x ||
                _autoMipmapTexture.height != baseSize.y ||
                _autoMipmapTexture.mipmapCount != mipCount)
            {
                if (_autoMipmapTexture != null)
                    _autoMipmapTexture.Release();
                
                _autoMipmapTexture = new RenderTexture(baseSize.x, baseSize.y, 0, RenderTextureFormat.RFloat, mipCount)
                {
                    name = "HiZ_AutoMipmap",
                    useMipMap = true,
                    autoGenerateMips = false, // 我们手动填充
                    filterMode = FilterMode.Point,
                    wrapMode = TextureWrapMode.Clamp
                };
                _autoMipmapTexture.Create();
            }
            
            _cmd.Clear();
            
            // 逐个拷贝mip层级
            for (int i = 0; i < mipCount; i++)
            {
                var mipSize = depthPyramid.GetMipSize(i);
                depthPyramid.GetMipCoord(i, out int srcX, out int srcY);
                
                // 直接从源纹理的特定区域拷贝到目标纹理的mip层级
                _cmd.CopyTexture(
                    depthPyramid.DepthPyramidTexture, 0, 0, srcX, srcY, mipSize.x, mipSize.y,
                    _autoMipmapTexture, i, 0, 0, 0
                );
            }
            
            Graphics.ExecuteCommandBuffer(_cmd);
            
            Debug.Log($"[HiZ Example] 已拷贝 {mipCount} 个mip层级到自动mipmap纹理");
        }
        
        /// <summary>
        /// 方式3：只拷贝特定的mip层级
        /// </summary>
        public void CopySingleMipLevel(int mipLevel, RenderTexture destination)
        {
            var hizSystem = HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
                return;
            
            var depthPyramid = hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
                return;
            
            if (mipLevel < 0 || mipLevel >= depthPyramid.MipCount)
            {
                Debug.LogError($"[HiZ Example] 无效的mip层级: {mipLevel}");
                return;
            }
            
            _cmd.Clear();
            depthPyramid.CopyMipLevel(_cmd, mipLevel, destination);
            Graphics.ExecuteCommandBuffer(_cmd);
            
            Debug.Log($"[HiZ Example] 已拷贝mip层级 {mipLevel} 到目标纹理");
        }
        
        /// <summary>
        /// 方式4：在Shader中直接采样特定mip层级
        /// 这是最推荐的方式，不需要拷贝数据
        /// </summary>
        public void SampleInShaderExample()
        {
            var hizSystem = HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
                return;
            
            var depthPyramid = hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
                return;
            
            // 设置Shader参数
            Shader.SetGlobalTexture("_MyCustomHiZTexture", depthPyramid.DepthPyramidTexture);
            Shader.SetGlobalInt("_MyCustomHiZBaseWidth", depthPyramid.BaseSize.x);
            Shader.SetGlobalInt("_MyCustomHiZBaseHeight", depthPyramid.BaseSize.y);
            
            // 然后在Shader中使用如下代码采样特定mip层级：
            //
            // float SampleHiZMipmap(float2 uv, int mipLevel)
            // {
            //     int baseWidth = _MyCustomHiZBaseWidth;
            //     int baseHeight = _MyCustomHiZBaseHeight;
            //     
            //     // 计算mip层级尺寸
            //     int mipWidth = baseWidth >> mipLevel;
            //     int mipHeight = baseHeight >> mipLevel;
            //     
            //     // 计算起始坐标
            //     int2 startCoord;
            //     if (mipLevel == 0)
            //     {
            //         startCoord = int2(0, 0);
            //     }
            //     else
            //     {
            //         startCoord.x = baseWidth;
            //         startCoord.y = 0;
            //     }
            //     
            //     // 计算像素坐标
            //     int2 coord = int2(uv * float2(mipWidth, mipHeight));
            //     
            //     // 采样
            //     return _MyCustomHiZTexture.Load(int3(startCoord + coord, 0));
            // }
        }
        
        [ContextMenu("测试拷贝到手动纹理")]
        private void TestCopyToManualTextures()
        {
            CopyToManualTextures();
        }
        
        [ContextMenu("测试拷贝到自动纹理")]
        private void TestCopyToAutoMipmapTexture()
        {
            CopyToAutoMipmapTexture();
        }
        
        private void OnGUI()
        {
            GUILayout.BeginArea(new Rect(10, 100, 250, 150));
            GUILayout.BeginVertical("box");
            
            GUILayout.Label("HiZ深度金字塔拷贝示例");
            
            if (GUILayout.Button("拷贝到手动纹理数组"))
            {
                CopyToManualTextures();
            }
            
            if (GUILayout.Button("拷贝到自动Mipmap纹理"))
            {
                CopyToAutoMipmapTexture();
            }
            
            var hizSystem = HizSystem.Instance;
            if (hizSystem?.GetDepthPyramid() != null)
            {
                var depthPyramid = hizSystem.GetDepthPyramid();
                GUILayout.Label($"Mip数量: {depthPyramid.MipCount}");
                GUILayout.Label($"基础尺寸: {depthPyramid.BaseSize.x}x{depthPyramid.BaseSize.y}");
            }
            
            GUILayout.EndVertical();
            GUILayout.EndArea();
        }
    }
}

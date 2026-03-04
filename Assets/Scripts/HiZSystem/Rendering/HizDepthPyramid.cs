using System;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ深度金字塔生成器
    /// 负责从相机深度纹理生成多级深度金字塔
    /// </summary>
    public class HizDepthPyramid : IDisposable
    {
        // public struct int2
        // {
        //     public int x;
        //     public int y;
        // }
        #region 属性
        
        private HizSettings _settings;
        private ComputeShader _depthPyramidCS;
        private Material _depthBlitMaterial;
        
        private RenderTexture _depthPyramidTexture;
        private int _mipCount;
        private int2 _baseSize;
        
        // Shader属性ID
        private static readonly int CameraDepthTextureId = Shader.PropertyToID("_CameraDepthTexture");
        private static readonly int HizDepthTextureId = Shader.PropertyToID("_HizDepthTexture");
        private static readonly int CameraDepthTextureWidthId = Shader.PropertyToID("_CameraDepthTextureWidth");
        private static readonly int CameraDepthTextureHeightId = Shader.PropertyToID("_CameraDepthTextureHeight");
        private static readonly int HizDepthTextureBaseWidthId = Shader.PropertyToID("_HizDepthTextureBaseWidth");
        private static readonly int HizDepthTextureBaseHeightId = Shader.PropertyToID("_HizDepthTextureBaseHeight");
        private static readonly int HizMipmapLevelId = Shader.PropertyToID("_HizMipmapLevel");
        private static readonly int HizReversedZId = Shader.PropertyToID("_HizReversedZ");
        
        private int _kernelDepthBlit;
        private int _kernelGenMipmap;
        
        private bool _isInitialized;
        private bool _useComputeShader;
        
        /// <summary>
        /// 深度金字塔纹理
        /// </summary>
        public RenderTexture DepthPyramidTexture => _depthPyramidTexture;
        
        /// <summary>
        /// Mip级别数量（逻辑上的mip层级数）
        /// 注意：由于使用手动mipmap管理，RenderTexture.mipmapCount可能返回1
        /// 请使用此属性获取正确的mip数量
        /// </summary>
        public int MipCount => _mipCount;
        
        /// <summary>
        /// 基础尺寸（Mip 0的尺寸）
        /// </summary>
        public Vector2Int BaseSize => new Vector2Int(_baseSize.x, _baseSize.y);
        
        /// <summary>
        /// 获取指定mip层级的尺寸
        /// </summary>
        public Vector2Int GetMipSize(int mipLevel)
        {
            if (mipLevel < 0 || mipLevel >= _mipCount)
                return Vector2Int.zero;
                
            return new Vector2Int(
                Mathf.Max(1, _baseSize.x >> mipLevel),
                Mathf.Max(1, _baseSize.y >> mipLevel)
            );
        }
        
        /// <summary>
        /// 验证C#和Shader的坐标计算是否一致
        /// 在编辑器中调用此方法来检查
        /// </summary>
        [ContextMenu("验证坐标计算")]
        public void ValidateCoordCalculation()
        {
            if (!_isInitialized)
            {
                Debug.LogError("[HiZ Validation] 系统未初始化");
                return;
            }
            
            Debug.Log($"=== HiZ 坐标计算验证 (BaseSize: {_baseSize.x}x{_baseSize.y}, MipCount: {_mipCount}) ===");
            
            // 打印每个mip层级的坐标
            for (int i = 0; i < _mipCount; i++)
            {
                GetMipCoord(i, out int startX, out int startY);
                var mipSize = GetMipSize(i);
                
                Debug.Log($"Mip {i}: 起始=({startX,4}, {startY}), 大小={mipSize.x,4}x{mipSize.y}");
            }
            
            // 打印Shader中应该使用的公式
            Debug.Log("=== Shader 公式参考 ===");
            Debug.Log("// 计算 Mip K 的 X 起始坐标");
            Debug.Log("int xOffset = baseWidth;");
            Debug.Log("for (int i = 1; i < mipmapLevel; i++) {");
            Debug.Log("    xOffset += max(1, baseWidth >> i);");
            Debug.Log("}");
        }
        
        /// <summary>
        /// 获取mipmap在纹理中的起始坐标（用于手动管理的mipmap布局）
        /// 
        /// 内存布局（横向排列）:
        /// 假设基础尺寸为 1024x1024
        /// 
        /// Mip 0: 起始 (0, 0),      大小 1024x1024
        /// Mip 1: 起始 (1024, 0),   大小 512x512
        /// Mip 2: 起始 (1536, 0),   大小 256x256
        /// Mip 3: 起始 (1792, 0),   大小 128x128
        /// 
        /// 坐标计算公式:
        /// Mip K 起始 X = BaseWidth + Σ(BaseWidth >> i) for i in [1, K-1]
        /// 
        /// 示例计算 Mip 2:
        /// startX = 1024 + (1024 >> 1) = 1024 + 512 = 1536
        /// </summary>
        /// <param name="mipLevel">mip层级 (0 = 最高分辨率)</param>
        /// <param name="startX">输出起始X坐标（像素）</param>
        /// <param name="startY">输出起始Y坐标（像素，始终为0）</param>
        public void GetMipCoord(int mipLevel, out int startX, out int startY)
        {
            if (mipLevel == 0)
            {
                // Mip 0 始终从 (0, 0) 开始
                startX = 0;
                startY = 0;
                return;
            }
            
            // Mip 1+ 存储在纹理右侧横向排列
            // 计算X偏移：BaseSize.x + 之前所有层级的宽度之和
            // 
            // 对于 Mip K:
            // xOffset = BaseWidth (Mip 0)
            //         + BaseWidth>>1 (Mip 1)
            //         + BaseWidth>>2 (Mip 2)
            //         + ...
            //         + BaseWidth>>(K-1) (Mip K-1)
            int xOffset = _baseSize.x;  // Mip 0 的宽度
            
            // 累加 Mip 1 到 Mip K-1 的宽度
            for (int i = 1; i < mipLevel; i++)
            {
                // 右移 i 位相当于除以 2^i
                // 确保至少为1像素
                xOffset += Mathf.Max(1, _baseSize.x >> i);
            }
            
            startX = xOffset;
            startY = 0;  // 所有层级都从 Y=0 开始（横向布局）
        }
        
        /// <summary>
        /// 将指定mip层级的数据拷贝到目标纹理
        /// </summary>
        /// <param name="cmd">CommandBuffer</param>
        /// <param name="mipLevel">要拷贝的mip层级</param>
        /// <param name="destination">目标纹理</param>
        public void CopyMipLevel(CommandBuffer cmd, int mipLevel, RenderTexture destination)
        {
            if (mipLevel < 0 || mipLevel >= _mipCount)
            {
                Debug.LogError($"[HiZ DepthPyramid] 无效的mip层级: {mipLevel}");
                return;
            }
            
            if (_depthPyramidTexture == null)
            {
                Debug.LogError("[HiZ DepthPyramid] 深度金字塔纹理为空");
                return;
            }
            
            GetMipCoord(mipLevel, out int srcX, out int srcY);
            var mipSize = GetMipSize(mipLevel);
            
            // 使用CopyTexture拷贝特定区域
            cmd.CopyTexture(
                _depthPyramidTexture, 0, 0, 
                srcX, srcY, mipSize.x, mipSize.y,
                destination, 0, 0,
                0, 0
            );
            
            Debug.Log($"[HiZ Copy] Mip {mipLevel}: 从 ({srcX},{srcY}) 拷贝 {mipSize.x}x{mipSize.y}");
        }
        
        /// <summary>
        /// 基础尺寸
        /// </summary>
        // public int2 BaseSize => _baseSize;
        
        /// <summary>
        /// 是否初始化完成
        /// </summary>
        public bool IsInitialized => _isInitialized;
        
        #endregion
        
        #region 初始化
        
        /// <summary>
        /// 初始化深度金字塔生成器
        /// </summary>
        public bool Initialize(HizSettings settings, ComputeShader computeShader = null, Shader fallbackShader = null)
        {
            _settings = settings;
            _depthPyramidCS = computeShader;
            
            // 检查是否使用Compute Shader
            _useComputeShader = !_settings.forceDisableComputeShader && 
                                _depthPyramidCS != null &&
                                SystemInfo.supportsComputeShaders;
            
            if (_useComputeShader)
            {
                InitializeComputeShader();
            }
            else if (fallbackShader != null)
            {
                InitializeFallbackMaterial(fallbackShader);
            }
            else
            {
                Debug.LogError("[HiZ DepthPyramid] 没有可用的Compute Shader或Fallback Shader");
                return false;
            }
            
            _isInitialized = true;
            return true;
        }
        
        private void InitializeComputeShader()
        {
            _kernelDepthBlit = _depthPyramidCS.FindKernel("DepthBlit");
            _kernelGenMipmap = _depthPyramidCS.FindKernel("GenMipmap");
            
            // 设置Reversed Z
            _depthPyramidCS.SetInt(HizReversedZId, HizPlatformCompatibility.UsesReversedZ() ? 1 : 0);
        }
        
        private void InitializeFallbackMaterial(Shader shader)
        {
            _depthBlitMaterial = new Material(shader);
            _depthBlitMaterial.hideFlags = HideFlags.HideAndDontSave;
        }
        
        #endregion
        
        #region 深度金字塔生成
        
        /// <summary>
        /// 构建深度金字塔
        /// </summary>
        public void BuildDepthPyramid(CommandBuffer cmd, RenderTexture cameraDepthTexture)
        {
            if (!_isInitialized || cameraDepthTexture == null)
                return;
                
            // 确保纹理尺寸匹配
            EnsureTextureSize(cameraDepthTexture);
            
            if (_useComputeShader)
            {
                BuildDepthPyramidCompute(cmd, cameraDepthTexture);
            }
            else
            {
                BuildDepthPyramidFallback(cmd, cameraDepthTexture);
            }
            
            // 设置全局纹理
            cmd.SetGlobalTexture(HizDepthTextureId, _depthPyramidTexture);
            Shader.SetGlobalInt(HizDepthTextureBaseWidthId, _baseSize.x);
            Shader.SetGlobalInt(HizDepthTextureBaseHeightId, _baseSize.y);
        }
        
        /// <summary>
        /// 使用Compute Shader构建深度金字塔
        /// </summary>
        private void BuildDepthPyramidCompute(CommandBuffer cmd, RenderTexture cameraDepthTexture)
        {
            // 设置全局尺寸参数（两个kernel都需要）
            cmd.SetComputeIntParam(_depthPyramidCS, HizDepthTextureBaseWidthId, _baseSize.x);
            cmd.SetComputeIntParam(_depthPyramidCS, HizDepthTextureBaseHeightId, _baseSize.y);
            
            // 第一步：将相机深度图复制到金字塔的第0层
            cmd.SetComputeTextureParam(_depthPyramidCS, _kernelDepthBlit, CameraDepthTextureId, cameraDepthTexture);
            cmd.SetComputeTextureParam(_depthPyramidCS, _kernelDepthBlit, HizDepthTextureId, _depthPyramidTexture);
            cmd.SetComputeIntParam(_depthPyramidCS, CameraDepthTextureWidthId, cameraDepthTexture.width);
            cmd.SetComputeIntParam(_depthPyramidCS, CameraDepthTextureHeightId, cameraDepthTexture.height);
            
            int threadGroupsX = Mathf.CeilToInt(_baseSize.x / 8f);
            int threadGroupsY = Mathf.CeilToInt(_baseSize.y / 8f);
            
            if (_settings.enableDebug)
            {
                Debug.Log($"[HiZ Build] DepthBlit: 相机深度图 {cameraDepthTexture.width}x{cameraDepthTexture.height}, " +
                          $"HiZ基础尺寸 {_baseSize.x}x{_baseSize.y}, 线程组 {threadGroupsX}x{threadGroupsY}");
            }
            
            cmd.DispatchCompute(_depthPyramidCS, _kernelDepthBlit, threadGroupsX, threadGroupsY, 1);
            
            // 第二步：生成Mipmap链
            for (int mipLevel = 1; mipLevel < _mipCount; mipLevel++)
            {
                int curWidth = _baseSize.x >> mipLevel;
                int curHeight = _baseSize.y >> mipLevel;
                
                if (curWidth == 0 || curHeight == 0)
                    break;
                    
                cmd.SetComputeIntParam(_depthPyramidCS, HizMipmapLevelId, mipLevel);
                cmd.SetComputeTextureParam(_depthPyramidCS, _kernelGenMipmap, HizDepthTextureId, _depthPyramidTexture);
                
                threadGroupsX = Mathf.CeilToInt(curWidth / 8f);
                threadGroupsY = Mathf.CeilToInt(curHeight / 8f);
                
                if (_settings.enableDebug)
                {
                    GetMipCoord(mipLevel, out int startX, out int startY);
                    Debug.Log($"[HiZ Build] GenMipmap {mipLevel}: 写入位置 ({startX}, {startY}), " +
                              $"大小 {curWidth}x{curHeight}, 线程组 {threadGroupsX}x{threadGroupsY}");
                }
                
                cmd.DispatchCompute(_depthPyramidCS, _kernelGenMipmap, threadGroupsX, threadGroupsY, 1);
            }
        }
        
        /// <summary>
        /// 使用Graphics.Blit构建深度金字塔（Fallback方案）
        /// </summary>
        private void BuildDepthPyramidFallback(CommandBuffer cmd, RenderTexture cameraDepthTexture)
        {
            // 创建临时纹理
            RenderTexture[] tempTextures = new RenderTexture[_mipCount];
            
            try
            {
                // 第0层：从相机深度图复制到 (0,0) 位置
                int width = _baseSize.x;
                int height = _baseSize.y;
                
                tempTextures[0] = RenderTexture.GetTemporary(width, height, 0, 
                    HizPlatformCompatibility.GetRenderTextureFormat(_settings.depthFormat));
                tempTextures[0].filterMode = FilterMode.Point;
                cmd.Blit(cameraDepthTexture, tempTextures[0]);
                cmd.CopyTexture(tempTextures[0], _depthPyramidTexture);
                
                // 生成后续Mipmap层级
                for (int mipLevel = 1; mipLevel < _mipCount; mipLevel++)
                {
                    width = Mathf.Max(1, width >> 1);
                    height = Mathf.Max(1, height >> 1);
                    
                    tempTextures[mipLevel] = RenderTexture.GetTemporary(width, height, 0,
                        HizPlatformCompatibility.GetRenderTextureFormat(_settings.depthFormat));
                    tempTextures[mipLevel].filterMode = FilterMode.Point;
                    
                    _depthBlitMaterial.SetVector("_InvSize", new Vector4(1.0f / width, 1.0f / height, 0, 0));
                    _depthBlitMaterial.SetTexture("_DepthTexture", tempTextures[mipLevel - 1]);
                    _depthBlitMaterial.SetInt("_MipLevel", mipLevel);
                    
                    cmd.Blit(null, tempTextures[mipLevel], _depthBlitMaterial);
                    
                    // 拷贝到纹理的特定位置（手动布局）
                    GetMipCoord(mipLevel, out int destX, out int destY);
                    cmd.CopyTexture(
                        tempTextures[mipLevel], 0, 0, 0, 0, width, height,
                        _depthPyramidTexture, 0, 0, destX, destY
                    );
                }
            }
            finally
            {
                // 释放临时纹理
                for (int i = 0; i < tempTextures.Length; i++)
                {
                    if (tempTextures[i] != null)
                    {
                        RenderTexture.ReleaseTemporary(tempTextures[i]);
                    }
                }
            }
        }
        
        #endregion
        
        #region 纹理管理
        
        /// <summary>
        /// 计算存储所有mipmap所需的纹理宽度
        /// </summary>
        private int CalculateTotalTextureWidth()
        {
            // Mip 0 宽度
            int totalWidth = _baseSize.x;
            
            // Mip 1+ 横向排列在右侧
            for (int i = 1; i < _mipCount; i++)
            {
                totalWidth += Mathf.Max(1, _baseSize.x >> i);
            }
            
            return totalWidth;
        }
        
        /// <summary>
        /// 确保深度金字塔纹理尺寸匹配
        /// </summary>
        private void EnsureTextureSize(RenderTexture cameraDepthTexture)
        {
            CalculateBaseSize(cameraDepthTexture);
            
            int totalWidth = CalculateTotalTextureWidth();
            int textureHeight = _baseSize.y; // 高度保持为基础尺寸
            
            if (_depthPyramidTexture != null &&
                _depthPyramidTexture.width == totalWidth &&
                _depthPyramidTexture.height == textureHeight)
            {
                return; // 尺寸匹配，无需重建
            }
            
            // 释放旧纹理
            ReleaseTexture();
            
            // 创建新的深度金字塔纹理
            // 注意：纹理宽度需要足够容纳所有mip层级的横向布局
            var format = HizPlatformCompatibility.GetGraphicsFormat(_settings.depthFormat);
            var desc = new RenderTextureDescriptor(totalWidth, textureHeight, format, 0)
            {
                useMipMap = false, // 我们手动管理mipmap布局
                autoGenerateMips = false,
                enableRandomWrite = true, // Compute Shader需要
            };
            
            _depthPyramidTexture = new RenderTexture(desc)
            {
                name = "_HizDepthTexture",
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Clamp,
            };
            _depthPyramidTexture.Create();
            
            // 清除纹理，避免残留数据
            RenderTexture.active = _depthPyramidTexture;
            GL.Clear(false, true, Color.clear);
            RenderTexture.active = null;
            
            Debug.Log($"[HiZ DepthPyramid] 创建深度金字塔纹理: {totalWidth}x{textureHeight} (包含所有 {_mipCount} 个mip层级的横向布局)");
        }
        
        /// <summary>
        /// 计算基础尺寸
        /// </summary>
        private void CalculateBaseSize(RenderTexture cameraDepthTexture)
        {
            if (cameraDepthTexture == null || cameraDepthTexture.width == 0 || cameraDepthTexture.height == 0)
            {
                Debug.LogError("[HiZ DepthPyramid] 相机深度纹理无效");
                return;
            }
            
            // 计算合适的基础尺寸（向上取整到2的幂）
            int targetHeight = Mathf.Min(cameraDepthTexture.height, _settings.baseResolution);
            _baseSize.y = CeilToPowerOfTwo(targetHeight);
            
            // 保持宽高比
            float aspectRatio = (float)cameraDepthTexture.width / cameraDepthTexture.height;
            _baseSize.x = CeilToPowerOfTwo(Mathf.RoundToInt(_baseSize.y * aspectRatio));
            
            // 计算mip级别数量
            _mipCount = Mathf.Min(
                _settings.maxMipLevel,
                Mathf.FloorToInt(Mathf.Log(Mathf.Min(_baseSize.x, _baseSize.y), 2)) + 1
            );
            
            if (_settings.enableDebug)
            {
                Debug.Log($"[HiZ DepthPyramid] 基础尺寸计算: 相机深度图 {cameraDepthTexture.width}x{cameraDepthTexture.height}, " +
                          $"HiZ基础尺寸 {_baseSize.x}x{_baseSize.y}, MipCount={_mipCount}");
            }
        }
        
        /// <summary>
        /// 向上取整到2的幂
        /// </summary>
        private int CeilToPowerOfTwo(int x)
        {
            if (x < 1) return 1;
            x--;
            x |= x >> 1;
            x |= x >> 2;
            x |= x >> 4;
            x |= x >> 8;
            x |= x >> 16;
            return x + 1;
        }
        
        /// <summary>
        /// 释放纹理资源
        /// </summary>
        private void ReleaseTexture()
        {
            if (_depthPyramidTexture != null)
            {
                _depthPyramidTexture.Release();
                Object.DestroyImmediate(_depthPyramidTexture);
                _depthPyramidTexture = null;
            }
        }
        
        #endregion
        
        #region IDisposable
        
        public void Dispose()
        {
            ReleaseTexture();
            
            if (_depthBlitMaterial != null)
            {
                Object.DestroyImmediate(_depthBlitMaterial);
                _depthBlitMaterial = null;
            }
            
            _isInitialized = false;
        }
        
        #endregion
    }
}

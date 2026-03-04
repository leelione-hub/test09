using UnityEngine;
using UnityEngine.UI;
using HiZTechnique;

namespace HiZTechnique.Examples
{
    /// <summary>
    /// HiZ深度金字塔可视化调试工具
    /// 用于验证深度金字塔是否正确生成
    /// </summary>
    public class HiZDebugVisualizer : MonoBehaviour
    {
        [Header("UI引用")]
        [SerializeField]
        private RawImage[] _mipDisplays;
        
        [SerializeField]
        private Text _debugText;
        
        [Header("设置")]
        [SerializeField]
        private int _maxDisplayMips = 4;
        
        [SerializeField]
        private bool _autoRefresh = true;
        
        [SerializeField]
        private float _refreshInterval = 1.0f;
        
        // 运行时
        private RenderTexture[] _cachedMips;
        private float _lastRefreshTime;
        private Material _displayMaterial;
        
        private static readonly int DepthTextureId = Shader.PropertyToID("_DepthTexture");
        
        private void Start()
        {
            // 创建显示材质（使用简单的深度可视化）
            Shader shader = Shader.Find("Unlit/Texture");
            if (shader != null)
            {
                _displayMaterial = new Material(shader);
            }
        }
        
        private void Update()
        {
            if (!_autoRefresh)
                return;
                
            if (Time.time - _lastRefreshTime < _refreshInterval)
                return;
                
            _lastRefreshTime = Time.time;
            RefreshDisplay();
        }
        
        [ContextMenu("刷新显示")]
        public void RefreshDisplay()
        {
            var hizSystem = HizSystem.Instance;
            if (hizSystem == null || !hizSystem.IsActive)
            {
                UpdateDebugText("HiZ系统未激活");
                return;
            }
            
            var depthPyramid = hizSystem.GetDepthPyramid();
            if (depthPyramid == null)
            {
                UpdateDebugText("深度金字塔为空");
                return;
            }
            
            var sourceTexture = depthPyramid.DepthPyramidTexture;
            if (sourceTexture == null)
            {
                UpdateDebugText("源纹理为空");
                return;
            }
            
            int mipCount = Mathf.Min(depthPyramid.MipCount, _maxDisplayMips);
            
            // 确保缓存数组大小正确
            if (_cachedMips == null || _cachedMips.Length != mipCount)
            {
                ClearCachedMips();
                _cachedMips = new RenderTexture[mipCount];
            }
            
            // 拷贝每个mip层级到缓存
            for (int i = 0; i < mipCount; i++)
            {
                var mipSize = depthPyramid.GetMipSize(i);
                depthPyramid.GetMipCoord(i, out int srcX, out int srcY);
                
                // 创建或重建缓存纹理
                if (_cachedMips[i] == null || 
                    _cachedMips[i].width != mipSize.x || 
                    _cachedMips[i].height != mipSize.y)
                {
                    if (_cachedMips[i] != null)
                        _cachedMips[i].Release();
                    
                    _cachedMips[i] = new RenderTexture(mipSize.x, mipSize.y, 0, RenderTextureFormat.ARGB32)
                    {
                        name = $"HiZ_Debug_Mip_{i}",
                        filterMode = FilterMode.Point
                    };
                    _cachedMips[i].Create();
                }
                
                // 使用与源纹理相同的格式创建临时纹理
                RenderTexture tempRT = RenderTexture.GetTemporary(mipSize.x, mipSize.y, 0, sourceTexture.graphicsFormat);
                
                // 从源纹理拷贝数据（格式必须匹配）
                Graphics.CopyTexture(
                    sourceTexture, 0, 0, srcX, srcY, mipSize.x, mipSize.y,
                    tempRT, 0, 0, 0, 0
                );
                
                // 使用材质将深度转换为可视颜色
                RenderTexture.active = _cachedMips[i];
                GL.Clear(false, true, Color.black);
                
                // 简单的深度可视化：将深度值作为灰度输出
                Material blitMat = new Material(Shader.Find("Hidden/BlitCopy"));
                blitMat.SetFloat("_Scale", 1.0f);
                blitMat.SetFloat("_Offset", 0.0f);
                Graphics.Blit(tempRT, _cachedMips[i], blitMat);
                
                RenderTexture.active = null;
                RenderTexture.ReleaseTemporary(tempRT);
                Destroy(blitMat);
                
                // 更新UI显示
                if (_mipDisplays != null && i < _mipDisplays.Length && _mipDisplays[i] != null)
                {
                    _mipDisplays[i].texture = _cachedMips[i];
                }
            }
            
            // 更新调试信息
            string info = $"源纹理: {sourceTexture.width}x{sourceTexture.height}\n" +
                         $"基础尺寸: {depthPyramid.BaseSize.x}x{depthPyramid.BaseSize.y}\n" +
                         $"Mip数量: {depthPyramid.MipCount}\n" +
                         $"图形格式: {sourceTexture.graphicsFormat}";
            UpdateDebugText(info);
        }
        
        private void ClearCachedMips()
        {
            if (_cachedMips != null)
            {
                foreach (var rt in _cachedMips)
                {
                    if (rt != null)
                        rt.Release();
                }
            }
        }
        
        private void UpdateDebugText(string text)
        {
            if (_debugText != null)
            {
                _debugText.text = text;
            }
            Debug.Log($"[HiZ Visualizer] {text}");
        }
        
        private void OnDestroy()
        {
            ClearCachedMips();
            if (_displayMaterial != null)
                Destroy(_displayMaterial);
        }
        
        private void OnGUI()
        {
            GUILayout.BeginArea(new Rect(10, 200, 300, 150));
            GUILayout.BeginVertical("box");
            
            GUILayout.Label("HiZ调试可视化");
            
            if (GUILayout.Button("刷新显示"))
            {
                RefreshDisplay();
            }
            
            if (GUILayout.Button(_autoRefresh ? "停止自动刷新" : "开始自动刷新"))
            {
                _autoRefresh = !_autoRefresh;
            }
            
            GUILayout.EndVertical();
            GUILayout.EndArea();
        }
    }
}

using UnityEngine;
using UnityEngine.UI;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ Debug面板
    /// 提供可视化的调试信息和控制界面
    /// </summary>
    public class HizDebugPanel : MonoBehaviour
    {
        [Header("UI引用")]
        [Tooltip("根面板")]
        [SerializeField]
        private GameObject _panelRoot;
        
        [Tooltip("状态文本")]
        [SerializeField]
        private Text _statusText;
        
        [Tooltip("对象数量文本")]
        [SerializeField]
        private Text _objectCountText;
        
        [Tooltip("可见数量文本")]
        [SerializeField]
        private Text _visibleCountText;
        
        [Tooltip("剔除统计文本")]
        [SerializeField]
        private Text _cullingStatsText;
        
        [Tooltip("剔除率文本")]
        [SerializeField]
        private Text _cullingRatioText;
        
        [Tooltip("开关按钮")]
        [SerializeField]
        private Button _toggleButton;
        
        [Tooltip("开关按钮文本")]
        [SerializeField]
        private Text _toggleButtonText;
        
        [Tooltip("深度纹理显示")]
        [SerializeField]
        private RawImage _depthTextureDisplay;
        
        [Tooltip("Mip级别滑块")]
        [SerializeField]
        private Slider _mipLevelSlider;
        
        [Tooltip("Mip级别文本")]
        [SerializeField]
        private Text _mipLevelText;
        
        [Tooltip("FPS文本")]
        [SerializeField]
        private Text _fpsText;
        
        [Tooltip("性能统计文本")]
        [SerializeField]
        private Text _performanceText;
        
        [Header("设置")]
        [Tooltip("默认按键打开/关闭面板")]
        [SerializeField]
        private KeyCode _toggleKey = KeyCode.F2;
        
        [Tooltip("是否显示帧率")]
        [SerializeField]
        private bool _showFPS = true;
        
        [Tooltip("更新间隔（秒）")]
        [SerializeField]
        private float _updateInterval = 0.5f;

        //在面板上显示，方便Debug使用
        public RenderTexture DepthTexture;
        
        // 运行时数据
        private HizSystem _hizSystem;
        private float _lastUpdateTime;
        private float _fpsAccumulator;
        private int _fpsFrameCount;
        private float _currentFPS;
        private int _currentMipLevel;
        private Material _depthDisplayMaterial;
        
        // Shader属性
        private static readonly int DepthTextureId = Shader.PropertyToID("_DepthTexture");
        private static readonly int MipLevelId = Shader.PropertyToID("_MipLevel");
        private static readonly int ShowDepthId = Shader.PropertyToID("_ShowDepth");
        
        private void Start()
        {
            Initialize();
        }
        
        private void OnDestroy()
        {
            if (_depthDisplayMaterial != null)
            {
                Destroy(_depthDisplayMaterial);
            }

            if (DepthTexture != null)
            {
                DepthTexture.Release();
                DepthTexture = null;
            }
        }
        
        private void Update()
        {
            // 切换面板显示
            if (Input.GetKeyDown(_toggleKey))
            {
                TogglePanel();
            }
            
            // 更新数据
            if (_panelRoot.activeInHierarchy && Time.time - _lastUpdateTime >= _updateInterval)
            {
                UpdatePanel();
                _lastUpdateTime = Time.time;
            }
            
            // 计算FPS
            if (_showFPS)
            {
                _fpsAccumulator += Time.timeScale / Time.deltaTime;
                _fpsFrameCount++;
                
                if (Time.time >= _lastUpdateTime + _updateInterval)
                {
                    _currentFPS = _fpsAccumulator / _fpsFrameCount;
                    _fpsAccumulator = 0;
                    _fpsFrameCount = 0;
                }
            }
            
            // 更新深度纹理显示
            UpdateDepthTextureDisplay();
        }
        
        private void Initialize()
        {
            _hizSystem = HizSystem.Instance;
            
            // 创建深度显示材质
            Shader depthDisplayShader = Shader.Find("HiZ/DebugDepthDisplay");
            if (depthDisplayShader != null)
            {
                _depthDisplayMaterial = new Material(depthDisplayShader);
            }
            else
            {
                Debug.LogWarning("[HiZ DebugPanel] 找不到DebugDepthDisplay shader");
            }
            
            // 设置按钮回调
            if (_toggleButton != null)
            {
                _toggleButton.onClick.AddListener(OnToggleButtonClick);
            }
            
            // 设置滑块回调
            if (_mipLevelSlider != null)
            {
                _mipLevelSlider.onValueChanged.AddListener(OnMipLevelChanged);
            }
            
            // 默认隐藏面板
            if (_panelRoot != null)
            {
                _panelRoot.SetActive(false);
            }
            
            _lastUpdateTime = Time.time;
        }
        
        private void UpdatePanel()
        {
            if (_hizSystem == null)
            {
                _hizSystem = HizSystem.Instance;
                if (_hizSystem == null)
                {
                    if (_statusText != null)
                        _statusText.text = "HiZ System: Not Found";
                    return;
                }
            }
            
            // 更新状态
            if (_statusText != null)
            {
                _statusText.text = $"状态: {_hizSystem.State}";
                _statusText.color = GetStateColor(_hizSystem.State);
            }
            
            // 更新对象数量
            if (_objectCountText != null)
            {
                int count = _hizSystem.CullingManager?.ObjectCount ?? 0;
                _objectCountText.text = $"对象总数: {count}";
            }
            
            // 更新可见数量
            var stats = _hizSystem.CurrentStats;
            if (_visibleCountText != null && stats != null)
            {
                _visibleCountText.text = $"可见对象: {stats.visibleInstances}/{stats.totalInstances}";
            }
            
            // 更新剔除统计
            if (_cullingStatsText != null && stats != null)
            {
                _cullingStatsText.text = $"视锥剔除: {stats.culledByFrustum}\nHiZ剔除: {stats.culledByHiz}";
            }
            
            // 更新剔除率
            if (_cullingRatioText != null && stats != null)
            {
                _cullingRatioText.text = $"剔除率: {stats.CullingRatio:P1}";
            }
            
            // 更新FPS
            if (_fpsText != null && _showFPS)
            {
                Color fpsColor = _currentFPS >= 60 ? Color.green : (_currentFPS >= 30 ? Color.yellow : Color.red);
                _fpsText.text = $"FPS: {_currentFPS:F1}";
                _fpsText.color = fpsColor;
            }
            
            // 更新按钮文本
            if (_toggleButtonText != null)
            {
                _toggleButtonText.text = _hizSystem.IsActive ? "关闭HiZ" : "开启HiZ";
            }
            
            // 更新性能统计
            UpdatePerformanceStats();
        }
        
        private void UpdatePerformanceStats()
        {
            if (_performanceText == null || _hizSystem?.CullingManager == null)
                return;
            
            var cullingManager = _hizSystem.CullingManager;
            float avgCullingRatio = cullingManager.GetAverageCullingRatio();
            
            _performanceText.text = $"平均剔除率: {avgCullingRatio:P1}\n" +
                                   $"历史帧数: {cullingManager.StatsHistory.Count}";
        }
        
        private void UpdateDepthTextureDisplay()
        {
            if (_depthTextureDisplay == null || _hizSystem == null)
                return;
            
            var depthTexture = _hizSystem.DepthPyramidTexture;
            if (depthTexture == null)
            {
                _depthTextureDisplay.texture = null;
                return;
            }
            
            if (_depthDisplayMaterial != null)
            {
                _depthDisplayMaterial.SetTexture(DepthTextureId, depthTexture);
                _depthDisplayMaterial.SetInt(MipLevelId, _currentMipLevel);
                _depthTextureDisplay.material = _depthDisplayMaterial;
            }
            else
            {
                _depthTextureDisplay.texture = depthTexture;
            }
        }
        
        private void TogglePanel()
        {
            if (_panelRoot != null)
            {
                _panelRoot.SetActive(!_panelRoot.activeInHierarchy);
            }
        }
        
        private void OnToggleButtonClick()
        {
            if (_hizSystem != null)
            {
                _hizSystem.ToggleSystem();
            }
        }
        
        private void OnMipLevelChanged(float value)
        {
            _currentMipLevel = Mathf.RoundToInt(value);
            
            if (_mipLevelText != null)
            {
                _mipLevelText.text = $"Mip Level: {_currentMipLevel}";
            }
        }
        
        private Color GetStateColor(HizSystemState state)
        {
            switch (state)
            {
                case HizSystemState.Active:
                    return Color.green;
                case HizSystemState.Ready:
                    return Color.yellow;
                case HizSystemState.Error:
                case HizSystemState.PlatformNotSupported:
                    return Color.red;
                default:
                    return Color.gray;
            }
        }
        
        #region 可视化辅助
        
        /// <summary>
        /// 在场景中绘制剔除结果的Gizmo
        /// </summary>
        private void OnDrawGizmos()
        {
            if (_hizSystem == null || !_hizSystem.Settings.showCullingResult)
                return;
            
            // 这里可以绘制被剔除和可见对象的包围盒
            // 需要访问CullingManager中的对象列表
        }
        
        #endregion
    }
}

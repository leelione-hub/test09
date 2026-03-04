using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ系统主管理器
    /// 统一入口，负责协调深度金字塔生成和剔除管理
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public class HizSystem : MonoBehaviour
    {
        #region 单例
        
        private static HizSystem _instance;
        public static HizSystem Instance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = FindObjectOfType<HizSystem>();
                    if (_instance == null)
                    {
                        Debug.LogWarning("[HiZ System] 场景中不存在HiZSystem，请手动添加");
                    }
                }
                return _instance;
            }
        }
        
        #endregion
        
        #region Inspector设置
        
        [Header("HiZ设置")]
        [SerializeField]
        private HizSettings _settings = new HizSettings();
        
        [Header("Compute Shaders")]
        [Tooltip("深度金字塔生成Compute Shader")]
        [SerializeField]
        private ComputeShader _depthPyramidComputeShader;
        
        [Tooltip("剔除Compute Shader")]
        [SerializeField]
        private ComputeShader _cullingComputeShader;
        
        [Header("Fallback设置")]
        [Tooltip("Fallback深度金字塔Shader（当Compute Shader不支持时使用）")]
        [SerializeField]
        private Shader _depthBlitFallbackShader;
        
        [Header("相机设置")]
        [Tooltip("使用指定相机（为空则使用主相机）")]
        [SerializeField]
        private Camera _targetCamera;
        
        #endregion
        
        #region 组件
        
        private HizDepthPyramid _depthPyramid;
        private HizCullingManager _cullingManager;
        private HizRenderFeature _renderFeature;
        
        #endregion
        
        #region 状态
        
        private HizSystemState _state = HizSystemState.Disabled;
        private bool _isQuitting;
        
        // 事件
        public event Action OnSystemEnabled;
        public event Action OnSystemDisabled;
        public event Action<HizSystemState> OnStateChanged;
        
        #endregion
        
        #region 公共属性
        
        /// <summary>
        /// 当前设置
        /// </summary>
        public HizSettings Settings => _settings;
        
        /// <summary>
        /// 当前状态
        /// </summary>
        public HizSystemState State => _state;
        
        /// <summary>
        /// 是否激活
        /// </summary>
        public bool IsActive => _state == HizSystemState.Active;
        
        /// <summary>
        /// 深度金字塔纹理
        /// </summary>
        public RenderTexture DepthPyramidTexture => _depthPyramid?.DepthPyramidTexture;
        
        /// <summary>
        /// 剔除管理器
        /// </summary>
        public HizCullingManager CullingManager => _cullingManager;
        
        /// <summary>
        /// 当前统计
        /// </summary>
        public HizCullingStats CurrentStats => _cullingManager?.CurrentStats;
        
        /// <summary>
        /// 目标相机
        /// </summary>
        public Camera TargetCamera => _targetCamera ?? Camera.main;
        
        #endregion
        
        #region 生命周期
        
        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }
            
            _instance = this;
            DontDestroyOnLoad(gameObject);
            
            Initialize();
        }
        
        private void OnEnable()
        {
            if (_state == HizSystemState.Ready)
            {
                EnableSystem();
            }
        }
        
        private void OnDisable()
        {
            DisableSystem();
        }
        
        private void OnDestroy()
        {
            _isQuitting = true;
            Shutdown();
            
            if (_instance == this)
            {
                _instance = null;
            }
        }
        
        private void OnApplicationQuit()
        {
            _isQuitting = true;
        }
        
        #endregion
        
        #region 初始化
        
        /// <summary>
        /// 初始化系统
        /// </summary>
        private void Initialize()
        {
            if (!_settings.enableHiz)
            {
                SetState(HizSystemState.Disabled);
                return;
            }
            
            SetState(HizSystemState.Initializing);
            
            // 验证设置
            _settings.Validate();
            
            // 自动适配平台
            HizPlatformCompatibility.AdjustSettingsForPlatform(_settings);
            
            // 检查平台支持
            if (!HizPlatformCompatibility.IsPlatformSupported())
            {
                SetState(HizSystemState.PlatformNotSupported);
                return;
            }
            
            // 初始化深度金字塔
            _depthPyramid = new HizDepthPyramid();
            if (!_depthPyramid.Initialize(_settings, _depthPyramidComputeShader, _depthBlitFallbackShader))
            {
                Debug.LogError("[HiZ System] 深度金字塔初始化失败");
                SetState(HizSystemState.Error);
                return;
            }
            
            // 初始化剔除管理器
            _cullingManager = new HizCullingManager();
            if (!_cullingManager.Initialize(_settings, _cullingComputeShader))
            {
                Debug.LogWarning("[HiZ System] 剔除管理器初始化失败，HiZ剔除将不可用");
                // 继续运行，只是没有剔除功能
            }
            
            // 监听设置变更
            _settings.OnSettingsChanged += OnSettingsChanged;
            
            SetState(HizSystemState.Ready);
            
            // 如果启用了运行时开关，自动激活
            if (_settings.runtimeToggle)
            {
                EnableSystem();
            }
        }
        
        /// <summary>
        /// 关闭系统
        /// </summary>
        private void Shutdown()
        {
            DisableSystem();
            
            _depthPyramid?.Dispose();
            _depthPyramid = null;
            
            _cullingManager?.Dispose();
            _cullingManager = null;
            
            _settings.OnSettingsChanged -= OnSettingsChanged;
        }
        
        #endregion
        
        #region 系统控制
        
        /// <summary>
        /// 启用系统
        /// </summary>
        public void EnableSystem()
        {
            if (_state == HizSystemState.Active || _state == HizSystemState.Error || 
                _state == HizSystemState.PlatformNotSupported)
            {
                return;
            }
            
            if (_depthPyramid == null || !_depthPyramid.IsInitialized)
            {
                Debug.LogError("[HiZ System] 系统未正确初始化");
                return;
            }
            
            // 注册渲染事件
            RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
            RenderPipelineManager.endCameraRendering += OnEndCameraRendering;
            
            SetState(HizSystemState.Active);
            OnSystemEnabled?.Invoke();
            
            Debug.Log("[HiZ System] 系统已启用");
        }
        
        /// <summary>
        /// 禁用系统
        /// </summary>
        public void DisableSystem()
        {
            if (_state != HizSystemState.Active)
            {
                return;
            }
            
            // 注销渲染事件
            RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
            RenderPipelineManager.endCameraRendering -= OnEndCameraRendering;
            
            // 恢复所有被剔除的对象
            _cullingManager?.Dispose();
            if (_settings.enableHiz && _cullingComputeShader != null)
            {
                _cullingManager = new HizCullingManager();
                _cullingManager.Initialize(_settings, _cullingComputeShader);
            }
            
            SetState(HizSystemState.Ready);
            OnSystemDisabled?.Invoke();
            
            Debug.Log("[HiZ System] 系统已禁用");
        }
        
        /// <summary>
        /// 切换系统开关
        /// </summary>
        public void ToggleSystem()
        {
            if (IsActive)
            {
                DisableSystem();
            }
            else
            {
                EnableSystem();
            }
        }
        
        /// <summary>
        /// 重启系统（用于设置变更后）
        /// </summary>
        public void RestartSystem()
        {
            if (_isQuitting) return;
            
            bool wasActive = IsActive;
            Shutdown();
            Initialize();
            
            if (wasActive && _state == HizSystemState.Ready)
            {
                EnableSystem();
            }
        }
        
        #endregion
        
        #region 渲染回调
        
        private void OnBeginCameraRendering(ScriptableRenderContext context, Camera camera)
        {
            if (camera != TargetCamera)
                return;
            
            // 深度金字塔由RenderFeature处理
        }
        
        private void OnEndCameraRendering(ScriptableRenderContext context, Camera camera)
        {
            if (camera != TargetCamera)
                return;
            
            // 执行剔除
            if (_cullingManager != null && _cullingManager.IsInitialized && 
                _depthPyramid != null && _depthPyramid.DepthPyramidTexture != null)
            {
                _cullingManager.ExecuteCulling(
                    camera, 
                    _depthPyramid.DepthPyramidTexture,
                    _depthPyramid.BaseSize.x,
                    _depthPyramid.BaseSize.y
                );
            }
        }
        
        #endregion
        
        #region 公共API
        
        /// <summary>
        /// 注册剔除对象
        /// </summary>
        public void RegisterCullingObject(IHizCullingObject obj)
        {
            _cullingManager?.RegisterObject(obj);
        }
        
        /// <summary>
        /// 注销剔除对象
        /// </summary>
        public void UnregisterCullingObject(IHizCullingObject obj)
        {
            _cullingManager?.UnregisterObject(obj);
        }
        
        /// <summary>
        /// 更新设置
        /// </summary>
        public void UpdateSettings(HizSettings newSettings)
        {
            bool needRestart = _settings.enableHiz != newSettings.enableHiz ||
                               _settings.maxMipLevel != newSettings.maxMipLevel ||
                               _settings.baseResolution != newSettings.baseResolution ||
                               _settings.depthFormat != newSettings.depthFormat;
            
            _settings = newSettings.Clone();
            
            if (needRestart)
            {
                RestartSystem();
            }
            else
            {
                _settings.NotifyChanged();
            }
        }
        
        /// <summary>
        /// 获取深度金字塔
        /// </summary>
        public HizDepthPyramid GetDepthPyramid()
        {
            return _depthPyramid;
        }
        
        #endregion
        
        #region 事件处理
        
        private void OnSettingsChanged()
        {
            // 设置变更时的处理
        }
        
        private void SetState(HizSystemState newState)
        {
            if (_state == newState)
                return;
            
            _state = newState;
            OnStateChanged?.Invoke(newState);
            
            if (_settings.enableDebug)
            {
                Debug.Log($"[HiZ System] 状态变更为: {newState}");
            }
        }
        
        #endregion
        
        #region 调试
        
        private void OnGUI()
        {
            if (!_settings.enableDebug)
                return;
            
            GUILayout.BeginArea(new Rect(10, 10, 300, 200));
            GUILayout.BeginVertical("box");
            
            GUILayout.Label($"HiZ System: {_state}");
            GUILayout.Label($"Objects: {_cullingManager?.ObjectCount ?? 0}");
            
            if (_cullingManager != null)
            {
                var stats = _cullingManager.CurrentStats;
                GUILayout.Label($"Visible: {stats.visibleInstances}/{stats.totalInstances}");
                GUILayout.Label($"Culled (Frustum): {stats.culledByFrustum}");
                GUILayout.Label($"Culled (HiZ): {stats.culledByHiz}");
                GUILayout.Label($"Culling Ratio: {stats.CullingRatio:P1}");
            }
            
            if (GUILayout.Button(IsActive ? "Disable HiZ" : "Enable HiZ"))
            {
                ToggleSystem();
            }
            
            GUILayout.EndVertical();
            GUILayout.EndArea();
        }
        
        #endregion
    }
}

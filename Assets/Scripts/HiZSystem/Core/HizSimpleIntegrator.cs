using UnityEngine;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ简单集成器
    /// 提供一种简单的方式来批量注册场景中的对象进行HiZ剔除
    /// </summary>
    public class HizSimpleIntegrator : MonoBehaviour
    {
        [Header("设置")]
        [Tooltip("自动注册场景中的所有Renderer")]
        [SerializeField]
        private bool _autoRegisterOnStart = true;
        
        [Tooltip("只注册激活的对象")]
        [SerializeField]
        private bool _onlyActiveObjects = true;
        
        [Tooltip("注册时添加的包围盒扩展")]
        [SerializeField]
        private float _defaultBoundsPadding = 0.5f;
        
        [Tooltip("批量注册时的最大对象数")]
        [SerializeField]
        private int _maxRegisterCount = 1000;
        
        [Tooltip("注册对象的层筛选")]
        [SerializeField]
        private LayerMask _layerFilter = ~0;
        
        [Header("性能")]
        [Tooltip("分批注册，每帧最多注册数量（避免卡顿）")]
        [SerializeField]
        private int _registerPerFrame = 50;
        
        [Tooltip("延迟注册（秒）")]
        [SerializeField]
        private float _registerDelay = 0.5f;
        
        // 状态
        private bool _isRegistering;
        private Renderer[] _pendingRenderers;
        private int _currentIndex;
        private float _timer;
        
        private void Start()
        {
            if (_autoRegisterOnStart)
            {
                _timer = _registerDelay;
            }
        }
        
        private void Update()
        {
            if (_timer > 0)
            {
                _timer -= Time.deltaTime;
                if (_timer <= 0)
                {
                    StartAutoRegister();
                }
            }
            
            if (_isRegistering)
            {
                ProcessRegistration();
            }
        }
        
        /// <summary>
        /// 开始自动注册
        /// </summary>
        public void StartAutoRegister()
        {
            if (HizSystem.Instance == null)
            {
                Debug.LogWarning("[HiZ Integrator] HiZSystem未找到，无法注册对象");
                return;
            }
            
            // 获取所有Renderer
            if (_onlyActiveObjects)
            {
                _pendingRenderers = FindObjectsOfType<Renderer>();
            }
            else
            {
                _pendingRenderers = Resources.FindObjectsOfTypeAll<Renderer>();
            }
            
            // 限制数量
            if (_pendingRenderers.Length > _maxRegisterCount)
            {
                System.Array.Resize(ref _pendingRenderers, _maxRegisterCount);
            }
            
            _currentIndex = 0;
            _isRegistering = true;
            
            Debug.Log($"[HiZ Integrator] 开始注册 {_pendingRenderers.Length} 个对象");
        }
        
        private void ProcessRegistration()
        {
            int endIndex = Mathf.Min(_currentIndex + _registerPerFrame, _pendingRenderers.Length);
            int registeredCount = 0;
            
            for (int i = _currentIndex; i < endIndex; i++)
            {
                var renderer = _pendingRenderers[i];
                
                if (renderer == null)
                    continue;
                
                // 检查层筛选
                if ((1 << renderer.gameObject.layer & _layerFilter) == 0)
                    continue;
                
                // 检查是否已经有HizCullingObject组件
                if (renderer.GetComponent<HizCullingObject>() != null)
                    continue;
                
                // 跳过特定的Renderer类型
                if (renderer is CanvasRenderer)
                    continue;
                
                // 添加HizCullingObject组件
                var cullingObject = renderer.gameObject.AddComponent<HizCullingObject>();
                cullingObject.BoundsPadding = _defaultBoundsPadding;
                
                registeredCount++;
            }
            
            _currentIndex = endIndex;
            
            if (_currentIndex >= _pendingRenderers.Length)
            {
                _isRegistering = false;
                _pendingRenderers = null;
                Debug.Log($"[HiZ Integrator] 注册完成，共注册 {registeredCount} 个对象");
            }
        }
        
        /// <summary>
        /// 清空所有注册的对象
        /// </summary>
        public void ClearAllRegisteredObjects()
        {
            if (HizSystem.Instance?.CullingManager != null)
            {
                HizSystem.Instance.CullingManager.ClearObjects();
                Debug.Log("[HiZ Integrator] 已清空所有注册的对象");
            }
        }
        
        /// <summary>
        /// 手动注册一个对象
        /// </summary>
        public void RegisterObject(GameObject go)
        {
            if (go == null) return;
            
            var renderer = go.GetComponent<Renderer>();
            if (renderer == null)
            {
                Debug.LogWarning($"[HiZ Integrator] 对象 {go.name} 没有Renderer组件");
                return;
            }
            
            var cullingObject = go.GetComponent<HizCullingObject>();
            if (cullingObject == null)
            {
                cullingObject = go.AddComponent<HizCullingObject>();
                cullingObject.BoundsPadding = _defaultBoundsPadding;
            }
        }
        
        /// <summary>
        /// 手动注册一个对象（通过Renderer）
        /// </summary>
        public void RegisterObject(Renderer renderer)
        {
            if (renderer == null) return;
            RegisterObject(renderer.gameObject);
        }
        
        #if UNITY_EDITOR
        [UnityEditor.MenuItem("GameObject/HiZ System/Register Selected Objects", false, 11)]
        private static void RegisterSelectedObjects()
        {
            var hizSystem = FindObjectOfType<HizSystem>();
            if (hizSystem == null)
            {
                UnityEditor.EditorUtility.DisplayDialog("错误", "场景中不存在HiZSystem！请先创建HiZ System。", "确定");
                return;
            }
            
            var integrator = FindObjectOfType<HizSimpleIntegrator>();
            if (integrator == null)
            {
                GameObject go = new GameObject("HiZ Integrator");
                integrator = go.AddComponent<HizSimpleIntegrator>();
            }
            
            var selectedObjects = UnityEditor.Selection.gameObjects;
            int count = 0;
            
            foreach (var go in selectedObjects)
            {
                var renderers = go.GetComponentsInChildren<Renderer>();
                foreach (var renderer in renderers)
                {
                    if (renderer.GetComponent<HizCullingObject>() == null)
                    {
                        integrator.RegisterObject(renderer);
                        count++;
                    }
                }
            }
            
            UnityEditor.EditorUtility.DisplayDialog("注册完成", $"成功注册 {count} 个对象到HiZ系统", "确定");
        }
        #endif
    }
}

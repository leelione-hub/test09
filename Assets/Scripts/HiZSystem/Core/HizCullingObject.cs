using UnityEngine;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ剔除对象组件
    /// 将这个组件附加到需要参与HiZ剔除的游戏对象上
    /// </summary>
    [RequireComponent(typeof(Renderer))]
    public class HizCullingObject : MonoBehaviour, IHizCullingObject
    {
        [Header("剔除设置")]
        [Tooltip("是否启用HiZ剔除")]
        [SerializeField]
        private bool _enableCulling = true;
        
        [Tooltip("包围盒扩展（米）")]
        [SerializeField]
        private float _boundsPadding = 0.5f;
        
        [Tooltip("被剔除时隐藏的方式")]
        [SerializeField]
        private CullingMode _cullingMode = CullingMode.DisableRenderer;
        
        [Tooltip("剔除后保留的层（用于恢复）")]
        [SerializeField]
        private int _originalLayer = -1;
        
        public enum CullingMode
        {
            DisableRenderer,    // 禁用Renderer
            ChangeLayer,        // 切换到剔除层
            SetScaleZero,       // 缩放设置为0
            DisableGameObject,  // 禁用GameObject
        }
        
        // 缓存
        private Renderer _renderer;
        private Transform _transform;
        private Bounds _localBounds;
        private Vector3 _originalScale;
        private int _actualOriginalLayer;
        private bool _wasVisible = true;
        
        // 公共属性
        public bool EnableCulling
        {
            get => _enableCulling;
            set => _enableCulling = value;
        }
        
        public float BoundsPadding
        {
            get => _boundsPadding;
            set => _boundsPadding = value;
        }
        
        #region IHizCullingObject实现
        
        public Vector3 BoundsCenter => GetWorldBounds().center;
        
        public Vector3 BoundsExtents => GetWorldBounds().extents;
        
        public bool IsActive => enabled && gameObject.activeInHierarchy && _enableCulling;
        
        public void OnCulled()
        {
            if (!_wasVisible) return;
            _wasVisible = false;
            
            ApplyCullingState(true);
            
            if (HizSystem.Instance != null && HizSystem.Instance.Settings.enableDebug)
            {
                Debug.Log($"[HiZ] 对象被剔除: {gameObject.name}");
            }
        }
        
        public void OnVisible()
        {
            if (_wasVisible) return;
            _wasVisible = true;
            
            ApplyCullingState(false);
            
            if (HizSystem.Instance != null && HizSystem.Instance.Settings.enableDebug)
            {
                Debug.Log($"[HiZ] 对象恢复可见: {gameObject.name}");
            }
        }
        
        #endregion
        
        #region 生命周期
        
        private void Awake()
        {
            _transform = transform;
            _renderer = GetComponent<Renderer>();
            _originalScale = _transform.localScale;
            
            // 保存原始层
            if (_originalLayer < 0)
            {
                _actualOriginalLayer = gameObject.layer;
            }
            else
            {
                _actualOriginalLayer = _originalLayer;
            }
            
            // 计算本地包围盒
            CalculateLocalBounds();
        }
        
        private void OnEnable()
        {
            if (_enableCulling && HizSystem.Instance != null)
            {
                HizSystem.Instance.RegisterCullingObject(this);
            }
        }
        
        private void OnDisable()
        {
            // 确保对象在禁用时恢复可见
            if (!_wasVisible)
            {
                ApplyCullingState(false);
                _wasVisible = true;
            }
            
            if (HizSystem.Instance != null)
            {
                HizSystem.Instance.UnregisterCullingObject(this);
            }
        }
        
        private void OnDestroy()
        {
            if (!_wasVisible)
            {
                ApplyCullingState(false);
            }
        }
        
        private void Update()
        {
            // 可选：每帧更新包围盒（如果对象在移动）
            // 注意：这会带来性能开销，建议在必要时才启用
        }
        
        #endregion
        
        #region 工具方法
        
        private void CalculateLocalBounds()
        {
            _localBounds = new Bounds(Vector3.zero, Vector3.one);
            
            // 尝试从各种组件获取包围盒
            if (_renderer != null)
            {
                _localBounds = _renderer.bounds;
                _localBounds.center = _transform.InverseTransformPoint(_localBounds.center);
                _localBounds.size = Vector3.Scale(_localBounds.size, _transform.localScale);
            }
            else
            {
                // 尝试从Collider获取
                Collider col = GetComponent<Collider>();
                if (col != null)
                {
                    _localBounds = col.bounds;
                    _localBounds.center = _transform.InverseTransformPoint(_localBounds.center);
                    _localBounds.size = Vector3.Scale(_localBounds.size, _transform.localScale);
                }
            }
            
            // 应用padding
            _localBounds.Expand(_boundsPadding * 2);
        }
        
        private Bounds GetWorldBounds()
        {
            Bounds worldBounds = _localBounds;
            worldBounds.center = _transform.TransformPoint(_localBounds.center);
            worldBounds.size = Vector3.Scale(_localBounds.size, _transform.lossyScale);
            return worldBounds;
        }
        
        private void ApplyCullingState(bool culled)
        {
            switch (_cullingMode)
            {
                case CullingMode.DisableRenderer:
                    if (_renderer != null)
                    {
                        _renderer.enabled = !culled;
                    }
                    break;
                    
                case CullingMode.ChangeLayer:
                    if (culled)
                    {
                        gameObject.layer = 31; // 使用31层作为剔除层（假设相机不渲染这个层）
                    }
                    else
                    {
                        gameObject.layer = _actualOriginalLayer;
                    }
                    break;
                    
                case CullingMode.SetScaleZero:
                    if (culled)
                    {
                        _transform.localScale = Vector3.zero;
                    }
                    else
                    {
                        _transform.localScale = _originalScale;
                    }
                    break;
                    
                case CullingMode.DisableGameObject:
                    gameObject.SetActive(!culled);
                    break;
            }
        }
        
        #endregion
        
        #region Gizmos
        
        private void OnDrawGizmosSelected()
        {
            if (!Application.isPlaying)
            {
                CalculateLocalBounds();
            }
            
            Bounds bounds = GetWorldBounds();
            
            // 根据剔除状态选择颜色
            if (_wasVisible)
            {
                Gizmos.color = new Color(0, 1, 0, 0.3f); // 绿色 = 可见
            }
            else
            {
                Gizmos.color = new Color(1, 0, 0, 0.3f); // 红色 = 被剔除
            }
            
            Gizmos.DrawWireCube(bounds.center, bounds.size);
            Gizmos.DrawCube(bounds.center, bounds.size * 0.95f);
        }
        
        #endregion
    }
}

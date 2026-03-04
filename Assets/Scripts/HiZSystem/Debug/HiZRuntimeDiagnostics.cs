using System.Collections;
using System.Text;
using UnityEngine;
using UnityEngine.UI;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ运行时诊断工具
    /// 附加到场景中的GameObject以进行实时诊断
    /// </summary>
    public class HiZRuntimeDiagnostics : MonoBehaviour
    {
        [Header("诊断设置")]
        [Tooltip("是否自动在启动时运行诊断")]
        public bool runOnStart = true;
        
        [Tooltip("诊断间隔（秒）")]
        public float diagnosticInterval = 5f;
        
        [Header("可视化")]
        [Tooltip("显示深度金字塔的RawImage")]
        public RawImage visualizationImage;
        
        [Tooltip("显示诊断信息的Text")]
        public Text diagnosticText;
        
        // 组件引用
        private HizSystem _hizSystem;
        private HizDepthPyramid _depthPyramid;
        private bool _isRunning;
        
        void Start()
        {
            if (runOnStart)
            {
                StartCoroutine(RunDiagnostics());
            }
        }
        
        void OnDestroy()
        {
            _isRunning = false;
            StopAllCoroutines();
        }
        
        /// <summary>
        /// 运行诊断协程
        /// </summary>
        IEnumerator RunDiagnostics()
        {
            _isRunning = true;
            
            // 等待HiZ系统初始化
            yield return new WaitForSeconds(1f);
            
            while (_isRunning)
            {
                // 查找HiZ系统
                FindHiZSystem();
                
                if (_depthPyramid != null)
                {
                    // 运行坐标验证
                    RunCoordValidation();
                    
                    // 运行深度分析
                    yield return StartCoroutine(RunDepthAnalysis());
                    
                    // 更新可视化
                    yield return StartCoroutine(UpdateVisualization());
                }
                else
                {
                    LogMessage("HiZ系统未找到或未初始化");
                }
                
                yield return new WaitForSeconds(diagnosticInterval);
            }
        }
        
        /// <summary>
        /// 查找HiZ系统组件
        /// </summary>
        void FindHiZSystem()
        {
            if (_hizSystem == null)
            {
                _hizSystem = FindObjectOfType<HizSystem>();
            }
            
            if (_hizSystem != null && _depthPyramid == null)
            {
                // 通过反射获取私有字段
                var field = typeof(HizSystem).GetField("_depthPyramid", 
                    System.Reflection.BindingFlags.NonPublic | 
                    System.Reflection.BindingFlags.Instance);
                
                if (field != null)
                {
                    _depthPyramid = field.GetValue(_hizSystem) as HizDepthPyramid;
                }
            }
        }
        
        /// <summary>
        /// 运行坐标验证
        /// </summary>
        void RunCoordValidation()
        {
            // 获取基础尺寸
            var baseSizeField = typeof(HizDepthPyramid).GetField("_baseSize",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            var mipCountField = typeof(HizDepthPyramid).GetField("_mipCount",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            if (baseSizeField != null && mipCountField != null)
            {
                var baseSize = (Unity.Mathematics.int2)baseSizeField.GetValue(_depthPyramid);
                int mipCount = (int)mipCountField.GetValue(_depthPyramid);
                
                string result = HiZDiagnosticUtility.ValidateCoordCalculation(
                    baseSize.x, baseSize.y, mipCount);
                
                LogMessage(result);
            }
        }
        
        /// <summary>
        /// 运行深度分析
        /// </summary>
        IEnumerator RunDepthAnalysis()
        {
            var textureField = typeof(HizDepthPyramid).GetField("_depthPyramidTexture",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            var baseSizeField = typeof(HizDepthPyramid).GetField("_baseSize",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            var mipCountField = typeof(HizDepthPyramid).GetField("_mipCount",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            if (textureField != null && baseSizeField != null && mipCountField != null)
            {
                var texture = (RenderTexture)textureField.GetValue(_depthPyramid);
                var baseSize = (Unity.Mathematics.int2)baseSizeField.GetValue(_depthPyramid);
                int mipCount = (int)mipCountField.GetValue(_depthPyramid);
                
                string result = null;
                yield return StartCoroutine(HiZDiagnosticUtility.AnalyzeDepthPyramid(
                    texture, baseSize.x, baseSize.y, mipCount,
                    r => result = r));
                
                LogMessage(result);
            }
        }
        
        /// <summary>
        /// 更新可视化
        /// </summary>
        IEnumerator UpdateVisualization()
        {
            if (visualizationImage == null) yield break;
            
            var textureField = typeof(HizDepthPyramid).GetField("_depthPyramidTexture",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            var baseSizeField = typeof(HizDepthPyramid).GetField("_baseSize",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            var mipCountField = typeof(HizDepthPyramid).GetField("_mipCount",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance);
            
            if (textureField != null && baseSizeField != null && mipCountField != null)
            {
                var texture = (RenderTexture)textureField.GetValue(_depthPyramid);
                var baseSize = (Unity.Mathematics.int2)baseSizeField.GetValue(_depthPyramid);
                int mipCount = (int)mipCountField.GetValue(_depthPyramid);
                
                Texture2D visTex = null;
                yield return StartCoroutine(HiZDiagnosticUtility.CreateVisualizationTexture(
                    texture, baseSize.x, baseSize.y, mipCount,
                    t => visTex = t));
                
                if (visTex != null)
                {
                    visualizationImage.texture = visTex;
                    visualizationImage.SetNativeSize();
                }
            }
        }
        
        /// <summary>
        /// 记录消息
        /// </summary>
        void LogMessage(string message)
        {
            Debug.Log($"[HiZ Diagnostics] {message}");
            
            if (diagnosticText != null)
            {
                diagnosticText.text = message;
            }
        }
        
        #region 公共方法
        
        [ContextMenu("立即运行诊断")]
        public void RunDiagnosticsNow()
        {
            StartCoroutine(RunDiagnostics());
        }
        
        [ContextMenu("停止诊断")]
        public void StopDiagnostics()
        {
            _isRunning = false;
            StopAllCoroutines();
        }
        
        #endregion
    }
}

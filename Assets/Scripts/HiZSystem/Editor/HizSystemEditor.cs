#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

namespace HiZTechnique.Editor
{
    /// <summary>
    /// HiZ系统编辑器
    /// </summary>
    [CustomEditor(typeof(HizSystem))]
    public class HizSystemEditor : UnityEditor.Editor
    {
        private SerializedProperty _settings;
        private SerializedProperty _depthPyramidComputeShader;
        private SerializedProperty _depthBlitFallbackShader;
        
        private bool _showSettings = true;
        private bool _showShaders = true;
        private bool _showPlatformInfo = true;
        private bool _showRuntimeControl = true;
        
        private void OnEnable()
        {
            _settings = serializedObject.FindProperty("_settings");
            _depthPyramidComputeShader = serializedObject.FindProperty("_depthPyramidComputeShader");
            _depthBlitFallbackShader = serializedObject.FindProperty("_depthBlitFallbackShader");
        }
        
        public override void OnInspectorGUI()
        {
            serializedObject.Update();
            
            var hizSystem = target as HizSystem;
            
            // 标题
            EditorGUILayout.Space();
            EditorGUILayout.LabelField("HiZ Depth Pyramid System", EditorStyles.boldLabel);
            EditorGUILayout.Space();
            
            // 状态显示
            DrawStatus(hizSystem);
            
            EditorGUILayout.Space();
            
            // 运行时控制
            _showRuntimeControl = EditorGUILayout.Foldout(_showRuntimeControl, "运行时控制", true);
            if (_showRuntimeControl && Application.isPlaying)
            {
                EditorGUI.indentLevel++;
                DrawRuntimeControl(hizSystem);
                EditorGUI.indentLevel--;
            }
            
            EditorGUILayout.Space();
            
            // 设置
            _showSettings = EditorGUILayout.Foldout(_showSettings, "HiZ设置", true);
            if (_showSettings)
            {
                EditorGUI.indentLevel++;
                DrawSettings();
                EditorGUI.indentLevel--;
            }
            
            EditorGUILayout.Space();
            
            // Shader设置
            _showShaders = EditorGUILayout.Foldout(_showShaders, "Shader设置", true);
            if (_showShaders)
            {
                EditorGUI.indentLevel++;
                DrawShaderSettings();
                EditorGUI.indentLevel--;
            }
            
            EditorGUILayout.Space();
            
            // 平台信息
            _showPlatformInfo = EditorGUILayout.Foldout(_showPlatformInfo, "平台信息", true);
            if (_showPlatformInfo)
            {
                EditorGUI.indentLevel++;
                DrawPlatformInfo();
                EditorGUI.indentLevel--;
            }
            
            serializedObject.ApplyModifiedProperties();
        }
        
        private void DrawStatus(HizSystem hizSystem)
        {
            EditorGUILayout.BeginVertical("box");
            
            EditorGUILayout.LabelField("系统状态", EditorStyles.boldLabel);
            
            if (Application.isPlaying)
            {
                var state = hizSystem.State;
                Color stateColor = GetStateColor(state);
                
                GUI.color = stateColor;
                EditorGUILayout.LabelField("当前状态", state.ToString(), EditorStyles.boldLabel);
                GUI.color = Color.white;
            }
            else
            {
                EditorGUILayout.HelpBox("进入Play模式查看运行时状态", MessageType.Info);
            }
            
            EditorGUILayout.EndVertical();
        }
        
        private void DrawRuntimeControl(HizSystem hizSystem)
        {
            EditorGUILayout.BeginVertical("box");
            
            if (hizSystem.IsActive)
            {
                if (GUILayout.Button("禁用HiZ系统"))
                {
                    hizSystem.DisableSystem();
                }
            }
            else if (hizSystem.State == HizSystemState.Ready)
            {
                if (GUILayout.Button("启用HiZ系统"))
                {
                    hizSystem.EnableSystem();
                }
            }
            else
            {
                EditorGUILayout.HelpBox($"当前状态无法启用: {hizSystem.State}", MessageType.Warning);
            }
            
            if (GUILayout.Button("重启系统"))
            {
                hizSystem.RestartSystem();
            }
            
            EditorGUILayout.EndVertical();
        }
        
        private void DrawSettings()
        {
            EditorGUILayout.BeginVertical("box");
            
            // 基本设置
            var enableHiz = _settings.FindPropertyRelative("enableHiz");
            EditorGUILayout.PropertyField(enableHiz, new GUIContent("启用HiZ", "是否启用HiZ系统"));
            
            if (enableHiz.boolValue)
            {
                EditorGUILayout.PropertyField(_settings.FindPropertyRelative("runtimeToggle"), 
                    new GUIContent("运行时开关", "允许运行时动态开关"));
                
                EditorGUILayout.Space();
                EditorGUILayout.LabelField("深度金字塔设置", EditorStyles.boldLabel);
                
                EditorGUILayout.PropertyField(_settings.FindPropertyRelative("maxMipLevel"), 
                    new GUIContent("最大Mip级别", "深度金字塔的最大层级"));
                EditorGUILayout.PropertyField(_settings.FindPropertyRelative("baseResolution"), 
                    new GUIContent("基础分辨率", "深度金字塔的基础分辨率"));
                EditorGUILayout.PropertyField(_settings.FindPropertyRelative("depthFormat"), 
                    new GUIContent("深度格式", "RFloat精度高，RHalf性能好"));
                
                EditorGUILayout.Space();
                EditorGUILayout.LabelField("平台适配", EditorStyles.boldLabel);
                
                EditorGUILayout.PropertyField(_settings.FindPropertyRelative("autoAdjustForPlatform"), 
                    new GUIContent("自动适配平台", "根据平台自动调整设置"));
                EditorGUILayout.PropertyField(_settings.FindPropertyRelative("lowEndMobileFallback"), 
                    new GUIContent("低端设备降级", "低端移动设备自动降级"));
                
                EditorGUILayout.Space();
                EditorGUILayout.LabelField("Debug", EditorStyles.boldLabel);
                
                EditorGUILayout.PropertyField(_settings.FindPropertyRelative("enableDebug"), 
                    new GUIContent("启用Debug", "显示调试信息"));
            }
            
            EditorGUILayout.EndVertical();
        }
        
        private void DrawShaderSettings()
        {
            EditorGUILayout.BeginVertical("box");
            
            EditorGUILayout.PropertyField(_depthPyramidComputeShader, 
                new GUIContent("深度金字塔CS", "用于生成深度金字塔的Compute Shader"));
            
            EditorGUILayout.PropertyField(_depthBlitFallbackShader, 
                new GUIContent("Fallback Shader", "当Compute Shader不支持时使用"));
            
            EditorGUILayout.EndVertical();
            
            EditorGUILayout.Space();
            
            // 快速设置按钮
            EditorGUILayout.LabelField("快速设置", EditorStyles.boldLabel);
            
            if (GUILayout.Button("自动查找Shader资源"))
            {
                AutoFindShaders();
            }
        }
        
        private void DrawPlatformInfo()
        {
            EditorGUILayout.BeginVertical("box");
            
            EditorGUILayout.LabelField("当前平台信息", EditorStyles.boldLabel);
            
            EditorGUILayout.LabelField("图形API", SystemInfo.graphicsDeviceType.ToString());
            EditorGUILayout.LabelField("Compute Shader支持", SystemInfo.supportsComputeShaders ? "是" : "否");
            EditorGUILayout.LabelField("Reversed Z", HizPlatformCompatibility.UsesReversedZ() ? "是" : "否");
            EditorGUILayout.LabelField("移动端", HizPlatformCompatibility.IsMobilePlatform() ? "是" : "否");
            EditorGUILayout.LabelField("低端设备", HizPlatformCompatibility.IsLowEndMobileDevice() ? "是" : "否");
            
            EditorGUILayout.Space();
            
            EditorGUILayout.LabelField("系统信息", EditorStyles.boldLabel);
            EditorGUILayout.LabelField("GPU", SystemInfo.graphicsDeviceName);
            EditorGUILayout.LabelField("Shader Level", SystemInfo.graphicsShaderLevel.ToString());
            EditorGUILayout.LabelField("最大纹理尺寸", SystemInfo.maxTextureSize.ToString());
            EditorGUILayout.LabelField("处理器数量", SystemInfo.processorCount.ToString());
            EditorGUILayout.LabelField("内存大小", $"{SystemInfo.systemMemorySize} MB");
            
            EditorGUILayout.EndVertical();
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
        
        private void AutoFindShaders()
        {
            // 查找Compute Shader
            string[] guids = AssetDatabase.FindAssets("t:ComputeShader HiZ");
            foreach (string guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                ComputeShader cs = AssetDatabase.LoadAssetAtPath<ComputeShader>(path);
                
                if (cs != null)
                {
                    if (path.Contains("DepthPyramid") || path.Contains("Mipmap"))
                    {
                        _depthPyramidComputeShader.objectReferenceValue = cs;
                    }
                }
            }
            
            // 查找Shader
            guids = AssetDatabase.FindAssets("t:Shader HiZ");
            foreach (string guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(path);
                
                if (shader != null && path.Contains("DepthBlit"))
                {
                    _depthBlitFallbackShader.objectReferenceValue = shader;
                }
            }
            
            serializedObject.ApplyModifiedProperties();
            
            EditorUtility.DisplayDialog("自动查找完成", 
                "已尝试查找并设置HiZ相关Shader资源。请检查设置是否正确。", "确定");
        }
        
        [MenuItem("GameObject/HiZ System/Create HiZ System", false, 10)]
        private static void CreateHizSystem()
        {
            // 检查是否已存在
            if (FindObjectOfType<HizSystem>() != null)
            {
                EditorUtility.DisplayDialog("错误", "场景中已存在HiZSystem！", "确定");
                return;
            }
            
            GameObject go = new GameObject("HiZ System");
            go.AddComponent<HizSystem>();
            
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
        }
    }
}
#endif

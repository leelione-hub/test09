#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

namespace VegetationSystem.HiZIntegration.Editor
{
    /// <summary>
    /// VegetationHizIntegrator编辑器
    /// </summary>
    [CustomEditor(typeof(VegetationHizIntegrator))]
    public class VegetationHizIntegratorEditor : UnityEditor.Editor
    {
        private SerializedProperty _enableHiZCulling;
        private SerializedProperty _cullingMode;
        private SerializedProperty _depthBias;
        private SerializedProperty _cullingFrameInterval;
        private SerializedProperty _boundsPadding;
        private SerializedProperty _showDebugInfo;
        private SerializedProperty _showCulledChunks;

        private void OnEnable()
        {
            _enableHiZCulling = serializedObject.FindProperty("_enableHiZCulling");
            _cullingMode = serializedObject.FindProperty("_cullingMode");
            _depthBias = serializedObject.FindProperty("_depthBias");
            _cullingFrameInterval = serializedObject.FindProperty("_cullingFrameInterval");
            _boundsPadding = serializedObject.FindProperty("_boundsPadding");
            _showDebugInfo = serializedObject.FindProperty("_showDebugInfo");
            _showCulledChunks = serializedObject.FindProperty("_showCulledChunks");
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Vegetation HiZ Integration", EditorStyles.boldLabel);
            EditorGUILayout.Space();

            // HiZ系统状态检查
            DrawHiZSystemStatus();

            EditorGUILayout.Space();

            // 设置
            EditorGUILayout.LabelField("设置", EditorStyles.boldLabel);
            EditorGUILayout.PropertyField(_enableHiZCulling, new GUIContent("启用HiZ剔除"));
            
            if (_enableHiZCulling.boolValue)
            {
                EditorGUI.indentLevel++;
                
                EditorGUILayout.PropertyField(_cullingMode, new GUIContent("剔除模式"));
                
                EditorGUILayout.PropertyField(_depthBias, new GUIContent("深度偏差"));
                EditorGUILayout.HelpBox("深度偏差用于防止Z-fighting导致的闪烁问题。如果植被闪烁，请增加此值。", MessageType.Info);
                
                EditorGUILayout.PropertyField(_cullingFrameInterval, new GUIContent("剔除频率"));
                EditorGUILayout.HelpBox("每N帧执行一次HiZ剔除。增加此值可以提高性能，但会降低剔除响应速度。", MessageType.Info);
                
                EditorGUILayout.PropertyField(_boundsPadding, new GUIContent("包围盒扩展"));
                
                EditorGUI.indentLevel--;
            }

            EditorGUILayout.Space();

            // 调试
            EditorGUILayout.LabelField("调试", EditorStyles.boldLabel);
            EditorGUILayout.PropertyField(_showDebugInfo, new GUIContent("显示调试信息"));
            EditorGUILayout.PropertyField(_showCulledChunks, new GUIContent("显示被剔除的Chunk"));

            EditorGUILayout.Space();

            // 快速操作
            DrawQuickActions();

            serializedObject.ApplyModifiedProperties();
        }

        private void DrawHiZSystemStatus()
        {
            EditorGUILayout.BeginVertical("box");
            EditorGUILayout.LabelField("HiZ系统状态", EditorStyles.boldLabel);

            var hizSystem = HiZTechnique.HizSystem.Instance;
            if (hizSystem == null)
            {
                EditorGUILayout.HelpBox("HiZ系统未找到！请确保场景中存在HiZSystem。", MessageType.Error);
            }
            else
            {
                var state = hizSystem.State;
                Color stateColor = GetStateColor(state);
                
                GUI.color = stateColor;
                EditorGUILayout.LabelField("状态", state.ToString(), EditorStyles.boldLabel);
                GUI.color = Color.white;

                if (state != HiZTechnique.HizSystemState.Active)
                {
                    EditorGUILayout.HelpBox("HiZ系统未激活。请启用HiZSystem或检查设置。", MessageType.Warning);
                }
                else
                {
                    // 显示统计
                    var stats = hizSystem.CurrentStats;
                    if (stats != null)
                    {
                        EditorGUILayout.LabelField($"可见/总数: {stats.visibleInstances}/{stats.totalInstances}");
                        EditorGUILayout.LabelField($"剔除率: {stats.CullingRatio:P1}");
                    }
                }
            }

            EditorGUILayout.EndVertical();
        }

        private void DrawQuickActions()
        {
            EditorGUILayout.LabelField("快速操作", EditorStyles.boldLabel);

            EditorGUILayout.BeginHorizontal();
            
            if (GUILayout.Button("创建HiZ系统"))
            {
                CreateHiZSystem();
            }
            
            if (GUILayout.Button("查找HiZ Shader"))
            {
                FindHiZShaders();
            }
            
            EditorGUILayout.EndHorizontal();
        }

        private Color GetStateColor(HiZTechnique.HizSystemState state)
        {
            switch (state)
            {
                case HiZTechnique.HizSystemState.Active:
                    return Color.green;
                case HiZTechnique.HizSystemState.Ready:
                    return Color.yellow;
                case HiZTechnique.HizSystemState.Error:
                case HiZTechnique.HizSystemState.PlatformNotSupported:
                    return Color.red;
                default:
                    return Color.gray;
            }
        }

        private void CreateHiZSystem()
        {
            if (HiZTechnique.HizSystem.Instance != null)
            {
                EditorUtility.DisplayDialog("提示", "场景中已存在HiZSystem！", "确定");
                return;
            }

            GameObject go = new GameObject("HiZ System");
            go.AddComponent<HiZTechnique.HizSystem>();
            
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
            
            EditorUtility.DisplayDialog("完成", "HiZ系统已创建。请配置Shader资源。", "确定");
        }

        private void FindHiZShaders()
        {
            string[] guids = AssetDatabase.FindAssets("t:ComputeShader VegetationHiZ");
            
            if (guids.Length == 0)
            {
                EditorUtility.DisplayDialog("未找到", "未找到VegetationHiZ.compute文件。请确保文件存在。", "确定");
                return;
            }

            string path = AssetDatabase.GUIDToAssetPath(guids[0]);
            var shader = AssetDatabase.LoadAssetAtPath<ComputeShader>(path);
            
            if (shader != null)
            {
                // 找到VegetationSystemObjectHiZ组件并赋值
                var targetComponent = target as VegetationHizIntegrator;
                var vegSystem = targetComponent.GetComponent<VegetationSystemObjectHiZ>();
                
                if (vegSystem != null)
                {
                    // 通过反射设置（因为字段可能是私有的）
                    var field = vegSystem.GetType().GetField("_hizCullingComputeShader",
                        System.Reflection.BindingFlags.NonPublic |
                        System.Reflection.BindingFlags.Instance);
                    
                    if (field != null)
                    {
                        field.SetValue(vegSystem, shader);
                        EditorUtility.SetDirty(vegSystem);
                    }
                }
                
                EditorGUIUtility.PingObject(shader);
                EditorUtility.DisplayDialog("找到", $"已找到并设置: {path}", "确定");
            }
        }

        [MenuItem("GameObject/Vegetation System/Add HiZ Integration", false, 10)]
        private static void AddHiZIntegration()
        {
            var selected = Selection.activeGameObject;
            if (selected == null)
            {
                EditorUtility.DisplayDialog("错误", "请先选择一个带有VegetationSystemObject的游戏对象", "确定");
                return;
            }

            var vegSystem = selected.GetComponent<VegetationSystemObject>();
            if (vegSystem == null)
            {
                EditorUtility.DisplayDialog("错误", "选中的对象没有VegetationSystemObject组件", "确定");
                return;
            }

            // 检查是否已有HiZ集成
            var existingIntegrator = selected.GetComponent<VegetationHizIntegrator>();
            if (existingIntegrator != null)
            {
                EditorUtility.DisplayDialog("提示", "该对象已存在HiZ集成组件", "确定");
                return;
            }

            // 添加组件
            selected.AddComponent<VegetationHizIntegrator>();
            
            EditorUtility.DisplayDialog("完成", "HiZ集成组件已添加", "确定");
        }
    }
}
#endif

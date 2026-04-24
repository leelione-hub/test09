using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public class TerrainSplatTreePainterWindow : EditorWindow
{
    private enum SplatChannel
    {
        R = 0,
        G = 1,
        B = 2,
        A = 3,
    }

    private Terrain _terrain;
    private int _controlTextureIndex;
    private SplatChannel _channel = SplatChannel.R;
    private Vector2 _thresholdRange = new Vector2(0.5f, 1.0f);
    private float _density = 0.35f;
    private int _samplesPerPixel = 4;
    private int _treePrototypeIndex;
    private int _randomSeed = 12345;
    private bool _randomRotation = true;
    private Vector2 _widthScaleRange = Vector2.one;
    private Vector2 _heightScaleRange = Vector2.one;

    [MenuItem("Tools/Vegetation/Terrain Splat Tree Painter")]
    private static void OpenWindow()
    {
        GetWindow<TerrainSplatTreePainterWindow>("Splat Tree Painter");
    }

    private void OnEnable()
    {
        if (_terrain == null && Selection.activeGameObject != null)
        {
            _terrain = Selection.activeGameObject.GetComponent<Terrain>();
        }
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Terrain", EditorStyles.boldLabel);
        using (new EditorGUI.ChangeCheckScope())
        {
            _terrain = (Terrain)EditorGUILayout.ObjectField("Target Terrain", _terrain, typeof(Terrain), true);
            if (_terrain != null && _terrain.terrainData != null)
            {
                int maxControlIndex = Mathf.Max(0, GetControlTextureCount(_terrain.terrainData) - 1);
                _controlTextureIndex = EditorGUILayout.IntSlider("Control Texture", _controlTextureIndex, 0, maxControlIndex);
                _channel = (SplatChannel)EditorGUILayout.EnumPopup("Channel", _channel);
                _thresholdRange = DrawNormalizedRangeField("Threshold Range", _thresholdRange);
                _density = EditorGUILayout.Slider("Density", _density, 0f, 1f);
                _samplesPerPixel = EditorGUILayout.IntSlider("Samples Per Pixel", _samplesPerPixel, 1, 64);
            }
        }

        EditorGUILayout.Space(6f);
        DrawTreePrototypeSection();

        EditorGUILayout.Space(6f);
        EditorGUILayout.LabelField("Placement", EditorStyles.boldLabel);
        _randomSeed = EditorGUILayout.IntField("Random Seed", _randomSeed);
        _randomRotation = EditorGUILayout.Toggle("Random Rotation", _randomRotation);
        _widthScaleRange = DrawMinMaxField("Width Scale", _widthScaleRange, 0.01f);
        _heightScaleRange = DrawMinMaxField("Height Scale", _heightScaleRange, 0.01f);

        EditorGUILayout.Space(10f);
        using (new EditorGUI.DisabledScope(!CanGenerate()))
        {
            if (GUILayout.Button("Generate Trees", GUILayout.Height(32f)))
            {
                GenerateTrees();
            }
        }

        EditorGUILayout.Space(4f);
        using (new EditorGUI.DisabledScope(_terrain == null || _terrain.terrainData == null || _terrain.terrainData.treeInstances.Length == 0))
        {
            if (GUILayout.Button("Clear All Trees", GUILayout.Height(26f)))
            {
                ClearAllTrees();
            }
        }

        DrawHelpBox();
    }

    private void DrawTreePrototypeSection()
    {
        EditorGUILayout.LabelField("Tree Type", EditorStyles.boldLabel);

        if (_terrain == null || _terrain.terrainData == null)
        {
            EditorGUILayout.HelpBox("Select a Terrain first.", MessageType.Info);
            return;
        }

        TreePrototype[] prototypes = _terrain.terrainData.treePrototypes;
        if (prototypes == null || prototypes.Length == 0)
        {
            EditorGUILayout.HelpBox("This Terrain has no Tree Prototypes.", MessageType.Warning);
            return;
        }

        _treePrototypeIndex = Mathf.Clamp(_treePrototypeIndex, 0, prototypes.Length - 1);

        string[] prototypeOptions = new string[prototypes.Length];
        for (int i = 0; i < prototypes.Length; i++)
        {
            prototypeOptions[i] = BuildPrototypeLabel(prototypes[i], i);
        }

        _treePrototypeIndex = EditorGUILayout.Popup("Tree Prototype", _treePrototypeIndex, prototypeOptions);
    }

    private void DrawHelpBox()
    {
        if (_terrain == null)
        {
            EditorGUILayout.HelpBox("Pick a Terrain, then choose the control texture index, RGBA channel, density, and target Tree Prototype.", MessageType.Info);
            return;
        }

        TerrainData terrainData = _terrain.terrainData;
        if (terrainData == null)
        {
            EditorGUILayout.HelpBox("The selected Terrain is missing TerrainData.", MessageType.Error);
            return;
        }

        int layerIndex = _controlTextureIndex * 4 + (int)_channel;
        string layerName = ResolveLayerName(terrainData, layerIndex);
        EditorGUILayout.HelpBox(
            $"Current target: Control {_controlTextureIndex} / {_channel} channel / threshold range {_thresholdRange.x:F2} ~ {_thresholdRange.y:F2}\n" +
            $"Resolved terrain layer index: {layerIndex} ({layerName})\n" +
            $"Each valid alphamap pixel tests {_samplesPerPixel} placement samples.\n" +
            $"Generation appends new trees to existing Terrain tree instances.",
            MessageType.None);
    }

    private bool CanGenerate()
    {
        if (_terrain == null || _terrain.terrainData == null)
        {
            return false;
        }

        TreePrototype[] prototypes = _terrain.terrainData.treePrototypes;
        if (prototypes == null || prototypes.Length == 0)
        {
            return false;
        }

        return _treePrototypeIndex >= 0 && _treePrototypeIndex < prototypes.Length;
    }

    private void GenerateTrees()
    {
        TerrainData terrainData = _terrain.terrainData;
        if (terrainData == null)
        {
            Debug.LogError("[TerrainSplatTreePainter] Selected Terrain has no TerrainData.");
            return;
        }

        int layerIndex = _controlTextureIndex * 4 + (int)_channel;
        if (layerIndex < 0 || layerIndex >= terrainData.alphamapLayers)
        {
            Debug.LogError($"[TerrainSplatTreePainter] Invalid layer index {layerIndex}. Terrain only has {terrainData.alphamapLayers} alphamap layers.", _terrain);
            return;
        }

        _thresholdRange.x = Mathf.Clamp01(_thresholdRange.x);
        _thresholdRange.y = Mathf.Clamp(_thresholdRange.y, _thresholdRange.x, 1f);

        TreePrototype[] prototypes = terrainData.treePrototypes;
        if (prototypes == null || prototypes.Length == 0)
        {
            Debug.LogError("[TerrainSplatTreePainter] Terrain has no Tree Prototypes.", _terrain);
            return;
        }

        if (_treePrototypeIndex < 0 || _treePrototypeIndex >= prototypes.Length)
        {
            Debug.LogError($"[TerrainSplatTreePainter] Invalid Tree Prototype index {_treePrototypeIndex}.", _terrain);
            return;
        }

        float[,,] alphaMaps = terrainData.GetAlphamaps(0, 0, terrainData.alphamapWidth, terrainData.alphamapHeight);
        List<TreeInstance> generatedTrees = BuildTreesFromAlphaMap(terrainData, alphaMaps, layerIndex);
        if (generatedTrees.Count == 0)
        {
            Debug.LogWarning("[TerrainSplatTreePainter] No trees were generated. Try lowering the threshold or increasing the density.", _terrain);
            return;
        }

        Undo.RegisterCompleteObjectUndo(terrainData, "Generate Terrain Trees From Splat");

        TreeInstance[] existingTrees = terrainData.treeInstances;
        TreeInstance[] mergedTrees = new TreeInstance[existingTrees.Length + generatedTrees.Count];
        Array.Copy(existingTrees, mergedTrees, existingTrees.Length);
        for (int i = 0; i < generatedTrees.Count; i++)
        {
            mergedTrees[existingTrees.Length + i] = generatedTrees[i];
        }

        terrainData.treeInstances = mergedTrees;
        EditorUtility.SetDirty(terrainData);
        EditorSceneManager.MarkSceneDirty(_terrain.gameObject.scene);
        _terrain.Flush();

        string prototypeLabel = BuildPrototypeLabel(prototypes[_treePrototypeIndex], _treePrototypeIndex);
        Debug.Log(
            $"[TerrainSplatTreePainter] Added {generatedTrees.Count} trees on '{_terrain.name}'. " +
            $"Prototype: {prototypeLabel}, Control: {_controlTextureIndex}, Channel: {_channel}, ThresholdRange: {_thresholdRange.x:F2}~{_thresholdRange.y:F2}, Density: {_density:F2}, SamplesPerPixel: {_samplesPerPixel}.",
            _terrain);
    }

    private void ClearAllTrees()
    {
        TerrainData terrainData = _terrain != null ? _terrain.terrainData : null;
        if (terrainData == null)
        {
            Debug.LogError("[TerrainSplatTreePainter] Selected Terrain has no TerrainData.");
            return;
        }

        int existingCount = terrainData.treeInstances.Length;
        if (existingCount == 0)
        {
            Debug.LogWarning("[TerrainSplatTreePainter] Terrain has no tree instances to clear.", _terrain);
            return;
        }

        if (!EditorUtility.DisplayDialog(
                "Clear All Terrain Trees",
                $"This will remove all {existingCount} tree instances from '{_terrain.name}'.\n\nThis action can be undone with Ctrl+Z.",
                "Clear",
                "Cancel"))
        {
            return;
        }

        Undo.RegisterCompleteObjectUndo(terrainData, "Clear All Terrain Trees");
        terrainData.treeInstances = Array.Empty<TreeInstance>();
        EditorUtility.SetDirty(terrainData);
        EditorSceneManager.MarkSceneDirty(_terrain.gameObject.scene);
        _terrain.Flush();

        Debug.Log($"[TerrainSplatTreePainter] Cleared {existingCount} tree instances from '{_terrain.name}'.", _terrain);
    }

    private List<TreeInstance> BuildTreesFromAlphaMap(TerrainData terrainData, float[,,] alphaMaps, int layerIndex)
    {
        int width = terrainData.alphamapWidth;
        int height = terrainData.alphamapHeight;
        Vector3 terrainSize = terrainData.size;
        System.Random random = new System.Random(_randomSeed);
        List<TreeInstance> trees = new List<TreeInstance>();

        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                float weight = alphaMaps[y, x, layerIndex];
                if (weight < _thresholdRange.x || weight > _thresholdRange.y)
                {
                    continue;
                }

                for (int sampleIndex = 0; sampleIndex < _samplesPerPixel; sampleIndex++)
                {
                    if ((float)random.NextDouble() > _density)
                    {
                        continue;
                    }

                    float normalizedX = (x + (float)random.NextDouble()) / width;
                    float normalizedZ = (y + (float)random.NextDouble()) / height;
                    float heightWorld = terrainData.GetInterpolatedHeight(normalizedX, normalizedZ);
                    float normalizedY = terrainSize.y > 0.0001f ? heightWorld / terrainSize.y : 0f;

                    TreeInstance tree = new TreeInstance
                    {
                        position = new Vector3(normalizedX, normalizedY, normalizedZ),
                        prototypeIndex = _treePrototypeIndex,
                        widthScale = RandomRange(random, _widthScaleRange.x, _widthScaleRange.y),
                        heightScale = RandomRange(random, _heightScaleRange.x, _heightScaleRange.y),
                        rotation = _randomRotation ? Mathf.Lerp(0f, Mathf.PI * 2f, (float)random.NextDouble()) : 0f,
                        color = Color.white,
                        lightmapColor = Color.white,
                    };

                    trees.Add(tree);
                }
            }
        }

        return trees;
    }

    private static Vector2 DrawMinMaxField(string label, Vector2 range, float minValue)
    {
        float min = Mathf.Max(minValue, range.x);
        float max = Mathf.Max(min, range.y);

        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.PrefixLabel(label);
        min = EditorGUILayout.FloatField(min);
        max = EditorGUILayout.FloatField(max);
        EditorGUILayout.EndHorizontal();

        return new Vector2(Mathf.Max(minValue, min), Mathf.Max(min, max));
    }

    private static Vector2 DrawNormalizedRangeField(string label, Vector2 range)
    {
        float min = Mathf.Clamp01(range.x);
        float max = Mathf.Clamp(range.y, min, 1f);

        EditorGUILayout.LabelField(label);
        EditorGUILayout.MinMaxSlider(ref min, ref max, 0f, 1f);

        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.PrefixLabel("Range");
        min = EditorGUILayout.FloatField(min);
        max = EditorGUILayout.FloatField(max);
        EditorGUILayout.EndHorizontal();

        min = Mathf.Clamp01(min);
        max = Mathf.Clamp(max, min, 1f);
        return new Vector2(min, max);
    }

    private static int GetControlTextureCount(TerrainData terrainData)
    {
        Texture2D[] controlTextures = terrainData.alphamapTextures;
        if (controlTextures != null && controlTextures.Length > 0)
        {
            return controlTextures.Length;
        }

        return Mathf.Max(1, Mathf.CeilToInt(terrainData.alphamapLayers / 4f));
    }

    private static string BuildPrototypeLabel(TreePrototype prototype, int index)
    {
        string prefabName = prototype.prefab != null ? prototype.prefab.name : "Missing Prefab";
        return $"{index}: {prefabName}";
    }

    private static string ResolveLayerName(TerrainData terrainData, int layerIndex)
    {
        TerrainLayer[] layers = terrainData.terrainLayers;
        if (layers != null && layerIndex >= 0 && layerIndex < layers.Length && layers[layerIndex] != null)
        {
            return layers[layerIndex].name;
        }

        return "No TerrainLayer";
    }

    private static float RandomRange(System.Random random, float min, float max)
    {
        if (Mathf.Approximately(min, max))
        {
            return min;
        }

        return Mathf.Lerp(min, max, (float)random.NextDouble());
    }
}

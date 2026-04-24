using System.IO;
using UnityEditor;
using UnityEngine;

public sealed class ThicknessMapGeneratorWindow : EditorWindow
{
    private enum SourceChannel
    {
        Luminance,
        Alpha,
        Red,
        Green,
        Blue,
        AverageRGB
    }

    private Texture2D _sourceTexture;
    private int _width = 1024;
    private int _height = 1024;
    private SourceChannel _sourceChannel = SourceChannel.Luminance;
    private bool _invertSource = false;

    private float _sourceWeight = 0.65f;
    private float _edgeBoost = 0.35f;
    private float _edgePower = 1.5f;
    private float _centerDarken = 0.25f;
    private float _contrast = 1.0f;
    private float _bias = 0.0f;

    [MenuItem("Tools/Rendering/Thickness Map Generator")]
    private static void OpenWindow()
    {
        GetWindow<ThicknessMapGeneratorWindow>("Thickness Map Generator");
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Source", EditorStyles.boldLabel);
        _sourceTexture = (Texture2D)EditorGUILayout.ObjectField("Source Texture", _sourceTexture, typeof(Texture2D), false);
        _sourceChannel = (SourceChannel)EditorGUILayout.EnumPopup("Source Channel", _sourceChannel);
        _invertSource = EditorGUILayout.Toggle("Invert Source", _invertSource);

        EditorGUILayout.Space(6f);
        EditorGUILayout.LabelField("Output", EditorStyles.boldLabel);
        _width = EditorGUILayout.IntPopup("Width", _width, new[] { "256", "512", "1024", "2048" }, new[] { 256, 512, 1024, 2048 });
        _height = EditorGUILayout.IntPopup("Height", _height, new[] { "256", "512", "1024", "2048" }, new[] { 256, 512, 1024, 2048 });

        EditorGUILayout.Space(6f);
        EditorGUILayout.LabelField("Thickness Heuristic", EditorStyles.boldLabel);
        _sourceWeight = EditorGUILayout.Slider("Source Weight", _sourceWeight, 0f, 1f);
        _edgeBoost = EditorGUILayout.Slider("Edge Boost", _edgeBoost, 0f, 1f);
        _edgePower = EditorGUILayout.Slider("Edge Power", _edgePower, 0.25f, 6f);
        _centerDarken = EditorGUILayout.Slider("Center Darken", _centerDarken, 0f, 1f);
        _contrast = EditorGUILayout.Slider("Contrast", _contrast, 0.25f, 3f);
        _bias = EditorGUILayout.Slider("Bias", _bias, -1f, 1f);

        EditorGUILayout.Space(8f);
        EditorGUILayout.HelpBox(
            "这是基础版 UV 空间近似生成器，不是真实几何厚度烘焙。\n" +
            "它会把输入纹理信息和 UV 边缘距离组合成一张 thickness map：\n" +
            "白色 = 更薄 / 更容易透，黑色 = 更厚 / 更不容易透。\n" +
            "导入设置会自动改成 Linear / Clamp / Bilinear / No MipMaps。",
            MessageType.Info);

        EditorGUILayout.Space(10f);
        if (GUILayout.Button("Generate Thickness Map", GUILayout.Height(32f)))
        {
            GenerateAndSave();
        }
    }

    private void GenerateAndSave()
    {
        string defaultDirectory = "Assets/Shaders/SSS";
        string outputPath = EditorUtility.SaveFilePanelInProject(
            "Save Thickness Map",
            "Generated_ThicknessMap.png",
            "png",
            "Choose where to save the generated Thickness Map.",
            defaultDirectory);

        if (string.IsNullOrEmpty(outputPath))
        {
            return;
        }

        Texture2D texture = new(_width, _height, TextureFormat.RGBA32, false, true);
        try
        {
            for (int y = 0; y < _height; y++)
            {
                float v = _height > 1 ? y / (float)(_height - 1) : 0f;
                for (int x = 0; x < _width; x++)
                {
                    float u = _width > 1 ? x / (float)(_width - 1) : 0f;
                    float thickness = EvaluateThickness(u, v);
                    texture.SetPixel(x, y, new Color(thickness, thickness, thickness, 1f));
                }
            }

            texture.Apply(false, false);
            File.WriteAllBytes(outputPath, texture.EncodeToPNG());
        }
        finally
        {
            DestroyImmediate(texture);
        }

        AssetDatabase.ImportAsset(outputPath, ImportAssetOptions.ForceSynchronousImport);
        ConfigureImporter(outputPath);
        AssetDatabase.ImportAsset(outputPath, ImportAssetOptions.ForceSynchronousImport);

        Debug.Log($"[ThicknessMapGenerator] Generated thickness map: {outputPath}");
        Selection.activeObject = AssetDatabase.LoadAssetAtPath<Texture2D>(outputPath);
    }

    private float EvaluateThickness(float u, float v)
    {
        float sourceValue = SampleSource(u, v);

        float edgeDistance = Mathf.Min(Mathf.Min(u, 1f - u), Mathf.Min(v, 1f - v));
        float normalizedEdgeDistance = Mathf.Clamp01(edgeDistance / 0.5f);
        float edgeFactor = 1f - Mathf.Pow(normalizedEdgeDistance, _edgePower);

        float value = 0f;
        value += sourceValue * _sourceWeight;
        value += edgeFactor * _edgeBoost;
        value -= (1f - edgeFactor) * _centerDarken;

        value = Mathf.Clamp01(value + _bias);
        value = Mathf.Clamp01(Mathf.Pow(value, 1f / Mathf.Max(_contrast, 0.001f)));
        return value;
    }

    private float SampleSource(float u, float v)
    {
        if (_sourceTexture == null)
        {
            return 0.5f;
        }

        Color color = _sourceTexture.GetPixelBilinear(u, v);
        float value = _sourceChannel switch
        {
            SourceChannel.Alpha => color.a,
            SourceChannel.Red => color.r,
            SourceChannel.Green => color.g,
            SourceChannel.Blue => color.b,
            SourceChannel.AverageRGB => (color.r + color.g + color.b) / 3f,
            _ => color.grayscale,
        };

        return _invertSource ? 1f - value : value;
    }

    private static void ConfigureImporter(string assetPath)
    {
        if (AssetImporter.GetAtPath(assetPath) is not TextureImporter importer)
        {
            return;
        }

        importer.textureType = TextureImporterType.Default;
        importer.sRGBTexture = false;
        importer.mipmapEnabled = false;
        importer.alphaSource = TextureImporterAlphaSource.None;
        importer.wrapMode = TextureWrapMode.Clamp;
        importer.filterMode = FilterMode.Bilinear;
        importer.textureCompression = TextureImporterCompression.Uncompressed;
        importer.SaveAndReimport();
    }
}

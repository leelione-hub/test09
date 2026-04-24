using System.IO;
using UnityEditor;
using UnityEngine;

public sealed class SSSLUTGeneratorWindow : EditorWindow
{
    private int _width = 128;
    private int _height = 128;

    private float _directStrength = 0.75f;
    private float _curvatureBoost = 0.65f;
    private float _curvaturePower = 1.5f;
    private float _edgeBoost = 0.2f;
    private float _ambientFloor = 0.03f;

    private Color _baseTint = new(1.0f, 0.92f, 0.88f, 1.0f);
    private Color _scatterTint = new(1.0f, 0.52f, 0.38f, 1.0f);

    [MenuItem("Tools/Rendering/SSS LUT Generator")]
    private static void OpenWindow()
    {
        GetWindow<SSSLUTGeneratorWindow>("SSS LUT Generator");
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Output", EditorStyles.boldLabel);
        _width = EditorGUILayout.IntPopup("Width", _width, new[] { "64", "128", "256", "512" }, new[] { 64, 128, 256, 512 });
        _height = EditorGUILayout.IntPopup("Height", _height, new[] { "64", "128", "256", "512" }, new[] { 64, 128, 256, 512 });

        EditorGUILayout.Space(6f);
        EditorGUILayout.LabelField("Shape", EditorStyles.boldLabel);
        _directStrength = EditorGUILayout.Slider("Direct Strength", _directStrength, 0f, 2f);
        _curvatureBoost = EditorGUILayout.Slider("Curvature Boost", _curvatureBoost, 0f, 2f);
        _curvaturePower = EditorGUILayout.Slider("Curvature Power", _curvaturePower, 0.25f, 4f);
        _edgeBoost = EditorGUILayout.Slider("Edge Boost", _edgeBoost, 0f, 1f);
        _ambientFloor = EditorGUILayout.Slider("Ambient Floor", _ambientFloor, 0f, 0.2f);

        EditorGUILayout.Space(6f);
        EditorGUILayout.LabelField("Color", EditorStyles.boldLabel);
        _baseTint = EditorGUILayout.ColorField("Base Tint", _baseTint);
        _scatterTint = EditorGUILayout.ColorField("Scatter Tint", _scatterTint);

        EditorGUILayout.Space(10f);
        EditorGUILayout.HelpBox(
            "横轴 U = wrapped NdotL，越往右表示越亮。\n" +
            "纵轴 V = curvature/thickness，越往上表示越薄、越接近轮廓、越容易散射。\n" +
            "生成结果会自动导入为 Linear / Clamp / Bilinear / No MipMaps。",
            MessageType.Info);

        EditorGUILayout.Space(8f);
        if (GUILayout.Button("Generate LUT PNG", GUILayout.Height(32f)))
        {
            GenerateAndSave();
        }
    }

    private void GenerateAndSave()
    {
        string defaultDirectory = "Assets/Shaders/SSS";
        string outputPath = EditorUtility.SaveFilePanelInProject(
            "Save SSS LUT",
            "Generated_SSSLUT.png",
            "png",
            "Choose where to save the generated SSS LUT.",
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
                    texture.SetPixel(x, y, EvaluateLUT(u, v));
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

        Debug.Log($"[SSSLUTGenerator] Generated LUT: {outputPath}");
        Selection.activeObject = AssetDatabase.LoadAssetAtPath<Texture2D>(outputPath);
    }

    private Color EvaluateLUT(float u, float v)
    {
        float direct = Mathf.Pow(Mathf.Clamp01(u), 0.85f) * _directStrength;
        float curvature = Mathf.Pow(Mathf.Clamp01(v), _curvaturePower) * _curvatureBoost;
        float edge = Mathf.Pow(Mathf.Clamp01(v), 2f) * (1f - Mathf.Clamp01(u)) * _edgeBoost;

        float scatter = Mathf.Clamp01(direct + curvature + edge + _ambientFloor);

        Color baseColor = _baseTint * direct;
        Color scatterColor = _scatterTint * (curvature + edge + _ambientFloor);
        Color result = baseColor + scatterColor;
        result.r = Mathf.Clamp01(result.r * scatter);
        result.g = Mathf.Clamp01(result.g * scatter);
        result.b = Mathf.Clamp01(result.b * scatter);
        result.a = 1f;
        return result;
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

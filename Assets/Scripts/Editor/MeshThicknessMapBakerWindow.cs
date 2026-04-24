using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public sealed class MeshThicknessMapBakerWindow : EditorWindow
{
    private Mesh _mesh;
    private int _width = 1024;
    private int _height = 1024;

    private float _maxThicknessDistance = 0.1f;
    private float _surfaceOffset = 0.0005f;
    private bool _bidirectionalRays = true;
    private float _noHitValue = 1.0f;
    private float _contrast = 1.0f;
    private float _bias = 0.0f;

    private bool _dilateResult = true;
    private int _dilateIterations = 1;

    [MenuItem("Tools/Rendering/Mesh Thickness Map Baker")]
    private static void OpenWindow()
    {
        GetWindow<MeshThicknessMapBakerWindow>("Mesh Thickness Baker");
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Source", EditorStyles.boldLabel);
        _mesh = (Mesh)EditorGUILayout.ObjectField("Mesh", _mesh, typeof(Mesh), false);

        using (new EditorGUILayout.HorizontalScope())
        {
            GUILayout.FlexibleSpace();
            if (GUILayout.Button("Use Selected Mesh", GUILayout.Width(160f)))
            {
                TryAssignSelectedMesh();
            }
        }

        EditorGUILayout.Space(6f);
        EditorGUILayout.LabelField("Output", EditorStyles.boldLabel);
        _width = EditorGUILayout.IntPopup("Width", _width, new[] { "256", "512", "1024", "2048", "4096" }, new[] { 256, 512, 1024, 2048, 4096 });
        _height = EditorGUILayout.IntPopup("Height", _height, new[] { "256", "512", "1024", "2048", "4096" }, new[] { 256, 512, 1024, 2048, 4096 });

        EditorGUILayout.Space(6f);
        EditorGUILayout.LabelField("Ray Thickness Bake", EditorStyles.boldLabel);
        _maxThicknessDistance = EditorGUILayout.FloatField("Max Thickness Distance", _maxThicknessDistance);
        _surfaceOffset = EditorGUILayout.FloatField("Surface Offset", _surfaceOffset);
        _bidirectionalRays = EditorGUILayout.Toggle("Bidirectional Rays", _bidirectionalRays);
        _noHitValue = EditorGUILayout.Slider("No Hit Value", _noHitValue, 0f, 1f);
        _contrast = EditorGUILayout.Slider("Contrast", _contrast, 0.25f, 3f);
        _bias = EditorGUILayout.Slider("Bias", _bias, -1f, 1f);

        EditorGUILayout.Space(6f);
        EditorGUILayout.LabelField("Post", EditorStyles.boldLabel);
        _dilateResult = EditorGUILayout.Toggle("Dilate Result", _dilateResult);
        using (new EditorGUI.DisabledScope(!_dilateResult))
        {
            _dilateIterations = EditorGUILayout.IntSlider("Dilate Iterations", _dilateIterations, 1, 8);
        }

        EditorGUILayout.Space(8f);
        EditorGUILayout.HelpBox(
            "This baker rasterizes the mesh in UV space, then casts rays through a temporary MeshCollider to estimate geometric thickness per texel.\n" +
            "White = thinner / easier to transmit. Black = thicker / harder to transmit.\n" +
            "It is more physically grounded than the UV heuristic generator, but still depends on a readable mesh, valid UV0, and reasonably clean closed geometry.",
            MessageType.Info);

        EditorGUILayout.Space(10f);
        if (GUILayout.Button("Bake Thickness Map", GUILayout.Height(32f)))
        {
            BakeAndSave();
        }
    }

    private void TryAssignSelectedMesh()
    {
        if (Selection.activeObject is Mesh mesh)
        {
            _mesh = mesh;
            return;
        }

        if (Selection.activeGameObject == null)
        {
            return;
        }

        if (Selection.activeGameObject.TryGetComponent(out MeshFilter meshFilter) && meshFilter.sharedMesh != null)
        {
            _mesh = meshFilter.sharedMesh;
            return;
        }

        if (Selection.activeGameObject.TryGetComponent(out SkinnedMeshRenderer skinnedMeshRenderer) && skinnedMeshRenderer.sharedMesh != null)
        {
            _mesh = skinnedMeshRenderer.sharedMesh;
        }
    }

    private void BakeAndSave()
    {
        if (!ValidateInput())
        {
            return;
        }

        string outputPath = EditorUtility.SaveFilePanelInProject(
            "Save Mesh Thickness Map",
            "Generated_MeshThicknessMap.png",
            "png",
            "Choose where to save the baked thickness map.",
            "Assets/Shaders/SSS");

        if (string.IsNullOrEmpty(outputPath))
        {
            return;
        }

        Texture2D texture = new(_width, _height, TextureFormat.RGBA32, false, true);
        GameObject tempObject = null;
        MeshCollider meshCollider = null;
        bool previousHitBackfaces = Physics.queriesHitBackfaces;
        bool succeeded = false;

        try
        {
            tempObject = new GameObject("MeshThicknessBaker_Temp");
            tempObject.hideFlags = HideFlags.HideAndDontSave;
            meshCollider = tempObject.AddComponent<MeshCollider>();
            meshCollider.sharedMesh = _mesh;
            meshCollider.convex = false;

            Physics.queriesHitBackfaces = true;

            float[] pixels = BakeTexture(meshCollider);
            if (_dilateResult)
            {
                DilatePixels(pixels, _width, _height, _dilateIterations);
            }

            for (int y = 0; y < _height; y++)
            {
                for (int x = 0; x < _width; x++)
                {
                    float value = pixels[y * _width + x];
                    texture.SetPixel(x, y, new Color(value, value, value, 1f));
                }
            }

            texture.Apply(false, false);
            File.WriteAllBytes(outputPath, texture.EncodeToPNG());
            succeeded = true;
        }
        catch (OperationCanceledException)
        {
            return;
        }
        catch (Exception exception)
        {
            Debug.LogException(exception);
            return;
        }
        finally
        {
            Physics.queriesHitBackfaces = previousHitBackfaces;
            EditorUtility.ClearProgressBar();

            if (texture != null)
            {
                DestroyImmediate(texture);
            }

            if (tempObject != null)
            {
                DestroyImmediate(tempObject);
            }
        }

        if (!succeeded)
        {
            return;
        }

        AssetDatabase.ImportAsset(outputPath, ImportAssetOptions.ForceSynchronousImport);
        ConfigureImporter(outputPath);
        AssetDatabase.ImportAsset(outputPath, ImportAssetOptions.ForceSynchronousImport);

        Debug.Log($"[MeshThicknessMapBaker] Baked thickness map: {outputPath}");
        Selection.activeObject = AssetDatabase.LoadAssetAtPath<Texture2D>(outputPath);
    }

    private bool ValidateInput()
    {
        if (_mesh == null)
        {
            Debug.LogError("[MeshThicknessMapBaker] Missing mesh.");
            return false;
        }

        if (!_mesh.isReadable)
        {
            Debug.LogError("[MeshThicknessMapBaker] Mesh must be readable.");
            return false;
        }

        if (_mesh.uv == null || _mesh.uv.Length != _mesh.vertexCount)
        {
            Debug.LogError("[MeshThicknessMapBaker] Mesh must have valid UV0.");
            return false;
        }

        if (_mesh.triangles == null || _mesh.triangles.Length < 3)
        {
            Debug.LogError("[MeshThicknessMapBaker] Mesh has no triangles.");
            return false;
        }

        if (_maxThicknessDistance <= 0f)
        {
            Debug.LogError("[MeshThicknessMapBaker] Max Thickness Distance must be > 0.");
            return false;
        }

        if (_surfaceOffset <= 0f)
        {
            Debug.LogError("[MeshThicknessMapBaker] Surface Offset must be > 0.");
            return false;
        }

        return true;
    }

    private float[] BakeTexture(MeshCollider meshCollider)
    {
        Vector3[] vertices = _mesh.vertices;
        Vector3[] normals = BuildNormals(_mesh, vertices);
        Vector2[] uvs = _mesh.uv;
        int[] triangles = _mesh.triangles;

        float[] pixels = new float[_width * _height];
        bool[] written = new bool[pixels.Length];
        for (int i = 0; i < pixels.Length; i++)
        {
            pixels[i] = _noHitValue;
        }

        int triangleCount = triangles.Length / 3;
        for (int triangleIndex = 0; triangleIndex < triangleCount; triangleIndex++)
        {
            if (triangleIndex % 32 == 0)
            {
                float progress = triangleCount > 0 ? triangleIndex / (float)triangleCount : 1f;
                if (EditorUtility.DisplayCancelableProgressBar("Bake Mesh Thickness Map", "Rasterizing UV triangles and casting rays...", progress))
                {
                    throw new OperationCanceledException("Thickness baking cancelled by user.");
                }
            }

            int i0 = triangles[triangleIndex * 3 + 0];
            int i1 = triangles[triangleIndex * 3 + 1];
            int i2 = triangles[triangleIndex * 3 + 2];

            Vector2 uv0 = uvs[i0];
            Vector2 uv1 = uvs[i1];
            Vector2 uv2 = uvs[i2];

            float area = EdgeFunction(uv0, uv1, uv2);
            if (Mathf.Abs(area) < 1e-8f)
            {
                continue;
            }

            GetPixelBounds(uv0, uv1, uv2, out int minX, out int maxX, out int minY, out int maxY);

            for (int y = minY; y <= maxY; y++)
            {
                float v = _height > 1 ? (y + 0.5f) / _height : 0.5f;
                for (int x = minX; x <= maxX; x++)
                {
                    float u = _width > 1 ? (x + 0.5f) / _width : 0.5f;
                    Vector2 uv = new(u, v);

                    if (!TryGetBarycentric(uv, uv0, uv1, uv2, area, out Vector3 barycentric))
                    {
                        continue;
                    }

                    Vector3 position = barycentric.x * vertices[i0] + barycentric.y * vertices[i1] + barycentric.z * vertices[i2];
                    Vector3 normal = (barycentric.x * normals[i0] + barycentric.y * normals[i1] + barycentric.z * normals[i2]).normalized;
                    if (normal.sqrMagnitude < 1e-8f)
                    {
                        continue;
                    }

                    float bakedValue = BakeThicknessValue(meshCollider, position, normal);
                    int pixelIndex = y * _width + x;
                    if (!written[pixelIndex])
                    {
                        pixels[pixelIndex] = bakedValue;
                        written[pixelIndex] = true;
                    }
                    else
                    {
                        // When UV islands overlap, keep the brighter value so thinner surfaces win.
                        pixels[pixelIndex] = Mathf.Max(pixels[pixelIndex], bakedValue);
                    }
                }
            }
        }

        return pixels;
    }

    private float BakeThicknessValue(MeshCollider meshCollider, Vector3 positionLS, Vector3 normalLS)
    {
        if (!TryMeasureThickness(meshCollider, positionLS, normalLS, out float rawThickness))
        {
            return _noHitValue;
        }

        float value = 1f - Mathf.Clamp01(rawThickness / _maxThicknessDistance);
        value = Mathf.Clamp01(value + _bias);
        value = Mathf.Clamp01(Mathf.Pow(value, 1f / Mathf.Max(_contrast, 0.001f)));
        return value;
    }

    private bool TryMeasureThickness(MeshCollider meshCollider, Vector3 positionLS, Vector3 normalLS, out float rawThickness)
    {
        rawThickness = -1f;
        Vector3 normal = normalLS.normalized;

        if (TryCastThickness(meshCollider, positionLS - normal * _surfaceOffset, -normal, out rawThickness))
        {
            return true;
        }

        if (_bidirectionalRays && TryCastThickness(meshCollider, positionLS + normal * _surfaceOffset, normal, out rawThickness))
        {
            return true;
        }

        return false;
    }

    private bool TryCastThickness(MeshCollider meshCollider, Vector3 origin, Vector3 direction, out float hitDistance)
    {
        if (meshCollider.Raycast(new Ray(origin, direction), out RaycastHit hit, _maxThicknessDistance + _surfaceOffset))
        {
            hitDistance = hit.distance + _surfaceOffset;
            return true;
        }

        hitDistance = -1f;
        return false;
    }

    private static Vector3[] BuildNormals(Mesh mesh, Vector3[] vertices)
    {
        if (mesh.normals != null && mesh.normals.Length == mesh.vertexCount)
        {
            return mesh.normals;
        }

        Vector3[] generatedNormals = new Vector3[mesh.vertexCount];
        int[] triangles = mesh.triangles;
        for (int i = 0; i < triangles.Length; i += 3)
        {
            int i0 = triangles[i + 0];
            int i1 = triangles[i + 1];
            int i2 = triangles[i + 2];

            Vector3 v0 = vertices[i0];
            Vector3 v1 = vertices[i1];
            Vector3 v2 = vertices[i2];
            Vector3 faceNormal = Vector3.Cross(v1 - v0, v2 - v0);

            generatedNormals[i0] += faceNormal;
            generatedNormals[i1] += faceNormal;
            generatedNormals[i2] += faceNormal;
        }

        for (int i = 0; i < generatedNormals.Length; i++)
        {
            generatedNormals[i] = generatedNormals[i].normalized;
            if (generatedNormals[i].sqrMagnitude < 1e-8f)
            {
                generatedNormals[i] = Vector3.up;
            }
        }

        return generatedNormals;
    }

    private void GetPixelBounds(Vector2 uv0, Vector2 uv1, Vector2 uv2, out int minX, out int maxX, out int minY, out int maxY)
    {
        float minU = Mathf.Min(uv0.x, Mathf.Min(uv1.x, uv2.x));
        float maxU = Mathf.Max(uv0.x, Mathf.Max(uv1.x, uv2.x));
        float minV = Mathf.Min(uv0.y, Mathf.Min(uv1.y, uv2.y));
        float maxV = Mathf.Max(uv0.y, Mathf.Max(uv1.y, uv2.y));

        minX = Mathf.Clamp(Mathf.FloorToInt(minU * _width), 0, _width - 1);
        maxX = Mathf.Clamp(Mathf.CeilToInt(maxU * _width), 0, _width - 1);
        minY = Mathf.Clamp(Mathf.FloorToInt(minV * _height), 0, _height - 1);
        maxY = Mathf.Clamp(Mathf.CeilToInt(maxV * _height), 0, _height - 1);
    }

    private static bool TryGetBarycentric(Vector2 p, Vector2 a, Vector2 b, Vector2 c, float area, out Vector3 barycentric)
    {
        float w0 = EdgeFunction(b, c, p) / area;
        float w1 = EdgeFunction(c, a, p) / area;
        float w2 = EdgeFunction(a, b, p) / area;

        barycentric = new Vector3(w0, w1, w2);
        const float epsilon = -1e-4f;
        return w0 >= epsilon && w1 >= epsilon && w2 >= epsilon;
    }

    private static float EdgeFunction(Vector2 a, Vector2 b, Vector2 c)
    {
        return (c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x);
    }

    private static void DilatePixels(float[] pixels, int width, int height, int iterations)
    {
        float[] working = new float[pixels.Length];
        Array.Copy(pixels, working, pixels.Length);

        for (int iteration = 0; iteration < iterations; iteration++)
        {
            Array.Copy(working, pixels, pixels.Length);
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    int index = y * width + x;
                    float value = pixels[index];
                    if (value > 0.0001f)
                    {
                        continue;
                    }

                    float maxNeighbor = 0f;
                    for (int offsetY = -1; offsetY <= 1; offsetY++)
                    {
                        int sampleY = y + offsetY;
                        if (sampleY < 0 || sampleY >= height)
                        {
                            continue;
                        }

                        for (int offsetX = -1; offsetX <= 1; offsetX++)
                        {
                            int sampleX = x + offsetX;
                            if (sampleX < 0 || sampleX >= width)
                            {
                                continue;
                            }

                            int sampleIndex = sampleY * width + sampleX;
                            maxNeighbor = Mathf.Max(maxNeighbor, pixels[sampleIndex]);
                        }
                    }

                    working[index] = maxNeighbor;
                }
            }
        }

        Array.Copy(working, pixels, pixels.Length);
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

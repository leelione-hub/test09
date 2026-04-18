using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace VegetationSystem.Editor
{
    public static class VegetationTerrainBlendBaker
    {
        private const string BakerShaderName = "Hidden/Vegetation/TerrainBlendBaker";

        private static readonly int ControlId = Shader.PropertyToID("_Control");
        private static readonly int Splat0Id = Shader.PropertyToID("_Splat0");
        private static readonly int Splat1Id = Shader.PropertyToID("_Splat1");
        private static readonly int Splat2Id = Shader.PropertyToID("_Splat2");
        private static readonly int Splat3Id = Shader.PropertyToID("_Splat3");
        private static readonly int Splat0StId = Shader.PropertyToID("_Splat0_ST");
        private static readonly int Splat1StId = Shader.PropertyToID("_Splat1_ST");
        private static readonly int Splat2StId = Shader.PropertyToID("_Splat2_ST");
        private static readonly int Splat3StId = Shader.PropertyToID("_Splat3_ST");
        private static readonly int DiffuseRemapScale0Id = Shader.PropertyToID("_DiffuseRemapScale0");
        private static readonly int DiffuseRemapScale1Id = Shader.PropertyToID("_DiffuseRemapScale1");
        private static readonly int DiffuseRemapScale2Id = Shader.PropertyToID("_DiffuseRemapScale2");
        private static readonly int DiffuseRemapScale3Id = Shader.PropertyToID("_DiffuseRemapScale3");

        private static readonly int[] SplatTextureIds =
        {
            Splat0Id,
            Splat1Id,
            Splat2Id,
            Splat3Id
        };

        private static readonly int[] SplatStIds =
        {
            Splat0StId,
            Splat1StId,
            Splat2StId,
            Splat3StId
        };

        private static readonly int[] DiffuseRemapScaleIds =
        {
            DiffuseRemapScale0Id,
            DiffuseRemapScale1Id,
            DiffuseRemapScale2Id,
            DiffuseRemapScale3Id
        };

        [MenuItem("Tools/Vegetation/Bake Selected Terrain Blend Texture")]
        private static void BakeSelectedTerrainBlendTexture()
        {
            Terrain terrain = Selection.activeGameObject != null
                ? Selection.activeGameObject.GetComponent<Terrain>()
                : null;
            if (terrain == null)
            {
                EditorUtility.DisplayDialog("Bake Terrain Blend", "Select a GameObject with a Terrain component first.", "OK");
                return;
            }

            BakeTerrainBlendTexture(terrain);
        }

        [MenuItem("Tools/Vegetation/Bake Selected Terrain Blend Texture", true)]
        private static bool ValidateBakeSelectedTerrainBlendTexture()
        {
            return Selection.activeGameObject != null && Selection.activeGameObject.GetComponent<Terrain>() != null;
        }

        [MenuItem("CONTEXT/Terrain/Bake Vegetation Blend Texture")]
        private static void BakeTerrainBlendTextureFromContext(MenuCommand command)
        {
            var terrain = command.context as Terrain;
            if (terrain != null)
            {
                BakeTerrainBlendTexture(terrain);
            }
        }

        private static void BakeTerrainBlendTexture(Terrain terrain)
        {
            if (terrain == null || terrain.terrainData == null)
            {
                Debug.LogError("[VegetationTerrainBlendBaker] Terrain or TerrainData is missing.");
                return;
            }

            TerrainData terrainData = terrain.terrainData;
            TerrainLayer[] terrainLayers = terrainData.terrainLayers;
            Texture2D[] alphaMaps = terrainData.alphamapTextures;
            if (terrainLayers == null || terrainLayers.Length == 0 || alphaMaps == null || alphaMaps.Length == 0)
            {
                Debug.LogError("[VegetationTerrainBlendBaker] Terrain is missing terrain layers or control textures.");
                return;
            }

            if (terrainLayers.Length > 4 || alphaMaps.Length > 1)
            {
                Debug.LogWarning("[VegetationTerrainBlendBaker] This baker currently uses only the first 4 terrain layers and the first control texture.");
            }

            Shader bakerShader = Shader.Find(BakerShaderName);
            if (bakerShader == null)
            {
                Debug.LogError($"[VegetationTerrainBlendBaker] Cannot find shader: {BakerShaderName}");
                return;
            }

            int resolution = Mathf.Max(128, terrainData.baseMapResolution > 0 ? terrainData.baseMapResolution : terrainData.alphamapResolution);
            string terrainDataPath = AssetDatabase.GetAssetPath(terrainData);
            string defaultDirectory = string.IsNullOrEmpty(terrainDataPath) ? "Assets" : Path.GetDirectoryName(terrainDataPath);
            string defaultName = $"{terrain.name}_VgTerrainBlend.png";
            string outputPath = EditorUtility.SaveFilePanelInProject(
                "Save Terrain Blend Texture",
                defaultName,
                "png",
                "Choose where to save the baked terrain blend texture.",
                defaultDirectory);

            if (string.IsNullOrEmpty(outputPath))
            {
                return;
            }

            var material = new Material(bakerShader);
            try
            {
                material.SetTexture(ControlId, alphaMaps[0]);

                for (int i = 0; i < 4; i++)
                {
                    TerrainLayer layer = i < terrainLayers.Length ? terrainLayers[i] : null;
                    Texture diffuseTexture = layer != null && layer.diffuseTexture != null
                        ? layer.diffuseTexture
                        : Texture2D.whiteTexture;

                    material.SetTexture(SplatTextureIds[i], diffuseTexture);
                    material.SetVector(SplatStIds[i], CalculateSplatSt(layer, terrainData.size));
                    material.SetVector(DiffuseRemapScaleIds[i], CalculateDiffuseRemapScale(layer));
                }

                var renderTexture = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB)
                {
                    useMipMap = false,
                    autoGenerateMips = false,
                    wrapMode = TextureWrapMode.Clamp,
                    filterMode = FilterMode.Bilinear
                };

                Texture2D bakedTexture = null;
                RenderTexture previousActive = RenderTexture.active;
                try
                {
                    Graphics.Blit(Texture2D.whiteTexture, renderTexture, material);
                    RenderTexture.active = renderTexture;

                    bakedTexture = new Texture2D(resolution, resolution, TextureFormat.RGBA32, false, false);
                    bakedTexture.ReadPixels(new Rect(0, 0, resolution, resolution), 0, 0);
                    bakedTexture.Apply(false, false);
                }
                finally
                {
                    RenderTexture.active = previousActive;
                    renderTexture.Release();
                    Object.DestroyImmediate(renderTexture);
                }

                File.WriteAllBytes(outputPath, bakedTexture.EncodeToPNG());
                Object.DestroyImmediate(bakedTexture);

                AssetDatabase.ImportAsset(outputPath, ImportAssetOptions.ForceSynchronousImport);
                ConfigureTextureImporter(outputPath);
                AssetDatabase.ImportAsset(outputPath, ImportAssetOptions.ForceSynchronousImport);

                Texture2D savedTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(outputPath);
                if (savedTexture == null)
                {
                    Debug.LogError("[VegetationTerrainBlendBaker] Failed to import baked texture.");
                    return;
                }

                var blendData = terrain.GetComponent<VegetationTerrainBlendData>();
                if (blendData == null)
                {
                    blendData = terrain.gameObject.AddComponent<VegetationTerrainBlendData>();
                }

                blendData.SetBakedBlendTexture(savedTexture);
                EditorUtility.SetDirty(blendData);
                EditorSceneManager.MarkSceneDirty(terrain.gameObject.scene);
                AssetDatabase.SaveAssets();

                Debug.Log($"[VegetationTerrainBlendBaker] Baked terrain blend texture saved to: {outputPath}");
            }
            finally
            {
                Object.DestroyImmediate(material);
            }
        }

        private static void ConfigureTextureImporter(string assetPath)
        {
            if (!(AssetImporter.GetAtPath(assetPath) is TextureImporter importer))
            {
                return;
            }

            importer.textureType = TextureImporterType.Default;
            importer.sRGBTexture = true;
            importer.mipmapEnabled = true;
            importer.alphaSource = TextureImporterAlphaSource.None;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.filterMode = FilterMode.Bilinear;
            importer.textureCompression = TextureImporterCompression.Compressed;
            importer.SaveAndReimport();
        }

        private static Vector4 CalculateSplatSt(TerrainLayer layer, Vector3 terrainSize)
        {
            if (layer == null)
            {
                return new Vector4(1, 1, 0, 0);
            }

            float tileX = Mathf.Max(layer.tileSize.x, 0.0001f);
            float tileY = Mathf.Max(layer.tileSize.y, 0.0001f);
            float scaleX = terrainSize.x / tileX;
            float scaleY = terrainSize.z / tileY;
            float offsetX = layer.tileOffset.x / tileX;
            float offsetY = layer.tileOffset.y / tileY;
            return new Vector4(scaleX, scaleY, offsetX, offsetY);
        }

        private static Vector4 CalculateDiffuseRemapScale(TerrainLayer layer)
        {
            if (layer == null)
            {
                return Vector4.one;
            }

            Vector4 remap = layer.diffuseRemapMax;
            if (remap == Vector4.zero)
            {
                return Vector4.one;
            }

            return remap;
        }
    }
}

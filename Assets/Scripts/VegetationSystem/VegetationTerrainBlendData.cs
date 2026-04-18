using UnityEngine;

namespace VegetationSystem
{
    [ExecuteAlways]
    public class VegetationTerrainBlendData : MonoBehaviour
    {
        [SerializeField]
        private Texture2D _bakedBlendTexture;

        private static readonly int GlobalControlId = Shader.PropertyToID("_VGTerrainControl");
        private static readonly int GlobalSplat0Id = Shader.PropertyToID("_VGTerrainSplat0");
        private static readonly int GlobalSplat1Id = Shader.PropertyToID("_VGTerrainSplat1");
        private static readonly int GlobalSplat2Id = Shader.PropertyToID("_VGTerrainSplat2");
        private static readonly int GlobalSplat3Id = Shader.PropertyToID("_VGTerrainSplat3");
        private static readonly int GlobalSplat0StId = Shader.PropertyToID("_VGTerrainSplat0_ST");
        private static readonly int GlobalSplat1StId = Shader.PropertyToID("_VGTerrainSplat1_ST");
        private static readonly int GlobalSplat2StId = Shader.PropertyToID("_VGTerrainSplat2_ST");
        private static readonly int GlobalSplat3StId = Shader.PropertyToID("_VGTerrainSplat3_ST");
        private static readonly int GlobalDiffuseRemapScale0Id = Shader.PropertyToID("_VGDiffuseRemapScale0");
        private static readonly int GlobalDiffuseRemapScale1Id = Shader.PropertyToID("_VGDiffuseRemapScale1");
        private static readonly int GlobalDiffuseRemapScale2Id = Shader.PropertyToID("_VGDiffuseRemapScale2");
        private static readonly int GlobalDiffuseRemapScale3Id = Shader.PropertyToID("_VGDiffuseRemapScale3");
        private static readonly int GlobalTerrainTransformDataId = Shader.PropertyToID("_VGTerrainTransformData");
        private static readonly int GlobalTerrainRoughnessId = Shader.PropertyToID("_VGTerrainRoughness");
        private static readonly int GlobalTerrainColorId = Shader.PropertyToID("_VGTerrainColor");
        private static readonly int LocalControlId = Shader.PropertyToID("_Control");
        private static readonly int LocalSplat0Id = Shader.PropertyToID("_Splat0");
        private static readonly int LocalSplat1Id = Shader.PropertyToID("_Splat1");
        private static readonly int LocalSplat2Id = Shader.PropertyToID("_Splat2");
        private static readonly int LocalSplat3Id = Shader.PropertyToID("_Splat3");
        private static readonly int LocalSplat0StId = Shader.PropertyToID("_Splat0_ST");
        private static readonly int LocalSplat1StId = Shader.PropertyToID("_Splat1_ST");
        private static readonly int LocalSplat2StId = Shader.PropertyToID("_Splat2_ST");
        private static readonly int LocalSplat3StId = Shader.PropertyToID("_Splat3_ST");
        private static readonly int LocalDiffuseRemapScale0Id = Shader.PropertyToID("_DiffuseRemapScale0");
        private static readonly int LocalDiffuseRemapScale1Id = Shader.PropertyToID("_DiffuseRemapScale1");
        private static readonly int LocalDiffuseRemapScale2Id = Shader.PropertyToID("_DiffuseRemapScale2");
        private static readonly int LocalDiffuseRemapScale3Id = Shader.PropertyToID("_DiffuseRemapScale3");
        private static readonly int LocalTerrainTransformDataId = Shader.PropertyToID("_TerrainTransformData");
        private static readonly int LocalTerrainRoughnessId = Shader.PropertyToID("_TerrainRoughness");
        private static readonly int LocalTerrainColorId = Shader.PropertyToID("_TerrainColor");

        private const string TerrainBlendKeyword = "_BLEND_TERRAIN_ON";
        private const string TerrainBlendBakedKeyword = "_TERRAIN_BLEND_BAKED";

        private static readonly int[] SplatTextureIds =
        {
            GlobalSplat0Id,
            GlobalSplat1Id,
            GlobalSplat2Id,
            GlobalSplat3Id
        };

        private static readonly int[] SplatStIds =
        {
            GlobalSplat0StId,
            GlobalSplat1StId,
            GlobalSplat2StId,
            GlobalSplat3StId
        };

        private static readonly int[] DiffuseRemapScaleIds =
        {
            GlobalDiffuseRemapScale0Id,
            GlobalDiffuseRemapScale1Id,
            GlobalDiffuseRemapScale2Id,
            GlobalDiffuseRemapScale3Id
        };

        private static readonly int[] LocalSplatTextureIds =
        {
            LocalSplat0Id,
            LocalSplat1Id,
            LocalSplat2Id,
            LocalSplat3Id
        };

        private static readonly int[] LocalSplatStIds =
        {
            LocalSplat0StId,
            LocalSplat1StId,
            LocalSplat2StId,
            LocalSplat3StId
        };

        private static readonly int[] LocalDiffuseRemapScaleIds =
        {
            LocalDiffuseRemapScale0Id,
            LocalDiffuseRemapScale1Id,
            LocalDiffuseRemapScale2Id,
            LocalDiffuseRemapScale3Id
        };

        private Terrain _terrain;
        private int _lastSyncHash;
        private bool _hasSyncedOnce;

        public Texture2D BakedBlendTexture => _bakedBlendTexture;

        private void Awake()
        {
            CacheTerrain();
            SyncTerrainBlend();
        }
        
        private void OnEnable()
        {
            CacheTerrain();
            SyncTerrainBlend();
        }

        private void OnValidate()
        {
            CacheTerrain();
            MarkDirtyAndSync();
        }

        private void Update()
        {
            if (Application.isPlaying)
            {
                return;
            }

            CacheTerrain();
            SyncTerrainBlendIfDirty();
        }

        private void CacheTerrain()
        {
            if (_terrain == null)
            {
                _terrain = GetComponent<Terrain>();
            }
        }

        public void SyncTerrainBlend()
        {
            ApplyTerrainBlendGlobals(_terrain);
            _lastSyncHash = CalculateTerrainStateHash();
            _hasSyncedOnce = true;
        }

        [ContextMenu("Test Terrain Blend Sync")]
        private void TestTerrainBlendSync()
        {
            CacheTerrain();
            if (!TryBuildTerrainBlendData(_terrain, out TerrainBlendShaderData shaderData))
            {
                Debug.LogWarning("[VegetationTerrainBlendData] Test failed: Terrain or TerrainData is missing.", this);
                return;
            }

            SyncTerrainBlend();

            string bakedName = shaderData.bakedBlendTexture != null ? shaderData.bakedBlendTexture.name : "null";
            string controlName = shaderData.controlTexture != null ? shaderData.controlTexture.name : "null";
            string terrainColorName = shaderData.terrainColor != null ? shaderData.terrainColor.name : "null";

            Debug.Log(
                "[VegetationTerrainBlendData] Test sync executed.\n" +
                $"Terrain: {(_terrain != null ? _terrain.name : "null")}\n" +
                $"BakedBlendTexture: {bakedName}\n" +
                $"ControlTexture: {controlName}\n" +
                $"TerrainColor: {terrainColorName}\n" +
                $"TerrainTransformData: {shaderData.terrainTransformData}\n" +
                $"TerrainRoughness: {shaderData.terrainRoughness}\n" +
                $"StateHash: {_lastSyncHash}",
                this);
        }

        private void SyncTerrainBlendIfDirty()
        {
            int currentHash = CalculateTerrainStateHash();
            if (!_hasSyncedOnce || currentHash != _lastSyncHash)
            {
                SyncTerrainBlend();
            }
        }

        private void MarkDirtyAndSync()
        {
            _hasSyncedOnce = false;
            SyncTerrainBlend();
        }

        private int CalculateTerrainStateHash()
        {
            unchecked
            {
                if (_terrain == null || _terrain.terrainData == null)
                {
                    return 0;
                }

                int hash = 17;
                TerrainData terrainData = _terrain.terrainData;

                hash = hash * 23 + _terrain.transform.position.GetHashCode();
                hash = hash * 23 + terrainData.GetInstanceID();
                hash = hash * 23 + terrainData.size.GetHashCode();
                hash = hash * 23 + (_bakedBlendTexture != null ? _bakedBlendTexture.GetInstanceID() : 0);

                var terrainLayers = terrainData.terrainLayers;
                if (terrainLayers != null)
                {
                    hash = hash * 23 + terrainLayers.Length;
                    for (int i = 0; i < terrainLayers.Length; i++)
                    {
                        TerrainLayer layer = terrainLayers[i];
                        hash = hash * 23 + (layer != null ? layer.GetInstanceID() : 0);
                    }
                }

                var alphaMaps = terrainData.alphamapTextures;
                if (alphaMaps != null)
                {
                    hash = hash * 23 + alphaMaps.Length;
                    for (int i = 0; i < alphaMaps.Length; i++)
                    {
                        Texture2D alphaMap = alphaMaps[i];
                        hash = hash * 23 + (alphaMap != null ? alphaMap.GetInstanceID() : 0);
                    }
                }

                return hash;
            }
        }

#if UNITY_EDITOR
        public void SetBakedBlendTexture(Texture2D texture)
        {
            _bakedBlendTexture = texture;
            MarkDirtyAndSync();
        }
#endif

        public static void ApplyTerrainBlendGlobals(Terrain terrain)
        {
            if (!TryBuildTerrainBlendData(terrain, out TerrainBlendShaderData shaderData))
            {
                return;
            }

            Shader.EnableKeyword(TerrainBlendKeyword);
            if (shaderData.bakedBlendTexture != null)
            {
                Shader.EnableKeyword(TerrainBlendBakedKeyword);
            }
            else
            {
                Shader.DisableKeyword(TerrainBlendBakedKeyword);
            }

            Shader.SetGlobalVector(GlobalTerrainTransformDataId, shaderData.terrainTransformData);
            Shader.SetGlobalFloat(GlobalTerrainRoughnessId, shaderData.terrainRoughness);
            Shader.SetGlobalTexture(GlobalTerrainColorId, shaderData.terrainColor);
            Shader.SetGlobalTexture(GlobalControlId, shaderData.controlTexture);

            for (int i = 0; i < 4; i++)
            {
                Shader.SetGlobalTexture(SplatTextureIds[i], shaderData.splatTextures[i]);
                Shader.SetGlobalVector(SplatStIds[i], shaderData.splatSt[i]);
                Shader.SetGlobalVector(DiffuseRemapScaleIds[i], shaderData.diffuseRemapScale[i]);
            }
        }

        public static void ApplyTerrainBlendProperties(Material material, Terrain terrain)
        {
            if (material == null || !TryBuildTerrainBlendData(terrain, out TerrainBlendShaderData shaderData))
            {
                return;
            }

            if (!material.HasProperty(LocalTerrainTransformDataId))
            {
                return;
            }

            material.SetVector(LocalTerrainTransformDataId, shaderData.terrainTransformData);
            material.SetFloat(LocalTerrainRoughnessId, shaderData.terrainRoughness);

            if (material.HasProperty(LocalControlId))
            {
                material.SetTexture(LocalControlId, shaderData.controlTexture);
            }

            if (material.HasProperty(LocalTerrainColorId))
            {
                material.SetTexture(LocalTerrainColorId, shaderData.terrainColor);
            }

            for (int i = 0; i < 4; i++)
            {
                if (material.HasProperty(LocalSplatTextureIds[i]))
                {
                    material.SetTexture(LocalSplatTextureIds[i], shaderData.splatTextures[i]);
                }

                if (material.HasProperty(LocalSplatStIds[i]))
                {
                    material.SetVector(LocalSplatStIds[i], shaderData.splatSt[i]);
                }

                if (material.HasProperty(LocalDiffuseRemapScaleIds[i]))
                {
                    material.SetVector(LocalDiffuseRemapScaleIds[i], shaderData.diffuseRemapScale[i]);
                }
            }

            material.EnableKeyword(TerrainBlendKeyword);
            if (shaderData.bakedBlendTexture != null)
            {
                material.EnableKeyword(TerrainBlendBakedKeyword);
            }
            else
            {
                material.DisableKeyword(TerrainBlendBakedKeyword);
            }
        }

        private static bool TryBuildTerrainBlendData(Terrain terrain, out TerrainBlendShaderData shaderData)
        {
            shaderData = default;
            if (terrain == null || terrain.terrainData == null)
            {
                return false;
            }

            TerrainData terrainData = terrain.terrainData;
            Vector3 terrainPosition = terrain.transform.position;
            Vector3 terrainSize = terrainData.size;
            TerrainLayer[] terrainLayers = terrainData.terrainLayers;
            Texture2D[] alphaMaps = terrainData.alphamapTextures;

            Texture bakedBlendTexture = null;
            var terrainBlendData = terrain.GetComponent<VegetationTerrainBlendData>();
            if (terrainBlendData != null)
            {
                bakedBlendTexture = terrainBlendData.BakedBlendTexture;
            }

            shaderData.terrainTransformData = new Vector4(
                terrainPosition.x,
                terrainPosition.z,
                Mathf.Max(terrainSize.x, 0.0001f),
                Mathf.Max(terrainSize.z, 0.0001f));
            shaderData.terrainRoughness = CalculateTerrainRoughness(terrainLayers);
            shaderData.bakedBlendTexture = bakedBlendTexture;
            shaderData.controlTexture = alphaMaps != null && alphaMaps.Length > 0 && alphaMaps[0] != null
                ? alphaMaps[0]
                : Texture2D.redTexture;
            shaderData.terrainColor = ResolveTerrainColor(terrainLayers, bakedBlendTexture);
            shaderData.splatTextures = new Texture[4];
            shaderData.splatSt = new Vector4[4];
            shaderData.diffuseRemapScale = new Vector4[4];

            for (int i = 0; i < 4; i++)
            {
                TerrainLayer layer = terrainLayers != null && i < terrainLayers.Length ? terrainLayers[i] : null;
                shaderData.splatTextures[i] = layer != null && layer.diffuseTexture != null
                    ? layer.diffuseTexture
                    : Texture2D.whiteTexture;
                shaderData.splatSt[i] = CalculateSplatSt(layer, terrainSize);
                shaderData.diffuseRemapScale[i] = CalculateDiffuseRemapScale(layer);
            }

            return true;
        }

        private static Texture ResolveTerrainColor(TerrainLayer[] terrainLayers, Texture bakedBlendTexture)
        {
            if (bakedBlendTexture != null)
            {
                return bakedBlendTexture;
            }

            if (terrainLayers != null && terrainLayers.Length > 0 && terrainLayers[0] != null &&
                terrainLayers[0].diffuseTexture != null)
            {
                return terrainLayers[0].diffuseTexture;
            }

            return Texture2D.whiteTexture;
        }

        private static float CalculateTerrainRoughness(TerrainLayer[] terrainLayers)
        {
            if (terrainLayers == null || terrainLayers.Length == 0)
            {
                return 1.0f;
            }

            float smoothness = 0.0f;
            int count = Mathf.Min(terrainLayers.Length, 4);
            int validCount = 0;
            for (int i = 0; i < count; i++)
            {
                if (terrainLayers[i] == null)
                {
                    continue;
                }

                smoothness += terrainLayers[i].smoothness;
                validCount++;
            }

            smoothness /= Mathf.Max(1, validCount);
            return 1.0f - Mathf.Clamp01(smoothness);
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

        private struct TerrainBlendShaderData
        {
            public Vector4 terrainTransformData;
            public float terrainRoughness;
            public Texture terrainColor;
            public Texture controlTexture;
            public Texture bakedBlendTexture;
            public Texture[] splatTextures;
            public Vector4[] splatSt;
            public Vector4[] diffuseRemapScale;
        }
    }
}

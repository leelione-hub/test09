using System;
using UnityEngine;

namespace VegetationSystem
{
    [DisallowMultipleComponent]
    public class VegetationTerrainBlendData : MonoBehaviour
    {
        [SerializeField]
        private Texture2D _bakedBlendTexture;

        private static readonly int       TerrainColorId = Shader.PropertyToID("_TerrainColor");
        public                  Texture2D BakedBlendTexture => _bakedBlendTexture;

#if UNITY_EDITOR
        public void SetBakedBlendTexture(Texture2D texture)
        {
            _bakedBlendTexture = texture;
        }

        public void OnValidate()
        {
            Shader.SetGlobalTexture(TerrainColorId, _bakedBlendTexture);
        }
#endif
    }
}

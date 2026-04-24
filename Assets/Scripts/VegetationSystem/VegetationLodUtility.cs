using UnityEngine;

namespace VegetationSystem
{
    public sealed class VegetationLodUtility
    {
        public float CalculateLodDistance(float nearPlane, float halfFrustumHeightAtNear, float objectHalfHeight, float transitionHeight)
        {
            return (nearPlane * objectHalfHeight) / (halfFrustumHeightAtNear * transitionHeight) - nearPlane;
        }

        public float CalculateLodDistance(Camera camera, float objectHalfHeight, float transitionHeight)
        {
            if (camera == null || transitionHeight <= 0f)
            {
                return float.PositiveInfinity;
            }

            if (camera.orthographic)
            {
                return objectHalfHeight / (Mathf.Max(camera.orthographicSize, 0.0001f) * transitionHeight);
            }

            float near = camera.nearClipPlane;
            float halfFrustumHeightAtNear = Mathf.Tan(camera.fieldOfView * 0.5f * Mathf.Deg2Rad) * near;
            return CalculateLodDistance(near, halfFrustumHeightAtNear, objectHalfHeight, transitionHeight);
        }

        public float GetLodDistance(VegetationRenderData data, int lodIndex, Camera camera, float lodBias)
        {
            if (lodIndex < 0 || lodIndex >= data.activeLodCount)
            {
                return -1f;
            }

            float halfHeight = Mathf.Max(data.lodReferenceHeight * 0.5f, 0.0001f);
            float distance = CalculateLodDistance(camera, halfHeight, data.lodScreenHeights[lodIndex]);
            return float.IsInfinity(distance) ? float.PositiveInfinity : distance * lodBias;
        }

        public bool TryGetLodDistanceRange(
            VegetationRenderData data,
            int lodIndex,
            Camera camera,
            float lodBias,
            int maximumLodLevel,
            out Vector2 distanceRange)
        {
            distanceRange = default;
            if (lodIndex < maximumLodLevel || lodIndex < 0 || lodIndex >= data.activeLodCount)
            {
                return false;
            }

            int firstEnabledLod = Mathf.Clamp(maximumLodLevel, 0, Mathf.Max(0, data.activeLodCount - 1));
            float minDistance = 0f;
            if (lodIndex > firstEnabledLod)
            {
                minDistance = GetLodDistance(data, lodIndex - 1, camera, lodBias);
            }

            float maxDistance = GetLodDistance(data, lodIndex, camera, lodBias);
            if (maxDistance <= minDistance)
            {
                return false;
            }

            distanceRange = new Vector2(minDistance, maxDistance);
            return true;
        }
    }
}

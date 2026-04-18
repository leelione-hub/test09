using UnityEngine;
using UnityEngine.Rendering;

namespace Rendering.Cloud
{
    [ExecuteAlways]
    [DisallowMultipleComponent]
    [RequireComponent(typeof(MeshFilter))]
    public class BumpNoiseCloudInstancedRenderer : MonoBehaviour
    {
        private const int MaxInstancePerDraw = 1023;
        private static readonly int LayerOffsetId = Shader.PropertyToID("_LayerOffset");
        private static readonly int LayerClipId = Shader.PropertyToID("_LayerClip");
        private static readonly int CloudBoundsCenterId = Shader.PropertyToID("_CloudBoundsCenterOS");
        private static readonly int CloudBoundsExtentId = Shader.PropertyToID("_CloudBoundsExtentOS");

        [SerializeField] private Material cloudMaterial;
        [SerializeField] private int layerCount = 64;
        [SerializeField] private float layerSpread = 1.0f;
        [SerializeField] private float clipBias = 0.2f;
        [SerializeField] private float clipPower = 1.5f;
        [SerializeField] private bool cloneMeshForBounds = true;
        [SerializeField] private float boundsPadding = 8f;
        [SerializeField] private bool hideMeshRenderer = true;
        [SerializeField] private ShadowCastingMode shadowCasting = ShadowCastingMode.Off;

        private MeshFilter meshFilter;
        private MeshRenderer meshRenderer;
        private Mesh sourceMesh;
        private Mesh runtimeMesh;
        private MaterialPropertyBlock propertyBlock;
        private Matrix4x4[] matrices;
        private float[] layerOffsets;
        private float[] layerClips;

        private void OnEnable()
        {
            EnsureResources();
            UpdateMeshBounds();
            RebuildLayerData();
        }

        private void OnValidate()
        {
            layerCount = Mathf.Clamp(layerCount, 1, MaxInstancePerDraw);
            layerSpread = Mathf.Max(0.01f, layerSpread);
            clipPower = Mathf.Max(0.01f, clipPower);
            clipBias = Mathf.Clamp01(clipBias);
            boundsPadding = Mathf.Max(0f, boundsPadding);

            EnsureResources();
            UpdateMeshBounds();
            RebuildLayerData();
        }

        private void OnDisable()
        {
            ReleaseRuntimeMesh();
        }

        private void EnsureResources()
        {
            if (meshFilter == null)
            {
                meshFilter = GetComponent<MeshFilter>();
            }

            if (meshRenderer == null)
            {
                meshRenderer = GetComponent<MeshRenderer>();
            }

            if (propertyBlock == null)
            {
                propertyBlock = new MaterialPropertyBlock();
            }

            if (meshRenderer != null)
            {
                meshRenderer.enabled = !hideMeshRenderer;
            }
        }

        private void UpdateMeshBounds()
        {
            if (meshFilter == null)
            {
                return;
            }

            if (meshFilter.sharedMesh != null && meshFilter.sharedMesh != runtimeMesh)
            {
                sourceMesh = meshFilter.sharedMesh;
            }

            if (sourceMesh == null)
            {
                ReleaseRuntimeMesh();
                return;
            }

            if (!cloneMeshForBounds)
            {
                if (runtimeMesh != null && meshFilter.sharedMesh == runtimeMesh)
                {
                    meshFilter.sharedMesh = sourceMesh;
                }

                ReleaseRuntimeMesh();
                return;
            }

            if (runtimeMesh == null || runtimeMesh.vertexCount != sourceMesh.vertexCount)
            {
                ReleaseRuntimeMesh();
                runtimeMesh = Instantiate(sourceMesh);
                runtimeMesh.name = sourceMesh.name + " (Cloud Instance Bounds)";
                runtimeMesh.hideFlags = HideFlags.DontSave;
            }
            else
            {
                runtimeMesh.vertices = sourceMesh.vertices;
                runtimeMesh.normals = sourceMesh.normals;
                runtimeMesh.tangents = sourceMesh.tangents;
                runtimeMesh.uv = sourceMesh.uv;
                runtimeMesh.triangles = sourceMesh.triangles;
            }

            Bounds bounds = sourceMesh.bounds;
            bounds.Expand(boundsPadding * 2f);
            runtimeMesh.bounds = bounds;
            meshFilter.sharedMesh = runtimeMesh;
        }

        private void RebuildLayerData()
        {
            matrices = new Matrix4x4[layerCount];
            layerOffsets = new float[layerCount];
            layerClips = new float[layerCount];

            for (int i = 0; i < layerCount; i++)
            {
                float t = layerCount <= 1 ? 1f : (float)i / (layerCount - 1);
                layerOffsets[i] = t * layerSpread;
                layerClips[i] = Mathf.Clamp01(clipBias + Mathf.Pow(t, clipPower));
            }
        }

        private void LateUpdate()
        {
            if (cloudMaterial == null)
            {
                return;
            }

            EnsureResources();
            UpdateMeshBounds();

            if (meshFilter == null || meshFilter.sharedMesh == null)
            {
                return;
            }

            if (matrices == null || matrices.Length != layerCount)
            {
                RebuildLayerData();
            }

            Matrix4x4 localToWorld = transform.localToWorldMatrix;
            for (int i = 0; i < matrices.Length; i++)
            {
                matrices[i] = localToWorld;
            }

            propertyBlock.Clear();
            propertyBlock.SetFloatArray(LayerOffsetId, layerOffsets);
            propertyBlock.SetFloatArray(LayerClipId, layerClips);
            if (sourceMesh != null)
            {
                Bounds sourceBounds = sourceMesh.bounds;
                propertyBlock.SetVector(CloudBoundsCenterId, new Vector4(sourceBounds.center.x, sourceBounds.center.y, sourceBounds.center.z, 0f));
                propertyBlock.SetVector(CloudBoundsExtentId, new Vector4(sourceBounds.extents.x, sourceBounds.extents.y, sourceBounds.extents.z, 0f));
            }

            Graphics.DrawMeshInstanced(
                meshFilter.sharedMesh,
                0,
                cloudMaterial,
                matrices,
                matrices.Length,
                propertyBlock,
                shadowCasting,
                false,
                gameObject.layer,
                null,
                LightProbeUsage.Off,
                null
            );
        }

        private void ReleaseRuntimeMesh()
        {
            if (runtimeMesh == null)
            {
                return;
            }

            if (meshFilter != null && meshFilter.sharedMesh == runtimeMesh)
            {
                meshFilter.sharedMesh = sourceMesh;
            }

            if (Application.isPlaying)
            {
                Destroy(runtimeMesh);
            }
            else
            {
                DestroyImmediate(runtimeMesh);
            }

            runtimeMesh = null;
        }
    }
}

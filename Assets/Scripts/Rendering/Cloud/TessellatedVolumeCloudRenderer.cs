using UnityEngine;

namespace Rendering.Cloud
{
    [ExecuteAlways]
    [DisallowMultipleComponent]
    [RequireComponent(typeof(MeshFilter))]
    public class TessellatedVolumeCloudRenderer : MonoBehaviour
    {
        [SerializeField] private bool cloneMeshForBounds = true;
        [SerializeField] private float boundsPadding = 8f;

        private MeshFilter meshFilter;
        private Mesh sourceMesh;
        private Mesh runtimeMesh;

        private void OnEnable()
        {
            UpdateBounds();
        }

        private void OnValidate()
        {
            boundsPadding = Mathf.Max(0f, boundsPadding);
            UpdateBounds();
        }

        private void OnDisable()
        {
            ReleaseRuntimeMesh();
        }

        private void UpdateBounds()
        {
            if (meshFilter == null)
            {
                meshFilter = GetComponent<MeshFilter>();
            }

            if (meshFilter == null)
            {
                ReleaseRuntimeMesh();
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
                if (runtimeMesh != null && meshFilter.sharedMesh == runtimeMesh && sourceMesh != null)
                {
                    meshFilter.sharedMesh = sourceMesh;
                }

                ReleaseRuntimeMesh();
                return;
            }

            if (runtimeMesh == null)
            {
                runtimeMesh = Instantiate(sourceMesh);
                runtimeMesh.name = sourceMesh.name + " (Tessellated Cloud Bounds)";
                runtimeMesh.hideFlags = HideFlags.DontSave;
            }
            else if (runtimeMesh.vertexCount != sourceMesh.vertexCount)
            {
                ReleaseRuntimeMesh();
                runtimeMesh = Instantiate(sourceMesh);
                runtimeMesh.name = sourceMesh.name + " (Tessellated Cloud Bounds)";
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

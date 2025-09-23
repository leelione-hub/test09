using System.Collections.Generic;
using System.Diagnostics;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using Debug = UnityEngine.Debug;

public class IndirectTreeRenderer : MonoBehaviour
{
    [System.Serializable]
    public class TreePrototypeRenderer
    {
        public Mesh mesh;
        public Material material;
        public List<Matrix4x4> matrices = new List<Matrix4x4>();
        public List<Vector3> worldPosition = new List<Vector3>();
        public float boundsRadius = 2f;
        
        // 用于间接渲染
        public ComputeBuffer matrixBuffer;
        public ComputeBuffer argsBuffer;
        public ComputeBuffer culledMatrixBuffer;
        public uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        
        //用于视锥剔除
        public ComputeBuffer inputBuffer;
        public ComputeBuffer outputBuffer;
        public ComputeBuffer counterBuffer;
    }

    public Terrain terrain;
    public string dataPath = "TerrainTrees.json";

    public ComputeShader cullingCompleteShader;
    public float treeBoundsRadius = 2f;
    
    private List<TreePrototypeRenderer> treeRenderers = new List<TreePrototypeRenderer>();
    private Camera mainCamera;
    private Bounds terrainBounds;

    private Plane[] frusrumPlanes = new Plane[6];
    private Vector4[] frustumPlanesVector = new Vector4[6];

    private const int THREAD_GROUP_SIZE = 64;

    void Start()
    {
        mainCamera = Camera.main;
        LoadAndSetupTrees();
    }

    void LoadAndSetupTrees()
    {
        string filePath = System.IO.Path.Combine(Application.dataPath, dataPath);
        if (!System.IO.File.Exists(filePath))
        {
            Debug.LogError("No tree data found!");
            return;
        }

        string json = System.IO.File.ReadAllText(filePath);
        TerrainTreeData data = JsonUtility.FromJson<TerrainTreeData>(json);

        // 初始化每个原型的渲染器
        for (int i = 0; i < data.prefabPath.Count; i++)
        {
            TreePrototypeRenderer renderer = new TreePrototypeRenderer();
            
            // 获取预制体中的网格和材质
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(data.prefabPath[i]);
            if (prefab != null)
            {
                MeshFilter meshFilter = prefab.GetComponentInChildren<MeshFilter>();
                MeshRenderer meshRenderer = prefab.GetComponentInChildren<MeshRenderer>();

                if (meshFilter != null)
                {
                    renderer.mesh = meshFilter.sharedMesh;
                    renderer.boundsRadius = renderer.mesh.bounds.extents.magnitude;
                }

                if (meshRenderer != null)
                {
                    renderer.material = meshRenderer.sharedMaterial;
                }
            }
            
            treeRenderers.Add(renderer);
        }

        // 收集所有树的变换矩阵
        TerrainData terrainData = terrain.terrainData;
        Vector3 terrainSize = terrainData.size;
        Vector3 terrainPos = terrain.transform.position;

        Stopwatch stopwatch = new Stopwatch();
        stopwatch.Start();
        foreach (TreeInstanceData treeData in data.trees)
        {
            if (treeData.prototypeIndex >= 0 && treeData.prototypeIndex < treeRenderers.Count)
            {
                Vector3 worldPos = new Vector3(
                    treeData.position.x * terrainSize.x + terrainPos.x,
                    treeData.position.y * terrainSize.y + terrainPos.y,
                    treeData.position.z * terrainSize.z + terrainPos.z
                );

                Quaternion rotation = Quaternion.Euler(0, treeData.rotation * Mathf.Rad2Deg, 0);
                Vector3 scale = treeData.scale;
                
                Matrix4x4 matrix = Matrix4x4.TRS(worldPos, rotation, scale);
                var renderer = treeRenderers[treeData.prototypeIndex];
                renderer.matrices.Add(matrix);
                renderer.worldPosition.Add(worldPos);
            }
        }
        stopwatch.Stop();
        Debug.LogError($"收集所有树的变换矩阵耗时:{stopwatch.ElapsedMilliseconds}ms");

        // 设置计算缓冲区和参数
        foreach (var renderer in treeRenderers)
        {
            if (renderer.mesh != null && renderer.material != null && renderer.matrices.Count > 0)
            {
                int instanceCount = renderer.matrices.Count;
                
                // 创建输入缓冲区（所有实例的矩阵）
                renderer.inputBuffer = new ComputeBuffer(instanceCount, 64);
                renderer.inputBuffer.SetData(renderer.matrices);
                // 创建输出缓冲区（剔除后的矩阵）
                renderer.outputBuffer = new ComputeBuffer(instanceCount, 64, ComputeBufferType.Append);
                renderer.outputBuffer.SetCounterValue(0);
                // 创建计数器缓冲区
                renderer.counterBuffer = new ComputeBuffer(1, sizeof(int), ComputeBufferType.Raw);
                // 创建最终的矩阵缓冲区（将在剔除后使用）
                renderer.culledMatrixBuffer = new ComputeBuffer(instanceCount, 64);
                
                
                // 创建矩阵缓冲区
                renderer.matrixBuffer = new ComputeBuffer(renderer.matrices.Count, 64); // 64 bytes = sizeof(Matrix4x4)
                renderer.matrixBuffer.SetData(renderer.matrices);
                
                // 设置材质参数
                renderer.material.SetBuffer("positionBuffer", renderer.culledMatrixBuffer);
                
                // 设置间接渲染参数
                renderer.args[0] = renderer.mesh.GetIndexCount(0);
                renderer.args[1] = (uint)renderer.matrices.Count;
                renderer.args[2] = renderer.mesh.GetIndexStart(0);
                renderer.args[3] = renderer.mesh.GetBaseVertex(0);
                renderer.args[4] = 0;
                
                renderer.argsBuffer = new ComputeBuffer(1, renderer.args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
                renderer.argsBuffer.SetData(renderer.args);
            }
        }

        // 设置地形边界
        terrainBounds = terrainData.bounds;
        terrainBounds.center += terrain.transform.position;
    }

    void Update()
    {
        if (mainCamera == null || cullingCompleteShader == null)
        {
            return;
        }

        GeometryUtility.CalculateFrustumPlanes(mainCamera, frusrumPlanes);

        for (int i = 0; i < frusrumPlanes.Length; i++)
        {
            frustumPlanesVector[i] = new Vector4(
                frusrumPlanes[i].normal.x,
                frusrumPlanes[i].normal.y,
                frusrumPlanes[i].normal.z,
                frusrumPlanes[i].distance
            );
        }
        
        // 对每种树木类型进行视锥剔除
        foreach (var renderer in treeRenderers)
        {
            if (renderer.mesh != null && renderer.material != null && renderer.inputBuffer != null)
            {
                PerformFrustumCulling(renderer);
                DrawCulledTrees(renderer);
            }
        }
        
    }

    void PerformFrustumCulling(TreePrototypeRenderer renderer)
    {
        int instaceCount = renderer.matrices.Count;
        renderer.outputBuffer.SetCounterValue(0);
        
        //设置
    }

    void DrawCulledTrees(TreePrototypeRenderer renderer)
    {
        if (renderer.mesh != null && renderer.material != null && renderer.argsBuffer != null)
        {
            // 这里可以添加视锥体剔除逻辑
            Graphics.DrawMeshInstancedIndirect(
                renderer.mesh, 
                0, 
                renderer.material, 
                terrainBounds, 
                renderer.argsBuffer,
                0,
                null,
                ShadowCastingMode.On,
                true
            );
        }
    }

    void OnDisable()
    {
        // 释放缓冲区
        foreach (TreePrototypeRenderer renderer in treeRenderers)
        {
            if (renderer.matrixBuffer != null)
            {
                renderer.matrixBuffer.Release();
                renderer.matrixBuffer = null;
            }
            
            if (renderer.argsBuffer != null)
            {
                renderer.argsBuffer.Release();
                renderer.argsBuffer = null;
            }
        }
        
        treeRenderers.Clear();
    }
}
using System.Collections.Generic;
using System.Diagnostics;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;
using Debug = UnityEngine.Debug;

//https://chat.deepseek.com/share/2fka9egwa83rwnprk6
public class IndirectTreeRenderer : MonoBehaviour
{
    [System.Serializable]
    public class TreePrototypeRenderer
    {
        public Mesh mesh;
        public Material material;
        public List<Matrix4x4> matrices = new List<Matrix4x4>();
        public List<Matrix4x4> normalMatrices = new List<Matrix4x4>();
        public List<Vector3> worldPosition = new List<Vector3>();
        public float boundsRadius = 2f;
        
        // 用于间接渲染
        public ComputeBuffer matrixBuffer;
        public ComputeBuffer normalMatrixBuffer;
        public ComputeBuffer argsBuffer;
        public ComputeBuffer culledMatrixBuffer;
        public ComputeBuffer culledNormalMatrixBuffer;
        public uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        
        //用于视锥剔除
        public ComputeBuffer inputBuffer;
        public ComputeBuffer inputNormalBuffer;
        public ComputeBuffer outputBuffer;
        public ComputeBuffer outputNormalBuffer;
        public ComputeBuffer counterBuffer;
    }

    public Terrain terrain;
    public string dataPath = "TerrainTrees.json";

    public ComputeShader cullingComputeShader;
    public float treeBoundsRadius = 2f;
    
    private List<TreePrototypeRenderer> treeRenderers = new List<TreePrototypeRenderer>();
    private Camera mainCamera;
    private Bounds terrainBounds;

    private Plane[] frusrumPlanes = new Plane[6];
    private Vector4[] frustumPlanesVector = new Vector4[6];

    private const int THREAD_GROUP_SIZE = 64;

    public bool GPUInstanceON = true;
    private const string GPUINSTANCE_ON = "_GPUINSTANCE_ON";

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
                
                //收集矩阵
                Matrix4x4 matrix = Matrix4x4.TRS(worldPos, rotation, scale);
                Matrix4x4 normalMatrix = matrix.inverse.transpose;
                
                var renderer = treeRenderers[treeData.prototypeIndex];
                renderer.matrices.Add(matrix);
                renderer.normalMatrices.Add(normalMatrix);
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
                renderer.inputNormalBuffer = new ComputeBuffer(instanceCount, 64);
                renderer.inputNormalBuffer.SetData(renderer.normalMatrices);
                // 创建输出缓冲区（剔除后的矩阵）
                renderer.outputBuffer = new ComputeBuffer(instanceCount, 64, ComputeBufferType.Append);
                renderer.outputBuffer.SetCounterValue(0);
                renderer.outputNormalBuffer = new ComputeBuffer(instanceCount, 64, ComputeBufferType.Append);
                renderer.outputNormalBuffer.SetCounterValue(0);
                // 创建计数器缓冲区
                renderer.counterBuffer = new ComputeBuffer(1, sizeof(int), ComputeBufferType.Raw);
                // 创建最终的矩阵缓冲区（将在剔除后使用）
                renderer.culledMatrixBuffer = new ComputeBuffer(instanceCount, 64, ComputeBufferType.Raw);
                renderer.culledNormalMatrixBuffer = new ComputeBuffer(instanceCount, 64, ComputeBufferType.Raw);
                
                // 创建矩阵缓冲区
                renderer.matrixBuffer = new ComputeBuffer(renderer.matrices.Count, 64); // 64 bytes = sizeof(Matrix4x4)
                renderer.matrixBuffer.SetData(renderer.matrices);
                
                // 设置材质参数
                renderer.material.SetBuffer("positionBuffer", renderer.culledMatrixBuffer);
                renderer.material.SetBuffer("normalBuffer",renderer.culledNormalMatrixBuffer);
                if (GPUInstanceON)
                {
                    renderer.material.EnableKeyword(GPUINSTANCE_ON);
                }
                else
                {
                    renderer.material.DisableKeyword(GPUINSTANCE_ON);
                }
                
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
        if (mainCamera == null || cullingComputeShader == null)
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
        
        //设置computeshader参数
        cullingComputeShader.SetBuffer(0, "InputMatrices", renderer.inputBuffer);
        cullingComputeShader.SetBuffer(0, "InputNormalMatrices", renderer.inputNormalBuffer);
        cullingComputeShader.SetBuffer(0, "OutputMatrices", renderer.outputBuffer);
        cullingComputeShader.SetBuffer(0,"OutputNormalMatrices",renderer.outputNormalBuffer);
        cullingComputeShader.SetInt("InstanceCount", instaceCount);
        cullingComputeShader.SetFloat("BoundsRadius", renderer.boundsRadius);
        
        //设置视锥平面
        cullingComputeShader.SetVectorArray("FrustumPlanes", frustumPlanesVector);

        // 计算线程组数量
        int threadGroups = Mathf.CeilToInt((float)instaceCount / THREAD_GROUP_SIZE);

        // 执行Compute Shader
        cullingComputeShader.Dispatch(0, threadGroups, 1, 1);

        // 获取剔除后的实例数量
        ComputeBuffer.CopyCount(renderer.outputBuffer, renderer.counterBuffer, 0);

        int[] counter = new int[1] { 0 };

        renderer.counterBuffer.GetData(counter);
        int visibleCount = counter[0];

        if (visibleCount > 0)
        {
            // 使用ComputeShader将数据从输出缓冲区复制到最终缓冲区
            ComputeShader copyShader = cullingComputeShader; // 可以使用同一个Shader的不同kernel
            copyShader.SetBuffer(1, "InputMatrices", renderer.outputBuffer);
            copyShader.SetBuffer(1, "OutputMatricesCopy", renderer.culledMatrixBuffer);
            copyShader.SetInt("InstanceCount", visibleCount);
            
            int copyThreadGroups = Mathf.CeilToInt((float)visibleCount / THREAD_GROUP_SIZE);
            copyShader.Dispatch(1, copyThreadGroups, 1, 1);

            // ComputeBuffer.CopyCount(renderer.outputBuffer, renderer.culledMatrixBuffer, 0);
            //ComputeBuffer.CopyCount(renderer.outputNormalBuffer,renderer.culledNormalMatrixBuffer,0);
            
            // 更新绘制参数
            renderer.args[1] = (uint)visibleCount;
            renderer.argsBuffer.SetData(renderer.args);
        }
        else
        {
            //没有可见实例，设置实例数量为0
            renderer.args[1] = 0;
            renderer.argsBuffer.SetData(renderer.args);
        }
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
            ClearBuffer(renderer.matrixBuffer);
            ClearBuffer(renderer.argsBuffer);
            ClearBuffer(renderer.inputBuffer);
            ClearBuffer(renderer.outputBuffer);
            ClearBuffer(renderer.culledMatrixBuffer);
            ClearBuffer(renderer.counterBuffer);
            
            if (GPUInstanceON)
            {
                renderer.material.DisableKeyword(GPUINSTANCE_ON);
            }
        }
        
        treeRenderers.Clear();
    }

    void ClearBuffer(ComputeBuffer buffer)
    {
        if (buffer != null)
        {
            buffer.Release();
            buffer = null;
        }
    }
}
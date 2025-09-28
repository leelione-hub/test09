using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class TreePrototypeRenderer : GPUCullingData
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
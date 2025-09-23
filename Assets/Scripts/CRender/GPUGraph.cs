using System;
using System.Diagnostics;
using UnityEngine;
using Debug = UnityEngine.Debug;

namespace CRender
{
    public class GPUGraph : MonoBehaviour
    {
        [SerializeField]
        private ComputeShader computeShader;
        [SerializeField,Range(10,10000)]
        private int Resolution;
        [SerializeField]
        private Material material;
        [SerializeField]
        private Mesh mesh;

        [SerializeField,Range(0.01f,10f)] 
        private float speed;

        private ComputeBuffer positionBuffer;

        private readonly int positionsId = Shader.PropertyToID("_Positions"),
            resolustionId = Shader.PropertyToID("_Resolution"),
            stepId = Shader.PropertyToID("_Step"),
            timeId = Shader.PropertyToID("_Time"),
            gopositionId = Shader.PropertyToID("_GOPosition");
        
        
        void UpdateFunctionOnGPU()
        {
            computeShader.SetFloat(timeId, Time.time * speed);
            computeShader.SetVector(gopositionId, this.transform.position);
            int groups = Mathf.CeilToInt(Resolution / 8f);
            computeShader.Dispatch(0, groups, groups, 1);
        }

        void Draw()
        {
            Bounds bounds = new Bounds(Vector3.zero, Vector3.one * (2f + 2f / Resolution));
            Graphics.DrawMeshInstancedProcedural(mesh, 0, material, bounds, positionBuffer.count);
        }

        private void OnEnable()
        {
            
            positionBuffer = new ComputeBuffer(Resolution * Resolution, sizeof(float) * 4);
            float step = 2f / Resolution;
            computeShader.SetInt(resolustionId, Resolution);
            computeShader.SetFloat(stepId, step);
            computeShader.SetBuffer(0, positionsId, positionBuffer);
            
            computeShader.SetFloat(timeId, Time.time);
            int groups = Mathf.CeilToInt(Resolution / 8f);
            computeShader.Dispatch(0, groups, groups, 1);
            
            material.SetBuffer(positionsId, positionBuffer);
            material.SetFloat(stepId, stepId);
        }

        private void OnDisable()
        {
            positionBuffer.Release();
            positionBuffer = null;
        }

        private void Update()
        {
            UpdateFunctionOnGPU();
            Draw();
        }
    }
}
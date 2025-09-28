using UnityEngine;

public class HizCulling : IGPUCulling
{
    public ComputeShader cullingComputeShader;
    public Camera _camera;
    private const int THREAD_GROUP_SIZE = 64;

    public HizCulling(ComputeShader computeShader, Camera camera)
    {
        this.cullingComputeShader = computeShader;
        this._camera = camera;
    }
    
    public void Culling(GPUCullingData data)
    {
        TreePrototypeRenderer renderer = data as TreePrototypeRenderer;
        int instanceCount = renderer.matrices.Count;
        
        // 创建可见性标记缓冲区
        ComputeBuffer visibilityBuffer = new ComputeBuffer(instanceCount, sizeof(uint));
        ComputeBuffer visibleCountBuffer = new ComputeBuffer(1, sizeof(uint));
        // 设置Compute Shader参数
        cullingComputeShader.SetBuffer(0, "InputMatrices", renderer.inputBuffer);
        cullingComputeShader.SetBuffer(0, "OutputMatrices", renderer.outputBuffer);
        cullingComputeShader.SetBuffer(0, "VisibilityFlags", visibilityBuffer);
        cullingComputeShader.SetBuffer(0, "VisibleCount", visibleCountBuffer);
        cullingComputeShader.SetInt("InstanceCount", instanceCount);
        cullingComputeShader.SetMatrix("_V", _camera.worldToCameraMatrix);
        cullingComputeShader.SetMatrix("_P",_camera.projectionMatrix);
        
        // 计算线程组数量
        int threadGroups = Mathf.CeilToInt((float)instanceCount / THREAD_GROUP_SIZE);
        
        // 执行Compute Shader
        cullingComputeShader.Dispatch(0, threadGroups, 1, 1);
        
        // 获取可见实例数量
        uint[] visibleCountArray = new uint[1];
        visibleCountBuffer.GetData(visibleCountArray);
        int visibleCount = (int)visibleCountArray[0];

        if (visibleCount > 0)
        {
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
        
        // 清理临时缓冲区
        visibilityBuffer.Release();
        visibleCountBuffer.Release();
    }
}
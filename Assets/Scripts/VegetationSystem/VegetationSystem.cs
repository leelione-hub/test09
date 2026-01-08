using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class VegetationSystemObject : MonoBehaviour
{
    public Material material;
    public Mesh mesh;

    private GraphicsBuffer commandBuf;
    private GraphicsBuffer.IndirectDrawIndexedArgs[] commandData;
    private const int commandCount = 2;

    private void Start()
    {
        commandBuf = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, commandCount,
            GraphicsBuffer.IndirectDrawIndexedArgs.size);
        commandData = new GraphicsBuffer.IndirectDrawIndexedArgs[commandCount];
    }

    private void OnDestroy()
    {
        commandBuf?.Release();
        commandBuf = null;
    }

    private void Update()
    {
        Draw();
    }

    void Draw()
    {
        RenderParams rp = new RenderParams(material);
        rp.worldBounds = new Bounds(Vector3.zero, Vector3.one * 10000);
        rp.matProps = new MaterialPropertyBlock();
        rp.matProps.SetMatrix("_ObjectToWorld", Matrix4x4.Translate(new Vector3(-4.5f, 0, 0)));
        commandData[0].indexCountPerInstance = mesh.GetIndexCount(0);
        commandData[0].instanceCount = 10;
        commandData[1].indexCountPerInstance = mesh.GetIndexCount(0);
        commandData[1].instanceCount = 10;
        commandBuf.SetData(commandData);
        Graphics.RenderMeshIndirect(rp, mesh, commandBuf, commandCount);
    }
}

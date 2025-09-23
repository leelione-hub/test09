using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;


public class SetSingleData : MonoBehaviour
{
    public GameObject go;
    public Material mat;

    private Matrix4x4 objectToWorld;
    private ComputeBuffer matrixBuffer;

    public List<GameObject> gos = new List<GameObject>();

    private void Start()
    {
        mat = go.GetComponentInChildren<MeshRenderer>().material; 
        matrixBuffer = new ComputeBuffer(2, 64);
        var gameObjects = GetComponentsInChildren<GameObject>();
        gos = gameObjects.ToList();
    }

    private void Update()
    {
        if (mat != null)
        {
            objectToWorld = Matrix4x4.TRS(go.transform.position, go.transform.rotation, go.transform.localScale);
            //matrixBuffer.SetData(objectToWorld);
            //mat.SetBuffer("positionBuffer", objectToWorld);
            Debug.Log(objectToWorld);
            mat.SetMatrix("positionBuffer", objectToWorld);

            Debug.Log(mat.GetMatrix("unity_ObjectToWorld"));
            Debug.Log(mat.GetMatrix("UNITY_MATRIX_M"));
        }
    }
}

using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AutoRatation : MonoBehaviour
{
    public Vector3 axis;
    public float   speed;
    public float   invokeTime = 0f;

    private float     _curTime;
    private Transform _transform;
    
    private void Start()
    {
        _transform = this.transform;
    }

    private void FixedUpdate()
    {
        _curTime += Time.deltaTime;
        if (_curTime < invokeTime) return;
        _transform.Rotate(axis,speed);
    }
}

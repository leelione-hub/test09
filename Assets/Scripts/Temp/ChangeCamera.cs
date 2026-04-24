using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ChangeCamera : MonoBehaviour
{
    [Serializable]
    public class CameraPointTime
    {
        public GameObject cameraPoint;
        public float      startTime;
        public float      endTime;
    }
    
    public List<CameraPointTime> cameralist;

    public float curTime;
    private void Start()
    {
        if (cameralist == null)
        {
            this.enabled = false;
            return;
        }

        curTime = 0f;
    }

    private void Update()
    {
        curTime += Time.deltaTime;
        foreach (var data in cameralist)
        {
            if (data.startTime < curTime)
            {
                if (data.endTime < 0f || data.endTime > curTime)
                {
                    if (!data.cameraPoint.activeSelf)
                    {
                        data.cameraPoint.SetActive(true);
                    }
                }
                else
                {
                    if (data.cameraPoint.activeSelf)
                    {
                        data.cameraPoint.SetActive(false);
                    }
                }
            }
            else
            {
                if (data.cameraPoint.activeSelf)
                {
                    data.cameraPoint.SetActive(false);
                }
            }
        }
    }
}

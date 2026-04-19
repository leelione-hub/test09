using System.Collections.Generic;
using UnityEngine;

public class MaterialUpdater : MonoBehaviour
{
    private enum FaceAxis
    {
        XPlus,
        XMinus,
        YPlus,
        YMinus,
        ZPlus,
        ZMinus
    }

    [SerializeField]
    private GameObject m_HeadBone;

    [SerializeField]
    private FaceAxis m_FaceAxis = FaceAxis.YPlus;

    [SerializeField]
    private List<SkinnedMeshRenderer> m_FaceRenderers;

    private void Update()
    {
        if (m_FaceRenderers == null || m_HeadBone == null)
        {
            return;
        }

        Vector3 localFaceDirection = GetLocalFaceDirection();
        
        Vector3 direction = (m_HeadBone.transform.rotation * localFaceDirection).normalized;
        Debug.Log($"BD{m_HeadBone.transform.forward}, BR{m_HeadBone.transform.rotation}, faceDirection {m_FaceRenderers[0].transform.forward} direction {direction}");
        foreach (var renderer in m_FaceRenderers)
        {
            if (renderer == null)
            {
                continue;
            }

            foreach (var material in renderer.sharedMaterials)
            {
                if (material == null)
                {
                    continue;
                }

                material.SetVector("_FaceDirection", direction);
            }
        }
    }

    private Vector3 GetLocalFaceDirection()
    {
        return m_FaceAxis switch
        {
            FaceAxis.XPlus => Vector3.right,
            FaceAxis.XMinus => Vector3.left,
            FaceAxis.YPlus => Vector3.up,
            FaceAxis.YMinus => Vector3.down,
            FaceAxis.ZPlus => Vector3.forward,
            FaceAxis.ZMinus => Vector3.back,
            _ => Vector3.up
        };
    }
}

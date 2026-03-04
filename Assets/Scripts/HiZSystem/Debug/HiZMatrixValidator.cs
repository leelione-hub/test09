using UnityEngine;

namespace HiZTechnique
{
    /// <summary>
    /// HiZ VP矩阵验证工具
    /// 用于验证投影矩阵设置是否正确
    /// </summary>
    public class HiZMatrixValidator : MonoBehaviour
    {
        [Header("参考点")]
        public Transform testPoint;
        
        [Header("相机")]
        public Camera cullingCamera;
        
        [Header("调试输出")]
        public bool showDebugInfo = true;
        
        void OnValidate()
        {
            if (cullingCamera == null)
                cullingCamera = Camera.main;
        }
        
        [ContextMenu("验证VP矩阵")]
        void ValidateVPMatrix()
        {
            if (cullingCamera == null)
            {
                Debug.LogError("[HiZ MatrixValidator] 相机未设置");
                return;
            }
            
            // 计算VP矩阵（与VegetationHizIntegrator相同的方式）
            Matrix4x4 vp = GL.GetGPUProjectionMatrix(cullingCamera.projectionMatrix, false) * 
                          cullingCamera.worldToCameraMatrix;
            
            // 转置后的矩阵（用于Shader）
            Matrix4x4 vpTransposed = vp.transpose;
            
            Debug.Log("=== VP矩阵验证 ===");
            Debug.Log($"相机: {cullingCamera.name}");
            Debug.Log($"相机位置: {cullingCamera.transform.position}");
            Debug.Log($"相机朝向: {cullingCamera.transform.forward}");
            
            // 测试原点
            Vector4 origin = new Vector4(0, 0, 0, 1);
            Vector4 originClip = vp * origin;
            Debug.Log($"原点 (0,0,0) 在裁剪空间: {originClip} (w={originClip.w})");
            
            // 测试相机位置
            Vector4 camPos = cullingCamera.transform.position;
            camPos.w = 1;
            Vector4 camClip = vp * camPos;
            Debug.Log($"相机位置在裁剪空间: {camClip} (w={camClip.w})");
            
            // 测试相机前方1单位
            Vector4 frontPos = cullingCamera.transform.position + cullingCamera.transform.forward;
            frontPos.w = 1;
            Vector4 frontClip = vp * frontPos;
            Debug.Log($"相机前方1单位在裁剪空间: {frontClip} (w={frontClip.w})");
            
            // 测试Shader中的变换（使用转置矩阵和行向量乘法）
            Vector4 testWorld = testPoint != null ? 
                new Vector4(testPoint.position.x, testPoint.position.y, testPoint.position.z, 1) : 
                new Vector4(0, 0, 5, 1);
            
            // 模拟Shader中的 mul(vector, matrix)
            Vector4 testClipShader = MultiplyVectorMatrix(testWorld, vpTransposed);
            Debug.Log($"测试点世界坐标: {testWorld}");
            Debug.Log($"测试点在裁剪空间(Shader): {testClipShader} (w={testClipShader.w})");
            
            if (testClipShader.w > 0)
            {
                Vector3 ndc = new Vector3(testClipShader.x, testClipShader.y, testClipShader.z) / testClipShader.w;
                Vector2 uv = new Vector2(ndc.x * 0.5f + 0.5f, ndc.y * 0.5f + 0.5f);
                float depth = ndc.z * 0.5f + 0.5f;
                
                Debug.Log($"测试点 NDC: {ndc}");
                Debug.Log($"测试点 UV: {uv}");
                Debug.Log($"测试点深度: {depth}");
                
                // 检查UV是否在有效范围内
                if (uv.x >= 0 && uv.x <= 1 && uv.y >= 0 && uv.y <= 1)
                {
                    Debug.Log("✓ 测试点在屏幕范围内");
                }
                else
                {
                    Debug.LogWarning("✗ 测试点在屏幕范围外");
                }
            }
            else
            {
                Debug.LogWarning("✗ 测试点在相机后面 (w <= 0)");
            }
        }
        
        /// <summary>
        /// 模拟 HLSL 的 mul(vector, matrix) - 行向量乘以矩阵
        /// </summary>
        Vector4 MultiplyVectorMatrix(Vector4 vector, Matrix4x4 matrix)
        {
            Vector4 result = new Vector4();
            result.x = vector.x * matrix.m00 + vector.y * matrix.m10 + vector.z * matrix.m20 + vector.w * matrix.m30;
            result.y = vector.x * matrix.m01 + vector.y * matrix.m11 + vector.z * matrix.m21 + vector.w * matrix.m31;
            result.z = vector.x * matrix.m02 + vector.y * matrix.m12 + vector.z * matrix.m22 + vector.w * matrix.m32;
            result.w = vector.x * matrix.m03 + vector.y * matrix.m13 + vector.z * matrix.m23 + vector.w * matrix.m33;
            return result;
        }
        
        void OnDrawGizmos()
        {
            if (!showDebugInfo || cullingCamera == null) return;
            
            // 绘制视锥体
            Gizmos.color = Color.yellow;
            Matrix4x4 temp = Gizmos.matrix;
            Gizmos.matrix = Matrix4x4.TRS(cullingCamera.transform.position, cullingCamera.transform.rotation, Vector3.one);
            
            float far = cullingCamera.farClipPlane;
            float near = cullingCamera.nearClipPlane;
            float aspect = cullingCamera.aspect;
            float fov = cullingCamera.fieldOfView;
            
            float tanFov = Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
            float nearHeight = 2 * near * tanFov;
            float nearWidth = nearHeight * aspect;
            float farHeight = 2 * far * tanFov;
            float farWidth = farHeight * aspect;
            
            Vector3 nearCenter = new Vector3(0, 0, near);
            Vector3 farCenter = new Vector3(0, 0, far);
            
            // 绘制近裁剪面
            Vector3 ntl = nearCenter + new Vector3(-nearWidth * 0.5f, nearHeight * 0.5f, 0);
            Vector3 ntr = nearCenter + new Vector3(nearWidth * 0.5f, nearHeight * 0.5f, 0);
            Vector3 nbl = nearCenter + new Vector3(-nearWidth * 0.5f, -nearHeight * 0.5f, 0);
            Vector3 nbr = nearCenter + new Vector3(nearWidth * 0.5f, -nearHeight * 0.5f, 0);
            
            Gizmos.DrawLine(ntl, ntr);
            Gizmos.DrawLine(ntr, nbr);
            Gizmos.DrawLine(nbr, nbl);
            Gizmos.DrawLine(nbl, ntl);
            
            Gizmos.matrix = temp;
            
            // 绘制测试点
            if (testPoint != null)
            {
                Gizmos.color = Color.red;
                Gizmos.DrawSphere(testPoint.position, 0.1f);
                Gizmos.DrawLine(cullingCamera.transform.position, testPoint.position);
            }
        }
    }
}

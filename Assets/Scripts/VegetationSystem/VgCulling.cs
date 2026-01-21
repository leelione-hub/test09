using UnityEngine;

namespace VegetationSystem
{
    public class VgCulling
    {
        private VgRender      _vgRender;
        private ComputeShader _cullingCS;
        private Camera        _cullingCamera;
        public VgCulling(VgRender vgRender,ComputeShader cs)
        {
            _vgRender = vgRender;
            _cullingCS = cs;
        }

        public void SetCullingCamera(Camera camera)
        {
            _cullingCamera = camera;
        }
        
        
        void SetFrustumPlanes()
        {
            Plane[] planes = GeometryUtility.CalculateFrustumPlanes(_cullingCamera);

            Vector4[] planeData = new Vector4[6];
            for (int i = 0; i < 6; i++)
            {
                var normal   = planes[i].normal;
                var distance = planes[i].distance;
                planeData[i] = new Vector4(
                    normal.x,
                    normal.y,
                    normal.z,
                    distance
                );
            }
            _cullingCS.SetVectorArray(VgConstantProperty.FRUSTUMPLANES, planeData);
        }
        
        public void DispatchCulling()
        {
            int indexID = -1;
            SetFrustumPlanes();
            for (int i = 0; i < _vgRender.vgDataList.Count; i++)
            {
                var    mesh = _vgRender.vgDataList[i].mesh;
                uint[] args = new uint[5];
                args[0] = mesh.GetIndexCount(_vgRender.vgDataList[i].subMesh);
                args[1] = 0;
                args[2] = mesh.GetIndexStart(_vgRender.vgDataList[i].subMesh);
                args[3] = mesh.GetBaseVertex(_vgRender.vgDataList[i].subMesh);
                args[4] = 0;
                _vgRender.vgDataList[i].args.SetData(args);
                
                _vgRender.vgDataList[i].visibleBuffer.SetCounterValue(0);
                int kernel = 0;
                _cullingCS.SetBuffer(kernel, VgConstantProperty.ALLINSTANCES, _vgRender.vgDataList[i].allInstanceBuffer);
                _cullingCS.SetBuffer(kernel, VgConstantProperty.VISIBLEINSTANCES, _vgRender.vgDataList[i].visibleBuffer);
                _cullingCS.SetBuffer(kernel, VgConstantProperty.ARGSBUFFER, _vgRender.vgDataList[i].args);
                _cullingCS.SetBool(VgConstantProperty.ENABLECULLING, true);
                
                int threadGroup = Mathf.CeilToInt(_vgRender.vgDataList[i].grassCount / 64.0f);
                _cullingCS.Dispatch(kernel, threadGroup, 1, 1);
            }
        }
    }
}
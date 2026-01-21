using Extension;
using LWGUI;
using UnityEngine;
using UnityEngine.Rendering;

namespace VegetationSystem
{
    public class GrassIndirectRenderer : MonoBehaviour
    {
        public  Mesh     grassMesh;
        public  Material grassMaterial;
        private int      grassCount           = 100_000;
        public  float    areaSize             = 50f;
        public  Vector3  terrainSize          = new Vector3(1000, 1000, 1000);
        public  bool     EnableFrustumCulling = true;
        public  Camera   cullingCamere;
        
        private GraphicsBuffer allInstanceBuffer;
        private GraphicsBuffer argsBuffer;
        // private GraphicsBuffer grassBuffer;
        private GraphicsBuffer visibleBuffer;

        const int ARGS_STRIDE = 5;

        public ComputeShader cullingCS;

        public TextAsset grassJson;

        private int stride;

        private int ALLINSTANCES     = Shader.PropertyToID("_AllInstances");
        private int VISIBLEINSTANCES = Shader.PropertyToID("_VisibleInstances");
        private int ARGSBUFFER       = Shader.PropertyToID("_ArgsBuffer");
        private int FRUSTUMPLANES    = Shader.PropertyToID("_FrustumPlanes");
        private int ENABLECULLING    = Shader.PropertyToID("EnableFrustumCulling");
        private int INSTANCEBUFFER   = Shader.PropertyToID("_InstanceBuffer");

        private VgRender  _vgRender;
        private VgCulling _vgCulling;



        void Start()
        {
            if (cullingCamere == null)
            {
                cullingCamere = Camera.main;
            }

            if (this.GetComponentInChildren<Terrain>())
            {
                var data = this.GetComponent<Terrain>().terrainData;
                terrainSize = data.bounds.size;
            }
            
            _vgRender           = new VgRender();
            _vgRender.isCulling = true;
            _vgCulling          = new VgCulling(_vgRender,cullingCS);
            _vgCulling.SetCullingCamera(cullingCamere);
            
            InitBuffers();
        }

        void InitBuffers()
        {
            var grassData = LoadGrassDatas();

            _vgRender.InitVgDatas(grassData, terrainSize/*,grassMesh,grassMaterial*/);
            
            if (grassData == null)
            {
                //没有加载到对应的数据
                this.enabled = false;
                return;
            }

            grassCount = grassData.trees.Count;
            stride     = sizeof(float) * (3 + 1 + 2);
            
            allInstanceBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, grassCount, stride);
            SetAllBufferDatas(grassData);
            
            visibleBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append, grassCount, stride);
            argsBuffer    = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, 1, sizeof(uint) * ARGS_STRIDE);
            
          
        }

        void DispatchCulling()
        {
            visibleBuffer.SetCounterValue(0);

            uint[] args = new uint[ARGS_STRIDE];
            args[0] = grassMesh.GetIndexCount(0);
            args[1] = (uint)grassCount;
            args[2] = grassMesh.GetIndexStart(0);
            args[3] = grassMesh.GetBaseVertex(0);
            args[4] = 0;
            argsBuffer.SetData(args);

            int kernel = 0 /*cullingCS.FindKernel("CSMain")*/;

            cullingCS.SetBuffer(kernel, ALLINSTANCES, allInstanceBuffer);
            cullingCS.SetBuffer(kernel, VISIBLEINSTANCES, visibleBuffer);
            cullingCS.SetBuffer(kernel, ARGSBUFFER, argsBuffer);
            cullingCS.SetBool(ENABLECULLING,EnableFrustumCulling);
            SetFrustumPlanes(cullingCS);

            int threadGroup = Mathf.CeilToInt(grassCount / 64.0f);
            cullingCS.Dispatch(kernel, threadGroup, 1, 1);
        }

        TerrainTreeData LoadGrassDatas()
        {
            if (grassJson == null)
            {
                return null;
            }
            string json = grassJson.text;
            TerrainTreeData treedata = JsonUtility.FromJson<TerrainTreeData>(json);
            return treedata;
        }

        void SetAllBufferDatas(TerrainTreeData treedata)
        {
            GrassInstanceData[] data = new GrassInstanceData[grassCount];
            for (int i = 0; i < grassCount; i++)
            {
                data[i] = new GrassInstanceData
                {
                    position = treedata.trees[i].position.Multiply(terrainSize),
                    rotationY = treedata.trees[i].rotation,
                    scale = treedata.trees[i].scale
                };
            }
            allInstanceBuffer.SetData(data);
            //grassMaterial.SetBuffer(INSTANCEBUFFER, allInstanceBuffer);
        }
        

        void Update()
        {
            // DispatchCulling();
            // Render();
            _vgCulling.DispatchCulling();
            _vgRender.Render();
        }

        void Render()
        {
            grassMaterial.SetBuffer(INSTANCEBUFFER, visibleBuffer);
            RenderParams rp = new RenderParams(grassMaterial)
            {
                layer             = gameObject.layer,
                shadowCastingMode = ShadowCastingMode.On,
                receiveShadows    = true,
                worldBounds       = new Bounds(Vector3.zero, Vector3.one * areaSize)
            };
            Graphics.RenderMeshIndirect(rp, grassMesh, argsBuffer);
            
        }

        void SetFrustumPlanes(ComputeShader cs)
        {
            Plane[] planes = GeometryUtility.CalculateFrustumPlanes(cullingCamere);

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
            cs.SetVectorArray(FRUSTUMPLANES, planeData);
        }

        void OnDisable()
        {
            allInstanceBuffer?.Release();
            visibleBuffer?.Release();
            argsBuffer?.Release();
            _vgRender.Dispose();
        }
    }
}

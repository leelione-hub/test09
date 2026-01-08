using UnityEngine;
using UnityEngine.Rendering;

namespace VegetationSystem
{

    public class GrassIndirectRenderer : MonoBehaviour
    {
        public Mesh grassMesh;
        public Material grassMaterial;
        private int grassCount = 100_000;
        public float areaSize = 50f;

        ComputeBuffer instanceBuffer;
        ComputeBuffer argsBuffer;
        GraphicsBuffer grassBuffer;

        const int ARGS_STRIDE = 5;
        
        public TextAsset grassJson;

        struct GrassInstanceData
        {
            public Vector3 position;
            public float rotationY;
            public Vector2 scale;
        }

        void Start()
        {
            InitInstanceBuffer();
            InitArgsBuffer();
        }

        void InitInstanceBuffer()
        {
            
            if (grassJson == null) return;
            
            string json = grassJson.text;
            
            TerrainTreeData treedata = JsonUtility.FromJson<TerrainTreeData>(json);

            grassCount = treedata.trees.Count;
            
            instanceBuffer = new ComputeBuffer(
                grassCount,
                sizeof(float) * (3 + 1 + 2),
                ComputeBufferType.Structured
            );

            GrassInstanceData[] data = new GrassInstanceData[grassCount];

            for (int i = 0; i < grassCount; i++)
            {
                data[i] = new GrassInstanceData
                {
                    position = treedata.trees[i].position * areaSize,
                    rotationY = treedata.trees[i].rotation,
                    scale = treedata.trees[i].scale
                };
            }
            
            // for (int i = 0; i < grassCount; i++)
            // {
            //     data[i] = new GrassInstanceData
            //     {
            //         position = new Vector3(
            //             Random.Range(-areaSize, areaSize),
            //             0,
            //             Random.Range(-areaSize, areaSize)
            //         ),
            //         rotationY = Random.Range(0, Mathf.PI * 2),
            //         scale = Vector2.one * Random.Range(0.8f, 1.2f)
            //     };
            // }

            instanceBuffer.SetData(data);
            grassMaterial.SetBuffer("_InstanceBuffer", instanceBuffer);
        }

        void InitArgsBuffer()
        {
            uint[] args = new uint[ARGS_STRIDE];
            args[0] = grassMesh.GetIndexCount(0);
            args[1] = (uint)grassCount;
            args[2] = grassMesh.GetIndexStart(0);
            args[3] = grassMesh.GetBaseVertex(0);
            args[4] = 0;

            argsBuffer = new ComputeBuffer(
                1,
                sizeof(uint) * ARGS_STRIDE,
                ComputeBufferType.IndirectArguments
            );
            argsBuffer.SetData(args);
            grassBuffer = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, grassCount, GraphicsBuffer.IndirectDrawIndexedArgs.size);
            grassBuffer.SetData(args);
        }

        void Update()
        {
            RenderParams rp = new RenderParams(grassMaterial)
            {
                layer = gameObject.layer,
                shadowCastingMode = ShadowCastingMode.On,
                receiveShadows = true,
                worldBounds = new Bounds(Vector3.zero, Vector3.one * areaSize)
            };

            Graphics.RenderMeshIndirect(
                rp,
                grassMesh,
                grassBuffer
            );
        }

        void OnDisable()
        {
            instanceBuffer?.Release();
            argsBuffer?.Release();
        }
    }
}

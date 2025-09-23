Shader "Custom/VertexModification"
{
    Properties
    {
    }
    SubShader
    {
        Tags
        {
            "LightMode" = "UniversalForward"
        }
        LOD 200

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5

            // #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #pragma multi_compile_instancing
            
            // 从ComputeBuffer获取修改后的顶点位置
            StructuredBuffer<float3> _Positions;
            
            struct appdata
            {
                uint vertexID : SV_VertexID;
                uint instanceID : SV_InstanceID;
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float3 worldPos : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            
            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                // 使用ComputeBuffer中的位置数据
                float3 modifiedPosition = _Positions[v.instanceID];

                v.vertex.xyz += modifiedPosition;
                // 转换到裁剪空间
                o.vertex = TransformObjectToHClip(v.vertex);
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = TransformObjectToWorld(v.vertex);
                return o;
            }
            
            real4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                real4 col = 1;
                col.xyz = saturate(i.worldPos * 0.5 + 0.5);
                return col;
            }
            ENDHLSL
        }
    }
    Fallback "Universal Render Pipeline/Unlit"
}
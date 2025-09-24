Shader "Custom/CustomCapsule"
{
    Properties
    {
        _Color("Color",color) = (1,1,1,1)
        _WindDir("WindDir",Vector)=(1,0,0,1)
        _HColor("HighColor",color) =(1,1,1,1)
        _BColor("BottomColor",color) = (0,1,0,1)
        _HeighRatio("HeightRatio",Float) = 10
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
            "UniversalMaterialType" = "Unlit"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100

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
            StructuredBuffer<float4x4> positionBuffer;
            //float4x4 positionBuffer;
            
            struct appdata
            {
                uint vertexID : SV_VertexID;
                uint instanceID : SV_InstanceID;
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float4 worldPos : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            half4 _Color;
            real4 _WindDir;
            real4 _HColor;
            real4 _BColor;
            real _HeighRatio;
            
            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                // 使用ComputeBuffer中的位置数据
                // 转换到裁剪空间
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = mul(positionBuffer[v.instanceID],v.vertex);
                //o.worldPos.xyz += _WindDir.xyz * _WindDir.w * v.vertex.y * sin(_Time.y);
                o.vertex = mul(UNITY_MATRIX_VP,o.worldPos);
                return o;
            }
            
            real4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                real4 col = 1;
                col.rgb = lerp(_BColor,_HColor,i.worldPos.y / _HeighRatio);
                //col.rgb = _HColor.xyz;
                return _Color * col;
            }
            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }
            HLSLPROGRAM
            #pragma vertex DepthVertex
            #pragma fragment DepthFragment
            #pragma target 4.5

            // #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #pragma multi_compile_instancing
            
            // 从ComputeBuffer获取修改后的顶点位置
            StructuredBuffer<float4x4> positionBuffer;
            //float4x4 positionBuffer;
            
            struct appdata
            {
                uint vertexID : SV_VertexID;
                uint instanceID : SV_InstanceID;
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float4 worldPos : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            half4 _Color;
            
            v2f DepthVertex (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                // 使用ComputeBuffer中的位置数据
                // 转换到裁剪空间
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = mul(positionBuffer[v.instanceID],v.vertex);
                o.vertex = mul(UNITY_MATRIX_VP,o.worldPos);
                return o;
            }
            
            real DepthFragment (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                return i.vertex.z;
            }
            ENDHLSL
        }
    }
    Fallback "Universal Render Pipeline/Unlit"
}
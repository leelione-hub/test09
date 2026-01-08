Shader "URP/GrassIndirect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _WindStrength ("Wind Strength", Range(0, 1)) = 0.5
        _BoundsRadius ("Bounds Radius", Float) = 50
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct GrassInstanceData
            {
                float3 position;
                float rotationY;
                float2 scale;
            };

            StructuredBuffer<GrassInstanceData> _InstanceBuffer;

            // 简单的风动画
            float3 ApplyWind(float3 position, float3 normal, float strength)
            {
                float windTime = _Time.y * 0.5;
                float windX = sin(position.x * 0.1 + windTime) * 0.1;
                float windZ = cos(position.z * 0.1 + windTime) * 0.1;
                
                float3 wind = float3(windX, 0, windZ) * strength;
                return position + normal * wind;
            }

            // 材质属性
            float4 _Color;
            float _WindStrength;
            float _BoundsRadius;
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normal     : NORMAL;
                float2 uv         : TEXCOORD0;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            Varyings vert (Attributes IN)
            {
                GrassInstanceData data = _InstanceBuffer[IN.instanceID];

                float c = cos(data.rotationY);
                float s = sin(data.rotationY);

                float3 pos = IN.positionOS;
                
                pos.xz *= data.scale;
                float3 rotated;
                rotated.x = pos.x * c - pos.z * s;
                rotated.z = pos.x * s + pos.z * c;
                rotated.y = pos.y;

                float3 worldPos = rotated + data.position;

                Varyings OUT;
                OUT.positionCS = TransformWorldToHClip(worldPos);
                OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);
                return OUT;
            }

            half4 frag (Varyings input) : SV_Target
            {
                real4 finalColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv);
                return finalColor;
            }
            ENDHLSL
        }
    }
}

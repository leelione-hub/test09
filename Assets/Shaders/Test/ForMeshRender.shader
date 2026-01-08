// 实例化着色器 - InstancedIndirect.shader
Shader "Custom/InstancedIndirect"
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
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        // 实例数据结构（与C#端匹配）
        struct InstanceData
        {
            float4x4 Matrix;
            float4x4 inverseMatrix;
            float4 color;
        };
        
        // 实例数据缓冲区
        StructuredBuffer<InstanceData> _InstanceData;
        StructuredBuffer<InstanceData> _VisibleInstances;
        
        // 材质属性
        float4 _Color;
        float _WindStrength;
        float _BoundsRadius;
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        float4 _MainTex_ST;
        
        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float2 texcoord : TEXCOORD0;
            uint instanceID : SV_InstanceID;
        };
        
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD0;
            float3 normalWS : TEXCOORD1;
            float2 uv : TEXCOORD2;
            float4 color : TEXCOORD3;
            float3 viewDir : TEXCOORD4;
            float fogCoord  : TEXCOORD5;
        };
        
        // 简单的风动画
        float3 ApplyWind(float3 position, float3 normal, float strength)
        {
            float windTime = _Time.y * 0.5;
            float windX = sin(position.x * 0.1 + windTime) * 0.1;
            float windZ = cos(position.z * 0.1 + windTime) * 0.1;
            
            float3 wind = float3(windX, 0, windZ) * strength;
            return position + normal * wind;
        }
        
        ENDHLSL
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // 获取实例数据
                InstanceData instance = _VisibleInstances[input.instanceID];
                
                // 应用实例变换
                float4 positionWS = mul(instance.Matrix, input.positionOS);
                float3 normalWS = mul((float3x3)instance.inverseMatrix, input.normalOS);
                
                // 应用风动画（可选）
                #ifdef _WIND_ENABLED
                positionWS.xyz = ApplyWind(positionWS.xyz, normalWS, _WindStrength);
                #endif
                
                // 变换到裁剪空间
                output.positionCS = TransformWorldToHClip(positionWS.xyz);
                output.positionWS = positionWS.xyz;
                output.normalWS = normalize(normalWS);
                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.color = instance.color * _Color;
                output.viewDir = GetWorldSpaceNormalizeViewDir(positionWS.xyz);
                output.fogCoord = ComputeFogFactor(output.positionCS.z);
                return output;
            }
            
            float4 frag(Varyings input) : SV_Target
            {
                // 采样纹理
                float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                
                // 基础颜色
                float4 color = texColor * input.color;
                
                // 光照计算
                Light mainLight = GetMainLight();
                float3 lightColor = mainLight.color * mainLight.distanceAttenuation;
                
                // 漫反射
                float NdotL = saturate(dot(input.normalWS, mainLight.direction));
                float3 diffuse = lightColor * NdotL;
                
                // 环境光
                float3 ambient = SampleSH(input.normalWS);
                
                // 最终颜色
                color.rgb *= (diffuse + ambient);
                
                // 雾效
                color.rgb = MixFog(color.rgb, input.fogCoord);
                
                return color;
            }
            ENDHLSL
        }
        
        // 阴影投射Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            
            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                
                // 获取实例数据
                InstanceData instance = _VisibleInstances[input.instanceID];
                
                // 应用实例变换
                float4 positionWS = mul(instance.Matrix, input.positionOS);
                
                // 变换到裁剪空间（阴影专用）
                output.positionCS = TransformWorldToHClip(positionWS.xyz);
                
                return output;
            }
            
            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }
    }
    
    Fallback "Universal Render Pipeline/Simple Lit"
}
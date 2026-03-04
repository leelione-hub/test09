#ifndef LEAF_SHADOW_CASTER_PASS_INCLUDED
#define LEAF_SHADOW_CASTER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

float3 _LightDirection;
float3 _LightPosition;


// 包含植被系统的实例化数据
#include "../../VgSystem/VgVertexInput.hlsl"
#include "../../VgSystem/VgVertexWind.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 uv           : TEXCOORD0;
    float4 color        : COLOR;
    uint instanceID     : SV_InstanceID;
};

struct Varyings
{
    float2 uv           : TEXCOORD0;
    float4 positionCS   : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


// 获取阴影位置（参考 URP Shadows.hlsl）
float4 GetShadowPositionHClip(Attributes input)
{
    // 应用风动效果
    WindStruct wind_data;
    wind_data.windSpeed = _WindSpeed;
    wind_data.vertexColor = input.color;
    wind_data.leafStrength = _LeafStrength;
    wind_data.normalOS = input.normalOS;
    wind_data.positionOS = input.positionOS.xyz;
    wind_data.bendStrength = _BendStrength;
    wind_data.bendSpeed = _BendSpeed;
    wind_data.bendWait = _BendWait;
    wind_data.windDirection = _WindDirection.xy;
    
    half3 wind = PlantWind(wind_data);
    input.positionOS.xyz += wind;
    
    // 获取世界空间位置
    float3 positionWS = GetInstanceWorldPosition(input.positionOS.xyz, input.instanceID);
    
    // 根据光源类型计算阴影位置
    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        // 点光源/聚光灯
        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
        // 方向光
        float3 lightDirectionWS = _LightDirection;
    #endif
    
    // 应用阴影偏移（Normal Bias）
    #if defined(_SHADOW_BIAS)
        float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
        positionWS += normalWS * _ShadowBias.x;
    #endif
    
    // 转换到裁剪空间
    float4 positionCS = TransformWorldToHClip(positionWS);
    
    // 应用深度偏移（Depth Bias）
    #if defined(_SHADOW_BIAS)
        #if UNITY_REVERSED_Z
            positionCS.z += _ShadowBias.y;
        #else
            positionCS.z -= _ShadowBias.y;
        #endif
    #endif
    
    // 确保在近平面内
    #if UNITY_REVERSED_Z
        positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
        positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif
    
    return positionCS;
}

Varyings ShadowCasterVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
    output.positionCS = GetShadowPositionHClip(input);
    
    return output;
}

half4 ShadowCasterFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
    #if defined(_ALPHATEST_ON)
    half alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).a;
    clip(alpha - _Cutoff);
    #endif
    
    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif
    
    return 0;
}

#endif // LEAF_SHADOW_CASTER_PASS_INCLUDED

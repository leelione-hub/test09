#ifndef LEAF_DEPTH_ONLY_PASS_INCLUDED
#define LEAF_DEPTH_ONLY_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

// 包含植被系统的实例化数据
#include "../../VgSystem/VgVertexInput.hlsl"
#include "../../VgSystem/VgVertexWind.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float2 uv           : TEXCOORD0;
    float3 normalOS     : NORMAL;
    float4 color        : COLOR;
    uint instanceID     : SV_InstanceID;
};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    float2 uv           : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

Varyings DepthOnlyVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
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
    wind_data.instanceID = input.instanceID;

    #if defined(_WIND_ON) || defined(_CIRCE_WIND_ON)
    half3 wind = PlantWind(wind_data);
    input.positionOS.xyz += wind;
    #endif
    
    // 获取实例化的世界位置
    float3 worldPos = GetInstanceWorldPosition(input.positionOS.xyz, input.instanceID);
    
    output.positionCS = TransformWorldToHClip(worldPos);
    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
    
    return output;
}

half DepthOnlyFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
    #if defined(_ALPHATEST_ON)
    half alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).a;
    clip(alpha - _Cutoff);
    #endif
    
    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif
    
    return input.positionCS.z;
}

#endif // LEAF_DEPTH_ONLY_PASS_INCLUDED

#ifndef PLANT_DEPTH_ONLY_PASS_INCLUDED
#define PLANT_DEPTH_ONLY_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

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

inline void ApplyPlantDepthAnimation(inout Attributes input)
{
    #if defined(_WIND_ON)
    WindStruct windData;
    windData.windSpeed = _WindSpeed;
    windData.vertexColor = input.color;
    windData.leafStrength = _LeafStrength;
    windData.normalOS = input.normalOS;
    windData.positionOS = input.positionOS.xyz;
    windData.bendStrength = _BendStrength;
    windData.bendSpeed = _BendSpeed;
    windData.bendWait = _BendWait;
    windData.windDirection = _WindDirection.xy;
    windData.instanceID = input.instanceID;
    input.positionOS.xyz += PlantWind(windData);
    #endif

    #if defined(_CIRCE_WIND_ON)
    NewWindStruct circleWind;
    circleWind.windDirection = _CirceWindDirection.xy;
    circleWind.windSpeed = _CirceWindSpeed;
    circleWind.windJitter = _WindJitter;
    circleWind.windStrength = _WindStrength;
    circleWind.instanceID = input.instanceID;
    input.positionOS.xyz += input.normalOS * GetWindScroll(circleWind, input.positionOS, _WindNoiseSize, _NoisePower);
    #endif

    input.positionOS.xyz += PlantInteractionOffset(input.positionOS.xyz) * input.positionOS.y;
}

Varyings DepthOnlyVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    ApplyPlantDepthAnimation(input);

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

#endif

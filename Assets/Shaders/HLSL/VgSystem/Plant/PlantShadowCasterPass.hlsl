#ifndef PLANT_SHADOW_CASTER_PASS_INCLUDED
#define PLANT_SHADOW_CASTER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

float3 _LightDirection;
float3 _LightPosition;

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

inline void ApplyPlantShadowAnimation(inout Attributes input)
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

float4 GetPlantShadowPositionHClip(Attributes input)
{
    ApplyPlantShadowAnimation(input);

    float3 positionWS = GetInstanceWorldPosition(input.positionOS.xyz, input.instanceID);
    float3 normalWS = GetInstanceWorldNormal(input.normalOS, input.instanceID);

    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
        float3 lightDirectionWS = _LightDirection;
    #endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

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
    output.positionCS = GetPlantShadowPositionHClip(input);
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

#endif

#ifndef LEAFINDIRECT_FORWARD_INCLUDE
#define LEAFINDIRECT_FORWARD_INCLUDE

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float3 positionOS : POSITION;
    float3 normal     : NORMAL;
    float2 uv         : TEXCOORD0;
    float4 color      : COLOR;
    uint instanceID   : SV_InstanceID;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv         : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS   : TEXCOORD2;
};

inline half3 AccumulateVegetationAdditionalLights(float3 positionWS, float3 normalWS, float4 positionCS)
{
    half3 lighting = 0;

    #if defined(_ADDITIONAL_LIGHTS)
    InputData inputData = (InputData)0;
    inputData.positionWS = positionWS;
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(positionCS);

    half4 shadowMask = half4(1, 1, 1, 1);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_FORWARD_PLUS
    UNITY_LOOP for (uint lightIndex = 0u; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, positionWS, shadowMask);
        half atten = light.distanceAttenuation * light.shadowAttenuation;
        half addNdotL = saturate(dot(normalWS, light.direction));

        #ifdef _LIGHT_LAYERS
        if (!IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            continue;
        }
        #endif

        lighting += light.color * (atten * addNdotL);
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, positionWS, shadowMask);
        half atten = light.distanceAttenuation * light.shadowAttenuation;
        half addNdotL = saturate(dot(normalWS, light.direction));

        #ifdef _LIGHT_LAYERS
        if (!IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        {
            continue;
        }
        #endif

        lighting += light.color * (atten * addNdotL);
    LIGHT_LOOP_END
    #endif

    return lighting;
}

Varyings vert(Attributes IN)
{
    WindStruct windData;
    windData.windSpeed = _WindSpeed;
    windData.vertexColor = IN.color;
    windData.leafStrength = _LeafStrength;
    windData.normalOS = IN.normal;
    windData.positionOS = IN.positionOS.xyz;
    windData.bendStrength = _BendStrength;
    windData.bendSpeed = _BendSpeed;
    windData.bendWait = _BendWait;
    windData.windDirection = _WindDirection.xy;

    half3 wind = PlantWind(windData);
    IN.positionOS.xyz += wind;

    float3 worldPos = GetInstanceWorldPosition(IN.positionOS, IN.instanceID);

    Varyings OUT;
    OUT.positionCS = TransformWorldToHClip(worldPos);
    OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
    OUT.positionWS = worldPos;
    OUT.normalWS = GetInstanceWorldNormal(IN.normal, IN.instanceID);
    return OUT;
}

half4 frag(Varyings input) : SV_Target
{
    real4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    #if defined(_ALPHATEST_ON)
    clip(baseColor.a - _Cutoff);
    #endif

    half3 albedo = baseColor.rgb * _Color.rgb;
    half3 normalWS = normalize(input.normalWS);

    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light mainLight = GetMainLight(shadowCoord);
    half NdotL = saturate(dot(normalWS, mainLight.direction));

    half3 lighting = SampleSH(normalWS);
    lighting += mainLight.color * (mainLight.distanceAttenuation * mainLight.shadowAttenuation * NdotL);

    lighting += AccumulateVegetationAdditionalLights(input.positionWS, normalWS, input.positionCS);

    return half4(albedo * lighting, baseColor.a * _Color.a);
}

#endif

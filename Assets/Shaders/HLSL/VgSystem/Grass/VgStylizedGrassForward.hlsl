#ifndef VG_STYLIZED_GRASS_FORWARD_INCLUDED
#define VG_STYLIZED_GRASS_FORWARD_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/Grass/VgStylizedGrassInput.hlsl"

// Shadow caster light parameters (same convention as URP ShadowCasterPass.hlsl)
float3 _LightDirection;
float3 _LightPosition;

Light VgGetMainLightStable(float4 shadowCoord, float3 positionWS)
{
    Light light;
    light.direction = _MainLightPosition.xyz;
    light.color = _MainLightColor.rgb;
    light.distanceAttenuation = 1.0;
    light.shadowAttenuation = 1.0;
    light.layerMask = _MainLightLayerMask;

    #if defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        light.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
    #endif
    
    #if defined(_LIGHT_COOKIES)
        light.color *= SampleMainLightCookie(positionWS);
    #endif

    return light;
}

float VgStylizedGrassComputeDiffuse(float3 normalWS, float3 lightDirWS)
{
    float ndl = dot(normalWS, lightDirWS);
    #if defined(_LAMBERT_HALFLAMBERT)
        return saturate(ndl * 0.5 + 0.5);
    #else
        return saturate(ndl);
    #endif
}

float3 VgStylizedGrassApplyWind(VgStylizedGrassAttributes input)
{
    WindStruct windData;
    windData.windSpeed = _WindSpeed;
    windData.vertexColor = input.color;
    windData.leafStrength = max(_WindForce, 0.001);
    windData.normalOS = input.normalOS;
    windData.positionOS = input.positionOS;
    windData.bendStrength = saturate(_WindForce);
    windData.bendSpeed = max(_WindSpeed, 0.01);
    windData.bendWait = lerp(0.8, 1.8, saturate(_WindWavesScale));
    float2 dir = normalize(_WindDirection.xy + float2(1e-5, 1e-5));
    windData.windDirection = dir;
    windData.instanceID = input.instanceID;

    float3 primary = PlantWind(windData) * _WindForce;
    float phase = _Time.y * (_WindSpeed + 0.25) + dot(input.positionOS.xz, float2(0.11, 0.07));
    float gust = sin(phase) * cos(phase * 0.73) * _WindWavesScale;
    return primary + float3(dir.x, 0, dir.y) * gust * input.color.g * input.positionOS.y;
}

VgStylizedGrassVaryings VgStylizedGrassForwardVert(VgStylizedGrassAttributes input)
{
    VgStylizedGrassVaryings output = (VgStylizedGrassVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);

    float3 deformedOS = input.positionOS + VgStylizedGrassApplyWind(input);
    float3 positionWS = GetInstanceWorldPosition(deformedOS, input.instanceID);
    float3 normalWS = GetInstanceWorldNormal(input.normalOS, input.instanceID);

    output.positionWS = positionWS;
    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.normalWS = normalize(normalWS);
    output.color = input.color;
    output.heightMask = saturate(deformedOS.y + _ColorUpLevel);
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = TransformWorldToShadowCoord(positionWS);
    #endif
    return output;
}

half4 VgStylizedGrassForwardFrag(VgStylizedGrassVaryings input) : SV_Target
{
    half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    clip(tex.a * _Alpha - _Cutoff);

    float gradient = saturate(pow(max(input.heightMask, 0.0), max(_ColorUpFade, 0.01)));
    half3 tint = lerp(_Color1.rgb, _Color2.rgb * _TopIntensity, gradient);
    half3 albedo = tex.rgb * _BaseColor.rgb * tint * _TerrainBrightness;

    float3 normalWS = normalize(input.normalWS);
    float4 shadowCoord;
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    #else
        shadowCoord = float4(0.0, 0.0, 0.0, 0.0);
    #endif
    Light mainLight = VgGetMainLightStable(shadowCoord, input.positionWS);
    float diffuse = VgStylizedGrassComputeDiffuse(normalWS, mainLight.direction);
    float shadowAtten = lerp(1.0, mainLight.shadowAttenuation, _ShadowStrength);

    half3 lighting = SampleSH(normalWS);
    lighting += mainLight.color * diffuse * shadowAtten;

    float3 viewDirWS = normalize(_WorldSpaceCameraPos - input.positionWS);
    float back = pow(saturate(dot(-mainLight.direction, viewDirWS)), _SSSPower);
    lighting += mainLight.color * back * _SSSColorIntensity * input.heightMask;
    lighting += _BackBrightness * 0.15;

    #if defined(_ADDITIONAL_LIGHTS)
        uint count = GetAdditionalLightsCount();
        LIGHT_LOOP_BEGIN(count)
            Light light = GetAdditionalLight(lightIndex, input.positionWS);
            float addDiffuse = VgStylizedGrassComputeDiffuse(normalWS, light.direction);
            lighting += light.color * addDiffuse * light.distanceAttenuation * light.shadowAttenuation * 0.35;
        LIGHT_LOOP_END
    #endif

    half3 finalColor = albedo * lighting;
    return half4(finalColor, tex.a * _BaseColor.a * _Alpha);
}

VgStylizedGrassShadowVaryings VgStylizedGrassShadowVert(VgStylizedGrassAttributes input)
{
    VgStylizedGrassShadowVaryings output;
    UNITY_SETUP_INSTANCE_ID(input);
    float3 deformedOS = input.positionOS + VgStylizedGrassApplyWind(input);
    float3 positionWS = GetInstanceWorldPosition(deformedOS, input.instanceID);
    float3 normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));

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

    output.positionCS = positionCS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    return output;
}

half4 VgStylizedGrassShadowFrag(VgStylizedGrassShadowVaryings input) : SV_Target
{
    half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    clip(tex.a * _Alpha - _Cutoff);
    return 0;
}

VgStylizedGrassDepthVaryings VgStylizedGrassDepthVert(VgStylizedGrassAttributes input)
{
    VgStylizedGrassDepthVaryings output;
    UNITY_SETUP_INSTANCE_ID(input);
    float3 deformedOS = input.positionOS + VgStylizedGrassApplyWind(input);
    float3 positionWS = GetInstanceWorldPosition(deformedOS, input.instanceID);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    return output;
}

half VgStylizedGrassDepthFrag(VgStylizedGrassDepthVaryings input) : SV_Target
{
    half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    clip(tex.a * _Alpha - _Cutoff);
    return input.positionCS.z;
}

#endif

#ifndef PREINTEGRATED_SCREEN_SPACE_SSS_FORWARD_INCLUDED
#define PREINTEGRATED_SCREEN_SPACE_SSS_FORWARD_INCLUDED

#include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"

inline half3 EvaluatePreIntegratedSSS(
    half3 albedo,
    half3 normalWS,
    half3 viewDirWS,
    half3 lightDirWS,
    half3 lightColor,
    half attenuation,
    half thickness)
{
    #if !defined(_PREINTEGRATED_SSS_ON)
    return 0;
    #else
    half wrappedNdotL = saturate(dot(normalWS, lightDirWS) * 0.5h + 0.5h);
    half curvature = saturate((1.0h - saturate(dot(normalWS, viewDirWS))) * _CurvatureScale + thickness);
    half3 lut = SAMPLE_TEXTURE2D(_SSSLUT, sampler_SSSLUT, float2(wrappedNdotL, curvature)).rgb;
    half transmission = pow(saturate(dot(-viewDirWS, lightDirWS)), _TransmissionPower) * thickness * _TransmissionIntensity;
    half3 scatter = lut * _SSSColor.rgb * _PreIntegratedSSSIntensity;
    half3 transmissionColor = transmission * _TransmissionColor.rgb;
    return albedo * lightColor * attenuation * (scatter + transmissionColor);
    #endif
}

inline half3 EvaluateWrapThicknessSSS(
    half3 albedo,
    half3 normalWS,
    half3 viewDirWS,
    half3 lightDirWS,
    half3 lightColor,
    half attenuation,
    half thickness)
{
    #if !defined(_WRAP_SSS_ON)
    return 0;
    #else
    half wrapped = saturate((dot(normalWS, lightDirWS) + _WrapLighting) / (1.0h + _WrapLighting));
    half forwardScatter = wrapped * thickness * _WrapSSSIntensity;
    half backScatter = pow(saturate(dot(-viewDirWS, lightDirWS)), _WrapThicknessPower) * thickness * _WrapThicknessTransmission;
    half scatterTerm = forwardScatter + backScatter;
    return albedo * _WrapSSSColor.rgb * lightColor * attenuation * scatterTerm;
    #endif
}

inline half3 EvaluateDirectDiffuse(half3 albedo, half3 normalWS, half3 lightDirWS, half3 lightColor, half attenuation)
{
    return albedo * lightColor * attenuation * saturate(dot(normalWS, lightDirWS));
}

inline half3 EvaluateSpecular(half3 normalWS, half3 viewDirWS, half3 lightDirWS, half3 lightColor, half attenuation)
{
    #if defined(_SPECULAR_ON)
    half3 halfDir = SafeNormalize(viewDirWS + lightDirWS);
    half exponent = lerp(8.0h, 96.0h, saturate(_Smoothness));
    half spec = pow(saturate(dot(normalWS, halfDir)), exponent) * _SpecularStrength;
    return lightColor * attenuation * spec;
    #else
    return 0;
    #endif
}

inline half3 EvaluateOneLight(
    half3 albedo,
    half3 normalWS,
    half3 viewDirWS,
    half thickness,
    Light light,
    bool enableSSS)
{
    half attenuation = light.distanceAttenuation * light.shadowAttenuation;
    half3 result = EvaluateDirectDiffuse(albedo, normalWS, light.direction, light.color, attenuation);
    result += EvaluateSpecular(normalWS, viewDirWS, light.direction, light.color, attenuation);
    if (enableSSS)
    {
        result += EvaluatePreIntegratedSSS(albedo, normalWS, viewDirWS, light.direction, light.color, attenuation, thickness);
        result += EvaluateWrapThicknessSSS(albedo, normalWS, viewDirWS, light.direction, light.color, attenuation, thickness);
    }

    return result;
}

SSSVaryings LitPassVertex(SSSAttributes input)
{
    return BuildSSSVaryings(input);
}

half4 LitPassFragment(SSSVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    SSSSurfaceData surfaceData;
    InitializeSSSSurfaceData(input.uv, surfaceData);

    #if defined(_ALPHATEST_ON)
    clip(surfaceData.alpha - _Cutoff);
    #endif

    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif

    half3 normalWS = SSSGetNormalWS(input, surfaceData.normalTS);
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 color = SampleSH(normalWS) * surfaceData.albedo * _AmbientIntensity;

    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light mainLight = GetMainLight(shadowCoord, input.positionWS, half4(1, 1, 1, 1));
    color += EvaluateOneLight(surfaceData.albedo, normalWS, viewDirWS, surfaceData.thickness, mainLight, true);

    #if defined(_ADDITIONAL_LIGHTS)
    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = viewDirWS;
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    half4 shadowMask = half4(1, 1, 1, 1);
    uint lightCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(lightCount)
        Light additionalLight = GetAdditionalLight(lightIndex, input.positionWS, shadowMask);
        color += EvaluateOneLight(surfaceData.albedo, normalWS, viewDirWS, surfaceData.thickness, additionalLight,
            #if defined(_SSS_ADDITIONAL_LIGHTS_ON)
            true
            #else
            false
            #endif
        );
    LIGHT_LOOP_END
    #endif

    color += _EmissionColor.rgb * _EmissionIntensity;
    color = MixFog(color, ComputeFogFactor(input.positionCS.z));
    return half4(color, surfaceData.alpha);
}

#endif

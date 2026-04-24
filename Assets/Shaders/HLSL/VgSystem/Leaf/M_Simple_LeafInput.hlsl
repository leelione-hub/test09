#ifndef VG_M_SIMPLE_LEAF_INPUT_INCLUDED
#define VG_M_SIMPLE_LEAF_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/VgVertexWind.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/SurfaceInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Custom/CommonFunc.hlsl"

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_LeavesRampMap); SAMPLER(sampler_LeavesRampMap);

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half4 _AOColor;
half4 _UpColor;
half4 _DarkColor;
half4 _SSSColor;
half3 _UpDirection;
half _AOScale;
half _Cutoff;
half _Roughness;
half _Alpha;
half _RampCount;
half _UpScale;
half _UpOffset;
half _Brightness;
half _BackScale;
half _BackOffset;
half _SSSDistortion;
half _SSSPower;
half _SSSScale;
half _HideCross;
half _BackBrightness;
half _ShadowStrength;
half _AOStrength;
half _WindSpeed;
half _LeafStrength;
half _BendStrength;
half _BendSpeed;
half _BendWait;
half4 _WindDirection;
CBUFFER_END

struct Attributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
    uint instanceID : SV_InstanceID;
};

struct Varyings
{
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float4 tangentWS : TEXCOORD3;
    half fogFactor : TEXCOORD4;
    float4 shadowCoord : TEXCOORD5;
    half3 vertexSH : TEXCOORD6;
    float2 staticLightmapUV : TEXCOORD7;
    float4 positionCS : SV_POSITION;
    float4 color : COLOR;
};

inline void ApplyMSimpleLeafWind(inout Attributes input)
{
    #if defined(_WIND_ON)
    WindStruct windData;
    windData.windSpeed = _WindSpeed;
    windData.vertexColor = input.color;
    windData.leafStrength = _LeafStrength;
    windData.normalOS = input.normalOS;
    windData.positionOS = input.positionOS;
    windData.bendStrength = _BendStrength;
    windData.bendSpeed = _BendSpeed;
    windData.bendWait = _BendWait;
    windData.windDirection = _WindDirection.xy;
    windData.instanceID = input.instanceID;
    input.positionOS += PlantWind(windData);
    #endif
}

inline half MSimpleLeafCrossMask(float3 positionWS, float3 normalWS, half vertexMask)
{
    if (_HideCross <= 0.5h || vertexMask >= 0.5h)
        return 1.0h;

    float3 viewDir = normalize(_WorldSpaceCameraPos - positionWS);
    float facing = 1.1h - abs(dot(viewDir, normalize(normalWS)));
    return saturate(1.0h - facing * facing);
}

inline void M_InitializeSimpleLeafSurfaceData(float2 uv, float3 positionWS, float3 normalWS, half4 vertexColor, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = VgSampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    half2 rampUV = half2(albedoAlpha.r, _RampCount);
    half4 rampColor = VgSampleAlbedoAlpha(rampUV, TEXTURE2D_ARGS(_LeavesRampMap, sampler_LeavesRampMap));

    half upMask = saturate((dot(normalize(_UpDirection), normalize(normalWS)) * _UpScale + _UpOffset) * albedoAlpha.g);
    rampColor.rgb = lerp(rampColor.rgb, _UpColor.rgb * _Brightness, upMask);

    half aoMask = lerp(1.0h, vertexColor.a, _AOScale);
    rampColor.rgb = lerp(_AOColor.rgb, rampColor.rgb, aoMask);

    half backMask = saturate(dot(_MainLightPosition.xyz, normalize(normalWS)) * -_BackScale + _BackOffset);
    rampColor.rgb = lerp(rampColor.rgb, _DarkColor.rgb, backMask);

    half3 finalAlbedo = lerp(albedoAlpha.rgb, rampColor.rgb, 1.0h - vertexColor.b) * _BaseColor.rgb;

    #if defined(_SSS_ON)
    finalAlbedo = FakeSSS(positionWS, normalWS, half4(finalAlbedo, 1.0h), 1.0h, _SSSDistortion, _SSSPower, _SSSScale, _SSSColor).rgb;
    #endif

    outSurfaceData.alpha = albedoAlpha.a * _BaseColor.a * _Alpha * MSimpleLeafCrossMask(positionWS, normalWS, vertexColor.b);
    outSurfaceData.albedo = saturate(finalAlbedo);
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = 0;
    outSurfaceData.smoothness = saturate(1.0h - _Roughness);
    outSurfaceData.normalTS = half3(0, 0, 1);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#endif

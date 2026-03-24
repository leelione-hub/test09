#ifndef PLANTINDIRECT_INPUT_INCLUDE
#define PLANTINDIRECT_INPUT_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/VgVertexWind.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/SurfaceInput.hlsl"

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
TEXTURE2D(_NRMTex); SAMPLER(sampler_NRMTex);
TEXTURE2D(_MossBase); SAMPLER(sampler_MossBase);
sampler2D _WindLineTex;

float4 _MainTex_TexelSize;
float4 _MainTex_MipInfo;

half3 _GrassInteractivePos;

CBUFFER_START(UnityPerMaterial)
    float4 _Color;
    float4 _MainTex_ST;
    float4 _MossUV;
    float4 _EmissionColor;
    float4 _SSSColor;
    float4 _EdgeBrightColor;
    float4 _WindDirection;
    float4 _CirceWindDirection;
    float _Cutoff;
    float _Metallic;
    float _Roughness;
    float _Alpha;
    float _BumpScale;
    float _NormalBack;
    float _RoughnessMin;

    float _BackFaceShadowInt;
    float _GIInt;
    float _MainLightInt;
    float _BackBrightness;
    float _ShadowStrength;
    float _AOStrength;

    float _WindSpeed;
    float _LeafStrength;
    float _BendStrength;
    float _BendSpeed;
    float _BendWait;

    float _CirceWindSpeed;
    float _WindStrength;
    float _WindJitter;
    float _WindNoiseSize;
    float _NoisePower;

    half _WindLineDirection;
    half _WindLineScale;
    half _WindLineStrength;
    half _WindLindSpeed;

    float _InteractiveStrength;
    float _InteractiveRange;

    float _EmissiveIntensity;
    float _SSSDistortion;
    float _SSSPower;
    float _SSSScale;
    float _Surface;
CBUFFER_END

inline half3 PlantInteractionOffset(half3 positionOS)
{
    half3 interactivePosOS = TransformWorldToObject(_GrassInteractivePos);
    half3 direction = normalize(positionOS - interactivePosOS);
    direction = half3(direction.x, direction.y - 0.5h, direction.z);
    half distanceOut = 1.0h - distance(interactivePosOS, positionOS);
    return saturate(distanceOut + _InteractiveRange) * _InteractiveStrength * direction;
}

inline void M_InitializePlantSurfaceData(float2 uv, out SurfaceData outSurfaceData, half3 viewDirWS)
{
    half4 albedoAlpha = VgSampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
    half4 nrm = SAMPLE_TEXTURE2D(_NRMTex, sampler_NRMTex, uv);

    outSurfaceData.alpha = albedoAlpha.a * _Color.a * _Alpha;
    outSurfaceData.albedo = albedoAlpha.rgb * _Color.rgb;
    outSurfaceData.metallic = GetNRM_Metallic(nrm, _Metallic);
    outSurfaceData.specular = half3(0, 0, 0);
    outSurfaceData.smoothness = 1.0h - GetNRM_Roughness(nrm, _Roughness, _RoughnessMin);
    outSurfaceData.normalTS = GetNRM_Normal_Plant(nrm, _BumpScale, _NormalBack, viewDirWS);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, _EmissiveIntensity, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#endif

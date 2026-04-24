#ifndef VG_M_SIMPLE_PLANT_INPUT_INCLUDED
#define VG_M_SIMPLE_PLANT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/VgVertexWind.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/SurfaceInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Custom/CommonFunc.hlsl"

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_NRMTex); SAMPLER(sampler_NRMTex);
TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _BaseColor;
float4 _EmissionColor;
float4 _SSSColor;
float4 _EdgeBrightColor;
float4 _WindDirection;
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
float _EdgeBrightIntensity;
float _EdgeBrightScale;
float _BackBrightness;
float _ShadowStrength;
float _AOStrength;
float _WindSpeed;
float _LeafStrength;
float _BendStrength;
float _BendSpeed;
float _BendWait;
float _EmissiveIntensity;
float _SSSDistortion;
float _SSSPower;
float _SSSScale;
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
};

inline void ApplyMSimplePlantWind(inout Attributes input)
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

inline void M_InitializeSimplePlantSurfaceData(float2 uv, half3 viewDirWS, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = VgSampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    half4 nrm = SAMPLE_TEXTURE2D(_NRMTex, sampler_NRMTex, uv);
    outSurfaceData.alpha = albedoAlpha.a * _BaseColor.a * _Alpha;
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = GetNRM_Metallic(nrm, _Metallic);
    outSurfaceData.specular = 0;
    outSurfaceData.smoothness = 1.0h - GetNRM_Roughness(nrm, _Roughness, _RoughnessMin);
    outSurfaceData.normalTS = GetNRM_Normal_Plant(nrm, _BumpScale, _NormalBack, viewDirWS);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, _EmissiveIntensity, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#endif

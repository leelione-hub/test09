#ifndef CUSTOM_NPR_INPUT_INCLUDED
#define CUSTOM_NPR_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    half4 _BaseColor;
    half4 _ShadowColor;
    half4 _FaceShadowColor;
    half3 _EdgeColor;
    float _ShadowThreshold;
    float _ShadowSmoothness;
    real4 _SpecularColor;
    float _FaceShaowOffset;
    float _FaceShadowMapPow;
    float _Glossiness;
    float _SpecularThreshold;
    float _MetalInternsity;
    real4 _RimColor;
    float _RimPower;
    float _RimThreshold;
    float _CurvatureScale;
    float _HairDarkShadowSmooth;
    float _HairDarkShadowArea;
    float _HairSmoothShadowIntensity;
    float _HairRange;
    float _StrokeRange;
    float _PatternRange;
    float _HairViewSpecularThreshold;
    float _HairSpecAreaBaseline;
    float _HairAccGroveBaseline;
    half _EmissionIntensity;
    half _InNight;
    half _EdgeWidth;
    half _EdgeIntensity;
    float4 _OutlineColor;
    float _OutlineWidth;
CBUFFER_END

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);
TEXTURE2D(_LightMap);
SAMPLER(sampler_LightMap);
TEXTURE2D(_MetalMap);
SAMPLER(sampler_MetalMap);
TEXTURE2D(_FaceShadowMap);
SAMPLER(sampler_FaceShadowMap);
TEXTURE2D(_ShadowRampMap);
SAMPLER(sampler_ShadowRampMap);

struct CustomNPRForwardAttributes
{
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float3 normalOS : NORMAL;
    float4 color : COLOR;
};

struct CustomNPRForwardVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float3 positionWS : TEXCOORD2;
    float4 vertexColor : TEXCOORD3;
    float4 screenPosition : TEXCOORD4;
};

struct CustomNPROutlineAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 color : COLOR;
};

struct CustomNPROutlineVaryings
{
    float4 positionCS : SV_POSITION;
    float3 vertexColor : TEXCOORD0;
};

#endif

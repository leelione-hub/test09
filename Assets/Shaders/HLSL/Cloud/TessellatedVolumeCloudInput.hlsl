#ifndef TESSELLATED_VOLUME_CLOUD_INPUT_INCLUDED
#define TESSELLATED_VOLUME_CLOUD_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

TEXTURE3D(_NoiseTex);
SAMPLER(sampler_NoiseTex);

CBUFFER_START(UnityPerMaterial)
float _NoiseScale;
float4 _NoiseSpeed;
float _Displacement;
float _DensityThreshold;
float _DensitySoftness;
float _Alpha;
float _TessellationFactor;
float _TessellationMinFactor;
float _TessellationStartDistance;
float _TessellationEndDistance;
float4 _BrightColor;
float4 _ShadowColor;
float _AmbientStrength;
float _BackscatterStrength;
float _BackscatterPower;
float _RimStrength;
float _RimPower;
float _NormalSampleOffset;
float _NormalStrength;
float _DistanceFadeStart;
float _DistanceFadeRange;
float _EdgeFadePower;
CBUFFER_END

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
};

struct TessellationControlPoint
{
    float4 positionOS : INTERNALTESSPOS;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
};

struct TessellationFactors
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv : TEXCOORD2;
    float fogFactor : TEXCOORD3;
};

#endif

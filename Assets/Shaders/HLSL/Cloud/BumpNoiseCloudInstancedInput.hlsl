#ifndef BUMP_NOISE_CLOUD_INSTANCED_INPUT_INCLUDED
#define BUMP_NOISE_CLOUD_INSTANCED_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE3D(_NoiseTex);
SAMPLER(sampler_NoiseTex);

CBUFFER_START(UnityPerMaterial)
float _NoiseScale;
float4 _NoiseSpeed;
float _FarNoiseScaleMul;
float _DetailNoiseScaleMul;
float _DetailNoiseWeight;
float _LayerThicknessRatio;
float _FarOffsetMul;
float _DistanceFadeStart;
float _DistanceFadeRange;
float _BaseClip;
float _ClipLayerStrength;
float _ClipCurvePower;
float _DensitySoftness;
float _DitherStrength;
float _OuterAlphaScale;
float _InnerAlphaScale;
float4 _BrightColor;
float4 _ShadowColor;
float _BackSssStrength;
float _BackSssPower;
float _BackSssBoost;
float _NdotLPower;
float _NdotVPower;
float _ViewLightingWeight;
float _ViewShadowSuppress;
float _ShadowFadeStart;
float _ShadowFadeRange;
float _HighlightCompression;
float _LitDetailStrength;
float _CoreShadowStrength;
float _FinalAlpha;
float _DepthFadeDistance;
float _PrepassThreshold;
float4 _CloudBoundsCenterOS;
float4 _CloudBoundsExtentOS;
CBUFFER_END

UNITY_INSTANCING_BUFFER_START(CloudLayerProps)
    UNITY_DEFINE_INSTANCED_PROP(float, _LayerOffset)
    UNITY_DEFINE_INSTANCED_PROP(float, _LayerClip)
UNITY_INSTANCING_BUFFER_END(CloudLayerProps)

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float4 shadowCoord : TEXCOORD2;
    float layerClip : TEXCOORD3;
    float viewDepth : TEXCOORD4;
    float fogFactor : TEXCOORD5;
    float3 normalizedPositionOS : TEXCOORD6;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct CloudShellData
{
    float3 positionWS;
    float3 normalWS;
    float layerClip;
    float distanceFade;
    float3 normalizedPositionOS;
};

float Hash21(float2 p)
{
    float h = dot(p, float2(127.1, 311.7));
    return frac(sin(h) * 43758.5453123);
}

float ComputeDistanceFade(float3 positionWS)
{
    float cameraDistance = distance(positionWS, _WorldSpaceCameraPos.xyz);
    return saturate((cameraDistance - _DistanceFadeStart) / max(_DistanceFadeRange, 0.001));
}

float3 GetCloudNoiseUV(float3 normalizedPositionOS, float distanceFade, float scaleMul, float3 scrollMul)
{
    float noiseScale = _NoiseScale * lerp(1.0, _FarNoiseScaleMul, distanceFade);
    return normalizedPositionOS / max(noiseScale / max(scaleMul, 0.001), 0.001) + _Time.y * (_NoiseSpeed.xyz * scrollMul);
}

float SampleCloudNoise(float3 normalizedPositionOS, float distanceFade, float scaleMul, float3 scrollMul)
{
    return SAMPLE_TEXTURE3D(_NoiseTex, sampler_NoiseTex, GetCloudNoiseUV(normalizedPositionOS, distanceFade, scaleMul, scrollMul)).r;
}

CloudShellData BuildCloudShellData(Attributes input)
{
    CloudShellData shellData;
    float3 positionOS = input.positionOS.xyz;
    float3 normalOS = normalize(input.normalOS);
    float3 boundsExtent = max(_CloudBoundsExtentOS.xyz, 0.001);
    float boundsRadius = max(boundsExtent.x, max(boundsExtent.y, boundsExtent.z));

    shellData.layerClip = UNITY_ACCESS_INSTANCED_PROP(CloudLayerProps, _LayerClip);
    float layerOffset = UNITY_ACCESS_INSTANCED_PROP(CloudLayerProps, _LayerOffset);
    float3 basePositionWS = TransformObjectToWorld(positionOS);
    shellData.distanceFade = ComputeDistanceFade(basePositionWS);
    float offsetScale = lerp(1.0, _FarOffsetMul, shellData.distanceFade);
    float shellThickness = layerOffset * _LayerThicknessRatio * boundsRadius * offsetScale;
    positionOS += normalOS * shellThickness;

    shellData.normalWS = normalize(TransformObjectToWorldNormal(normalOS));
    shellData.positionWS = TransformObjectToWorld(positionOS);
    shellData.normalizedPositionOS = (positionOS - _CloudBoundsCenterOS.xyz) / boundsExtent;
    return shellData;
}

float ComputeCloudDensity(float3 normalizedPositionOS, float layerClip, float distanceFade,out float noise)
{
    float baseNoise = SampleCloudNoise(normalizedPositionOS, distanceFade, 1.0, float3(1.0, 1.0, 1.0));
    float detailNoise = SampleCloudNoise(normalizedPositionOS, distanceFade, _DetailNoiseScaleMul, float3(1.37, 1.11, 1.23));
    noise = lerp(baseNoise, baseNoise * detailNoise, _DetailNoiseWeight);
    float threshold = _BaseClip + pow(saturate(layerClip), _ClipCurvePower) * _ClipLayerStrength;
    return noise - threshold;
}

void ClipCloudShell(float density, float4 positionCS)
{
    clip(density);

    float dither = Hash21(positionCS.xy);
    clip(density + (dither - 0.5) * _DitherStrength);
}

float ComputeCloudShellAlpha(float density, float layerClip)
{
    float shellInner = 1.0 - saturate(layerClip);
    float shellAlpha = lerp(_OuterAlphaScale, _InnerAlphaScale, shellInner);
    return saturate(density * _DensitySoftness) * shellAlpha * _FinalAlpha;
}

#endif

#ifndef M_RIVER_LWGUI_INPUT_INCLUDED
#define M_RIVER_LWGUI_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

#if defined(_DETAIL_MULX2) || defined(_DETAIL_SCALED)
#define _DETAIL
#endif

samplerCUBE _Cubemap;
sampler2D _WavesNormal;
sampler2D _FoamTex;
sampler2D _DistanceMap;
TEXTURE2D(_RiverSSRTexture); SAMPLER(sampler_RiverSSRTexture);

CBUFFER_START(UnityPerMaterial)
half4 _SurfaceColor;
half4 _DepthColor;
half4 _FresnelColor;
half4 _HighLightColor;
half4 _FoamColor;
half4 _FoamTexColor;
half4 _TilingOffset;
half4 _LightColor;
half4 _CausticColor1;
half4 _CausticColor2;
half4 _WaveTexTilingOffset;

half2 _CoastSpeed;
half2 _FoamSpeed;
half2 _CausticThreshold1;

float _HighLightSize;
float _HighLightScale;
float _NoiseScale;
float _NoiseSpeed;
float _LightPower;

half _Roughness;
half _Strength;
half _DepthDistance;
half _Refraction;
half _FresnelAmount;
half _FresnelPower;
half _FresnelScale;
half _CubemapRotation;
half _SSRIntensity;
half _SSRBlend;
half _SSRDistortion;
half _SSRMaskByFresnel;
half _SSRMaskByDepth;
half _SSRValidThreshold;
half _SSRStepSize;
half _SSRMaxDistance;
half _SSRThickness;
half _SSREdgeFade;
half _SSRRayStartBias;
half _SSRMaxSteps;
half _WavesNormalIntensity;
half _WaveSpeed;
half _WaveNormalScale;
half _DepthCutOff;
half _CoastScale;
half _CoastAlpha;
half _EdgeWidth;
half _FoamScale;
half _FoamDepth;
half _FoamDepthFallOff;
half _FoamTiling;
half _FoamWidth;
half _FoamCut;
half _FoamTexAlpha;
half _CausticSize1;
half _CausticAngle1;
half _CausticSpeed1;
half _CausticBrightness1;
half _CausticEndDepth1;
half _CausticFarDistance1;
half _CausticColorSplit1;
half _BackBrightness;
half _ShadowStrength;
half _AOStrength;
half _ClearCoatMask;
half _ClearCoatSmoothness;
half _Surface;
CBUFFER_END

#ifdef UNITY_DOTS_INSTANCING_ENABLED
UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
    UNITY_DOTS_INSTANCED_PROP(float4, _SurfaceColor)
    UNITY_DOTS_INSTANCED_PROP(float4, _DepthColor)
    UNITY_DOTS_INSTANCED_PROP(float4, _FresnelColor)
    UNITY_DOTS_INSTANCED_PROP(float4, _HighLightColor)
    UNITY_DOTS_INSTANCED_PROP(float4, _FoamColor)
    UNITY_DOTS_INSTANCED_PROP(float4, _FoamTexColor)
    UNITY_DOTS_INSTANCED_PROP(float4, _TilingOffset)
    UNITY_DOTS_INSTANCED_PROP(float4, _LightColor)
    UNITY_DOTS_INSTANCED_PROP(float4, _CausticColor1)
    UNITY_DOTS_INSTANCED_PROP(float4, _CausticColor2)
    UNITY_DOTS_INSTANCED_PROP(float4, _WaveTexTilingOffset)
    UNITY_DOTS_INSTANCED_PROP(float2, _CoastSpeed)
    UNITY_DOTS_INSTANCED_PROP(float2, _FoamSpeed)
    UNITY_DOTS_INSTANCED_PROP(float2, _CausticThreshold1)
    UNITY_DOTS_INSTANCED_PROP(float, _Roughness)
    UNITY_DOTS_INSTANCED_PROP(float, _Strength)
    UNITY_DOTS_INSTANCED_PROP(float, _DepthDistance)
    UNITY_DOTS_INSTANCED_PROP(float, _Refraction)
    UNITY_DOTS_INSTANCED_PROP(float, _FresnelAmount)
    UNITY_DOTS_INSTANCED_PROP(float, _FresnelPower)
    UNITY_DOTS_INSTANCED_PROP(float, _FresnelScale)
    UNITY_DOTS_INSTANCED_PROP(float, _HighLightSize)
    UNITY_DOTS_INSTANCED_PROP(float, _HighLightScale)
    UNITY_DOTS_INSTANCED_PROP(float, _CubemapRotation)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRIntensity)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRBlend)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRDistortion)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRMaskByFresnel)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRMaskByDepth)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRValidThreshold)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRStepSize)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRMaxDistance)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRThickness)
    UNITY_DOTS_INSTANCED_PROP(float, _SSREdgeFade)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRRayStartBias)
    UNITY_DOTS_INSTANCED_PROP(float, _SSRMaxSteps)
    UNITY_DOTS_INSTANCED_PROP(float, _WavesNormalIntensity)
    UNITY_DOTS_INSTANCED_PROP(float, _WaveSpeed)
    UNITY_DOTS_INSTANCED_PROP(float, _WaveNormalScale)
    UNITY_DOTS_INSTANCED_PROP(float, _DepthCutOff)
    UNITY_DOTS_INSTANCED_PROP(float, _CoastScale)
    UNITY_DOTS_INSTANCED_PROP(float, _CoastAlpha)
    UNITY_DOTS_INSTANCED_PROP(float, _EdgeWidth)
    UNITY_DOTS_INSTANCED_PROP(float, _FoamScale)
    UNITY_DOTS_INSTANCED_PROP(float, _FoamDepth)
    UNITY_DOTS_INSTANCED_PROP(float, _FoamDepthFallOff)
    UNITY_DOTS_INSTANCED_PROP(float, _FoamTiling)
    UNITY_DOTS_INSTANCED_PROP(float, _FoamWidth)
    UNITY_DOTS_INSTANCED_PROP(float, _FoamCut)
    UNITY_DOTS_INSTANCED_PROP(float, _FoamTexAlpha)
    UNITY_DOTS_INSTANCED_PROP(float, _NoiseScale)
    UNITY_DOTS_INSTANCED_PROP(float, _NoiseSpeed)
    UNITY_DOTS_INSTANCED_PROP(float, _LightPower)
    UNITY_DOTS_INSTANCED_PROP(float, _CausticSize1)
    UNITY_DOTS_INSTANCED_PROP(float, _CausticAngle1)
    UNITY_DOTS_INSTANCED_PROP(float, _CausticSpeed1)
    UNITY_DOTS_INSTANCED_PROP(float, _CausticBrightness1)
    UNITY_DOTS_INSTANCED_PROP(float, _CausticEndDepth1)
    UNITY_DOTS_INSTANCED_PROP(float, _CausticFarDistance1)
    UNITY_DOTS_INSTANCED_PROP(float, _CausticColorSplit1)
    UNITY_DOTS_INSTANCED_PROP(float, _BackBrightness)
    UNITY_DOTS_INSTANCED_PROP(float, _ShadowStrength)
    UNITY_DOTS_INSTANCED_PROP(float, _AOStrength)
    UNITY_DOTS_INSTANCED_PROP(float, _ClearCoatMask)
    UNITY_DOTS_INSTANCED_PROP(float, _ClearCoatSmoothness)
    UNITY_DOTS_INSTANCED_PROP(float, _Surface)
UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

#define _SurfaceColor           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _SurfaceColor)
#define _DepthColor             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _DepthColor)
#define _FresnelColor           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _FresnelColor)
#define _HighLightColor         UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _HighLightColor)
#define _FoamColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _FoamColor)
#define _FoamTexColor           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _FoamTexColor)
#define _TilingOffset           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _TilingOffset)
#define _LightColor             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _LightColor)
#define _CausticColor1          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _CausticColor1)
#define _CausticColor2          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _CausticColor2)
#define _WaveTexTilingOffset    UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _WaveTexTilingOffset)
#define _CoastSpeed             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float2, _CoastSpeed)
#define _FoamSpeed              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float2, _FoamSpeed)
#define _CausticThreshold1      UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float2, _CausticThreshold1)
#define _Roughness              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _Roughness)
#define _Strength               UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _Strength)
#define _DepthDistance          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _DepthDistance)
#define _Refraction             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _Refraction)
#define _FresnelAmount          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FresnelAmount)
#define _FresnelPower           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FresnelPower)
#define _FresnelScale           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FresnelScale)
#define _HighLightSize          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _HighLightSize)
#define _HighLightScale         UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _HighLightScale)
#define _CubemapRotation        UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CubemapRotation)
#define _SSRIntensity           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRIntensity)
#define _SSRBlend               UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRBlend)
#define _SSRDistortion          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRDistortion)
#define _SSRMaskByFresnel       UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRMaskByFresnel)
#define _SSRMaskByDepth         UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRMaskByDepth)
#define _SSRValidThreshold      UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRValidThreshold)
#define _SSRStepSize            UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRStepSize)
#define _SSRMaxDistance         UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRMaxDistance)
#define _SSRThickness           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRThickness)
#define _SSREdgeFade            UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSREdgeFade)
#define _SSRRayStartBias        UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRRayStartBias)
#define _SSRMaxSteps            UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _SSRMaxSteps)
#define _WavesNormalIntensity   UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _WavesNormalIntensity)
#define _WaveSpeed              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _WaveSpeed)
#define _WaveNormalScale        UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _WaveNormalScale)
#define _DepthCutOff            UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _DepthCutOff)
#define _CoastScale             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CoastScale)
#define _CoastAlpha             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CoastAlpha)
#define _EdgeWidth              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _EdgeWidth)
#define _FoamScale              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FoamScale)
#define _FoamDepth              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FoamDepth)
#define _FoamDepthFallOff       UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FoamDepthFallOff)
#define _FoamTiling             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FoamTiling)
#define _FoamWidth              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FoamWidth)
#define _FoamCut                UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FoamCut)
#define _FoamTexAlpha           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _FoamTexAlpha)
#define _NoiseScale             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _NoiseScale)
#define _NoiseSpeed             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _NoiseSpeed)
#define _LightPower             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _LightPower)
#define _CausticSize1           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CausticSize1)
#define _CausticAngle1          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CausticAngle1)
#define _CausticSpeed1          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CausticSpeed1)
#define _CausticBrightness1     UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CausticBrightness1)
#define _CausticEndDepth1       UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CausticEndDepth1)
#define _CausticFarDistance1    UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CausticFarDistance1)
#define _CausticColorSplit1     UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _CausticColorSplit1)
#define _BackBrightness         UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _BackBrightness)
#define _ShadowStrength         UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _ShadowStrength)
#define _AOStrength             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _AOStrength)
#define _ClearCoatMask          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _ClearCoatMask)
#define _ClearCoatSmoothness    UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _ClearCoatSmoothness)
#define _Surface                UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float, _Surface)
#endif

TEXTURE2D(_ParallaxMap);      SAMPLER(sampler_ParallaxMap);
TEXTURE2D(_OcclusionMap);     SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_DetailMask);       SAMPLER(sampler_DetailMask);
TEXTURE2D(_DetailAlbedoMap);  SAMPLER(sampler_DetailAlbedoMap);
TEXTURE2D(_DetailNormalMap);  SAMPLER(sampler_DetailNormalMap);
TEXTURE2D(_MetallicGlossMap); SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);     SAMPLER(sampler_SpecGlossMap);
TEXTURE2D(_ClearCoatMap);     SAMPLER(sampler_ClearCoatMap);

inline half3 unpackNormal(half r, half g, float scale)
{
    half2 xy = (half2(r, g) * 2.0h - 1.0h) * scale;
    return half3(xy, sqrt(saturate(1.0h - dot(xy, xy))));
}

float2 PolarCoordinates(float2 uv, float2 center = float2(0.5, 0.5), float radialScale = 1, float lengthScale = 1)
{
    float2 centeredUV = uv - center;
    float x = length(centeredUV) * radialScale * 2;
    float y = atan2(centeredUV.x, centeredUV.y) * (1 / TWO_PI) * lengthScale;
    return float2(x, y);
}

float2 mod2D289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float3 mod2D289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float3 permute(float3 x) { return mod2D289(((x * 34.0) + 1.0) * x); }
float snoise(float2 v)
{
    const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
    float2 i = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod2D289(i);
    float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m *= m;
    m *= m;
    float3 x = 2.0 * frac(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

void ApplyPerPixelDisplacement(half3 viewDirTS, inout float2 uv)
{
#if defined(_PARALLAXMAP)
    uv += ParallaxMapping(TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap), viewDirTS, 1, uv);
#endif
}

float3 RotateAroundAxis(float3 center, float3 original, float3 u, float angle)
{
    original -= center;
    float C = cos(angle);
    float S = sin(angle);
    float t = 1 - C;
    float3x3 finalMatrix = float3x3(
        t * u.x * u.x + C,         t * u.x * u.y - S * u.z, t * u.x * u.z + S * u.y,
        t * u.x * u.y + S * u.z,   t * u.y * u.y + C,       t * u.y * u.z - S * u.x,
        t * u.x * u.z - S * u.y,   t * u.y * u.z + S * u.x, t * u.z * u.z + C
    );
    return mul(finalMatrix, original) + center;
}

inline float4 ASE_ComputeGrabScreenPos(float4 pos)
{
#if UNITY_UV_STARTS_AT_TOP
    float scale = -1.0;
#else
    float scale = 1.0;
#endif
    float4 o = pos;
    o.y = pos.w * 0.5f;
    o.y = (pos.y - o.y) * _ProjectionParams.x * scale + o.y;
    return o;
}

float CommonSampleDepth(float2 uv)
{
    return SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, uv, 0);
}

half MyCustomExpression_Water(half2 uv, float4 screenPos)
{
    float4 screenPosNorm = screenPos / screenPos.w;
    screenPosNorm.z = (UNITY_NEAR_CLIP_VALUE >= 0) ? screenPosNorm.z : screenPosNorm.z * 0.5 + 0.5;
    float surfaceDepth = LinearEyeDepth(screenPosNorm.z, _ZBufferParams);
    float sceneDepth = LinearEyeDepth(CommonSampleDepth(uv), _ZBufferParams);
    return sceneDepth - surfaceDepth;
}

#endif

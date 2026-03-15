#ifndef VG_GRASS_INPUT_INCLUDED
#define VG_GRASS_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/SurfaceInput.hlsl"

#if defined(_DETAIL_MULX2) || defined(_DETAIL_SCALED)
#define _DETAIL
#endif

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_MossBase);
SAMPLER(sampler_MossBase);

float4 _BaseMap_TexelSize;
float4 _BaseMap_MipInfo;

sampler2D _WindLineTex;

half _TerrainRoughness;
half4 _TerrainTransformData = half4(0, 0, 1, 1);
sampler2D _TerrainColor;

half3 _GrassInteractivePos;
half _Cyclone;

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half4 _MossUV;
half4 _Color1;
half4 _Color2;
half2 _BlendRange;
half2 _WindDirection;
half _TopIntensity;
half _ColorUpLevel;
half _ColorUpFade;
half _Cutoff;
half _Smoothness;
half _Roughness;
half _Metallic;
half _Alpha;
half _TerrainBrightness;
half _WindSpeed;
half _WindForce;
half _WindWavesScale;
half _WindColorIntensity;
half _WindLineDirection;
half _WindLineScale;
half _WindLineStrength;
half _WindLindSpeed;
half _SSSColorIntensity;
half _SSSPower;
half _SSSScale;
half _Strength;
half _Range;
half _DarkIntensity;
half _DarkScale;
half _CycloneIntensity;
half _CycloneAmount;
half _CycloneScale;
half _CycloneSpeed;
half _BackBrightness;
half _ShadowStrength;
half _AOStrength;
half _OcclusionStrength;
half4 _SpecColor;
half _ClearCoatMask;
half _ClearCoatSmoothness;
half _Surface;
CBUFFER_END

TEXTURE2D(_ParallaxMap);
SAMPLER(sampler_ParallaxMap);
TEXTURE2D(_OcclusionMap);
SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_DetailMask);
SAMPLER(sampler_DetailMask);
TEXTURE2D(_DetailAlbedoMap);
SAMPLER(sampler_DetailAlbedoMap);
TEXTURE2D(_DetailNormalMap);
SAMPLER(sampler_DetailNormalMap);
TEXTURE2D(_MetallicGlossMap);
SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);
SAMPLER(sampler_SpecGlossMap);
TEXTURE2D(_ClearCoatMap);
SAMPLER(sampler_ClearCoatMap);

#ifdef _SPECULAR_SETUP
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif

struct GrassWindResult
{
    float3 offset;
    float4 color;
};

struct GrassAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 texcoord : TEXCOORD0;
    float2 staticLightmapUV : TEXCOORD1;
    float2 aoUV : TEXCOORD2;
    float4 color : COLOR;
    uint instanceID : SV_InstanceID;
};

struct GrassVaryings
{
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    half4 tangentWS : TEXCOORD3;
    half fogFactor : TEXCOORD4;
    float4 shadowCoord : TEXCOORD5;
    half3 vertexSH : TEXCOORD6;
    float2 staticLightmapUV : TEXCOORD7;
    float4 positionOS : TEXCOORD8;
    float4 windLineColor : TEXCOORD9;
    float originY : TEXCOORD10;
    float4 positionCS : SV_POSITION;
};

struct GrassDepthVaryings
{
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float4 positionCS : SV_POSITION;
};

struct GrassShadowVaryings
{
    float2 uv : TEXCOORD0;
    float4 positionCS : SV_POSITION;
};

inline GrassWindResult CalculateGrassWind(float4 positionOS, uint instanceID)
{
    GrassWindResult result;
    result.offset = 0;
    result.color = 0;

    float3 posWS = GetInstanceWorldPosition(positionOS.xyz, instanceID);

    float2 windDir = normalize(float2(_WindDirection.x, _WindDirection.y) + float2(1e-5, 1e-5));
    float2 windUV = float2(posWS.x, posWS.z) + windDir * _WindSpeed * 5.0 * _TimeParameters.x;
    float noise = snoise3D(float3(windUV, 0.0)) * _WindWavesScale * 0.01;
    noise *= pow(saturate(positionOS.y), 2.0);
    float3 windOffset = noise.xxx;

    #ifdef _WINDLINE_ON
    float2 rotatorUV = float2(posWS.x, posWS.z) / max(_WindLineScale * 10.0, 1e-4);
    float c = cos(radians(_WindLineDirection));
    float s = sin(radians(_WindLineDirection));
    float2 rotatedUV = mul(rotatorUV - float2(0.5, 0.5), float2x2(c, -s, s, c)) + float2(0.5, 0.5);
    rotatedUV += _WindLindSpeed * 0.01 * _TimeParameters.x;
    half4 windLineSample = tex2Dlod(_WindLineTex, float4(rotatedUV, 0, 0));
    windOffset = windLineSample.rgb * _WindLineStrength * noise;
    #endif

    float3 interactivePosOS = GetInstanceObjectPosition(_GrassInteractivePos, instanceID);
    float3 n = normalize(positionOS.xyz - interactivePosOS);
    n = float3(n.x, n.y * -0.5, n.z);

    float distanceOut = 1.0 - distance(interactivePosOS, positionOS.xyz);
    float3 interaction = saturate(distanceOut + _Range) * _Strength * n;
    float interactionMask = saturate((_Range - _DarkScale) + distanceOut);

    float2 cycloneUV = PolarCoordinates(float2(posWS.x, posWS.z)) + (_CycloneSpeed * _TimeParameters.x);
    float noise2 = snoise3D(float3(cycloneUV, 0.0)) * _CycloneAmount;
    float cyclone = saturate(_CycloneScale + distanceOut + _Range) * _CycloneIntensity * noise2 * _Cyclone;

    result.offset = windOffset * _WindForce * 30.0 + (interaction + cyclone) * positionOS.y;
    result.color = float4(result.offset, interactionMask);
    return result;
}

half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
{
    half4 specGloss;

    #ifdef _METALLICSPECGLOSSMAP
    specGloss = half4(SAMPLE_METALLICSPECULAR(uv));
        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        specGloss.a = albedoAlpha * _Smoothness;
        #else
        specGloss.a *= _Smoothness;
        #endif
    #else
        #if _SPECULAR_SETUP
        specGloss.rgb = _SpecColor.rgb;
        #else
        specGloss.rgb = _Metallic.rrr;
        #endif

        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        specGloss.a = albedoAlpha * _Smoothness;
        #else
        specGloss.a = 1 - _Roughness;
        #endif
    #endif

    return specGloss;
}

void ApplyPerPixelDisplacement(half3 viewDirTS, inout float2 uv)
{
    #if defined(_PARALLAXMAP)
    uv += ParallaxMapping(TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap), viewDirTS, 1, uv);
    #endif
}

inline void M_InitializeGrassSurfaceData(float2 uv, float4 positionOS, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, 1, _Cutoff) * _Alpha;

    half3 color1 = albedoAlpha.rgb * _Color1.rgb;
    half3 color2 = albedoAlpha.rgb * _Color2.rgb;
    half colorMask = saturate((positionOS.y + _ColorUpLevel) * (_ColorUpFade * 2));
    half3 lerpColor = lerp(color1, color2, colorMask);

    outSurfaceData.albedo = AlphaModulate(lerpColor, outSurfaceData.alpha);
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = half3(0.0, 0.0, 0.0);
    outSurfaceData.smoothness = 0;
    outSurfaceData.normalTS = half3(0, 0, 1);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;

    #if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
    half2 clearCoat = SampleClearCoat(uv);
    outSurfaceData.clearCoatMask = clearCoat.r;
    outSurfaceData.clearCoatSmoothness = clearCoat.g;
    #else
    outSurfaceData.clearCoatMask = half(0.0);
    outSurfaceData.clearCoatSmoothness = half(0.0);
    #endif
}

#endif

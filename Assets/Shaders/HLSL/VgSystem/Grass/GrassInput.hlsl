#ifndef M_GRASS_INPUT_INCLUDED
#define M_GRASS_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Assets/M_Pipeline/ShaderLibrary/M_SurfaceInput.hlsl"

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

#if defined(_DETAIL_MULX2) || defined(_DETAIL_SCALED)
#define _DETAIL
#endif



TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_MossBase);
SAMPLER(sampler_MossBase);

float4 _BaseMap_TexelSize;
float4 _BaseMap_MipInfo;

// TEXTURE2D(_WindLineTex);
// SAMPLER(sampler_WindLineTex);

sampler2D _WindLineTex;

//global var
half _TerrainRoughness;
half4 _TerrainTransformData = half4(0,0,1,1);
sampler2D _TerrainColor;
//sampler2D _TerrainNormal;


half3 _GrassInteractivePos;
half _Cyclone;




// NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;

half4 _MossUV;
// half4 _MossTint;

half4 _Color1;
half4 _Color2;

half2 _BlendRange;//blend terrain
half2 _WindDirection;//wind

half _TopIntensity;
half _ColorUpLevel;
half _ColorUpFade;

half _Cutoff;
half _Roughness;
half _Metallic;
half _Alpha;
// half _BumpScale;
half _TerrainBrightness;//blend terrain

half _WindSpeed;//wind
half _WindForce;//wind
half _WindWavesScale;//wind
half _WindColorIntensity;//WindLine
half _WindLineDirection;//WindLine
half _WindLineScale;//WindLine
half _WindLineStrength;//WindLine
half _WindLindSpeed;//WindLine

half _SSSColorIntensity;//SSS
half _SSSPower;//SSS
half _SSSScale;//SSS

half _Strength;//interactive
half _Range;//interactive
half _DarkIntensity;//interactive
half _DarkScale;//interactive

half _CycloneIntensity;//Cyclone
half _CycloneAmount;//Cyclone
half _CycloneScale;//Cyclone
half _CycloneSpeed;//Cyclone

half _BackBrightness;
half _ShadowStrength;
half _AOStrength;//SSAO

// half _Parallax;
// half _OcclusionStrength;
half _ClearCoatMask;
half _ClearCoatSmoothness;
// half _DetailAlbedoMapScale;
// half _DetailNormalMapScale;
half _Surface;
CBUFFER_END

// NOTE: Do not ifdef the properties for dots instancing, but ifdef the actual usage.
// Otherwise you might break CPU-side as property constant-buffer offsets change per variant.
// NOTE: Dots instancing is orthogonal to the constant buffer above.
#ifdef UNITY_DOTS_INSTANCING_ENABLED

UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
    UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)

    UNITY_DOTS_INSTANCED_PROP(float4, _MossUV)
    // UNITY_DOTS_INSTANCED_PROP(float4, _MossTint)

    UNITY_DOTS_INSTANCED_PROP(float4, _Color1)
    UNITY_DOTS_INSTANCED_PROP(float4, _Color2)

    UNITY_DOTS_INSTANCED_PROP(float2, _BlendRange)
    UNITY_DOTS_INSTANCED_PROP(float2, _WindDirection)


    UNITY_DOTS_INSTANCED_PROP(float , _TopIntensity)
    UNITY_DOTS_INSTANCED_PROP(float , _ColorUpLevel)
    UNITY_DOTS_INSTANCED_PROP(float , _ColorUpFade)

    UNITY_DOTS_INSTANCED_PROP(float , _Cutoff)
    UNITY_DOTS_INSTANCED_PROP(float , _Roughness)
    UNITY_DOTS_INSTANCED_PROP(float , _Metallic)
    UNITY_DOTS_INSTANCED_PROP(float , _Alpha)
    // UNITY_DOTS_INSTANCED_PROP(float , _BumpScale)
    UNITY_DOTS_INSTANCED_PROP(float , _TerrainBrightness)

    UNITY_DOTS_INSTANCED_PROP(float , _WindSpeed)//wind
    UNITY_DOTS_INSTANCED_PROP(float , _WindForce)//wind
    UNITY_DOTS_INSTANCED_PROP(float , _WindWavesScale)//wind
    UNITY_DOTS_INSTANCED_PROP(float , _WindColorIntensity)//WindLine
    UNITY_DOTS_INSTANCED_PROP(float , _WindLineDirection)//WindLine
    UNITY_DOTS_INSTANCED_PROP(float , _WindLineScale)//WindLine
    UNITY_DOTS_INSTANCED_PROP(float , _WindLineStrength)//WindLine
    UNITY_DOTS_INSTANCED_PROP(float , _WindLindSpeed)//WindLine

    UNITY_DOTS_INSTANCED_PROP(float , _SSSColorIntensity)//SSS
    UNITY_DOTS_INSTANCED_PROP(float , _SSSPower)//SSS
    UNITY_DOTS_INSTANCED_PROP(float , _SSSScale)//SSS

    UNITY_DOTS_INSTANCED_PROP(float , _Strength)//interactive
    UNITY_DOTS_INSTANCED_PROP(float , _Range)//interactive
    UNITY_DOTS_INSTANCED_PROP(float , _DarkIntensity)//interactive
    UNITY_DOTS_INSTANCED_PROP(float , _DarkScale)//interactive

    UNITY_DOTS_INSTANCED_PROP(float , _CycloneIntensity)//Cyclone
    UNITY_DOTS_INSTANCED_PROP(float , _CycloneAmount)//Cyclone
    UNITY_DOTS_INSTANCED_PROP(float , _CycloneScale)//Cyclone
    UNITY_DOTS_INSTANCED_PROP(float , _CycloneSpeed)//Cyclone

    UNITY_DOTS_INSTANCED_PROP(float , _BackBrightness)
    UNITY_DOTS_INSTANCED_PROP(float , _ShadowStrength)
    UNITY_DOTS_INSTANCED_PROP(float , _AOStrength)


    // UNITY_DOTS_INSTANCED_PROP(float , _Parallax)
    // UNITY_DOTS_INSTANCED_PROP(float , _OcclusionStrength)
    UNITY_DOTS_INSTANCED_PROP(float , _ClearCoatMask)
    UNITY_DOTS_INSTANCED_PROP(float , _ClearCoatSmoothness)
    // UNITY_DOTS_INSTANCED_PROP(float , _DetailAlbedoMapScale)
    // UNITY_DOTS_INSTANCED_PROP(float , _DetailNormalMapScale)
    UNITY_DOTS_INSTANCED_PROP(float , _Surface)
UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

#define _BaseColor              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _BaseColor)

#define _MossUV                 UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4  , _MossUV)
// #define _MossTint               UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4  , _MossTint)

#define _Color1                 UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _Color1)
#define _Color2                 UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4 , _Color2)

#define _BlendRange             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float2 , _BlendRange)
#define _WindDirection          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float2 , _WindDirection)

#define _TopIntensity           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float , _TopIntensity)

#define _ColorUpLevel           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _ColorUpLevel)
#define _ColorUpFade            UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _ColorUpFade)

#define _Cutoff                 UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Cutoff)
#define _Roughness              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Roughness)
#define _Metallic               UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Metallic)
#define _Alpha                  UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Alpha)
// #define _BumpScale              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _BumpScale)
#define _TerrainBrightness      UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _TerrainBrightness)

#define _WindSpeed              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _WindSpeed)//wind
#define _WindForce              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _WindForce)//wind
#define _WindWavesScale         UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _WindWavesScale)//wind
#define _WindColorIntensity     UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _WindColorIntensity)//WindLine
#define _WindLineDirection      UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _WindLineDirection)//WindLine
#define _WindLineScale          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _WindLineScale)//WindLine
#define _WindLineStrength       UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _WindLineStrength)//WindLine
#define _WindLindSpeed          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _WindLindSpeed)//WindLine

#define _SSSColorIntensity      UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _SSSColorIntensity)//SSS
#define _SSSPower               UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _SSSPower)//SSS
#define _SSSScale               UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _SSSScale)//SSS

#define _Strength               UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Strength)//interactive
#define _Range                  UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Range)//interactive
#define _DarkIntensity          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _DarkIntensity)//interactive
#define _DarkScale              UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _DarkScale)//interactive

#define _CycloneIntensity       UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _CycloneIntensity)//Cyclone
#define _CycloneAmount          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _CycloneAmount)//Cyclone
#define _CycloneScale           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _CycloneScale)//Cyclone
#define _CycloneSpeed           UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _CycloneSpeed)//Cyclone

#define _BackBrightness         UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _BackBrightness)
#define _ShadowStrength         UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _ShadowStrength)
#define _AOStrength             UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _AOStrength)


// #define _Parallax               UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Parallax)
// #define _OcclusionStrength      UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _OcclusionStrength)
#define _ClearCoatMask          UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _ClearCoatMask)
#define _ClearCoatSmoothness    UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _ClearCoatSmoothness)
// #define _DetailAlbedoMapScale   UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _DetailAlbedoMapScale)
// #define _DetailNormalMapScale   UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _DetailNormalMapScale)
#define _Surface                UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float  , _Surface)
#endif

TEXTURE2D(_ParallaxMap);        SAMPLER(sampler_ParallaxMap);
TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_DetailMask);         SAMPLER(sampler_DetailMask);
TEXTURE2D(_DetailAlbedoMap);    SAMPLER(sampler_DetailAlbedoMap);
TEXTURE2D(_DetailNormalMap);    SAMPLER(sampler_DetailNormalMap);
TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);
TEXTURE2D(_ClearCoatMap);       SAMPLER(sampler_ClearCoatMap);

#ifdef _SPECULAR_SETUP
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif

inline float3 WindOffset(float4 positionOS)
{
    float3 posWS = TransformObjectToWorld(positionOS.xyz);
    
    half4 windlineColor = half4(0,0,0,0);
    half3 windOffset = half3(0,0,0);
    
    // WIND
//#ifdef _WIND_ON
    
    //
    // compute wind line color
    //
    float2 windUV = float2(posWS.x,posWS.z) + (normalize(_WindDirection) * _WindSpeed * 5 * _TimeParameters.x);
    float noise = snoise3D(half3(windUV,0)) * _WindWavesScale * 0.01;
    noise = noise * pow(saturate(positionOS.y),2);
    windOffset = noise;
    
#ifdef _WINDLINE_ON
    float2 rotatorUV = float2(posWS.x,posWS.z)/(_WindLineScale * 10);
    float _cos = cos(radians(_WindLineDirection));
    float _sin = sin(radians(_WindLineDirection));
    half2 rotatOutput = mul(rotatorUV - half2(0.5,0.5) , float2x2( _cos , -_sin , _sin , _cos )) + half2(0.5,0.5);

    rotatorUV = rotatOutput + (_WindLindSpeed * 0.01 * _TimeParameters.x);
    windlineColor = tex2Dlod(_WindLineTex,float4(rotatorUV,0,0));//SAMPLE_TEXTURE2D(_WindLineTex,sampler_WindLineTex,rotatorUV);//SampleAlbedoAlpha(rotatorUV,TEXTURE2D_ARGS(_WindLineTex,sampler_WindLineTex));

    windOffset = (windlineColor * _WindLineStrength * noise).xyz;
#endif

    //interaction
    half3 interactivePosOS = TransformWorldToObject(_GrassInteractivePos);
    half3 n = normalize(positionOS.xyz - interactivePosOS);
    n = half3(n.x,n.y * -0.5,n.z);
    
    float distanceOut = 1 - distance(interactivePosOS,positionOS.xyz);
    
    half3 Interaction = saturate(distanceOut + _Range) * _Strength * n;

    half interColor = saturate((_Range - _DarkScale) + distanceOut);
    //---- important !!!
    windlineColor.a = interColor;
    //
    //cyclone
    float2 cycloneUV = float2(posWS.x,posWS.z);
    cycloneUV = PolarCoordinates(cycloneUV) + (_CycloneSpeed * _TimeParameters.x);
    float noise2 = snoise3D(float3(cycloneUV,0)) * _CycloneAmount;
    float cyclone = saturate(_CycloneScale + distanceOut + _Range) * _CycloneIntensity * noise2 * _Cyclone;
    //
    //
    // combine with interaction , cyclone

    
    windOffset = windOffset * _WindForce * 30 + (Interaction + cyclone) * positionOS.y;
    return windOffset;
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
#else // _METALLICSPECGLOSSMAP
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


//
// Grass Surface Data For Project M
inline void M_InitializeGrassSurfaceData(float2 uv, float4 positionOS, out SurfaceData outSurfaceData)
{
    //base tex
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, 1, _Cutoff) * _Alpha;


    half3 color1 = albedoAlpha.rgb * _Color1.rgb;
    half3 color2 = albedoAlpha.rgb * _Color2.rgb;
    half colorMask = saturate((positionOS.y + _ColorUpLevel) * (_ColorUpFade * 2));
    half3 lerpColor = lerp(color1,color2,colorMask);
    //
    //
    //init surface data
    outSurfaceData.albedo = lerpColor;
    outSurfaceData.albedo = AlphaModulate(outSurfaceData.albedo, outSurfaceData.alpha);
    
    outSurfaceData.metallic = 0;//_Metallic;
    outSurfaceData.specular = half3(0.0, 0.0, 0.0);

    outSurfaceData.smoothness = 0;//1 - _Roughness;
    outSurfaceData.normalTS = half3(0, 0, 1);
    outSurfaceData.occlusion = 1;//SampleOcclusion(uv);
    outSurfaceData.emission = 0;    
    
    //urp default
    //
#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
    half2 clearCoat = SampleClearCoat(uv);
    outSurfaceData.clearCoatMask       = clearCoat.r;
    outSurfaceData.clearCoatSmoothness = clearCoat.g;
#else
    outSurfaceData.clearCoatMask       = half(0.0);
    outSurfaceData.clearCoatSmoothness = half(0.0);
#endif

    /* not use in project M
#if defined(_DETAIL)
    half detailMask = SAMPLE_TEXTURE2D(_DetailMask, sampler_DetailMask, uv).a;
    float2 detailUv = uv * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
    outSurfaceData.albedo = ApplyDetailAlbedo(detailUv, outSurfaceData.albedo, detailMask);
    outSurfaceData.normalTS = ApplyDetailNormal(detailUv, outSurfaceData.normalTS, detailMask);
#endif
    */
}

#endif // UNIVERSAL_INPUT_SURFACE_PBR_INCLUDED

#ifndef VG_GRASS_FORWARD_INCLUDED
#define VG_GRASS_FORWARD_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/Grass/GrassInput.hlsl"
#include "Assets/Shaders/HLSL/Lighting/CustomLighting.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Custom/BlendTerrain.hlsl"

#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

void InitializeInputData(GrassVaryings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    float sgn = input.tangentWS.w;
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

    #if defined(_NORMALMAP)
    inputData.tangentToWorld = tangentToWorld;
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
    #else
    inputData.normalWS = input.normalWS;
    #endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
    inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif

    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
}

void VgBlendTerrainInstance(
    float3 positionWS,
    float originY,
    float4 tangentWS,
    float3 normalWS,
    SurfaceData surfaceData,
    out BlendTerrainOutput output)
{
    VgBlendTerrainFromSplat(
        positionWS,
        originY,
        surfaceData.albedo,
        _BlendRange,
        _TerrainBrightness,
        _VGTerrainRoughness,
        _VGTerrainTransformData,
        output);
}

void VgBlendTerrainBakedInstance(
    float3 positionWS,
    float originY,
    SurfaceData surfaceData,
    out BlendTerrainOutput output)
{
    VgBlendTerrainFromBaked(
        positionWS,
        originY,
        surfaceData.albedo,
        _BlendRange,
        _TerrainBrightness,
        _VGTerrainRoughness,
        _VGTerrainTransformData,
        output);
}

void VgBlendMossInstance(
    float3 positionWS,
    float originY,
    SurfaceData surfaceData,
    out BlendTerrainOutput output)
{
    half2 mossUV_xy = half2(_MossUV.x, _MossUV.y);
    half2 mossUV_zw = half2(_MossUV.z, _MossUV.w);
    float2 uv1 = float2(positionWS.x, positionWS.z) / (half2(2, 2) / max(mossUV_xy, half2(1e-4, 1e-4)));
    float2 uv2 = mossUV_zw / max(mossUV_xy, half2(1e-4, 1e-4));
    float2 finalMossUV = uv1 + uv2;
    half4 mossColor = VgSampleAlbedoAlpha(finalMossUV, TEXTURE2D_ARGS(_MossBase, sampler_MossBase));

    VgBlendTerrainFromColor(
        positionWS,
        originY,
        surfaceData.albedo,
        mossColor.rgb,
        _BlendRange,
        _TerrainBrightness,
        _VGTerrainRoughness,
        output);
}

GrassVaryings LitPassVertex(GrassAttributes input)
{
    GrassVaryings output = (GrassVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);

    GrassWindResult wind = CalculateGrassWind(input.positionOS, input.instanceID);
    float4 deformedOS = input.positionOS;
    deformedOS.xyz += wind.offset;

    float3 positionWS = GetInstanceWorldPosition(deformedOS.xyz, input.instanceID);
    float3 normalWS = GetInstanceWorldNormal(input.normalOS, input.instanceID);
    float3 tangentDirWS = GetInstanceWorldDirection(input.tangentOS.xyz, input.instanceID);
    float4 positionCS = TransformWorldToHClip(positionWS);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.positionWS = positionWS;
    output.normalWS = normalWS;
    output.tangentWS = half4(tangentDirWS, input.tangentOS.w);
    output.fogFactor = ComputeFogFactor(positionCS.z);
    output.shadowCoord = TransformWorldToShadowCoord(positionWS);
    output.positionOS = deformedOS;
    output.windLineColor = wind.color;
    output.originY = GetInstanceOriginWS(input.instanceID).y;
    output.positionCS = positionCS;
    output.staticLightmapUV = input.staticLightmapUV.xy * unity_LightmapST.xy + unity_LightmapST.zw;
    output.vertexSH = SampleSHVertex(normalWS);
    return output;
}

half4 LitPassFragment(GrassVaryings input) : SV_Target
{
    SurfaceData surfaceData;
    M_InitializeGrassSurfaceData(input.uv, input.positionOS, surfaceData);

    SurfaceDataExt surfaceDataExt;
    surfaceDataExt.backBrightness = _BackBrightness;
    surfaceDataExt.shadowStrength = _ShadowStrength;

    half blendMask = 1;
    half3 blendColor = surfaceData.albedo;

    #if defined(_BLEND_TERRAIN_ON)
    BlendTerrainOutput blendTerrainOutput;
        #ifdef _USEGROSS
        VgBlendMossInstance(input.positionWS, input.originY, surfaceData, blendTerrainOutput);
        #else
        VgBlendTerrainBakedInstance(input.positionWS, input.originY, surfaceData, blendTerrainOutput);
        #endif

    blendMask = blendTerrainOutput.blendMask;
    blendColor = blendTerrainOutput.blendColor;
    surfaceData.albedo.rgb = blendColor * lerp(1, _TopIntensity, blendMask);
    #endif

    #ifdef _WINDLINE_ON
    half3 windColor = input.windLineColor.rgb * blendMask * (blendColor * _WindColorIntensity);
    surfaceData.albedo.rgb += windColor;
    #endif

    half l = saturate(input.positionOS.y) * input.windLineColor.a;
    half3 finalColor = surfaceData.albedo.rgb;
    surfaceData.albedo.rgb = lerp(finalColor, finalColor * _DarkIntensity, l);

    #ifdef LOD_FADE_CROSSFADE
    LODFadeCrossFade(input.positionCS);
    #endif

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    #if defined(_SSAO) && defined(_SCREEN_SPACE_OCCLUSION)
    surfaceData.occlusion *= lerp(1.0, SampleAmbientOcclusion(inputData.normalizedScreenSpaceUV), _AOStrength);
    #endif

    #ifdef _DBUFFER
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
    #endif

    CustomLightingData lightingData;
    half4 color = UniversalFragmentPBR(inputData, surfaceData, surfaceDataExt, lightingData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, IsSurfaceTypeTransparent(_Surface));
    return color;
}

#endif

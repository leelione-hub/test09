#ifndef VG_GRASS_FORWARD_INCLUDED
#define VG_GRASS_FORWARD_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/Grass/GrassInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Custom/SurfaceDataExt.hlsl"
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
    float2 uv = float2(positionWS.x, positionWS.z) - float2(_TerrainTransformData.x, _TerrainTransformData.y);
    uv = uv / half2(_TerrainTransformData.z, _TerrainTransformData.w);

    half4 splatControl = SAMPLE_TEXTURE2D(_Control, sampler_Control, uv);
    float2 uv0 = uv * _Splat0_ST.xy + _Splat0_ST.zw;
    float2 uv1 = uv * _Splat1_ST.xy + _Splat1_ST.zw;
    float2 uv2 = uv * _Splat2_ST.xy + _Splat2_ST.zw;
    float2 uv3 = uv * _Splat3_ST.xy + _Splat3_ST.zw;

    float4 diffAlbedo0 = SAMPLE_TEXTURE2D_LOD(_Splat0, sampler_Splat0, uv0, 0);
    float4 diffAlbedo1 = SAMPLE_TEXTURE2D_LOD(_Splat1, sampler_Splat1, uv1, 0);
    float4 diffAlbedo2 = SAMPLE_TEXTURE2D_LOD(_Splat2, sampler_Splat2, uv2, 0);
    float4 diffAlbedo3 = SAMPLE_TEXTURE2D_LOD(_Splat3, sampler_Splat3, uv3, 0);

    half4 mixedDiffuse = 0.0h;
    mixedDiffuse += diffAlbedo0 * float4(_DiffuseRemapScale0.rgb * splatControl.rrr, 1.0);
    mixedDiffuse += diffAlbedo1 * float4(_DiffuseRemapScale1.rgb * splatControl.ggg, 1.0);
    mixedDiffuse += diffAlbedo2 * float4(_DiffuseRemapScale2.rgb * splatControl.bbb, 1.0);
    mixedDiffuse += diffAlbedo3 * float4(_DiffuseRemapScale3.rgb * splatControl.aaa, 1.0);

    half3 terrainColor = mixedDiffuse.rgb * _TerrainBrightness;
    float smoothStep = smoothstep(_BlendRange.x, _BlendRange.y, positionWS.y - originY);

    output.blendColor = lerp(terrainColor, surfaceData.albedo, smoothStep);
    output.blendNormal = half3(0, 0, 1);
    output.blendRoughness = lerp(_TerrainRoughness, 1.0h, smoothStep);
    output.blendMask = smoothStep;
}

void VgBlendTerrainBakedInstance(
    float3 positionWS,
    float originY,
    SurfaceData surfaceData,
    out BlendTerrainOutput output)
{
    float2 uv = float2(positionWS.x, positionWS.z) - float2(_TerrainTransformData.x, _TerrainTransformData.y);
    uv = uv / half2(_TerrainTransformData.z, _TerrainTransformData.w);

    half4 terrainSample = SAMPLE_TEXTURE2D_LOD(_TerrainColor, sampler_TerrainColor, uv, 0);
    half3 terrainColor = terrainSample.rgb * _TerrainBrightness;
    float smoothStep = smoothstep(_BlendRange.x, _BlendRange.y, positionWS.y - originY);

    output.blendColor = lerp(terrainColor, surfaceData.albedo, smoothStep);
    output.blendNormal = half3(0, 0, 1);
    output.blendRoughness = lerp(_TerrainRoughness, 1.0h, smoothStep);
    output.blendMask = smoothStep;
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
    half4 mossColor = SampleAlbedoAlpha(finalMossUV, TEXTURE2D_ARGS(_MossBase, sampler_MossBase));

    half3 terrainColor = mossColor.rgb * _TerrainBrightness;
    float smoothStep = smoothstep(_BlendRange.x, _BlendRange.y, positionWS.y - originY);

    output.blendColor = lerp(terrainColor, surfaceData.albedo, smoothStep);
    output.blendNormal = half3(0, 0, 1);
    output.blendRoughness = lerp(_TerrainRoughness, 1.0h, smoothStep);
    output.blendMask = smoothStep;
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
            #if defined(_TERRAIN_BLEND_BAKED)
        VgBlendTerrainBakedInstance(input.positionWS, input.originY, surfaceData, blendTerrainOutput);
            #else
        VgBlendTerrainInstance(input.positionWS, input.originY, input.tangentWS, input.normalWS, surfaceData, blendTerrainOutput);
            #endif
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

    half4 color = UniversalFragmentBlinnPhong(inputData, surfaceData, surfaceDataExt);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, IsSurfaceTypeTransparent(_Surface));
    return color;
}

#endif

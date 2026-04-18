#ifndef M_RIVER_LWGUI_FORWARD_INCLUDED
#define M_RIVER_LWGUI_FORWARD_INCLUDED

#include "Assets/Shaders/HLSL/Lighting/CustomLighting.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

#if defined(LIGHTMAP_ON)
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) float2 lmName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT) OUT.xy = lightmapUV.xy * lightmapScaleOffset.xy + lightmapScaleOffset.zw;
    #define OUTPUT_SH(normalWS, OUT)
#else
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) half3 shName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT)
    #define OUTPUT_SH(normalWS, OUT) OUT.xyz = SampleSHVertex(normalWS)
#endif

#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 texcoord : TEXCOORD0;
    float2 staticLightmapUV : TEXCOORD1;
    float2 dynamicLightmapUV : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    float3 positionWS : TEXCOORD1;
#endif
    float3 normalWS : TEXCOORD2;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    half4 tangentWS : TEXCOORD3;
#endif
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight : TEXCOORD5;
#else
    half fogFactor : TEXCOORD5;
#endif
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord : TEXCOORD6;
#endif
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS : TEXCOORD7;
#endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
#ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD9;
#endif
    float4 positionCS : SV_POSITION;
    float4 screenPos : TEXCOORD10;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

half3 RiverLightingLambert(half3 lightColor, half3 lightDir, half3 normalWS)
{
    half ndotl = saturate(dot(normalWS, lightDir) * 0.5h + 0.5h);
    return lightColor * ndotl;
}

half3 RiverVertexLighting(float3 positionWS, half3 normalWS)
{
    half3 vertexLightColor = 0;
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    uint lightsCount = GetAdditionalLightsCount();
    LIGHT_LOOP_BEGIN(lightsCount)
        Light light = GetAdditionalLight(lightIndex, positionWS);
        vertexLightColor += RiverLightingLambert(light.color * light.distanceAttenuation, light.direction, normalWS);
    LIGHT_LOOP_END
#endif
    return vertexLightColor;
}

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
#endif

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    float sgn = input.tangentWS.w;
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
#if defined(_NORMALMAP)
    inputData.tangentToWorld = tangentToWorld;
#endif
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
    inputData.shadowCoord = 0;
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
#else
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
#endif

#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
#endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
}

half4 WaterFoam(half4 screenPosNorm, float screenDepth, float2 uv, half3 viewDirWS)
{
    half4 foamScreenPosNorm = screenPosNorm;
    foamScreenPosNorm.z = (UNITY_NEAR_CLIP_VALUE >= 0) ? foamScreenPosNorm.z : foamScreenPosNorm.z * 0.5 + 0.5;
    half distanceDepth = abs((screenDepth - LinearEyeDepth(foamScreenPosNorm.z, _ZBufferParams)) / _EdgeWidth);
    half foamMask = saturate(distanceDepth * abs(viewDirWS.y)) * _DepthCutOff;
    half2 coastUV = uv * _CoastScale.xx;
    half noise = snoise(_TimeParameters.x * _CoastSpeed + coastUV) * 0.5h + 0.5h;
    half4 tempFoamColor = step(foamMask, noise) * _FoamColor;

    half foamDepthMask = 0;
#if defined(_USEDISTANCETEX_ON)
    half distance = tex2D(_DistanceMap, uv).r;
    foamDepthMask = saturate(1.0 - distance / max(_FoamScale, 0.0001h));
#else
    half foamDistanceDepth = abs((screenDepth - LinearEyeDepth(screenPosNorm.z, _ZBufferParams)) / _FoamDepth);
    foamDepthMask = 1.0 - saturate(foamDistanceDepth * abs(viewDirWS.y)) * _FoamDepthFallOff;
#endif

    half2 foamUV = half2(uv.x * _FoamTiling, foamDepthMask * _FoamWidth) + _TimeParameters.x * _FoamSpeed;
    half foamTex = tex2D(_FoamTex, foamUV).g * foamDepthMask - saturate(_FoamCut);
#if defined(_FOAMSMOOTHEDGE1_ON)
    foamTex *= 3.0h;
#else
    foamTex = ceil(foamTex);
#endif
    foamTex = saturate(foamTex * _FoamTexColor.r * _FoamTexAlpha);
#if defined(_FOAMTEX_ON)
    tempFoamColor += foamTex;
#endif
    return saturate(tempFoamColor) * _FoamColor.a;
}

bool RiverTryProjectWorldToUV(float3 positionWS, out float2 uv, out float rayLinearDepth)
{
    float4 clipPos = TransformWorldToHClip(positionWS);
    if (clipPos.w <= 0.0001)
    {
        uv = 0;
        rayLinearDepth = 0;
        return false;
    }

    float4 screenPos = ComputeScreenPos(clipPos);
    uv = screenPos.xy / screenPos.w;

    float4 screenPosNorm = screenPos / screenPos.w;
    screenPosNorm.z = (UNITY_NEAR_CLIP_VALUE >= 0) ? screenPosNorm.z : screenPosNorm.z * 0.5 + 0.5;
    rayLinearDepth = LinearEyeDepth(screenPosNorm.z, _ZBufferParams);
    return all(uv >= 0.0.xx) && all(uv <= 1.0.xx);
}

half RiverComputeEdgeFade(float2 uv)
{
    float2 edge = min(uv, 1.0 - uv);
    float edgeFactor = min(edge.x, edge.y);
    return saturate(edgeFactor / max(_SSREdgeFade, 0.0001h));
}

half4 SampleRiverSSR(float3 surfacePositionWS, half3 surfaceNormalWS, half3 viewDirWS, half fresnelMask, half depthMask)
{
#if defined(_RIVER_SSR_ON)
    half3 reflectionDirWS = normalize(reflect(-viewDirWS, surfaceNormalWS));
    float stepSize = max(_SSRStepSize, 0.01h);
    float maxDistance = max(_SSRMaxDistance, stepSize);
    int maxSteps = clamp((int)round(_SSRMaxSteps), 1, 128);
    float travel = stepSize;
    float3 rayStartWS = surfacePositionWS + surfaceNormalWS * _SSRRayStartBias;
    half3 hitColor = 0;
    half hitMask = 0;

    [loop]
    for (int i = 0; i < 128; i++)
    {
        if (i >= maxSteps || travel > maxDistance)
        {
            break;
        }

        float3 rayPositionWS = rayStartWS + reflectionDirWS * travel;
        float2 hitUV;
        float rayLinearDepth;
        if (!RiverTryProjectWorldToUV(rayPositionWS, hitUV, rayLinearDepth))
        {
            break;
        }

        hitUV += surfaceNormalWS.xz * _SSRDistortion;
        if (any(hitUV < 0.0.xx) || any(hitUV > 1.0.xx))
        {
            break;
        }

        float sceneLinearDepth = LinearEyeDepth(CommonSampleDepth(hitUV), _ZBufferParams);
        float hitDelta = rayLinearDepth - sceneLinearDepth;
        if (hitDelta > 0.0 && hitDelta < _SSRThickness)
        {
            half4 ssrSample = SAMPLE_TEXTURE2D(_RiverSSRTexture, sampler_RiverSSRTexture, hitUV);
            half validity = step(_SSRValidThreshold, ssrSample.a);
            half edgeFade = RiverComputeEdgeFade(hitUV);
            hitMask = validity * edgeFade;
            hitColor = ssrSample.rgb;
            break;
        }

        travel += stepSize;
    }

    half ssrMask = _SSRBlend * _SSRIntensity * hitMask;
    ssrMask *= lerp(1.0h, fresnelMask, _SSRMaskByFresnel);
    ssrMask *= lerp(1.0h, depthMask, _SSRMaskByDepth);
    return half4(hitColor, saturate(ssrMask));
#else
    return 0;
#endif
}

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    half3 vertexLight = RiverVertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = 0;
#if !defined(_FOG_FRAGMENT)
    fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
#endif

    float4 clipPos = TransformObjectToHClip(input.positionOS.xyz);
    output.screenPos = ComputeScreenPos(clipPos);
    output.uv = input.texcoord;
    output.normalWS = normalInput.normalWS;

#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
#endif
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
    output.viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
#endif

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
#else
    output.fogFactor = fogFactor;
#endif

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif
    output.positionCS = vertexInput.positionCS;
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    return output;
}

void LitPassFragment(
    Varyings input,
    out half4 outColor : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

#if defined(_PARALLAXMAP)
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = input.viewDirTS;
#else
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
#endif
    ApplyPerPixelDisplacement(viewDirTS, input.uv);
#endif

    SurfaceData surfaceData;
    float2 uv = input.uv;
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    float3 normalWS = input.normalWS;

    half2 waveTile = (uv * _TilingOffset.xy + _TilingOffset.zw) * _WaveNormalScale;
    float waveSpeed = _WaveSpeed * _TimeParameters.x;
    half2 pannerUV1 = (waveSpeed / 50.0) * half2(0.4, -0.8) + waveTile;
    half2 pannerUV2 = (waveSpeed / -18.0) * half2(0.6, -0.3) + waveTile;
    half3 wavesNormal = UnpackNormalScale(tex2D(_WavesNormal, pannerUV1), 1.0f) + UnpackNormalScale(tex2D(_WavesNormal, pannerUV2), 1.0f);
    half3 normal = half3(wavesNormal.x * _WavesNormalIntensity, wavesNormal.y * _WavesNormalIntensity, wavesNormal.z);
    float sgn = input.tangentWS.w;
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    half3 waterNormalWS = normalize(TransformTangentToWorld(normal, tangentToWorld));

    half3 rotatedValue = RotateAroundAxis(float3(0, 0, 0), reflect(-viewDirWS, waterNormalWS) + half3(_Refraction * normal.xy, 0.0), float3(0, 1, 0), radians(_CubemapRotation));
    half4 cubemap = texCUBE(_Cubemap, rotatedValue);

    float4 screenPos = ASE_ComputeGrabScreenPos(input.screenPos);
    float4 screenPosNorm = screenPos / screenPos.w;
    float screenDepth = LinearEyeDepth(CommonSampleDepth(screenPosNorm.xy), _ZBufferParams);
    half2 sceneUV = screenPosNorm.xy;
    half4 refractions = half4(SHADERGRAPH_SAMPLE_SCENE_COLOR(sceneUV), 1.0);
    half mainDepth = saturate(saturate(MyCustomExpression_Water(sceneUV, screenPosNorm) / _DepthDistance));

    half lerpA = clamp(saturate(abs(viewDirWS.y) * mainDepth) * _Strength, 0.0, 1.0);
    half4 shallowDeepColor = lerp(_SurfaceColor, _DepthColor, lerpA);
    half4 fresnelColor = saturate(shallowDeepColor - (1 - _FresnelAmount).xxxx);
#if defined(_CUBEMAP_ON)
    fresnelColor *= cubemap;
#endif

    half fresnelNdot = dot(waterNormalWS, viewDirWS);
    half fresnelOut = _FresnelScale * pow(abs(1.0 - fresnelNdot), _FresnelPower);
    half4 color = lerp(shallowDeepColor, fresnelColor, saturate(fresnelOut * _FresnelColor));
    color = lerp(refractions, color, color.a);

    half ssrDepthMask = saturate(mainDepth);
    half4 ssrReflection = SampleRiverSSR(input.positionWS, waterNormalWS, viewDirWS, saturate(fresnelOut), ssrDepthMask);
    color.rgb = lerp(color.rgb, ssrReflection.rgb, ssrReflection.a);

#if defined(_ENABLEFOAM_ON)
    color += WaterFoam(screenPosNorm, screenDepth, uv, viewDirWS);
#endif

#if defined(_ENABLEWAVETEX_ON)
    float2 lightWaveUV = ((uv * _WaveTexTilingOffset.xy) + _WaveTexTilingOffset.zw) * _NoiseScale;
    float waveTime = _TimeParameters.x * _NoiseSpeed;
    float2 panner1 = waveTime * half2(0.3, 0.3) + lightWaveUV;
    float2 panner2 = waveTime * half2(-0.3, -0.3) + lightWaveUV;
    float lightTex = tex2D(_FoamTex, panner1).r * tex2D(_FoamTex, 1.0 - panner2).r;
    color += pow(abs(saturate(lightTex) * _LightColor), _LightPower.xxxx);
#endif

    half distanceDepth = abs((screenDepth - LinearEyeDepth(screenPosNorm.z, _ZBufferParams)));
    half alpha = saturate((distanceDepth * 5.0) / _CoastAlpha);

    surfaceData.albedo = color.rgb;
    surfaceData.alpha = alpha;
    surfaceData.metallic = 0;
    surfaceData.specular = 0.5;
    surfaceData.smoothness = 1 - _Roughness;
    surfaceData.normalTS = normal;
    surfaceData.occlusion = 1;
    surfaceData.emission = 0;
    surfaceData.clearCoatMask = 0;
    surfaceData.clearCoatSmoothness = 0;

    SurfaceDataExt surfaceDataExt;
    surfaceDataExt.backBrightness = _BackBrightness;
    surfaceDataExt.shadowStrength = _ShadowStrength;

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
    color = UniversalFragmentPBR(inputData, surfaceData, surfaceDataExt, lightingData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, IsSurfaceTypeTransparent(_Surface));
    outColor = color;
    // outColor.rgb = surfaceData.albedo;
    
#ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
#endif
}

#endif

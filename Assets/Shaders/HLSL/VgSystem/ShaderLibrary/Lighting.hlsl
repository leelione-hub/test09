#ifndef VG_LIGHTING_INCLUDED
#define VG_LIGHTING_INCLUDED


#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/RealtimeLights.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Custom/SurfaceDataExt.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Brdf.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/GlobalIllumination.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/PlayerShadow.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/CloudShadow.hlsl"


/////////////////////////////////// SG Skin////////////////////////////////////////////////////
// Alex added Spherical Gaussian SSS lighting functions
struct SphericalGaussian
{
    half3 Axis;
    half Sharpness;
    half Amplitude;
};
  
half DotCosineLobe( SphericalGaussian G, half3 N )
{
	const half muDotN = dot( G.Axis, N );

	const half c0 = 0.36;
	const half c1 = 0.25 / c0;

	half eml  = exp( -G.Sharpness );
	half em2l = eml * eml;
	half rl   = rcp( G.Sharpness );
 
	half scale = 1.0f + 2.0f * em2l - rl;
	half bias  = (eml - em2l) * rl - em2l;

	half x = sqrt( 1.0 - scale );
	half x0 = c0 * muDotN;
	half x1 = c1 * x;

	half n = x0 + x1;
	half y = ( abs( x0 ) <= x1 ) ? n*n / x : saturate( muDotN );

	return scale * y + bias;
}

SphericalGaussian MakeNormalizedSG(half3 LightDir, half Sharpness)
{
    SphericalGaussian SG;
    SG.Axis = LightDir;
    SG.Sharpness = Sharpness; 
    SG.Amplitude = SG.Sharpness / ((2 * PI) * (1 - exp(-2 * SG.Sharpness))); 
    return SG;
}

half3 SGDiffuseLighting(half3 N, half3 L, half3 ScatterAmt, half Tonemapping, half Curvature)
{
    SphericalGaussian RedKernel = MakeNormalizedSG(L, 1 / max(ScatterAmt.x, HALF_EPS));
    SphericalGaussian GreenKernel = MakeNormalizedSG(L, 1 / max(ScatterAmt.y, HALF_EPS));
    SphericalGaussian BlueKernel = MakeNormalizedSG(L, 1 / max(ScatterAmt.z, HALF_EPS));
    half3 Diffuse = half3(DotCosineLobe(RedKernel, N), DotCosineLobe(GreenKernel, N), DotCosineLobe(BlueKernel, N));

    half3 x = max(0, (Diffuse - 0.004));
    half3 DiffuseTonemapping = lerp(Diffuse, (x*(6.2*x+0.5))/(x*(6.2*x+1.7)+0.06), Tonemapping);
    return lerp(Diffuse, DiffuseTonemapping, Curvature);
}


#if defined(LIGHTMAP_ON)
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) float2 lmName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT) OUT.xy = lightmapUV.xy * lightmapScaleOffset.xy + lightmapScaleOffset.zw;
    #define OUTPUT_SH(normalWS, OUT)
#else
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) half3 shName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT)
    #if _UI_ON
        #define OUTPUT_SH(normalWS, OUT) OUT.xyz = ShadeSH9(half4(normalWS,1))
    #else
        #define OUTPUT_SH(normalWS, OUT) OUT.xyz = SampleSHVertex(normalWS)
    #endif
#endif
#define SAMPLE_CustomGI(staticLmName, shName, normalWSName) SampleCustomSHPixel(shName, normalWSName)

half3 LightingLambert(half3 lightColor, half3 lightDir, half3 normal)
{
    BRDFDataExt brdfDataExt;
    brdfDataExt.backBrightness = 0;
    brdfDataExt.shadowStrength = 0.5;
    
    half NdotL = saturate(lerp(brdfDataExt.backBrightness, 1, dot(normal, lightDir) * 0.5 + 0.5));
    // half NdotL = saturate(dot(normal, lightDir));
    NdotL = lerp(1,NdotL,brdfDataExt.shadowStrength);
    return lightColor * NdotL;
}

half3 LightingLambert(half3 lightColor, half3 lightDir, half3 normal,half shadowStrength)
{
    BRDFDataExt brdfDataExt;
    brdfDataExt.backBrightness = 0;
    brdfDataExt.shadowStrength = shadowStrength;
    
    half NdotL = saturate(lerp(brdfDataExt.backBrightness, 1, dot(normal, lightDir) * 0.5 + 0.5));
    // half NdotL = saturate(dot(normal, lightDir));
    NdotL = lerp(1,NdotL,brdfDataExt.shadowStrength);
    return lightColor * NdotL;
}

///////////////////////////////////////////////////////////////////////////////
//                      Lighting Functions                                   //
///////////////////////////////////////////////////////////////////////////////
half3 LightingLambert(half3 lightColor, half3 lightDir, half3 normal,BRDFDataExt brdfDataExt)
{
    half NdotL = saturate(lerp(brdfDataExt.backBrightness, 1, dot(normal, lightDir) * 0.5 + 0.5));
    // half NdotL = saturate(dot(normal, lightDir));
    return lightColor * NdotL;
}

half3 LightingSpecular(half3 lightColor, half3 lightDir, half3 normal, half3 viewDir, half4 specular, half smoothness)
{
    float3 halfVec = SafeNormalize(float3(lightDir) + float3(viewDir));
    half NdotH = half(saturate(dot(normal, halfVec)));
    half modifier = pow(NdotH, smoothness);
    half3 specularReflection = specular.rgb * modifier;
    return lightColor * specularReflection;
}

half3 LightingPhysicallyBased(BRDFData brdfData, BRDFData brdfDataClearCoat,BRDFDataExt brdfDataExt,
    half3 lightColor, half3 lightDirectionWS, half lightAttenuation,
    half3 normalWS, half3 viewDirectionWS,
    half clearCoatMask, bool specularHighlightsOff)
{
    //half NdotL = saturate(dot(normalWS, lightDirectionWS));

    //M
#ifdef _LAMBERT_HALFLAMBERT
    half NdotL = saturate(lerp(brdfDataExt.backBrightness, 1, dot(normalWS, lightDirectionWS) * 0.5 + 0.5));
#else
    half NdotL = saturate(dot(normalWS, lightDirectionWS));
#endif

// #ifndef _ADDITIONAL_LIGHTS
//     lightAttenuation = lerp(1, lightAttenuation, brdfDataExt.shadowStrength);
// #endif
    
    //使用_ADDITIONAL_LIGHTS宏后导致开启点光源（pixel）后，场景的内容所有物件背影处都无法通过
    //brdfDataExt.shadowStrength提亮故此去掉此处的宏
    lightAttenuation = lerp(1, lightAttenuation, brdfDataExt.shadowStrength);
    
    half3 radiance = lightColor * (lightAttenuation * NdotL);

    half3 brdf = brdfData.diffuse;
#ifndef _SPECULARHIGHLIGHTS_OFF
    [branch] if (!specularHighlightsOff)
    {
        brdf += saturate(brdfData.specular * DirectBRDFSpecular(brdfData, normalWS, lightDirectionWS, viewDirectionWS));

#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
        // Clear coat evaluates the specular a second timw and has some common terms with the base specular.
        // We rely on the compiler to merge these and compute them only once.
        half brdfCoat = kDielectricSpec.r * DirectBRDFSpecular(brdfDataClearCoat, normalWS, lightDirectionWS, viewDirectionWS);

            // Mix clear coat and base layer using khronos glTF recommended formula
            // https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_clearcoat/README.md
            // Use NoV for direct too instead of LoH as an optimization (NoV is light invariant).
            half NoV = saturate(dot(normalWS, viewDirectionWS));
            // Use slightly simpler fresnelTerm (Pow4 vs Pow5) as a small optimization.
            // It is matching fresnel used in the GI/Env, so should produce a consistent clear coat blend (env vs. direct)
            half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * Pow4(1.0 - NoV);

        brdf = brdf * (1.0 - clearCoatMask * coatFresnel) + brdfCoat * clearCoatMask;
#endif // _CLEARCOAT
    }
#endif // _SPECULARHIGHLIGHTS_OFF

    return brdf * radiance;
}

//FOR M
half3 LightingPhysicallyBased(BRDFData brdfData, BRDFData brdfDataClearCoat,BRDFDataExt brdfDataExt, Light light, half3 normalWS, half3 viewDirectionWS, half clearCoatMask, bool specularHighlightsOff)
{
    return LightingPhysicallyBased(brdfData, brdfDataClearCoat, brdfDataExt,light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, clearCoatMask, specularHighlightsOff);
}

half3 LightingPhysicallyBased(BRDFData brdfData, BRDFData brdfDataClearCoat, Light light, half3 normalWS, half3 viewDirectionWS, half clearCoatMask, bool specularHighlightsOff)
{
    BRDFDataExt brdf_data_ext;
    brdf_data_ext.backBrightness = 0;
    brdf_data_ext.shadowStrength = 1;
    return LightingPhysicallyBased(brdfData, brdfDataClearCoat,brdf_data_ext, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, clearCoatMask, specularHighlightsOff);
}

// Backwards compatibility
half3 LightingPhysicallyBased(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS)
{
    #ifdef _SPECULARHIGHLIGHTS_OFF
    bool specularHighlightsOff = true;
#else
    bool specularHighlightsOff = false;
#endif
    const BRDFData noClearCoat = (BRDFData)0;
    return LightingPhysicallyBased(brdfData, noClearCoat, light, normalWS, viewDirectionWS, 0.0, specularHighlightsOff);
}

half3 LightingPhysicallyBased(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS)
{
    Light light;
    light.color = lightColor;
    light.direction = lightDirectionWS;
    light.distanceAttenuation = lightAttenuation;
    light.shadowAttenuation   = 1;
    return LightingPhysicallyBased(brdfData, light, normalWS, viewDirectionWS);
}

half3 LightingPhysicallyBased(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS, bool specularHighlightsOff)
{
    const BRDFData noClearCoat = (BRDFData)0;
    return LightingPhysicallyBased(brdfData, noClearCoat, light, normalWS, viewDirectionWS, 0.0, specularHighlightsOff);
}

half3 LightingPhysicallyBased(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, bool specularHighlightsOff)
{
    Light light;
    light.color = lightColor;
    light.direction = lightDirectionWS;
    light.distanceAttenuation = lightAttenuation;
    light.shadowAttenuation   = 1;
    return LightingPhysicallyBased(brdfData, light, viewDirectionWS, specularHighlightsOff, specularHighlightsOff);
}

//自定义的SurfaceData 适配
half3 DirectBRDF_Char(BRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS, half3 debugRadiance = 0)
{
#ifndef _SPECULARHIGHLIGHTS_OFF
    float3 halfDir = SafeNormalize(float3(lightDirectionWS) + float3(viewDirectionWS));

    float NoH = saturate(dot(normalWS, halfDir));
    half LoH = saturate(dot(lightDirectionWS, halfDir));

    // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // BRDFspec = (D * V * F) / 4.0
    // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
    // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
    // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
    // https://community.arm.com/events/1155

    // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
    // We further optimize a few light invariant terms
    // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);

    // On platforms where half actually means something, the denominator has a risk of overflow
    // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
    // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
#if defined (SHADER_API_MOBILE) || defined (SHADER_API_SWITCH)
    specularTerm = specularTerm - HALF_MIN;
    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
#endif

#ifdef LM_SSS
    return specularTerm * brdfData.specular;
#endif
    
    half3 color = specularTerm * brdfData.specular + brdfData.diffuse;
    return color;
    
#else
    #ifdef LM_SSS
        return 0;
    #endif
    
    return brdfData.diffuse;
#endif
}

half3 LightingPhysicallyBased_Char(BRDFData brdfData, BRDFDataChar brdfData_char, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS)
{
    #ifdef _LAMBERT_HALFLAMBERT
        half NdotL = saturate(lerp(brdfData_char.backBrightness, 1, dot(normalWS, lightDirectionWS) * 0.5 + 0.5));
    #else
        half NdotL = saturate(dot(normalWS, lightDirectionWS));
    #endif
    
    // #ifndef _ADDITIONAL_LIGHTS
    //     lightAttenuation = lerp(1, lightAttenuation, brdfData_char.shadowStrength);
    // #endif
    
    //lightAttenuation = lerp(1, lightAttenuation, brdfData_char.shadowStrength);
    half3 radiance = lightColor * (lightAttenuation * NdotL);
    #ifdef LM_SSS
        half3 sg = SGDiffuseLighting(normalWS, lightDirectionWS, brdfData_char.scatterAmount, brdfData_char.tonemapping, brdfData_char.curvature);
        half3 diffuse = brdfData.diffuse * lightColor * lightAttenuation * sg;
        half3 specular = DirectBRDF_Char(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
        return diffuse + specular;
    #else
        return DirectBRDF(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
    #endif
}

half3 LightingPhysicallyBased_Char(BRDFData brdfData, BRDFDataChar brdfData_char, Light light, half3 normalWS, half3 viewDirectionWS)
{
    return LightingPhysicallyBased_Char(brdfData, brdfData_char,light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS);
}

///end

half3 VertexLighting(float3 positionWS, half3 normalWS)
{
    half3 vertexLightColor = half3(0.0, 0.0, 0.0);

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        uint lightsCount = GetAdditionalLightsCount();
        LIGHT_LOOP_BEGIN(lightsCount)
            Light light = GetAdditionalLight(lightIndex, positionWS);
            half3 lightColor = light.color * light.distanceAttenuation;
            vertexLightColor += LightingLambert(lightColor, light.direction, normalWS,1);
        LIGHT_LOOP_END
    #endif

    return vertexLightColor;
}

struct LightingData
{
    half3 giColor;
    half3 mainLightColor;
    half3 additionalLightsColor;
    half3 vertexLightingColor;
    half3 emissionColor;
};

half3 CalculateLightingColor(LightingData lightingData, half3 albedo)
{
    half3 lightingColor = 0;

    if (IsOnlyAOLightingFeatureEnabled())
    {
        return lightingData.giColor; // Contains white + AO
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_GLOBAL_ILLUMINATION))
    {
        lightingColor += lightingData.giColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_MAIN_LIGHT))
    {
        lightingColor += lightingData.mainLightColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_ADDITIONAL_LIGHTS))
    {
        lightingColor += lightingData.additionalLightsColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_VERTEX_LIGHTING))
    {
        lightingColor += lightingData.vertexLightingColor;
    }

    lightingColor *= albedo;

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_EMISSION))
    {
        lightingColor += lightingData.emissionColor;
    }

    return lightingColor;
}

half4 CalculateFinalColor(LightingData lightingData, half alpha)
{
    half3 finalColor = CalculateLightingColor(lightingData, 1);

    return half4(finalColor, alpha);
}

half4 CalculateFinalColor(LightingData lightingData, half3 albedo, half alpha, float fogCoord)
{
    #if defined(_FOG_FRAGMENT)
        #if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
        float viewZ = -fogCoord;
        float nearToFarZ = max(viewZ - _ProjectionParams.y, 0);
        half fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
    #else
        half fogFactor = 0;
        #endif
    #else
    half fogFactor = fogCoord;
    #endif
    half3 lightingColor = CalculateLightingColor(lightingData, albedo);
    half3 finalColor = MixFog(lightingColor, fogFactor);

    return half4(finalColor, alpha);
}

LightingData CreateLightingData(InputData inputData, SurfaceData surfaceData)
{
    LightingData lightingData;

    lightingData.giColor = inputData.bakedGI;
    lightingData.emissionColor = surfaceData.emission;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    return lightingData;
}

LightingData CreateLightingDataChar(SurfaceData surfaceData,SurfaceDataChar surfaceData_Char)
{
    LightingData lightingData;

    lightingData.giColor = surfaceData_Char.envMultiplier;
    lightingData.emissionColor = surfaceData.emission;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    return lightingData;
}

half3 CalculateBlinnPhong(Light light, InputData inputData, SurfaceData surfaceData,BRDFDataExt brdfDataExt)
{
    half atten = lerp(1,light.distanceAttenuation * light.shadowAttenuation,brdfDataExt.shadowStrength);
    half3 attenuatedLightColor = light.color * atten;
    half3 lightDiffuseColor = LightingLambert(attenuatedLightColor, light.direction, inputData.normalWS,brdfDataExt);

    half3 lightSpecularColor = half3(0,0,0);
    //#if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
    half smoothness = exp2(10 * surfaceData.smoothness + 1);
    
    lightSpecularColor += LightingSpecular(attenuatedLightColor, light.direction, inputData.normalWS, inputData.viewDirectionWS, half4(surfaceData.specular, 1), smoothness);
    //#endif
    #if _ALPHAPREMULTIPLY_ON
        return lightDiffuseColor * surfaceData.albedo * surfaceData.alpha + lightSpecularColor;
    #else
        return lightDiffuseColor * surfaceData.albedo + lightSpecularColor;
    #endif
}

////////////////////////////////////////////////////////////////////////////////
/// Phong lighting...
////////////////////////////////////////////////////////////////////////////////
half4 UniversalFragmentBlinnPhong(InputData inputData, SurfaceData surfaceData,SurfaceDataExt surfaceDataExt)
{
    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, debugColor))
    {
        return debugColor;
    }
    #endif

    uint meshRenderingLayers = GetMeshRenderingLayer();
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    
    #ifdef _CLOUD_SHADOW
    half cloudShadow = CustomCloudShadow(inputData.positionWS);
    mainLight.color *= cloudShadow;
    #endif 
    
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, aoFactor);

    BRDFDataExt brdfDataExt;
    brdfDataExt.backBrightness = surfaceDataExt.backBrightness;
    brdfDataExt.shadowStrength = surfaceDataExt.shadowStrength;

    inputData.bakedGI *= surfaceData.albedo;
    
    LightingData lightingData = CreateLightingData(inputData, surfaceData);
    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
        lightingData.mainLightColor += CalculateBlinnPhong(mainLight, inputData, surfaceData,brdfDataExt);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();
    //附件光源强制执行shadowStrength为1的计算，否则在场景内点光源数量增加时灯光计算出现严重错误
    brdfDataExt.shadowStrength = 1;
    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
                lightingData.additionalLightsColor += CalculateBlinnPhong(light, inputData, surfaceData,brdfDataExt);
        }
    }
    
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            lightingData.additionalLightsColor += CalculateBlinnPhong(light, inputData, surfaceData,brdfDataExt);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * surfaceData.albedo;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}

half4 UniversalFragmentBlinnPhong_GI(InputData inputData, SurfaceData surfaceData,SurfaceDataExt surfaceDataExt)
{
     #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, debugColor))
    {
        return debugColor;
    }
    #endif

    uint meshRenderingLayers = GetMeshRenderingLayer();
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    #ifdef _CLOUD_SHADOW
    half cloudShadow = CustomCloudShadow(inputData.positionWS);
    mainLight.color *= cloudShadow;
    #endif
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, aoFactor);

    BRDFDataExt brdfDataExt;
    brdfDataExt.backBrightness = surfaceDataExt.backBrightness;
    brdfDataExt.shadowStrength = surfaceDataExt.shadowStrength;

    BRDFData brdfData;
    
    InitializeBRDFData(surfaceData, brdfData);
    
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);

    //inputData.bakedGI *= surfaceData.albedo;
    
    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
        lightingData.mainLightColor += CalculateBlinnPhong(mainLight, inputData, surfaceData,brdfDataExt);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();
    //附件光源强制执行shadowStrength为1的计算，否则在场景内点光源数量增加时灯光计算出现严重错误
    brdfDataExt.shadowStrength = 1;
    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
                lightingData.additionalLightsColor += CalculateBlinnPhong(light, inputData, surfaceData,brdfDataExt);
        }
    }
    
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            lightingData.additionalLightsColor += CalculateBlinnPhong(light, inputData, surfaceData,brdfDataExt);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * surfaceData.albedo;
    #endif

    return CalculateFinalColor(lightingData, surfaceData.alpha);
}

///////////////////////////////////////////////////////////////////////////////
//                      Fragment Functions                                   //
//       Used by ShaderGraph and others builtin renderers                    //
///////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// PBR lighting...
////////////////////////////////////////////////////////////////////////////////
half4 UniversalFragmentPBR(InputData inputData,inout SurfaceData surfaceData, SurfaceDataExt surfaceDataExt)
{
    #if defined(BLINNPHONGLIGHT_ON)
        return UniversalFragmentBlinnPhong(inputData,surfaceData,surfaceDataExt);
    #endif
    
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;

    BRDFDataExt brdfDataExt;
    brdfDataExt.backBrightness = surfaceDataExt.backBrightness;
    brdfDataExt.shadowStrength = surfaceDataExt.shadowStrength;
    // NOTE: can modify "surfaceData"...
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    #ifdef _CLOUD_SHADOW
    half cloudShadow = CustomCloudShadow(inputData.positionWS);
    mainLight.color *= cloudShadow;
    #endif  
    
    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
    lightingData.giColor = saturate(lightingData.giColor);
    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
        lightingData.mainLightColor = LightingPhysicallyBased(brdfData, brdfDataClearCoat,brdfDataExt,
                                                              mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff);
    }
    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    //主光源计算完毕，后面的额外光计算时shadowStrength必须为1否则亮度会爆的
    brdfDataExt.shadowStrength = 1.0;

    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
                lightingData.additionalLightsColor += CalculateBlinnPhong(light,inputData,surfaceData,brdfDataExt);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif
    
    #if REAL_IS_HALF
        // Clamp any half.inf+ to HALF_MAX
        return min(CalculateFinalColor(lightingData, surfaceData.alpha), HALF_MAX);
    #else
        return CalculateFinalColor(lightingData, surfaceData.alpha);
    #endif
}

half4 UniversalFragmentPBR(InputData inputData,inout SurfaceData surfaceData, SurfaceDataExt surfaceDataExt,out LightingData lightingData)
{
    #if defined(BLINNPHONGLIGHT_ON)
        lightingData = CreateLightingData(inputData, surfaceData);
        return UniversalFragmentBlinnPhong(inputData,surfaceData,surfaceDataExt);
    #endif
    
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;

    BRDFDataExt brdfDataExt;
    brdfDataExt.backBrightness = surfaceDataExt.backBrightness;
    brdfDataExt.shadowStrength = surfaceDataExt.shadowStrength;
    // NOTE: can modify "surfaceData"...
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    #ifdef _CLOUD_SHADOW
    half cloudShadow = CustomCloudShadow(inputData.positionWS);
    mainLight.color *= cloudShadow;
    #endif  

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    lightingData = CreateLightingData(inputData, surfaceData);

    lightingData.giColor = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
    lightingData.giColor = saturate(lightingData.giColor);
    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        #endif
    {
        lightingData.mainLightColor = LightingPhysicallyBased(brdfData, brdfDataClearCoat,brdfDataExt,
                                                              mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff);
    }
    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

        #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
        #endif
    {
        lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
                                                                      inputData.normalWS, inputData.viewDirectionWS,
                                                                      surfaceData.clearCoatMask, specularHighlightsOff);
    }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif
    #if REAL_IS_HALF
    // Clamp any half.inf+ to HALF_MAX
    return min(CalculateFinalColor(lightingData, surfaceData.alpha), HALF_MAX);
    #else
    return CalculateFinalColor(lightingData, surfaceData.alpha);
    #endif
}

// Deprecated: Use the version which takes "SurfaceData" instead of passing all of these arguments...
half4 UniversalFragmentPBR(InputData inputData, half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha)
{
    SurfaceData surfaceData;

    surfaceData.albedo = albedo;
    surfaceData.specular = specular;
    surfaceData.metallic = metallic;
    surfaceData.smoothness = smoothness;
    surfaceData.normalTS = half3(0, 0, 1);
    surfaceData.emission = emission;
    surfaceData.occlusion = occlusion;
    surfaceData.alpha = alpha;
    surfaceData.clearCoatMask = 0;
    surfaceData.clearCoatSmoothness = 1;

    SurfaceDataExt surface_data_ext;
    surface_data_ext.backBrightness = 0;
    surface_data_ext.shadowStrength = 1;
    return UniversalFragmentPBR(inputData, surfaceData , surface_data_ext);
}



// Deprecated: Use the version which takes "SurfaceData" instead of passing all of these arguments...
half4 UniversalFragmentBlinnPhong(InputData inputData, half3 diffuse, half4 specularGloss, half smoothness, half3 emission, half alpha, half3 normalTS)
{
    SurfaceData surfaceData;

    surfaceData.albedo = diffuse;
    surfaceData.alpha = alpha;
    surfaceData.emission = emission;
    surfaceData.metallic = 0;
    surfaceData.occlusion = 1;
    surfaceData.smoothness = smoothness;
    surfaceData.specular = specularGloss.rgb;
    surfaceData.clearCoatMask = 0;
    surfaceData.clearCoatSmoothness = 1;
    surfaceData.normalTS = normalTS;

    SurfaceDataExt surfaceDataExt;
    surfaceDataExt.backBrightness = 0;
    surfaceDataExt.shadowStrength = 1;

    return UniversalFragmentBlinnPhong(inputData, surfaceData,surfaceDataExt);
}

////////////////////////////////////////////////////////////////////////////////
/// Unlit
////////////////////////////////////////////////////////////////////////////////
half4 UniversalFragmentBakedLit(InputData inputData, SurfaceData surfaceData)
{
    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, debugColor))
    {
        return debugColor;
    }
    #endif

    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_AMBIENT_OCCLUSION))
    {
        lightingData.giColor *= aoFactor.indirectAmbientOcclusion;
    }

    return CalculateFinalColor(lightingData, surfaceData.albedo, surfaceData.alpha, inputData.fogCoord);
}

// Deprecated: Use the version which takes "SurfaceData" instead of passing all of these arguments...
half4 UniversalFragmentPBR_Char(InputData inputData, SurfaceData surfaceData, SurfaceDataChar surfacedata_char,float _SSSStrength)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;

    BRDFDataChar brdfData_char;
    InitBRDFDataChar(surfacedata_char, brdfData_char);
    // NOTE: can modify "surfaceData"...
    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    #ifdef _CLOUD_SHADOW
    half cloudShadow = CustomCloudShadow(inputData.positionWS);
    mainLight.color *= cloudShadow;
    #endif  
    
    #if _UI_ON
    //     float3 projCoords = (inputData.shadowCoord.xyz / inputData.shadowCoord.w) * 0.5 + 0.5;
    //     float2 shadowuv;
    // #if UNITY_UV_STARTS_AT_TOP
    //     shadowuv = float2(projCoords.x,1.0 - projCoords.y);
    // #else
    //     shadowuv = float2(projCoords.x,projCoords.y);
    // #endif
    //     float closeDepth = SAMPLE_TEXTURE2D(_PlayerShadowTexture,sampler_PlayerShadowTexture,shadowuv).r;
    //     float bias = max(_HightPlayerShadow_NormalBias * (1.0 - dot(normalize(inputData.normalWS),_CharacterLightDirectionWS.xyz)),0.005);
    //     float currentDepth = 0;
    // #if UNITY_UV_STARTS_AT_TOP
    //     currentDepth = (inputData.shadowCoord.xyz / inputData.shadowCoord.w).z;
    //     closeDepth = saturate(closeDepth - bias);
    // #else
    //     currentDepth = projCoords.z;
    //     closeDepth = saturate(closeDepth + bias);
    // #endif
    //
    // #if UNITY_UV_STARTS_AT_TOP
    //     mainLight.shadowAttenuation = currentDepth >= closeDepth ? 1.0 : 0.0;
    // #else
    //     mainLight.shadowAttenuation = currentDepth > closeDepth ? 0.0 : 1.0;
    // #endif
        //mainLight.shadowAttenuation = HightPlayerShadow(inputData.shadowCoord) > currentDepth ? 1.0 : 0.0;
    mainLight.shadowAttenuation = CustomHighQualityShadow(inputData.shadowCoord,inputData.normalWS);
    mainLight.shadowAttenuation = step(0.99,mainLight.shadowAttenuation);
    #endif
    
    mainLight.color = lerp(mainLight.color,1,0.3);
    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    // //自定义环境色
    // half upMaskWS = inputData.normalWS.y-0.5;
    // half downMaskWS = -inputData.normalWS.y;
    // half4 envSkyColor = surfacedata_char.envSkyColor * upMaskWS;
    // half4 envEquatorColor = surfacedata_char.envEquatorColor;
    // half4 envGroundColor = surfacedata_char.envGroundColor * downMaskWS;

    // inputData.bakedGI = envSkyColor + envEquatorColor + envGroundColor;
    // inputData.bakedGI = half3(0.4,0.4,0.4);//envEquatorColor;
    
    inputData.bakedGI = lerp(inputData.bakedGI,surfaceData.albedo,0.5);//envEquatorColor;
    lightingData.giColor = GlobalIllumination_Char(brdfData,brdfData_char, brdfDataClearCoat, surfaceData.clearCoatMask,
                                                   inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                                   inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
    
    half envMultiplier = surfacedata_char.envMultiplier;
    half shadowMultiplier = lerp(surfacedata_char.giIntensityInShadow, 1, mainLight.shadowAttenuation);
    lightingData.giColor = saturate(lightingData.giColor * shadowMultiplier * envMultiplier);

    mainLight.shadowAttenuation = lerp(1,mainLight.shadowAttenuation,surfacedata_char.shadowStrength);

    // M_Light backLight = M_GetMainLight(surfacedata_char.backLightDirection.xyz,shadowMask);
    // Light backLight = M_GetMainLight(inputData.viewDirectionWS,inputData, shadowMask, aoFactor);
    // backLight.color *=  surfacedata_char.backLiwghtIntensity;
    //brdfData_char.scatterAmount = lightingData.giColor;
    #ifdef LM_SSS
    lightingData.giColor += saturate( _SSSStrength * SampleSH(-inputData.normalWS) * surfaceData.albedo * aoFactor.indirectAmbientOcclusion * surfacedata_char.scatterAmount);
    #endif
    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
        lightingData.mainLightColor = LightingPhysicallyBased_Char(brdfData, brdfData_char, mainLight,inputData.normalWS, inputData.viewDirectionWS);
    }
    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_Char(brdfData,brdfData_char, light,inputData.normalWS, inputData.viewDirectionWS) * 0.3;
        }
    }
    #endif
    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            // lightingData.additionalLightsColor += LightingPhysicallyBased_Char(brdfData, light,inputData.normalWS, inputData.viewDirectionWS);
            //lightingData.additionalLightsColor += LightingPhysicallyBased_Char(brdfData, brdfData_char, mainLight,inputData.normalWS, inputData.viewDirectionWS);
            lightingData.additionalLightsColor += LightingPhysicallyBased_Char(brdfData, brdfData_char, light,inputData.normalWS, inputData.viewDirectionWS) * 0.3;
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse * 0.3;
    #endif

    // //角色自带背面点光源
    // uint pixelLightCount = GetAdditionalLightsCount();
    // LIGHT_LOOP_BEGIN(pixelLightCount)
    //     Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
    // #endif
    //
    // lightingData.additionalLightsColor += LightingPhysicallyBased_Char(brdfData,brdfData_char, light.color,
    //                                                           inputData.normalWS, inputData.viewDirectionWS,
    //                                                           surfaceData.clearCoatMask, specularHighlightsOff);

    #if REAL_IS_HALF
    // Clamp any half.inf+ to HALF_MAX
    return min(CalculateFinalColor(lightingData, surfaceData.alpha), HALF_MAX);
    #else
    return CalculateFinalColor(lightingData, surfaceData.alpha);
    #endif
}


half4 UniversalFragmentBakedLit(InputData inputData, half3 color, half alpha, half3 normalTS)
{
    SurfaceData surfaceData;

    surfaceData.albedo = color;
    surfaceData.alpha = alpha;
    surfaceData.emission = half3(0, 0, 0);
    surfaceData.metallic = 0;
    surfaceData.occlusion = 1;
    surfaceData.smoothness = 1;
    surfaceData.specular = half3(0, 0, 0);
    surfaceData.clearCoatMask = 0;
    surfaceData.clearCoatSmoothness = 1;
    surfaceData.normalTS = normalTS;

    return UniversalFragmentBakedLit(inputData, surfaceData);
}


#endif

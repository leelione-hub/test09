#ifndef VG_BRDF_INCLUDED
#define VG_BRDF_INCLUDED

half3 GlossyEnvironmentReflection_Char(BRDFDataChar brdfData_char,half3 reflectVector, float3 positionWS, half perceptualRoughness, half occlusion, float2 normalizedScreenSpaceUV)
{
    #if !defined(_ENVIRONMENTREFLECTIONS_OFF)
    half3 irradiance;

    #if defined(_REFLECTION_PROBE_BLENDING) || USE_FORWARD_PLUS
    irradiance = CalculateIrradianceFromReflectionProbes(reflectVector, positionWS, perceptualRoughness, normalizedScreenSpaceUV);
    #else
    #ifdef _REFLECTION_PROBE_BOX_PROJECTION
    reflectVector = BoxProjectedCubemapDirection(reflectVector, positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
    #endif // _REFLECTION_PROBE_BOX_PROJECTION
    // half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
    half4 encodedIrradiance = brdfData_char.charEnvColor;//half4(SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip));

    irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
    #endif // _REFLECTION_PROBE_BLENDING
    return irradiance * occlusion;
    #else
    return _GlossyEnvironmentColor.rgb * occlusion;
    #endif // _ENVIRONMENTREFLECTIONS_OFF
}

#endif

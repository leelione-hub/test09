#ifndef CUSTOM_NPR_DEPTH_ONLY_PASS_INCLUDED
#define CUSTOM_NPR_DEPTH_ONLY_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct CustomNPRDepthOnlyAttributes
{
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct CustomNPRDepthOnlyVaryings
{
    float4 positionCS : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

CustomNPRDepthOnlyVaryings CustomNPRDepthOnlyVertex(CustomNPRDepthOnlyAttributes input)
{
    CustomNPRDepthOnlyVaryings output = (CustomNPRDepthOnlyVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    return output;
}

half CustomNPRDepthOnlyFragment(CustomNPRDepthOnlyVaryings input) : SV_TARGET
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

#if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
#endif

    return input.positionCS.z;
}

#endif

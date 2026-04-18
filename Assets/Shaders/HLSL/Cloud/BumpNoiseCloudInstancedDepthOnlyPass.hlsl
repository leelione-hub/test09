#ifndef BUMP_NOISE_CLOUD_INSTANCED_DEPTH_ONLY_PASS_INCLUDED
#define BUMP_NOISE_CLOUD_INSTANCED_DEPTH_ONLY_PASS_INCLUDED

#include "Assets/Shaders/HLSL/Cloud/BumpNoiseCloudInstancedInput.hlsl"

struct CloudDepthVaryings
{
    float4 positionCS : SV_POSITION;
    float3 normalizedPositionOS : TEXCOORD0;
    float layerClip : TEXCOORD1;
    float distanceFade : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

CloudDepthVaryings DepthOnlyVertex(Attributes input)
{
    CloudDepthVaryings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    CloudShellData shellData = BuildCloudShellData(input);
    output.normalizedPositionOS = shellData.normalizedPositionOS;
    output.layerClip = shellData.layerClip;
    output.distanceFade = shellData.distanceFade;
    output.positionCS = TransformWorldToHClip(shellData.positionWS);
    return output;
}

half DepthOnlyFragment(CloudDepthVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    #if !defined(_PREPASS_CUTOUT_ON)
    clip(-1);
    #endif

    float noise;
    float density = ComputeCloudDensity(input.normalizedPositionOS, input.layerClip, input.distanceFade, noise);
    ClipCloudShell(density, input.positionCS);
    float alpha = ComputeCloudShellAlpha(density, input.layerClip);
    clip(alpha - _PrepassThreshold);
    return input.positionCS.z;
}

#endif

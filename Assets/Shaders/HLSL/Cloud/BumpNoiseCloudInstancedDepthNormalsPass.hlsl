#ifndef BUMP_NOISE_CLOUD_INSTANCED_DEPTH_NORMALS_PASS_INCLUDED
#define BUMP_NOISE_CLOUD_INSTANCED_DEPTH_NORMALS_PASS_INCLUDED

#include "Assets/Shaders/HLSL/Cloud/BumpNoiseCloudInstancedInput.hlsl"

struct CloudDepthNormalsVaryings
{
    float4 positionCS : SV_POSITION;
    float3 normalWS : TEXCOORD0;
    float3 normalizedPositionOS : TEXCOORD1;
    float layerClip : TEXCOORD2;
    float distanceFade : TEXCOORD3;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

CloudDepthNormalsVaryings DepthNormalsVertex(Attributes input)
{
    CloudDepthNormalsVaryings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    CloudShellData shellData = BuildCloudShellData(input);
    output.normalWS = shellData.normalWS;
    output.normalizedPositionOS = shellData.normalizedPositionOS;
    output.layerClip = shellData.layerClip;
    output.distanceFade = shellData.distanceFade;
    output.positionCS = TransformWorldToHClip(shellData.positionWS);
    return output;
}

half4 DepthNormalsFragment(CloudDepthNormalsVaryings input) : SV_Target
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

    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
        return half4(packedNormalWS, 0.0);
    #else
        return half4(NormalizeNormalPerPixel(input.normalWS), 0.0);
    #endif
}

#endif

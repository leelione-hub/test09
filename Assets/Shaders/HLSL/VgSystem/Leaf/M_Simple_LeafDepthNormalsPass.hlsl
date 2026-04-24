#ifndef VG_M_SIMPLE_LEAF_DEPTH_NORMALS_PASS_INCLUDED
#define VG_M_SIMPLE_LEAF_DEPTH_NORMALS_PASS_INCLUDED

#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct DepthNormalsVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    half3 normalWS : TEXCOORD1;
};

DepthNormalsVaryings DepthNormalsVertex(Attributes input)
{
    DepthNormalsVaryings output = (DepthNormalsVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    ApplyMSimpleLeafWind(input);
    float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));
    return output;
}

half4 DepthNormalsFragment(DepthNormalsVaryings input) : SV_Target
{
    #if defined(_ALPHATEST_ON)
    clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a * _Alpha - _Cutoff);
    #endif
    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif
    return half4(normalize(input.normalWS), 0);
}

#endif

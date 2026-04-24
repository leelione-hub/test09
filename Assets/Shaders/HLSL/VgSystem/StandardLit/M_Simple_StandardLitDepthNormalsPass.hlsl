#ifndef VG_M_SIMPLE_STANDARD_LIT_DEPTH_NORMALS_PASS_INCLUDED
#define VG_M_SIMPLE_STANDARD_LIT_DEPTH_NORMALS_PASS_INCLUDED

#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct DepthNormalsVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    half3 normalWS : TEXCOORD1;
    float4 tangentWS : TEXCOORD2;
};

DepthNormalsVaryings DepthNormalsVertex(Attributes input)
{
    DepthNormalsVaryings output = (DepthNormalsVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));
    output.tangentWS = float4(normalize(GetInstanceWorldDirection(input.tangentOS.xyz, input.instanceID)), input.tangentOS.w);
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
    half3 normalWS = normalize(input.normalWS);
    #if defined(_NRM_ON)
    float sgn = input.tangentWS.w;
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(GetNRM_Normal(SAMPLE_TEXTURE2D(_NRMTex, sampler_NRMTex, input.uv), _BumpScale), tangentToWorld));
    #endif
    return half4(normalWS, 0);
}

#endif

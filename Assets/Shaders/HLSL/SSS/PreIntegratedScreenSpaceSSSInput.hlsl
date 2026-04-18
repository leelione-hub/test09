#ifndef PREINTEGRATED_SCREEN_SPACE_SSS_INPUT_INCLUDED
#define PREINTEGRATED_SCREEN_SPACE_SSS_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

CBUFFER_START(UnityPerMaterial)
    float4 _BaseColor;
    float4 _BaseMap_ST;
    float4 _SSSColor;
    float4 _TransmissionColor;
    float4 _WrapSSSColor;
    float4 _EmissionColor;
    float _Cutoff;
    float _Smoothness;
    float _SpecularStrength;
    float _NormalScale;
    float _PreIntegratedSSSIntensity;
    float _ThicknessScale;
    float _CurvatureScale;
    float _TransmissionIntensity;
    float _TransmissionPower;
    float _AmbientIntensity;
    float _WrapLighting;
    float _WrapSSSIntensity;
    float _WrapThicknessTransmission;
    float _WrapThicknessPower;
    float _ScreenSpaceSSSIntensity;
    float _ScreenSpaceSSSBlurScale;
    float _ScreenSpaceSSSDepthWeight;
    float _EmissionIntensity;
CBUFFER_END

TEXTURE2D(_BaseMap);             SAMPLER(sampler_BaseMap);
TEXTURE2D(_NormalMap);           SAMPLER(sampler_NormalMap);
TEXTURE2D(_ThicknessMap);        SAMPLER(sampler_ThicknessMap);
TEXTURE2D(_SSSLUT);              SAMPLER(sampler_SSSLUT);

float3 _LightDirection;
float3 _LightPosition;

struct SSSAttributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct SSSVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float4 tangentWS : TEXCOORD3;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct SSSSurfaceData
{
    half3 albedo;
    half alpha;
    half3 normalTS;
    half thickness;
};

inline half4 SSSSampleBase(float2 uv)
{
    return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
}

inline half3 SSSSampleNormalTS(float2 uv)
{
    #if defined(_NORMALMAP)
    return UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv), _NormalScale);
    #else
    return half3(0, 0, 1);
    #endif
}

inline half SSSSampleThickness(float2 uv)
{
    return SAMPLE_TEXTURE2D(_ThicknessMap, sampler_ThicknessMap, uv).r;
}

inline SSSVaryings BuildSSSVaryings(SSSAttributes input)
{
    SSSVaryings output = (SSSVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS);
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionCS = positionInputs.positionCS;
    output.positionWS = positionInputs.positionWS;
    output.normalWS = normalInputs.normalWS;
    output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    return output;
}

inline half3 SSSGetNormalWS(SSSVaryings input, half3 normalTS)
{
    float sign = input.tangentWS.w * GetOddNegativeScale();
    float3 bitangent = sign * cross(input.normalWS, input.tangentWS.xyz);
    float3x3 tbn = float3x3(input.tangentWS.xyz, bitangent, input.normalWS);
    return normalize(TransformTangentToWorld(normalTS, tbn));
}

inline void InitializeSSSSurfaceData(float2 uv, out SSSSurfaceData surfaceData)
{
    half4 baseSample = SSSSampleBase(uv);
    surfaceData.albedo = baseSample.rgb * _BaseColor.rgb;
    surfaceData.alpha = baseSample.a * _BaseColor.a;
    surfaceData.normalTS = SSSSampleNormalTS(uv);
    surfaceData.thickness = SSSSampleThickness(uv) * _ThicknessScale;
}

#endif

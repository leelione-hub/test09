#ifndef PLANT_DEPTH_NORMALS_PASS_INCLUDED
#define PLANT_DEPTH_NORMALS_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

struct Attributes
{
    float4 positionOS   : POSITION;
    float2 uv           : TEXCOORD0;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float4 color        : COLOR;
    uint instanceID     : SV_InstanceID;
};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    float2 uv           : TEXCOORD0;
    half3 normalWS      : TEXCOORD1;

    #if defined(_NORMALMAP)
    half4 tangentWS     : TEXCOORD2;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

inline void ApplyPlantDepthNormalsAnimation(inout Attributes input)
{
    #if defined(_WIND_ON)
    WindStruct windData;
    windData.windSpeed = _WindSpeed;
    windData.vertexColor = input.color;
    windData.leafStrength = _LeafStrength;
    windData.normalOS = input.normalOS;
    windData.positionOS = input.positionOS.xyz;
    windData.bendStrength = _BendStrength;
    windData.bendSpeed = _BendSpeed;
    windData.bendWait = _BendWait;
    windData.windDirection = _WindDirection.xy;
    windData.instanceID = input.instanceID;
    input.positionOS.xyz += PlantWind(windData);
    #endif

    #if defined(_CIRCE_WIND_ON)
    NewWindStruct circleWind;
    circleWind.windDirection = _CirceWindDirection.xy;
    circleWind.windSpeed = _CirceWindSpeed;
    circleWind.windJitter = _WindJitter;
    circleWind.windStrength = _WindStrength;
    circleWind.instanceID = input.instanceID;
    input.positionOS.xyz += input.normalOS * GetWindScroll(circleWind, input.positionOS, _WindNoiseSize, _NoisePower);
    #endif

    input.positionOS.xyz += PlantInteractionOffset(input.positionOS.xyz) * input.positionOS.y;
}

Varyings DepthNormalsVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    ApplyPlantDepthNormalsAnimation(input);

    float3 worldPos = GetInstanceWorldPosition(input.positionOS.xyz, input.instanceID);
    output.positionCS = TransformWorldToHClip(worldPos);
    output.uv = TRANSFORM_TEX(input.uv, _MainTex);

    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    output.normalWS = half3(normalInput.normalWS);

    #if defined(_NORMALMAP)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif

    return output;
}

void DepthNormalsFragment(Varyings input, out half4 outNormalWS : SV_Target0)
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    #if defined(_ALPHATEST_ON)
    half alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).a;
    clip(alpha - _Cutoff);
    #endif

    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif

    #if defined(_GBUFFER_NORMALS_OCT)
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
        outNormalWS = half4(packedNormalWS, 0.0);
    #else
        #if defined(_NORMALMAP)
            half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NRMTex, sampler_NRMTex, input.uv));
            half sgn = input.tangentWS.w;
            half3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            half3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS));
        #else
            half3 normalWS = input.normalWS;
        #endif

        outNormalWS = half4(NormalizeNormalPerPixel(normalWS), 0.0);
    #endif
}

#endif

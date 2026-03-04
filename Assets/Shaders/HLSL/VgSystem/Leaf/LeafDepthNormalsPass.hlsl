#ifndef LEAF_DEPTH_NORMALS_PASS_INCLUDED
#define LEAF_DEPTH_NORMALS_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

// 包含植被系统的实例化数据
#include "../../VgSystem/VgVertexInput.hlsl"
#include "../../VgSystem/VgVertexWind.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float2 uv           : TEXCOORD0;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float4 color        : COLOR;
    uint instanceID     : SV_InstanceID;
    UNITY_VERTEX_INPUT_INSTANCE_ID
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

#if defined(_NORMALMAP)
TEXTURE2D(_BumpMap);
SAMPLER(sampler_BumpMap);
#endif

Varyings DepthNormalsVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
    // 应用风动效果
    WindStruct wind_data;
    wind_data.windSpeed = _WindSpeed;
    wind_data.vertexColor = input.color;
    wind_data.leafStrength = _LeafStrength;
    wind_data.normalOS = input.normalOS;
    wind_data.positionOS = input.positionOS.xyz;
    wind_data.bendStrength = _BendStrength;
    wind_data.bendSpeed = _BendSpeed;
    wind_data.bendWait = _BendWait;
    wind_data.windDirection = _WindDirection.xy;
    
    half3 wind = PlantWind(wind_data);
    input.positionOS.xyz += wind;
    
    // 获取实例化的世界位置
    float3 worldPos = GetInstanceWorldPosition(input.positionOS.xyz, input.instanceID);
    
    output.positionCS = TransformWorldToHClip(worldPos);
    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
    
    // 计算世界空间法线（使用风动后的位置重新计算法线）
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    output.normalWS = half3(normalInput.normalWS);
    
    #if defined(_NORMALMAP)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif
    
    return output;
}

void DepthNormalsFragment(
    Varyings input
    , out half4 outNormalWS : SV_Target0
)
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    
    // Alpha Test
    #if defined(_ALPHATEST_ON)
    half alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).a;
    clip(alpha - _Cutoff);
    #endif
    
    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif
    
    // 输出法线
    #if defined(_GBUFFER_NORMALS_OCT)
        // 使用 Octahedron 编码（用于 GBuffer）
        float3 normalWS = normalize(input.normalWS);
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
        half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
        outNormalWS = half4(packedNormalWS, 0.0);
    #else
        #if defined(_NORMALMAP)
            // 使用法线贴图
            half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv));
            half sgn = input.tangentWS.w;
            half3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            half3 normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS));
        #else
            // 使用顶点法线
            half3 normalWS = input.normalWS;
        #endif
        
        outNormalWS = half4(NormalizeNormalPerPixel(normalWS), 0.0);
    #endif
}

#endif // LEAF_DEPTH_NORMALS_PASS_INCLUDED

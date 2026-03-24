#ifndef VG_STANDARD_LIT_INPUT_INCLUDED
#define VG_STANDARD_LIT_INPUT_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/SurfaceInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Custom/BlendTerrain.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

CBUFFER_START(UnityPerMaterial)
    float4 _BaseColor;
    float4 _BaseMap_ST;
    float4 _MossTex_ST;
    float4 _OverlayTex_ST;
    float4 _OverlayMask_ST;
    float4 _EmissionColor;
    float4 _AOColor;
    float4 _OverlayColor1;
    float4 _OverlayColor2;
    float4 _OverlayColor3;
    float4 _SimpleTerrainColor;
    float _Cutoff;
    float _Metallic;
    float _Roughness;
    float _Alpha;
    float _BumpScale;
    float _RoughnessMin;
    float _EmissiveIntensity;
    float _AOIntensity;
    float _AOLevels;
    float _OverlayRoughness;
    float _MossHeightMax;
    float _MossHeightMin;
    float _HightIntensity;
    float _BlendScale;
    float _BlendIntensity;
    float _MossNRMIntensity;
    float _BackBrightness;
    float _ShadowStrength;
    float _AOStrength;
    float _CorssFade;
CBUFFER_END

TEXTURE2D(_BaseMap);          SAMPLER(sampler_BaseMap);
TEXTURE2D(_NRMTex);           SAMPLER(sampler_NRMTex);
TEXTURE2D(_EmissionMap);      SAMPLER(sampler_EmissionMap);
TEXTURE2D(_AOTex);            SAMPLER(sampler_AOTex);
TEXTURE2D(_OverlayTex);       SAMPLER(sampler_OverlayTex);
TEXTURE2D(_OverlayMask);      SAMPLER(sampler_OverlayMask);
TEXTURE2D(_MossTex);          SAMPLER(sampler_MossTex);
TEXTURE2D(_MossNRM);          SAMPLER(sampler_MossNRM);
TEXTURE2D(_MossHeightTex);    SAMPLER(sampler_MossHeightTex);

float3 _LightDirection;
float3 _LightPosition;

struct StandardLitAttributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv2 : TEXCOORD1;
    float4 color : COLOR;
    uint instanceID : SV_InstanceID;
};

struct StandardLitVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 uv2 : TEXCOORD1;
    float3 positionWS : TEXCOORD2;
    float3 normalWS : TEXCOORD3;
    float4 tangentWS : TEXCOORD4;
    float4 color : COLOR;
    float4 screenPos : TEXCOORD5;
    float2 overlayUV : TEXCOORD6;
    float3 objectScale : TEXCOORD7;
};

inline half VgStandardDiffuseTerm(half3 normalWS, half3 lightDirWS)
{
    half ndl = dot(normalWS, lightDirWS);
    #if defined(_LAMBERT_HALFLAMBERT)
    return saturate(ndl * 0.5h + 0.5h);
    #else
    return saturate(ndl);
    #endif
}

inline half3 VgStandardSpecularTerm(half3 normalWS, half3 lightDirWS, half3 viewDirWS, half3 lightColor, half roughness)
{
    #if defined(_SPECULARHIGHLIGHTS)
    half3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
    half ndh = saturate(dot(normalWS, halfDir));
    half exponent = lerp(64.0h, 4.0h, saturate(roughness));
    return lightColor * pow(ndh, exponent);
    #else
    return 0;
    #endif
}

inline half3 VgStandardEnvironmentReflection(half3 normalWS, half3 viewDirWS, float3 positionWS, float2 normalizedScreenSpaceUV, half roughness)
{
    #if defined(_ENVIRONMENTREFLECTIONS)
    half3 reflectVector = reflect(-viewDirWS, normalWS);
    return GlossyEnvironmentReflection(reflectVector, positionWS, saturate(roughness), 1.0h, normalizedScreenSpaceUV);
    #else
    return 0;
    #endif
}

inline float2 VgApplyClassicRoofUV(float2 uv, float4 color, float3 objectScale)
{
    #if defined(_CLASSIC_ROOF_ON)
    half3 vertexColor = color.rgb;
    half3 scaleSq = objectScale * objectScale;
    half scaleFactor = sqrt(0.5h);
    if (vertexColor.r > max(vertexColor.g, vertexColor.b))
    {
        uv.y *= SafeSqrt(scaleSq.x + scaleSq.y) * scaleFactor;
    }
    else if (vertexColor.g > vertexColor.b)
    {
        uv.y *= SafeSqrt(scaleSq.x + scaleSq.z) * scaleFactor;
    }
    else
    {
        uv.y *= SafeSqrt(scaleSq.y + scaleSq.z) * scaleFactor;
    }
    #endif
    return uv;
}

inline half4 VgSampleBase(float2 uv)
{
    return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
}

inline half3 VgSampleNormalTS(float2 uv)
{
    #if defined(_NRM_ON)
    return UnpackNormalScale(SAMPLE_TEXTURE2D(_NRMTex, sampler_NRMTex, uv), _BumpScale);
    #else
    return half3(0, 0, 1);
    #endif
}

inline half VgSampleAO(float2 uv, inout half3 albedo)
{
    half ao = 1.0h;
    #if defined(_AO_ON)
    half sampleAO = SAMPLE_TEXTURE2D(_AOTex, sampler_AOTex, uv).r;
    ao = lerp(1.0h, pow(saturate(sampleAO), max(_AOLevels, 0.01h)), saturate(_AOIntensity));
    albedo = lerp(albedo, albedo * _AOColor.rgb, saturate(1.0h - ao));
    #endif
    return ao;
}

inline void VgApplyOverlay(float2 uv, inout half3 albedo, inout half roughness)
{
    #if defined(_OVERLAYTEX_ON)
    half4 overlayTex = SAMPLE_TEXTURE2D(_OverlayTex, sampler_OverlayTex, uv);
    half4 overlayMask = SAMPLE_TEXTURE2D(_OverlayMask, sampler_OverlayMask, uv);
    half3 overlayTint = overlayMask.r * _OverlayColor1.rgb + overlayMask.g * _OverlayColor2.rgb + overlayMask.b * _OverlayColor3.rgb;
    half overlayWeight = saturate(max(max(overlayMask.r, overlayMask.g), overlayMask.b) * overlayTex.a);
    albedo = lerp(albedo, overlayTex.rgb * max(overlayTint, half3(1, 1, 1)), overlayWeight);
    roughness = lerp(roughness, saturate(_OverlayRoughness), overlayWeight);
    #endif
}

inline half VgComputeMossMask(StandardLitVaryings input)
{
    half mask = saturate(input.color.g * _BlendIntensity);
    #if defined(_MOSS_HEIGHTTEX_ON)
    half height = SAMPLE_TEXTURE2D(_MossHeightTex, sampler_MossHeightTex, TRANSFORM_TEX(input.uv, _MossTex)).r;
    mask *= smoothstep(_MossHeightMin, _MossHeightMax, height);
    #endif
    mask *= saturate(input.normalWS.y * _HightIntensity);
    return saturate(mask);
}

inline void VgApplyVertexPaint(StandardLitVaryings input, float2 uv, inout half3 albedo, inout half3 normalTS, inout half roughness)
{
    #if defined(_VERTEX_PAINT_ON)
    half mossMask = VgComputeMossMask(input);
    half4 mossColor = SAMPLE_TEXTURE2D(_MossTex, sampler_MossTex, TRANSFORM_TEX(uv, _MossTex));
    half3 mossNormal = UnpackNormalScale(SAMPLE_TEXTURE2D(_MossNRM, sampler_MossNRM, uv), _MossNRMIntensity);
    albedo = lerp(albedo, mossColor.rgb, mossMask);
    normalTS = normalize(lerp(normalTS, mossNormal, mossMask));
    roughness = lerp(roughness, saturate(_RoughnessMin), mossMask);
    #endif
}

inline void VgApplyTerrainBlend(StandardLitVaryings input, inout half3 albedo, inout half roughness)
{
    #if defined(_BLEND_TERRAIN_ON)
    float2 terrainUV = (input.positionWS.xz - _VGTerrainTransformData.xy) / max(_VGTerrainTransformData.zw, float2(1e-5, 1e-5));
    half4 terrainSample = SAMPLE_TEXTURE2D(_VGTerrainColor, sampler_VGTerrainColor, terrainUV);
    half3 terrainColor = lerp(_SimpleTerrainColor.rgb, terrainSample.rgb, step(0.001h, dot(terrainSample.rgb, terrainSample.rgb)));
    half blend = saturate((input.positionWS.y - _BlendRange.x) / max(_BlendRange.y, 1e-4));
    blend = 1.0h - blend;
    albedo = lerp(albedo, terrainColor * _TerrainBrightness, blend);
    roughness = lerp(roughness, saturate(_VGTerrainRoughness), blend);
    #endif
}

inline StandardLitVaryings StandardLitBuildVaryings(StandardLitAttributes input)
{
    StandardLitVaryings output = (StandardLitVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);

    float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.uv2 = input.uv2;
    output.positionWS = positionWS;
    output.overlayUV = TRANSFORM_TEX(input.uv, _OverlayTex);
    output.normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));
    float3 tangentWS = normalize(GetInstanceWorldDirection(input.tangentOS.xyz, input.instanceID));
    output.tangentWS = float4(tangentWS, input.tangentOS.w);
    output.color = input.color;
    output.screenPos = ComputeScreenPos(output.positionCS);

    #ifdef GRAPHICDRAW_ON
    GrassInstanceData instanceData = _InstanceBuffer[input.instanceID];
    output.objectScale = float3(instanceData.scale.x, instanceData.scale.y, instanceData.scale.x);
    #else
    output.objectScale.x = length(UNITY_MATRIX_M._m00_m10_m20);
    output.objectScale.y = length(UNITY_MATRIX_M._m01_m11_m21);
    output.objectScale.z = length(UNITY_MATRIX_M._m02_m12_m22);
    #endif

    output.uv = VgApplyClassicRoofUV(output.uv, input.color, output.objectScale);
    return output;
}

inline half3 VgTransformNormalTS(float3 normalTS, float3 normalWS, float4 tangentWS)
{
    float sign = tangentWS.w * GetOddNegativeScale();
    float3 bitangent = sign * cross(normalWS, tangentWS.xyz);
    float3x3 tbn = float3x3(tangentWS.xyz, bitangent, normalWS);
    return normalize(TransformTangentToWorld(normalTS, tbn));
}

inline void M_InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 baseSample = VgSampleBase(uv);
    outSurfaceData.alpha = baseSample.a * _BaseColor.a * _Alpha;
    outSurfaceData.albedo = baseSample.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = _Metallic;
    outSurfaceData.specular = half3(0, 0, 0);
    outSurfaceData.smoothness = saturate(1.0h - _Roughness);
    outSurfaceData.normalTS = VgSampleNormalTS(uv);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#endif

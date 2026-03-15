#ifndef VG_STYLIZED_GRASS_INPUT_INCLUDED
#define VG_STYLIZED_GRASS_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"

#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/VgVertexWind.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _BaseColor;
    float4 _Color1;
    float4 _Color2;
    float4 _WindDirection;
    float _TopIntensity;
    float _ColorUpLevel;
    float _ColorUpFade;
    float _Alpha;
    float _Cutoff;
    float _WindSpeed;
    float _WindForce;
    float _WindWavesScale;
    float _BackBrightness;
    float _ShadowStrength;
    float _SSSColorIntensity;
    float _SSSPower;
    float _TerrainBrightness;
CBUFFER_END

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

struct VgStylizedGrassAttributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 color : COLOR;
    float2 uv : TEXCOORD0;
    uint instanceID : SV_InstanceID;
};

struct VgStylizedGrassVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float4 color : TEXCOORD3;
    float heightMask : TEXCOORD4;
    float4 shadowCoord : TEXCOORD5;
};

struct VgStylizedGrassShadowVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
};

struct VgStylizedGrassDepthVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
};

#endif

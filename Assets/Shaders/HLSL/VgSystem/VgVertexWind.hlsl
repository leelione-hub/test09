#ifndef VG_VERTEX_WIND_INCLUDE
#define VG_VERTEX_WIND_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct WindStruct
{
    half windSpeed;
    half4 vertexColor;
    half leafStrength;
    half3 normalOS;
    half3 positionOS;
    half bendStrength;
    half bendSpeed;
    half bendWait;
    half2 windDirection;
    uint instanceID;
};

struct NewWindStruct
{
    half2 windDirection;
    half windSpeed;
    half windJitter;
    half windStrength;
    uint instanceID;
};

float VgWindRemap(float inValue, float minold ,float maxOld, float minNew, float maxNew)
{
    return (minNew + (inValue - minold) * (maxNew - minNew) / (maxOld - minold));
}

// 简单的风动画
float3 ApplyWind(float3 position, float3 normal, float strength)
{
    float windTime = _Time.y * 0.5;
    float windX = sin(position.x * 0.1 + windTime) * 0.1;
    float windZ = cos(position.z * 0.1 + windTime) * 0.1;
            
    float3 wind = float3(windX, 0, windZ) * strength;
    return position + normal * wind;
}

half3 PlantWind(WindStruct windData)
{
    float3 objToWorld;
    #ifdef GRAPHICDRAW_ON
        objToWorld = GetInstanceWorldPosition(float3(0, 0, 0), windData.instanceID);
    #else
        objToWorld = TransformObjectToWorld(float3(0, 0, 0));
    #endif
    float objXZ = objToWorld.x + objToWorld.z;
    float a = windData.windSpeed * _TimeParameters.x * windData.vertexColor.g + objXZ;
    half f1 = sin(a);
    half f2 = windData.vertexColor.r;
    half f3 = windData.leafStrength;
    half3 f4 = windData.normalOS;
            

    half b = windData.positionOS.y * VgWindRemap(windData.bendStrength,0,1,0,0.1) * windData.vertexColor.b;

    float c = cos(windData.bendSpeed * _TimeParameters.x + objXZ);
            
    half2 d = b * sign(c) * (1 - pow(1 - abs(c) ,windData.bendWait)) * windData.windDirection;
            
    half3 finalWind = (f1 * f2 * f3 * f4) + half3(d.x,0.001,d.y);

    return finalWind;
}

float2 VgMod289(float2 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float3 VgMod289(float3 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float3 VgPermute(float3 x)
{
    return VgMod289(((x * 34.0) + 1.0) * x);
}

float VgSimplexNoise(float2 v)
{
    const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
    float2 i = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = VgMod289(i);
    float3 p = VgPermute(VgPermute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));
    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m *= m;
    m *= m;
    float3 x = 2.0 * frac(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float GetWindScroll(NewWindStruct inputData, float4 positionOS, float windNoiseSize, float noisePower)
{
    float3 originWS;
    #ifdef GRAPHICDRAW_ON
        originWS = GetInstanceWorldPosition(float3(0.0, 0.0, 0.0), inputData.instanceID);
    #else
        originWS = TransformObjectToWorld(float3(0.0, 0.0, 0.0));
    #endif

    float2 windDir = inputData.windDirection;
    float windDirLength = length(windDir);
    windDir = windDirLength > 1e-4 ? windDir / windDirLength : float2(1.0, 0.0);
    float2 noiseUV = (originWS.xz + positionOS.xz) / max(windNoiseSize, 1e-4);
    noiseUV += windDir * (_TimeParameters.x * inputData.windSpeed);

    float baseNoise = VgSimplexNoise(noiseUV);
    float jitterNoise = VgSimplexNoise(noiseUV * 1.73 + inputData.windJitter * 3.11);
    float wind = saturate(baseNoise * 0.5 + 0.5);
    float jitter = jitterNoise * inputData.windJitter;
    float heightMask = saturate(positionOS.y);
    return (wind + jitter) * inputData.windStrength * pow(heightMask, max(noisePower, 0.001));
}
#endif

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
};

float Remap(float inValue, float minold ,float maxOld, float minNew, float maxNew)
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
    float3 objToWorld = mul( GetObjectToWorldMatrix(), float4( float3( 0,0,0 ), 1 ) ).xyz;
    float objXZ = objToWorld.x + objToWorld.z;
    float a = windData.windSpeed * _TimeParameters.x * windData.vertexColor.g + objXZ;
    half f1 = sin(a);
    half f2 = windData.vertexColor.r;
    half f3 = windData.leafStrength;
    half3 f4 = windData.normalOS;
            

    half b = windData.positionOS.y * Remap(windData.bendStrength,0,1,0,0.1) * windData.vertexColor.b;

    float c = cos(windData.bendSpeed * _TimeParameters.x + objXZ);
            
    half2 d = b * sign(c) * (1 - pow(1 - abs(c) ,windData.bendWait)) * windData.windDirection;
            
    half3 finalWind = (f1 * f2 * f3 * f4) + half3(d.x,0.001,d.y);

    return finalWind;
}
#endif
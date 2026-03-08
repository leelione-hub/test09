#ifndef VG_VERTEX_INPUT_INCLUDE
#define VG_VERTEX_INPUT_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#pragma multi_compile _ GRAPHICDRAW_ON

struct GrassInstanceData
{
    float3 position;
    float rotationY;
    float2 scale;
};

StructuredBuffer<GrassInstanceData> _InstanceBuffer;

float3 GetInstanceWorldPosition(float3 positionOS,uint instanceID)
{
    #ifdef GRAPHICDRAW_ON
    GrassInstanceData data = _InstanceBuffer[instanceID];

    // const float ALIGN_ANGLE = PI * 0.5; // π/2
    //
    // // 总旋转角 = 校正角 + 实例旋转角
    // float totalRotation = ALIGN_ANGLE + data.rotationY;
    //
    // float c = cos(totalRotation);
    // float s = sin(totalRotation);
    
    float c = cos(data.rotationY);
    float s = sin(data.rotationY);

    float3 pos = positionOS;
            
    pos.xz *= data.scale.x;
    pos.y *= data.scale.y;
    float3 rotated;
    rotated.x = pos.x * c - pos.z * s;
    rotated.z = pos.x * s + pos.z * c;
    rotated.y = pos.y;

    float3 worldPos = rotated + data.position;
    return worldPos;
    #else
    return TransformObjectToWorld(positionOS);
    #endif
            
}

float3 GetInstanceWorldNormal(float3 normalOS, uint instanceID)
{
    #ifdef GRAPHICDRAW_ON
    GrassInstanceData data = _InstanceBuffer[instanceID];

    float sx = max(data.scale.x, 1e-5);
    float sy = max(data.scale.y, 1e-5);

    // inverse-transpose for M = R * S, S = diag(sx, sy, sx)
    float3 n = float3(normalOS.x / sx, normalOS.y / sy, normalOS.z / sx);

    float c = cos(data.rotationY);
    float s = sin(data.rotationY);

    float3 rotated;
    rotated.x = n.x * c - n.z * s;
    rotated.z = n.x * s + n.z * c;
    rotated.y = n.y;

    return normalize(rotated);
    #else
    return TransformObjectToWorldNormal(normalOS);
    #endif
}

#endif

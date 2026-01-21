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

#endif
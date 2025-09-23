#ifndef CUSTOM_NODE_INCLUDED
#define CUSTOM_NODE_INCLUDED

StructuredBuffer<float3> _Positions;

void GetModifiedVertex_float(uint VertexID, out float3 Position)
{
    #if defined(SHADER_API_D3D11) || defined(SHADER_API_GLCORE) || defined(SHADER_API_GLES3) || defined(SHADER_API_METAL) || defined(SHADER_API_VULKAN)
    Position = _Positions[VertexID];
    #else
    Position = float3(0, 0, 0);
    #endif
}

StructuredBuffer<float4x4> positionBuffer;

void GetWorldPosition_float(uint instanceID,float4 objectPosition, out float4 worldPosition)
{
    float4x4 c_ObjectToWorld = positionBuffer[instanceID];
    worldPosition = mul(c_ObjectToWorld,objectPosition);
}

#endif
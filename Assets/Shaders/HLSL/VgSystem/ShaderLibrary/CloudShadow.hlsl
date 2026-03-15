#ifndef M_CLOUD_SHADOW_INCLUDED
#define M_CLOUD_SHADOW_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

TEXTURE2D(_CustomCloudTexture);     SAMPLER(sampler_CustomCloudTexture);
float4 _CustomCloudTexture_ST;


half CustomCloudShadow(float3 positionWS)
{
    float2 uv = positionWS.xz * _CustomCloudTexture_ST.xy + _CustomCloudTexture_ST.zw;
    return SAMPLE_TEXTURE2D_X(_CustomCloudTexture,sampler_CustomCloudTexture,uv).r;
}

#endif

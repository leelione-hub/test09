#ifndef HIDDEN_SCREEN_SPACE_VOLUMETRIC_LIGHT_INPUT_INCLUDED
#define HIDDEN_SCREEN_SPACE_VOLUMETRIC_LIGHT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

float4 _SSVLParams0;
float4 _SSVLParams1;
float4 _SSVLParams2;
float4 _SSVLScatteringColor;

// Params0：x=步数，y=最大 Ray March 距离，z=整体强度，w=抖动强度
#define SSVL_STEP_COUNT _SSVLParams0.x
#define SSVL_MAX_RAY_DISTANCE _SSVLParams0.y
#define SSVL_INTENSITY _SSVLParams0.z
#define SSVL_JITTER_STRENGTH _SSVLParams0.w

// Params1：x=介质密度，y=消光系数，z=高度雾基准高度，w=高度衰减
#define SSVL_DENSITY _SSVLParams1.x
#define SSVL_EXTINCTION _SSVLParams1.y
#define SSVL_HEIGHT_BASE _SSVLParams1.z
#define SSVL_HEIGHT_FALLOFF _SSVLParams1.w

// Params2：x=各向异性 g，y=阴影对散射的影响强度
#define SSVL_ANISOTROPY _SSVLParams2.x
#define SSVL_SHADOW_STRENGTH _SSVLParams2.y

#endif

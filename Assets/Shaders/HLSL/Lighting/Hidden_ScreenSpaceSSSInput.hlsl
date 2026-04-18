#ifndef HIDDEN_SCREEN_SPACE_SSS_INPUT_INCLUDED
#define HIDDEN_SCREEN_SPACE_SSS_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_ScreenSpaceSSSMaskTexture);
SAMPLER(sampler_ScreenSpaceSSSMaskTexture);

TEXTURE2D_X(_ScreenSpaceSSSSceneTexture);
SAMPLER(sampler_ScreenSpaceSSSSceneTexture);

float4 _ScreenSpaceSSSParams0;

#define SSS_BLUR_RADIUS _ScreenSpaceSSSParams0.x
#define SSS_DEPTH_FALLOFF _ScreenSpaceSSSParams0.y
#define SSS_COMPOSITE_INTENSITY _ScreenSpaceSSSParams0.z
#define SSS_MASK_THRESHOLD _ScreenSpaceSSSParams0.w

#endif

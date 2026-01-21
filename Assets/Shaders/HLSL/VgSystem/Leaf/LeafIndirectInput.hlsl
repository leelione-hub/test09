#ifndef LEAFINDIRECT_INPUT_INCLUDE
#define LEAFINDIRECT_INPUT_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4 _Color;
    float _WindStrength;
    float _BoundsRadius;
    float4 _MainTex_ST;
    float _WindSpeed;
    float _LeafStrength;
    float _BendStrength;
    float _BendSpeed;
    float _BendWait;
    half4 _WindDirection;
    half _Cutoff;
CBUFFER_END

TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);

#endif
#ifndef LEAFINDIRECT_INPUT_INCLUDE
#define LEAFINDIRECT_INPUT_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/VgVertexWind.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4 _Color;
    float _WindStrength;
    float4 _MainTex_ST;
    float _WindSpeed;
    float _LeafStrength;
    float _BendStrength;
    float _BendSpeed;
    float _BendWait;
    float _Roughness;
    float _Alpha;
    float _BumpScale;
    float _NormalBackIntensity;
    float _BackBrightness;
    float _ShadowStrength;
    float _AOStrength;
    half4 _WindDirection;
    half _Cutoff;
CBUFFER_END

TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
TEXTURE2D(_NRMTex); SAMPLER(sampler_NRMTex);

inline void M_InitializeLeafSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = VgSampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
    outSurfaceData.alpha = albedoAlpha.a * _Color.a * _Alpha;
    outSurfaceData.albedo = albedoAlpha.rgb * _Color.rgb;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = half3(0, 0, 0);
    outSurfaceData.smoothness = saturate(1.0h - _Roughness);

    #if defined(_USE_NORMAL_BACK_ON)
    half4 nrm = SAMPLE_TEXTURE2D(_NRMTex, sampler_NRMTex, uv);
    outSurfaceData.normalTS = GetNRM_Normal(nrm, max(_BumpScale, _NormalBackIntensity));
    #else
    outSurfaceData.normalTS = half3(0, 0, 1);
    #endif

    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#endif

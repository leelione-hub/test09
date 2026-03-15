#ifndef M_PLAYER_SHADOW_INCLUDE
#define M_PLAYER_SHADOW_INCLUDE

real4 custom_SHAr;
real4 custom_SHAg;
real4 custom_SHAb;
real4 custom_SHBr;
real4 custom_SHBg;
real4 custom_SHBb;
real4 custom_SHC;

//高精度人物阴影vp矩阵
float4x4 unity_LightMatrixVP;

float _HightPlayerShadow_NormalBias;
float4 _CharacterLightDirectionWS;

TEXTURE2D_X(_PlayerShadowTexture);
SAMPLER(sampler_PlayerShadowTexture);
float4 _PlayerShadowTexture_TexelSize;


real CustomSampleShadowmapLowQuality(float2 shadowUV)
{
    float4 attenuation4;
    float2 size = _ScreenSize.zw;
    attenuation4.x = SAMPLE_TEXTURE2D(_PlayerShadowTexture,sampler_PlayerShadowTexture,shadowUV + float2(0,0) * size).r;
    attenuation4.y = SAMPLE_TEXTURE2D(_PlayerShadowTexture,sampler_PlayerShadowTexture,shadowUV + float2(0,1) * size).r;
    attenuation4.z = SAMPLE_TEXTURE2D(_PlayerShadowTexture,sampler_PlayerShadowTexture,shadowUV + float2(1,0) * size).r;
    attenuation4.w = SAMPLE_TEXTURE2D(_PlayerShadowTexture,sampler_PlayerShadowTexture,shadowUV + float2(1,1) * size).r;
    return dot(attenuation4,float(0.25));
}

real CustomSampleShadowmapHighQuality(float2 shadowUV)
{
    real fetchesWeights[16];
    real2 fetchesUV[16];
    float4 shadowmapSize = float4(_ScreenSize.zw,_ScreenSize.xy);
    SampleShadow_ComputeSamples_Tent_7x7(shadowmapSize, shadowUV, fetchesWeights, fetchesUV);

    return fetchesWeights[0] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[0]).r
                + fetchesWeights[1] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[1]).r
                + fetchesWeights[2] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[2]).r
                + fetchesWeights[3] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[3]).r
                + fetchesWeights[4] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[4]).r
                + fetchesWeights[5] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[5]).r
                + fetchesWeights[6] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[6]).r
                + fetchesWeights[7] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[7]).r
                + fetchesWeights[8] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[8]).r
                + fetchesWeights[9] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[9]).r
                + fetchesWeights[10] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[10]).r
                + fetchesWeights[11] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[11]).r
                + fetchesWeights[12] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[12]).r
                + fetchesWeights[13] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[13]).r
                + fetchesWeights[14] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[14]).r
                + fetchesWeights[15] * SAMPLE_TEXTURE2D(_PlayerShadowTexture, sampler_PlayerShadowTexture, fetchesUV[15]).r;
}

float CustomHighQualityShadow(float4 shadowCoord,float3 normalWS)
{
    float3 projCoords = (shadowCoord.xyz / shadowCoord.w) * 0.5 + 0.5;
    float2 shadowuv;
    #if UNITY_UV_STARTS_AT_TOP
    shadowuv = float2(projCoords.x,1.0 - projCoords.y);
    #else
    shadowuv = float2(projCoords.x,projCoords.y);
    #endif
    //float closeDepth = SAMPLE_TEXTURE2D(_PlayerShadowTexture,sampler_PlayerShadowTexture,shadowuv).r;
    float closeDepth = CustomSampleShadowmapHighQuality(shadowuv);
    float bias = max(_HightPlayerShadow_NormalBias * (1.0 - dot(normalize(normalWS),_CharacterLightDirectionWS.xyz)),0.005);
    float currentDepth = 0;
    #if UNITY_UV_STARTS_AT_TOP
    currentDepth = (shadowCoord.xyz / shadowCoord.w).z;
    closeDepth = saturate(closeDepth - bias);
    #else
    currentDepth = projCoords.z;
    closeDepth = saturate(closeDepth + bias);
    #endif

    half shadow;
    #if UNITY_UV_STARTS_AT_TOP
    shadow = currentDepth >= closeDepth ? 1.0 : closeDepth;
    #else
    shadow = currentDepth > closeDepth ? closeDepth : 1.0;
    #endif

    //return BEYOND_SHADOW_FAR(shadowCoord) ? 1.0 : shadow;
    return shadow;
}

half3 SHEvalLinearL0L1 (half4 normal)
{
    half3 x;

    // Linear (L1) + constant (L0) polynomial terms
    x.r = dot(custom_SHAr,normal);
    x.g = dot(custom_SHAg,normal);
    x.b = dot(custom_SHAb,normal);

    return x;
}

// normal should be normalized, w=1.0
half3 SHEvalLinearL2 (half4 normal)
{
    half3 x1, x2;
    // 4 of the quadratic (L2) polynomials
    half4 vB = normal.xyzz * normal.yzzx;
    x1.r = dot(custom_SHBr,vB);
    x1.g = dot(custom_SHBg,vB);
    x1.b = dot(custom_SHBb,vB);

    // Final (5th) quadratic (L2) polynomial
    half vC = normal.x*normal.x - normal.y*normal.y;
    x2 = custom_SHC.rgb * vC;

    return x1 + x2;
}

// normal should be normalized, w=1.0
// output in active color space
half3 ShadeSH9 (float4 normal)
{
    // Linear + constant polynomial terms
    half3 res = SHEvalLinearL0L1 (normal);

    // Quadratic polynomials
    res += SHEvalLinearL2 (normal);

    #   ifdef UNITY_COLORSPACE_GAMMA
    res = LinearToGammaSpace (res);
    #   endif

    return res;
}

half3 SampleCustomSHPixel(half3 L2Term, half3 normalWS)
{
    #if defined(EVALUATE_SH_VERTEX)
    return L2Term;
    #elif defined(EVALUATE_SH_MIXED)
    half3 res = L2Term + SHEvalLinearL0L1(normalWS, custom_SHAr, custom_SHAg, custom_SHAb);
    #ifdef UNITY_COLORSPACE_GAMMA
    res = LinearToSRGB(res);
    #endif
    return max(half3(0, 0, 0), res);
    #endif

    // Default: Evaluate SH fully per-pixel
    return ShadeSH9(half4(normalWS,1));
}



#endif
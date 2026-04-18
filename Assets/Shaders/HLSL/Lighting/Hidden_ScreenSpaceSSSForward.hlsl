#ifndef HIDDEN_SCREEN_SPACE_SSS_FORWARD_INCLUDED
#define HIDDEN_SCREEN_SPACE_SSS_FORWARD_INCLUDED

half4 SampleBlurredSSS(float2 uv, float2 direction)
{
    float centerDepth = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
    half4 centerMask = SAMPLE_TEXTURE2D(_ScreenSpaceSSSMaskTexture, sampler_ScreenSpaceSSSMaskTexture, uv);
    half4 centerColor = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);

    if (centerMask.a <= SSS_MASK_THRESHOLD)
    {
        return centerColor;
    }

    static const float kernel[5] = { 0.227027f, 0.1945946f, 0.1216216f, 0.054054f, 0.016216f };

    half4 accum = centerColor * kernel[0];
    float weightSum = kernel[0];

    [unroll]
    for (int i = 1; i < 5; i++)
    {
        float2 offset = direction * (SSS_BLUR_RADIUS * i) * _ScreenParams.zw;
        float2 uvA = saturate(uv + offset);
        float2 uvB = saturate(uv - offset);

        half4 maskA = SAMPLE_TEXTURE2D(_ScreenSpaceSSSMaskTexture, sampler_ScreenSpaceSSSMaskTexture, uvA);
        half4 maskB = SAMPLE_TEXTURE2D(_ScreenSpaceSSSMaskTexture, sampler_ScreenSpaceSSSMaskTexture, uvB);

        float depthA = LinearEyeDepth(SampleSceneDepth(uvA), _ZBufferParams);
        float depthB = LinearEyeDepth(SampleSceneDepth(uvB), _ZBufferParams);

        float weightA = kernel[i] * exp(-abs(depthA - centerDepth) * SSS_DEPTH_FALLOFF) * maskA.a;
        float weightB = kernel[i] * exp(-abs(depthB - centerDepth) * SSS_DEPTH_FALLOFF) * maskB.a;

        accum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uvA) * weightA;
        accum += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uvB) * weightB;
        weightSum += weightA + weightB;
    }

    return accum / max(weightSum, 1e-4);
}

half4 FragBlurHorizontal(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    return SampleBlurredSSS(input.texcoord, float2(1, 0));
}

half4 FragBlurVertical(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    return SampleBlurredSSS(input.texcoord, float2(0, 1));
}

half4 FragComposite(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv = input.texcoord;
    half3 original = SAMPLE_TEXTURE2D_X(_ScreenSpaceSSSSceneTexture, sampler_LinearClamp, uv).rgb;
    half4 blurred = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);
    half maskStrength = saturate(blurred.a * SSS_COMPOSITE_INTENSITY);
    return half4(lerp(original, original + blurred.rgb, maskStrength), 1);
}

#endif

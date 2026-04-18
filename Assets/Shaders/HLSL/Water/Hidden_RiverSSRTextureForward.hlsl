#ifndef HIDDEN_RIVER_SSR_TEXTURE_FORWARD_INCLUDED
#define HIDDEN_RIVER_SSR_TEXTURE_FORWARD_INCLUDED

half4 Frag(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    float2 uv = input.texcoord;
    half4 source = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);
    float rawDepth = SampleSceneDepth(uv);

#if UNITY_REVERSED_Z
    half valid = step(0.0001h, rawDepth);
#else
    half valid = step(rawDepth, 0.9999h);
#endif

    return half4(source.rgb, valid);
}

#endif

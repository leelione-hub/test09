#ifndef HIDDEN_SCREEN_SPACE_VOLUMETRIC_LIGHT_FORWARD_INCLUDED
#define HIDDEN_SCREEN_SPACE_VOLUMETRIC_LIGHT_FORWARD_INCLUDED

float Hash21(float2 p)
{
    // 每像素小噪声，用于打乱首个采样点，减轻固定步进带来的条纹感。
    float h = dot(p, float2(127.1, 311.7));
    return frac(sin(h) * 43758.5453123);
}

float GetFarRawDepth()
{
#if UNITY_REVERSED_Z
    return 0.0;
#else
    return 1.0;
#endif
}

bool HasGeometry(float rawDepth)
{
    // 是否命中实际几何体。
    // 远平面判定在 Reversed-Z 与普通深度下不同。
#if UNITY_REVERSED_Z
    return rawDepth > 0.0001;
#else
    return rawDepth < 0.9999;
#endif
}

float PhaseHenyeyGreenstein(float cosTheta, float g)
{
    // Henyey-Greenstein 相位函数。
    // 正的 g 会强调前向散射，通常更适合做神光/体积光束。
    float g2 = g * g;
    float denom = pow(max(1.0 + g2 - 2.0 * g * cosTheta, 1e-4), 1.5);
    return (1.0 - g2) / (4.0 * PI * denom);
}

float ComputeHeightDensity(float3 positionWS)
{
    // 简单的指数高度雾密度。
    // Ray March 每一步实际采样的就是这个介质密度场。
    float heightTerm = exp(-max(positionWS.y - SSVL_HEIGHT_BASE, 0.0) * SSVL_HEIGHT_FALLOFF);
    return SSVL_DENSITY * heightTerm;
}

float3 ReconstructWorldPosition(float2 uv, float rawDepth)
{
    // 通过屏幕 UV 和深度重建世界坐标。
    return ComputeWorldSpacePosition(uv, rawDepth, UNITY_MATRIX_I_VP);
}

half4 Frag(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    float2 uv = input.texcoord;
    half4 source = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);

    float rawDepth = SampleSceneDepth(uv);
    float farRawDepth = GetFarRawDepth();

    // 构建当前像素对应的世界空间视线。
    float3 cameraWS = GetCameraPositionWS();
    float3 farWS = ReconstructWorldPosition(uv, farRawDepth);
    float3 rayDirWS = normalize(farWS - cameraWS);

    // 如果当前像素能看到场景几何体，就只 march 到表面为止；
    // 如果看到的是天空，就 march 到固定最大距离。
    float rayLength = SSVL_MAX_RAY_DISTANCE;
    if (HasGeometry(rawDepth))
    {
        float3 surfaceWS = ReconstructWorldPosition(uv, rawDepth);
        rayLength = min(distance(cameraWS, surfaceWS), SSVL_MAX_RAY_DISTANCE);
    }

    int stepCount = max(1, (int)SSVL_STEP_COUNT);
    float stepLength = rayLength / stepCount;
    float jitter = Hash21(uv * _ScreenParams.xy) * SSVL_JITTER_STRENGTH;

    // 这版实现只使用主方向光来驱动散射。
    Light mainLight = GetMainLight();
    float3 lightDirWS = normalize(mainLight.direction);
    float phase = PhaseHenyeyGreenstein(dot(rayDirWS, lightDirWS), SSVL_ANISOTROPY);

    float3 accumulatedLight = 0.0;
    float transmittance = 1.0;

    [loop]
    for (int i = 0; i < stepCount; i++)
    {
        // 沿视线在介质里采样一个点。
        float travel = (i + jitter) * stepLength;
        float3 samplePosWS = cameraWS + rayDirWS * travel;

        float density = ComputeHeightDensity(samplePosWS);
        if (density <= 1e-4)
        {
            continue;
        }

        // 通过主光阴影图判断这个介质采样点是否被光照到。
        float4 shadowCoord = TransformWorldToShadowCoord(samplePosWS);
        float shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
        shadowAttenuation = lerp(1.0, shadowAttenuation, SSVL_SHADOW_STRENGTH);

        // 单次散射近似：
        // 当前步累加被照亮的介质散射；
        // 后续步再通过 transmittance 持续衰减。
        float3 stepScattering = _SSVLScatteringColor.rgb * mainLight.color * (density * phase * shadowAttenuation);
        accumulatedLight += transmittance * stepScattering * stepLength * 1.0 / stepCount;
        transmittance *= exp(-density * SSVL_EXTINCTION * stepLength);
    }

    // 体积光结果以加法方式叠加回原始画面。
    float3 finalColor = source.rgb + accumulatedLight * SSVL_INTENSITY;
    // finalColor =  accumulatedLight * SSVL_INTENSITY;
    return half4(finalColor, source.a);
}

#endif

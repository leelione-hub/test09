Shader "Hidden/Custom/AtmosphericScattering"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "AtmosphereScatter"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragScatter
            #pragma multi_compile_local_fragment _ ATMOSPHERE_HIGH_QUALITY

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #define ATMOSPHERE_PI 3.14159265

            float _AtmosphereBlend;
            float4 _AtmosphereSkyTint;
            float4 _AtmosphereHorizonTint;
            float4 _AtmosphereFogTint;
            float _AtmosphereDensity;
            float _AtmosphereHeightFalloff;
            float _AtmosphereHeightOffset;
            float _AtmosphereFogStartDistance;
            float _AtmosphereMaxDistance;
            float _AtmosphereAnisotropy;
            float _AtmosphereAerialPerspective;
            float4 _AtmosphereShaftParams;
            float4 _AtmosphereSunHaloParams;
            float4 _AtmosphereSunDirection;
            float4 _AtmosphereSunColor;
            float4 _AtmosphereSunScreenPos;
            float4 _AtmosphereSampleCounts;

            float Hash12(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }

            float3 GetFarWorldPosition(float2 uv)
            {
            #if UNITY_REVERSED_Z
                return ComputeWorldSpacePosition(uv, 0.0, UNITY_MATRIX_I_VP);
            #else
                return ComputeWorldSpacePosition(uv, 1.0, UNITY_MATRIX_I_VP);
            #endif
            }

            float PhaseHG(float cosTheta, float g)
            {
                float g2 = g * g;
                float denom = max(1e-4, 1.0 + g2 - 2.0 * g * cosTheta);
                return (1.0 - g2) / (4.0 * ATMOSPHERE_PI * pow(denom, 1.5));
            }

            float GetHeightDensity(float3 samplePosWS)
            {
                float h = max(0.0, samplePosWS.y - _AtmosphereHeightOffset);
                return exp(-h * _AtmosphereHeightFalloff);
            }

            float ComputeSkyVisibility(float2 uv)
            {
                float rawDepth = SampleSceneDepth(uv);
                return step(0.9997, Linear01Depth(rawDepth, _ZBufferParams));
            }

            float ComputeVolumetricShafts(float2 uv, float rayLength, float3 viewDirWS)
            {
                if (_AtmosphereSunScreenPos.z <= 0.0)
                {
                    return 0.0;
                }

                int shaftSamples = max(1, (int)_AtmosphereSampleCounts.y);
                float2 toSun = _AtmosphereSunScreenPos.xy - uv;
                float distanceToSun = length(toSun);
                float2 stepUV = toSun / shaftSamples;
                float jitter = (Hash12(uv * _ScreenParams.xy) - 0.5) * _AtmosphereShaftParams.z;
                float2 sampleUV = uv + stepUV * jitter;
                float illuminationDecay = 1.0;
                float accum = 0.0;

                [loop]
                for (int i = 0; i < 64; i++)
                {
                    if (i >= shaftSamples)
                    {
                        break;
                    }

                    sampleUV += stepUV;
                    if (any(sampleUV < 0.0) || any(sampleUV > 1.0))
                    {
                        break;
                    }

                    accum += ComputeSkyVisibility(sampleUV) * illuminationDecay;
                    illuminationDecay *= _AtmosphereShaftParams.y;
                }

                float sunAlignment = saturate(dot(viewDirWS, _AtmosphereSunDirection.xyz));
                float shaftFade = 1.0 - exp(-rayLength * _AtmosphereShaftParams.w * _AtmosphereDensity * 0.02);
                float radialFade = saturate(1.0 - distanceToSun * 0.85);
                return (accum / shaftSamples) * shaftFade * radialFade * pow(sunAlignment, 3.0) * _AtmosphereShaftParams.x;
            }

            float3 SampleAtmosphere(float2 uv, out float transmittance)
            {
                float rawDepth = SampleSceneDepth(uv);
                float linear01Depth = Linear01Depth(rawDepth, _ZBufferParams);
                bool isSky = linear01Depth >= 0.9997;

                float3 cameraPosWS = _WorldSpaceCameraPos;
                float3 farPosWS = GetFarWorldPosition(uv);
                float3 viewDirWS = normalize(farPosWS - cameraPosWS);

                float3 endPosWS = isSky ? cameraPosWS + viewDirWS * _AtmosphereMaxDistance : ComputeWorldSpacePosition(uv, rawDepth, UNITY_MATRIX_I_VP);
                float sceneDistance = distance(cameraPosWS, endPosWS);
                float rayLength = min(_AtmosphereMaxDistance, max(0.0, sceneDistance - _AtmosphereFogStartDistance));

                if (rayLength <= 1e-4)
                {
                    transmittance = 1.0;
                    return 0.0;
                }

                int raymarchSteps = max(1, (int)_AtmosphereSampleCounts.x);
                float jitter = Hash12(uv * _ScreenParams.xy);
                float stepLength = rayLength / raymarchSteps;
                float rayOffset = stepLength * lerp(0.5, jitter, _AtmosphereShaftParams.z);
                float opticalDepth = 0.0;
                float3 scatteredLight = 0.0;

                float horizon = saturate(1.0 - abs(viewDirWS.y));
                float sunAmount = saturate(dot(viewDirWS, _AtmosphereSunDirection.xyz));
                float phase = PhaseHG(sunAmount, _AtmosphereAnisotropy);
                float3 ambientTint = lerp(_AtmosphereSkyTint.rgb, _AtmosphereHorizonTint.rgb, horizon);
                float3 fogTint = lerp(_AtmosphereFogTint.rgb, ambientTint, 0.4);
                float3 sunlightTint = lerp(fogTint, _AtmosphereSunColor.rgb, saturate(phase * 12.0));

                [loop]
                for (int i = 0; i < 128; i++)
                {
                    if (i >= raymarchSteps)
                    {
                        break;
                    }

                    float3 samplePosWS = cameraPosWS + viewDirWS * (_AtmosphereFogStartDistance + rayOffset + stepLength * i);
                    float localDensity = _AtmosphereDensity * GetHeightDensity(samplePosWS);
                    float stepOpticalDepth = localDensity * stepLength;
                    opticalDepth += stepOpticalDepth;

                    float localTransmittance = exp(-opticalDepth);
                    scatteredLight += sunlightTint * stepOpticalDepth * localTransmittance;
                }

                transmittance = exp(-opticalDepth * _AtmosphereAerialPerspective);

                float shafts = ComputeVolumetricShafts(uv, rayLength, viewDirWS);
                float2 toSunUv = uv - _AtmosphereSunScreenPos.xy;
                float sunDisc = exp(-dot(toSunUv, toSunUv) / max(1e-4, _AtmosphereSunHaloParams.x * _AtmosphereSunHaloParams.x));
                float3 halo = _AtmosphereSunColor.rgb * sunDisc * _AtmosphereSunHaloParams.y;

                float3 color = scatteredLight * _AtmosphereAerialPerspective;
                color += _AtmosphereSunColor.rgb * shafts;
                color += halo * saturate(dot(viewDirWS, _AtmosphereSunDirection.xyz));

                if (isSky)
                {
                    color += ambientTint * (1.0 - transmittance) * 0.35;
                }

                return color;
            }

            half4 FragScatter(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float transmittance;
                float3 scattering = SampleAtmosphere(input.texcoord, transmittance);
                return float4(scattering, transmittance);
            }
            ENDHLSL
        }

        Pass
        {
            Name "AtmosphereComposite"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragComposite
            #pragma multi_compile_local_fragment _ ATMOSPHERE_HIGH_QUALITY

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            float _AtmosphereBlend;
            float4 _AtmosphereScatteringTexelSize;

            TEXTURE2D_X(_AtmosphereScatteringTex);

            float4 SampleScatteringFiltered(float2 uv)
            {
                float4 center = SAMPLE_TEXTURE2D_X(_AtmosphereScatteringTex, sampler_LinearClamp, uv);

            #if defined(ATMOSPHERE_HIGH_QUALITY)
                float2 texel = _AtmosphereScatteringTexelSize.xy;
                float4 sum = center * 4.0;
                sum += SAMPLE_TEXTURE2D_X(_AtmosphereScatteringTex, sampler_LinearClamp, uv + float2(texel.x, 0.0));
                sum += SAMPLE_TEXTURE2D_X(_AtmosphereScatteringTex, sampler_LinearClamp, uv - float2(texel.x, 0.0));
                sum += SAMPLE_TEXTURE2D_X(_AtmosphereScatteringTex, sampler_LinearClamp, uv + float2(0.0, texel.y));
                sum += SAMPLE_TEXTURE2D_X(_AtmosphereScatteringTex, sampler_LinearClamp, uv - float2(0.0, texel.y));
                return sum / 8.0;
            #else
                return center;
            #endif
            }

            half4 FragComposite(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float4 sceneColor = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);
                float4 scattering = SampleScatteringFiltered(input.texcoord);
                float3 composed = sceneColor.rgb * scattering.a + scattering.rgb;
                float3 finalColor = lerp(sceneColor.rgb, composed, _AtmosphereBlend);
                return float4(finalColor, sceneColor.a);
            }
            ENDHLSL
        }
    }
}

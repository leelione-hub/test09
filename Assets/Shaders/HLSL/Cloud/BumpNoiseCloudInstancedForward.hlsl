#ifndef BUMP_NOISE_CLOUD_INSTANCED_FORWARD_INCLUDED
#define BUMP_NOISE_CLOUD_INSTANCED_FORWARD_INCLUDED

Varyings vert(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    CloudShellData shellData = BuildCloudShellData(input);
    float4 positionCS = TransformWorldToHClip(shellData.positionWS);
    output.positionCS = positionCS;
    output.positionWS = shellData.positionWS;
    output.normalWS = shellData.normalWS;
    output.shadowCoord = TransformWorldToShadowCoord(shellData.positionWS);
    output.layerClip = shellData.layerClip;
    output.viewDepth = -TransformWorldToView(shellData.positionWS).z;
    output.fogFactor = ComputeFogFactor(positionCS.z);
    output.normalizedPositionOS = shellData.normalizedPositionOS;
    return output;
}

half4 frag(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float3 normalWS = normalize(input.normalWS);
    float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
    float distanceFade = ComputeDistanceFade(input.positionWS);
    float clipRate = saturate(input.layerClip);
    float noise;
    float density = ComputeCloudDensity(input.normalizedPositionOS, clipRate, distanceFade, noise);
    ClipCloudShell(density, input.positionCS);

    Light mainLight = GetMainLight(input.shadowCoord);
    float3 lightDirWS = normalize(mainLight.direction);
    float ndotl = saturate(dot(normalWS, lightDirWS));
    float ndotv = saturate(dot(normalWS, viewDirWS));

    float diffuse = saturate(pow(ndotl, max(0.2, _NdotLPower + clipRate * 0.75)));
    float edgeMask = saturate(pow(1.0 - ndotv, 1.2 + clipRate * 1.5));
    float3 backLightDir = normalize(normalWS * _BackSssStrength + lightDirWS);
    float backScatter = saturate(dot(viewDirWS, -backLightDir));
    backScatter = saturate(pow(backScatter, _BackSssPower + clipRate * 3.0) * _BackSssBoost);
    backScatter *= edgeMask * (1.0 - ndotl);
    float facing = saturate(pow(ndotv, max(0.2, _NdotVPower + clipRate)));

    float cameraDistance = distance(input.positionWS, _WorldSpaceCameraPos.xyz);
    float shadowFade = saturate((cameraDistance - _ShadowFadeStart) / max(_ShadowFadeRange, 0.001));
    float shadow = saturate(lerp(mainLight.shadowAttenuation, 1.0, shadowFade));
    float viewTerm = facing * _ViewLightingWeight * (1.0 - clipRate * 0.35);
    float litTerm = shadow * diffuse * (1.0 - ndotv * _ViewShadowSuppress);
    float lighting = saturate(viewTerm + litTerm + backScatter);
    lighting = saturate(pow(lighting, _HighlightCompression));

    float shellInner = 1.0 - clipRate;
    float cavity = pow(saturate(1.0 - noise), 1.5);
    float litDetail = lerp(1.0, 1.0 - cavity * 0.35, lighting * _LitDetailStrength);
    float coreShadow = saturate(shellInner * _CoreShadowStrength);

    float3 color = lerp(_ShadowColor.rgb, _BrightColor.rgb, lighting) /** mainLight.color*/;
    color = lerp(color, _BrightColor.rgb * mainLight.color, backScatter * 0.35);
    color = lerp(color, _ShadowColor.rgb * mainLight.color, coreShadow * (1.0 - lighting * 0.5));
    color *= litDetail;

    float alpha = ComputeCloudShellAlpha(density, clipRate);

    #if defined(_DEPTH_FADE_ON)
    float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);
    float sceneRawDepth = SampleSceneDepth(screenUV);
    float sceneLinearDepth = LinearEyeDepth(sceneRawDepth, _ZBufferParams);
    float depthDelta = sceneLinearDepth - input.viewDepth;
    float depthFade = depthDelta <= 0.0001 ? 1.0 : saturate(depthDelta / max(_DepthFadeDistance, 0.001));
    alpha *= depthFade;
    #endif

    color = MixFog(color, input.fogFactor);
    return half4(color, alpha);
}

#endif

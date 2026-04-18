#ifndef CUSTOM_NPR_FORWARD_INCLUDED
#define CUSTOM_NPR_FORWARD_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "CustomNPRInput.hlsl"

float RoughnessToSpecularExponent(float roughness)
{
    return sqrt(2 / (roughness + 2));
}

CustomNPROutlineVaryings CustomNPROutlineVert(CustomNPROutlineAttributes input)
{
    CustomNPROutlineVaryings output;

    half outlineIntensity = input.color.a;
    float3 positionOS = input.positionOS.xyz + input.normalOS * _OutlineWidth * 0.1 * step(0.5, outlineIntensity) * outlineIntensity;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(positionOS);

    output.positionCS = vertexInput.positionCS;
    output.vertexColor = input.color.rgb;
    return output;
}

half4 CustomNPROutlineFrag(CustomNPROutlineVaryings input) : SV_Target
{
    half3 finalColor = input.vertexColor * _OutlineColor.rgb;
    return half4(finalColor, 1);
}

CustomNPRForwardVaryings CustomNPRForwardVert(CustomNPRForwardAttributes input)
{
    CustomNPRForwardVaryings output;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

    output.positionCS = vertexInput.positionCS;
    output.positionWS = vertexInput.positionWS;
    output.normalWS = normalInput.normalWS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.vertexColor = input.color;
    output.screenPosition = ComputeScreenPos(output.positionCS);
    return output;
}

half4 CustomNPRForwardFrag(CustomNPRForwardVaryings input) : SV_Target
{
    float3 N = NormalizeNormalPerPixel(input.normalWS);
    float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half4 vertexColor = input.vertexColor;

    real4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
    real4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, input.uv);

    Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
    real3 L = normalize(mainLight.direction);
    real3 lightColor = mainLight.color;
    real shadowAttenuation = mainLight.shadowAttenuation;

    real NdotL = saturate(dot(N, L));
    real3 H = normalize(V + L);
    real NdotH = saturate(dot(N, H));
    real NdotV = saturate(dot(N, V));
    float ndotLRaw = dot(N, L);

    float lambert = NdotL;
    real lambertAO = lambert * saturate(lightMap.g);
    real lambertRampAO = smoothstep(0, _ShadowSmoothness, lambertAO);

    half dayOrNight = (1 - step(0.1, _InNight)) * 0.5 + 0.03;

    float halfSampler = saturate(lambertRampAO * 0.5 + 0.5);
    half rampOffset = step(0.5, vertexColor.g) == 1 ? vertexColor.g : vertexColor.g - 1;
    float adjustedHalfSampler = saturate(halfSampler + rampOffset);

    half3 diffuse = 0;
    half3 specualr = 0;
    half3 emission = 0;

#ifdef _BODY
    float rampV = saturate(lightMap.a * 0.45 + dayOrNight);
    float2 rampUV = float2(adjustedHalfSampler, rampV);
    half4 rampShadow = SAMPLE_TEXTURE2D(_ShadowRampMap, sampler_ShadowRampMap, rampUV);
    diffuse = lerp(rampShadow, lightColor, lambertRampAO) * albedo;
#endif

#ifdef _FACE
    float facerampV = saturate(lightMap.a * 0.45 + dayOrNight);
    // float2 facerampUV = float2(adjustedHalfSampler, facerampV);
    // half4 facerampShadow = SAMPLE_TEXTURE2D(_ShadowRampMap, sampler_ShadowRampMap, facerampUV);
    float sinx = sin(_FaceShaowOffset);
    float cosx = cos(_FaceShaowOffset);
    float2x2 rotationOffset = float2x2(cosx, -sinx, sinx, cosx);

    float3 Front = unity_ObjectToWorld._12_22_32;
    float3 Right = unity_ObjectToWorld._13_23_33;
    float2 LightDir = mul(rotationOffset, mainLight.direction.xz);
    float FrontL = dot(normalize(Front.xz), normalize(LightDir));
    float RightL = dot(normalize(Right.xz), normalize(LightDir));
    RightL = -(acos(RightL) / PI - 0.5) * 2;

    float2 lightData = float2(
        SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, input.uv.xy).r,
        SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, float2(-input.uv.x, input.uv.y)).r);
    lightData = pow(abs(lightData), _FaceShadowMapPow);
    float lightAttenuation = step(0, FrontL) * min(step(RightL, lightData.x), step(-RightL, lightData.y));
    diffuse = lerp(_FaceShadowColor, lightColor, lightAttenuation) * albedo;
    lightMap.r = 0;
#endif

#ifdef _HAIR
    float hairMapUV_U = smoothstep(_HairDarkShadowSmooth, _HairDarkShadowArea, ndotLRaw);
    float shadowUpperBound = step(ndotLRaw, _HairDarkShadowSmooth);
    float isHair = step(0.11, lightMap.r) - step(0.9, lightMap.r);
    float litHair = step(_HairDarkShadowArea, ndotLRaw);

    float vDark = saturate(0.35 + dayOrNight);
    float2 uvDark = float2(adjustedHalfSampler, vDark);
    real4 hairShadowD = SAMPLE_TEXTURE2D(_ShadowRampMap, sampler_ShadowRampMap, uvDark);

    float vLight = saturate(0.45 + dayOrNight);
    float2 uvLight = float2(adjustedHalfSampler, vLight);
    real4 hairShadowL = SAMPLE_TEXTURE2D(_ShadowRampMap, sampler_ShadowRampMap, uvLight);
    real3 shadowHair = lerp(hairShadowD, hairShadowL, hairMapUV_U) * step(ndotLRaw, _HairDarkShadowArea);
    float lightSmoothArea = step(_HairDarkShadowArea, ndotLRaw);
    float3 lightShadowSmooth = 0.5 * _HairSmoothShadowIntensity * hairShadowL * lightSmoothArea * shadowUpperBound;

    half3 diffuseHair = (shadowHair + litHair) * albedo * isHair + lightShadowSmooth * isHair;
    half3 diffuseHairAccessory = albedo * step(lightMap.r, _HairRange);
    half aoArea = lightMap.g;
    diffuse = (diffuseHair + diffuseHairAccessory) * aoArea;
    diffuse += hairShadowD * (1 - aoArea) * albedo;
#endif

#ifdef _BODY
    float specularPow = pow(NdotV, RoughnessToSpecularExponent(lightMap.b));
    float3 NormalVS = mul(unity_MatrixV, N) * 0.5;
    half4 MetalMap = SAMPLE_TEXTURE2D(_MetalMap, sampler_MetalMap, NormalVS.xy);
    half metal = step(0.98, lightMap.r);
    specualr = MetalMap.r * metal * albedo + (1 - metal) * lerp(0.04, albedo, lightMap.r) * specularPow * lightMap.b;
#endif

#ifdef _HAIR
    float3 viewPosWS = GetCurrentViewPosition();
    float disY = smoothstep(-0.5, 0.5, input.positionWS.y - viewPosWS.y);
    float hairSpecularMask = disY * lightMap.b;
    specualr = hairSpecularMask * ndotLRaw;
#endif

#ifdef _EMISSION
    emission = albedo * albedo.a * _EmissionIntensity;
#endif

#ifdef _EDGELIGHT
    float3 normalVS = TransformWorldToViewNormal(input.normalWS, true);
    float3 positionVS = TransformWorldToView(input.positionWS);
    float3 offsetPositionVS = positionVS + normalVS * _EdgeWidth * 0.01;
    float4 offsetClipPosistionCS = TransformWViewToHClip(offsetPositionVS);

    float2 offsetScreenUV = (offsetClipPosistionCS.xy / offsetClipPosistionCS.w) * 0.5 + 0.5;
#if UNITY_UV_STARTS_AT_TOP
    offsetScreenUV.y = 1.0 - offsetScreenUV.y;
#endif
    float offsetDepth = SampleSceneDepth(offsetScreenUV);
    float offsetEyeDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);

    float curDepth = LinearEyeDepth(input.positionCS.z, _ZBufferParams);
    float edgeLightInt = step(0.5, saturate(offsetEyeDepth - curDepth));
    diffuse = edgeLightInt * _EdgeColor * _EdgeIntensity + (1 - edgeLightInt) * diffuse;
#endif

    return half4(specualr + diffuse + emission, 1);
}

#endif

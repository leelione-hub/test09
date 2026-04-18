#ifndef TESSELLATED_VOLUME_CLOUD_FORWARD_INCLUDED
#define TESSELLATED_VOLUME_CLOUD_FORWARD_INCLUDED

float3 GetCloudNoiseUV(float3 positionWS)
{
    float invNoiseScale = rcp(max(_NoiseScale, 0.001));
    return positionWS * invNoiseScale + _Time.y * _NoiseSpeed.xyz;
}

float SampleCloudNoise(float3 positionWS)
{
    return SAMPLE_TEXTURE3D_LOD(_NoiseTex, sampler_NoiseTex, GetCloudNoiseUV(positionWS), 0).r;
}

float GetCloudDensity(float3 positionWS)
{
    float noise = SampleCloudNoise(positionWS);
    return saturate((noise - _DensityThreshold) * _DensitySoftness);
}

float GetPatchTessellationFactor(float3 positionWS)
{
    float distanceToCamera = distance(positionWS, _WorldSpaceCameraPos.xyz);
    float fade = saturate((distanceToCamera - _TessellationStartDistance) / max(_TessellationEndDistance - _TessellationStartDistance, 0.001));
    return lerp(_TessellationFactor, _TessellationMinFactor, fade);
}

TessellationControlPoint TessellationVertex(Attributes input)
{
    TessellationControlPoint output;
    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;
    output.uv = input.uv;
    return output;
}

TessellationFactors PatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch)
{
    TessellationFactors factors;

    float3 world0 = TransformObjectToWorld(patch[0].positionOS.xyz);
    float3 world1 = TransformObjectToWorld(patch[1].positionOS.xyz);
    float3 world2 = TransformObjectToWorld(patch[2].positionOS.xyz);

    float edge0 = GetPatchTessellationFactor((world1 + world2) * 0.5);
    float edge1 = GetPatchTessellationFactor((world2 + world0) * 0.5);
    float edge2 = GetPatchTessellationFactor((world0 + world1) * 0.5);

    factors.edge[0] = edge0;
    factors.edge[1] = edge1;
    factors.edge[2] = edge2;
    factors.inside = (edge0 + edge1 + edge2) * (1.0 / 3.0);
    return factors;
}

[domain("tri")]
[outputcontrolpoints(3)]
[outputtopology("triangle_cw")]
[partitioning("fractional_odd")]
[patchconstantfunc("PatchConstantFunction")]
TessellationControlPoint Hull(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
    return patch[id];
}

[domain("tri")]
Varyings Domain(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 bary : SV_DomainLocation)
{
    Varyings output;

    float3 positionOS =
        patch[0].positionOS.xyz * bary.x +
        patch[1].positionOS.xyz * bary.y +
        patch[2].positionOS.xyz * bary.z;

    float3 normalOS = normalize(
        patch[0].normalOS * bary.x +
        patch[1].normalOS * bary.y +
        patch[2].normalOS * bary.z
    );

    float2 uv =
        patch[0].uv * bary.x +
        patch[1].uv * bary.y +
        patch[2].uv * bary.z;

    float3 positionWS = TransformObjectToWorld(positionOS);
    float3 normalWS = normalize(TransformObjectToWorldNormal(normalOS));

    float shellNoise = SampleCloudNoise(positionWS);
    float shellOffset = saturate(shellNoise - _DensityThreshold) * _Displacement;
    positionWS += normalWS * shellOffset;

    float4 positionCS = TransformWorldToHClip(positionWS);

    output.positionWS = positionWS;
    output.normalWS = normalWS;
    output.uv = uv;
    output.positionCS = positionCS;
    output.fogFactor = ComputeFogFactor(positionCS.z);
    return output;
}

float3 ReconstructCloudNormal(float3 positionWS, float3 baseNormalWS)
{
    float sampleOffset = max(_NormalSampleOffset, 0.001);
    float center = SampleCloudNoise(positionWS);
    float gradX = SampleCloudNoise(positionWS + float3(sampleOffset, 0, 0)) - center;
    float gradY = SampleCloudNoise(positionWS + float3(0, sampleOffset, 0)) - center;
    float gradZ = SampleCloudNoise(positionWS + float3(0, 0, sampleOffset)) - center;
    float3 gradient = float3(gradX, gradY, gradZ) / sampleOffset;
    return normalize(baseNormalWS - gradient * _NormalStrength);
}

half4 Frag(Varyings input) : SV_Target
{
    float density = GetCloudDensity(input.positionWS);
    clip(density - 0.001);

    float3 normalWS = ReconstructCloudNormal(input.positionWS, normalize(input.normalWS));
    float3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));

    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light mainLight = GetMainLight(shadowCoord);
    float3 lightDirWS = normalize(mainLight.direction);

    float ndotl = saturate(dot(normalWS, lightDirWS));
    float viewFacing = saturate(dot(normalWS, viewDirWS));
    float edgeFade = pow(saturate(1.0 - viewFacing), _EdgeFadePower);
    float backscatter = pow(saturate(dot(viewDirWS, -lightDirWS)), _BackscatterPower) * _BackscatterStrength * (1.0 - ndotl);
    float rim = pow(saturate(1.0 - viewFacing), _RimPower) * _RimStrength;

    float litTerm = saturate(mainLight.shadowAttenuation * ndotl + backscatter + rim);
    float3 cloudColor = lerp(_ShadowColor.rgb, _BrightColor.rgb, litTerm);
    cloudColor += _BrightColor.rgb * _AmbientStrength * (0.35 + edgeFade * 0.65);
    cloudColor *= mainLight.color;

    float distanceToCamera = distance(input.positionWS, _WorldSpaceCameraPos.xyz);
    float distanceFade = 1.0 - saturate((distanceToCamera - _DistanceFadeStart) / max(_DistanceFadeRange, 0.001));
    float alpha = density * _Alpha * distanceFade * saturate(0.35 + edgeFade);

    cloudColor = MixFog(cloudColor, input.fogFactor);
    return half4(cloudColor, alpha);
}

#endif

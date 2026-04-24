#ifndef PARALLAX_CLOUD_FORWARD_INCLUDED
#define PARALLAX_CLOUD_FORWARD_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;
float4 _Color;
float4 _BrightColor;
float4 _ShadowColor;
float4 _UV1Speed;
float4 _UV2TilingSpeed;
float _Height;
float _HeightAmount;
float _ViewZBias;
float _LinearStepCount;
float _BinaryStepCount;
float _Alpha;
float _MainLightStrength;
float _AmbientStrength;
float _ForwardScattering;
float _RimPower;
float _RimStrength;
CBUFFER_END

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 uv2 : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float3 tangentWS : TEXCOORD3;
    float3 bitangentWS : TEXCOORD4;
    float3 viewDirWS : TEXCOORD5;
    float fogFactor : TEXCOORD6;
    float4 color : COLOR;
};

float4 SampleCloud(float2 uv)
{
    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
}

float4 SampleCloudLod(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 0);
}

float2 WrapUv(float2 uv)
{
    return frac(uv);
}

float3 GetViewDirTS(Varyings input)
{
    float3 viewDirWS = SafeNormalize(input.viewDirWS);
    return float3(
        dot(viewDirWS, input.tangentWS),
        dot(viewDirWS, input.bitangentWS),
        dot(viewDirWS, input.normalWS)
    );
}

float3 RaymarchParallaxUv(Varyings input, out float4 surfaceTex, out float4 distortionTex)
{
    float3 viewDirTS = GetViewDirTS(input);
    float3 rayDir = normalize(-viewDirTS);
    rayDir.z = abs(rayDir.z) + _ViewZBias;
    rayDir.xy *= _Height;

    distortionTex = SampleCloud(input.uv2);
    float heightAmount = max(distortionTex.a * _HeightAmount, 1e-4);

    float3 shadeP = float3(input.uv, 0.0);
    float linearSteps = clamp(_LinearStepCount, 1.0, 64.0);
    float3 linearStep = rayDir / (rayDir.z * (linearSteps + 1.0));

    [loop]
    for (int i = 0; i < 64; i++)
    {
        if (i >= (int)linearSteps)
        {
            break;
        }

        float4 cloud = SampleCloudLod(WrapUv(shadeP.xy));
        float depth = 1.0 - cloud.a * heightAmount;
        if (shadeP.z > depth)
        {
            break;
        }

        shadeP += linearStep;
    }

    float binarySteps = clamp(_BinaryStepCount, 0.0, 8.0);
    float3 refineStep = linearStep * 0.5;

    [loop]
    for (int j = 0; j < 8; j++)
    {
        if (j >= (int)binarySteps)
        {
            break;
        }

        float4 cloud = SampleCloudLod(WrapUv(shadeP.xy));
        float depth = 1.0 - cloud.a * heightAmount;
        shadeP += refineStep * sign(depth - shadeP.z);
        refineStep *= 0.5;
    }

    surfaceTex = SampleCloud(WrapUv(shadeP.xy));
    return shadeP;
}

Varyings vert(Attributes input)
{
    Varyings output;
    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    float2 uvBase = TRANSFORM_TEX(input.uv, _MainTex);
    output.positionCS = positionInputs.positionCS;
    output.uv = uvBase + _UV1Speed.xy * _Time.y;
    output.uv2 = input.uv * _UV2TilingSpeed.xy + _UV2TilingSpeed.zw * _Time.y;
    output.normalWS = NormalizeNormalPerVertex(normalInputs.normalWS);
    output.tangentWS = SafeNormalize(normalInputs.tangentWS);
    output.bitangentWS = SafeNormalize(normalInputs.bitangentWS);
    output.viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
    output.fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
    output.color = input.color;
    return output;
}

half4 frag(Varyings input) : SV_Target
{
    float4 surfaceTex;
    float4 distortionTex;
    RaymarchParallaxUv(input, surfaceTex, distortionTex);

    Light mainLight = GetMainLight();
    float3 normalWS = SafeNormalize(input.normalWS);
    float3 viewDirWS = SafeNormalize(input.viewDirWS);
    float3 lightDirWS = SafeNormalize(mainLight.direction);

    float lambert = saturate(dot(normalWS, lightDirWS));
    float forwardScatter = pow(saturate(dot(-lightDirWS, viewDirWS)), max(_ForwardScattering, 0.001));
    float DOV = abs(dot(normalWS, viewDirWS));
    float rim = pow(saturate(1.0 - DOV), max(_RimPower, 0.001)) * _RimStrength;

    float3 ambient = SampleSH(normalWS) * _AmbientStrength;
    float lightTerm = saturate(lambert * _MainLightStrength + forwardScatter * 0.65);
    float3 litColor = lerp(_ShadowColor.rgb, _BrightColor.rgb * mainLight.color, lightTerm);

    float3 color = surfaceTex.rgb * distortionTex.rgb * _Color.rgb;
    color *= (litColor + ambient);
    color += rim * _BrightColor.rgb;
    color = MixFog(color, input.fogFactor);

    float vertexFade = max(input.color.a, input.color.r);
    float heightFade = saturate(distortionTex.a);
    float alpha = vertexFade * heightFade * _Alpha * surfaceTex.a * smoothstep(0.05,0.2, DOV);

    return half4(color, alpha);
}

#endif

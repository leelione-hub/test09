#ifndef CUSTOM_PBR_FORWARD_INCLUDE
#define CUSTOM_PBR_FORWARD_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

// GLES2 has limited amount of interpolators
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

struct Attributes
{
    float4 positionOS   : POSITION;
    float2 uv           : TEXCOORD0;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    float3 positionWS   : TEXCOORD0;
    float3 normalWS     : TEXCOORD1;
    float4 tangentWS    : TEXCOORD2;
    float2 uv           : TEXCOORD3;
};

Varyings Vert(Attributes input)
{
    Varyings output;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionCS = vertexInput.positionCS;
    output.positionWS = vertexInput.positionWS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.normalWS = normalInput.normalWS;
    output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w);

    return output;
}

half4 Frag(Varyings input) : SV_Target
{
    float2 uv = input.uv;
                
    float4 baseMapSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;
    float3 baseColor = baseMapSample.rgb;
    half alpha = baseMapSample.a;
                
    float metallic = SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, uv).r * _Metallic;
    float roughness = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, uv).r * _Roughness;
    roughness = max(roughness, 0.04); 

    float occlusion = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).r;
    occlusion = lerp(1.0, occlusion, _OcclusionStrength);

    // Normal Map
    float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv), _BumpScale);
    float3 normalWS = normalize(input.normalWS);
    float3 tangentWS = normalize(input.tangentWS.xyz);
    float3 bitangentWS = cross(normalWS, tangentWS) * input.tangentWS.w;
    float3x3 TBN = float3x3(tangentWS, bitangentWS, normalWS);
    

    // --- Lighting ---
    float4 finalColor = float4(0, 0, 0,alpha);
    
    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light light = GetMainLight(shadowCoord);
    

    // ---- 2. 基础向量 ----
    float3 N = normalize(mul(normalTS, TBN)); 
    float3 V = normalize(GetCameraPositionWS() - input.positionWS);
    float3 L = normalize(light.direction);
    float3 H = normalize(V + L);
    
    
    float NdotL = saturate(dot(N, L));
    float NdotV = saturate(dot(N, V));
    float NdotH = saturate(dot(N, H));
    float LdotH = saturate(dot(L, H));
    
    
    // ===== Diffuse =====
    //half3 diffuseTerm = DisneyDiffuse(NdotV, NdotL, LdotH, roughness, baseColor);
    half3 diffuseTerm = URPDiffuse(metallic,baseColor);
    
    // ===== Specular GGX =====
    float3 F0 = lerp(float3(0.04, 0.04, 0.04), baseColor, metallic);
    half3 F = Custom_SchlickFresnel(F0,LdotH);
    half D = 0;
    
#ifdef _ANISOTROPY
    float3 T = normalize(tangentWS - dot(tangentWS,N) * N);
    float3 B = normalize(cross(N,T)) * input.tangentWS.w;
    real aspect = sqrt(1.0 - _Anisotropy * 0.9);
    real ax = max(0.001,Sq(roughness) / aspect);
    real ay = max(0.001,Sq(roughness) * aspect);
    D = Custom_D_GGX_Anisotropic(NdotH,H,T,B,ax,ay);
#else
    D = Custom_D_GGX(NdotH,roughness);
#endif
    half G = Custom_V_SmithGGX(NdotV,NdotL,roughness);
    half3 specularTerm = (D * G * F) / max(4.0 * NdotV * NdotL,1e-7);
    
    // ====== Sheen ======、
    half3 sheenTerm = half3(0,0,0);
#ifdef _SHEEN
    half3 sheenColor = lerp(half3(1,1,1),baseColor,_SheenTint);
    sheenTerm = DisneySheen(LdotH,sheenColor) * _Sheen;
#endif

    if (NdotL >= 0.0)
    {
        // Energy Conservation (kS = F, kD = 1-kS)
        real3 kS = F;
        real3 kD = (1.0 - kS) * (1.0 - metallic);
        
        finalColor.rgb += (kD * diffuseTerm + specularTerm + sheenTerm) * light.color * (light.distanceAttenuation * light.shadowAttenuation) * NdotL;
    }

# ifdef _EMISSION
    // ===== Emission =====
    half3 emissionColor = SAMPLE_TEXTURE2D(_EmissionMap,sampler_EmissionMap,input.uv).rgb * _EmissionColor.rgb;
    finalColor.rgb += emissionColor;
#endif
    
    // ===== IBL =====
    float3 bakedGI = SampleSH(N);
    float3 kD_IBL = (1.0 - metallic); 
    float3 diffuseGI = bakedGI * baseColor * kD_IBL;

    float3 reflectVector = reflect(-V, N);
    float3 reflection = GlossyEnvironmentReflection(reflectVector, roughness, 1.0);
    float3 F_IBL = Custom_SchlickFresnel(F0 ,NdotV);
    float3 specularGI = reflection * F_IBL;
    
#ifdef _ALPHATEST_ON
        clip(_Cutoff - alpha);
#endif

    finalColor.rgb += (diffuseGI + specularGI);

# ifdef _CLEARCOAT
    // ====== ClearCoat
    real coatRoughness =lerp(0.1,0.001,_ClearcoatGloss);
    real3 R_Coat = reflect(-V,N);
    real3 coatReflection = GlossyEnvironmentReflection(R_Coat,
        coatRoughness,occlusion);
    real F_Coat_IBL = F_Schlick(NdotV,0.04) * _Clearcoat;
    finalColor.rgb = finalColor * (1.0 - F_Coat_IBL) + coatReflection * F_Coat_IBL;
#endif
    
    return finalColor;
}

#endif
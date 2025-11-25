Shader "Custom/URP_DisneyPBR"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo Map", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0.0, 2.0)) = 1.0

        _MetallicMap("Metallic Map", 2D) = "white" {}
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0

        _RoughnessMap("Roughness Map", 2D) = "white" {}
        _Roughness("Roughness", Range(0.0, 1.0)) = 0.5
        
        _OcclusionMap("Occlusion Map", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Range(0.0, 1.0)) = 1.0
    }

    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque" 
            "RenderPipeline"="UniversalPipeline" 
            "Queue"="Geometry" 
        }

        // ------------------------------------------------------------------
        // 1. Forward Lit Pass (主要的渲染 Pass)
        // ------------------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            
            // URP Keywords - 确保阴影和光照正确编译
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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

            // 材质属性定义
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST; // 必须存在以支持 TRANSFORM_TEX
                float _Metallic;
                float _Roughness;
                float _NormalScale;
                float _OcclusionStrength;
            CBUFFER_END

            TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);      SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MetallicMap);    SAMPLER(sampler_MetallicMap);
            TEXTURE2D(_RoughnessMap);   SAMPLER(sampler_RoughnessMap);
            TEXTURE2D(_OcclusionMap);   SAMPLER(sampler_OcclusionMap);

            // --- Disney BRDF Functions ---

            float Custom_Sq(float x) { return x * x; }

            float3 F_Schlick(float u, float3 f0) 
            {
                return f0 + (1.0 - f0) * pow(max(1.0 - u, 0.0), 5.0);
            }

            // Disney Burley Diffuse
            float3 DisneyDiffuse(float NdotV, float NdotL, float LdotH, float roughness, float3 baseColor)
            {
                float fd90 = 0.5 + 2.0 * roughness * Custom_Sq(LdotH);
                float lightScatter = 1.0 + (fd90 - 1.0) * pow(max(1.0 - NdotL, 0.0), 5.0);
                float viewScatter = 1.0 + (fd90 - 1.0) * pow(max(1.0 - NdotV, 0.0), 5.0);
                return (baseColor / PI) * lightScatter * viewScatter;
            }

            // GGX Distribution
            float Custom_D_GGX(float NdotH, float roughness) 
            {
                float a = Custom_Sq(roughness);
                float a2 = Custom_Sq(a);
                float denom = PI * Custom_Sq(Custom_Sq(NdotH) * (a2 - 1.0) + 1.0);
                return a2 / max(denom, 1e-7);
            }

            // Smith-Schlick GGX (Disney mapping)
            float G_SchlickGGX(float NdotV, float roughness) 
            {
                // Disney modification for direct lighting hotness reduction
                float r = roughness + 1.0;
                float k = (r * r) / 8.0; 
                
                float denom = NdotV * (1.0 - k) + k;
                return NdotV / max(denom, 1e-7);
            }

            float G_Smith(float NdotV, float NdotL, float roughness) 
            {
                return G_SchlickGGX(NdotV, roughness) * G_SchlickGGX(NdotL, roughness);
            }

            // --- Lighting Logic ---

            float3 CalculateDisneyLighting(Light light, float3 N, float3 V, float3 baseColor, float metallic, float roughness)
            {
                float3 L = normalize(light.direction);
                float3 H = normalize(V + L);

                float NdotL = saturate(dot(N, L));
                float NdotV = saturate(dot(N, V));
                float NdotH = saturate(dot(N, H));
                float LdotH = saturate(dot(L, H));

                if (NdotL <= 0.0) return float3(0,0,0);

                // Diffuse
                float3 diffuseTerm = DisneyDiffuse(NdotV, NdotL, LdotH, roughness, baseColor);
                
                // Specular Setup
                float3 F0 = lerp(float3(0.04, 0.04, 0.04), baseColor, metallic);
                float3 F = F_Schlick(LdotH, F0);
                
                // Specular
                float D = Custom_D_GGX(NdotH, roughness);
                float G = G_Smith(NdotV, NdotL, roughness);
                
                // Cook-Torrance Denominator
                float3 specularTerm = (D * G * F) / max(4.0 * NdotV * NdotL, 1e-7);
                

                // Energy Conservation (kS = F, kD = 1-kS)
                float3 kS = F;
                float3 kD = (1.0 - kS) * (1.0 - metallic);

                // Final Radiance for this light
                return (kD * diffuseTerm + specularTerm) * light.color * (light.distanceAttenuation * light.shadowAttenuation) * NdotL;
            }

            Varyings vert(Attributes input)
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

            half4 frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                
                float4 baseMapSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                float3 baseColor = baseMapSample.rgb * _BaseColor.rgb;
                
                float metallic = SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, uv).r * _Metallic;
                float roughness = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, uv).r * _Roughness;
                roughness = max(roughness, 0.04); 

                float occlusion = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).r;
                occlusion = lerp(1.0, occlusion, _OcclusionStrength);

                // Normal Map
                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv), _NormalScale);
                float3 normalWS = normalize(input.normalWS);
                float3 tangentWS = normalize(input.tangentWS.xyz);
                float3 bitangentWS = cross(normalWS, tangentWS) * input.tangentWS.w;
                float3x3 TBN = float3x3(tangentWS, bitangentWS, normalWS);
                float3 N = normalize(mul(normalTS, TBN)); 

                float3 V = normalize(GetCameraPositionWS() - input.positionWS);

                // --- Lighting ---
                float3 finalColor = float3(0, 0, 0);

                // Main Light
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                finalColor += CalculateDisneyLighting(mainLight, N, V, baseColor, metallic, roughness);
                //return half4(finalColor, 1.0);
                // Additional Lights
                int pixelLightCount = GetAdditionalLightsCount();
                for (int i = 0; i < pixelLightCount; ++i)
                {
                    Light light = GetAdditionalLight(i, input.positionWS);
                    finalColor += CalculateDisneyLighting(light, N, V, baseColor, metallic, roughness);
                }

                // --- Indirect Lighting (Simplified IBL) ---
                float3 bakedGI = SampleSH(N);
                float3 kD_IBL = (1.0 - metallic); 
                float3 diffuseGI = bakedGI * baseColor * kD_IBL * occlusion;

                float3 reflectVector = reflect(-V, N);
                float3 reflection = GlossyEnvironmentReflection(reflectVector, roughness, occlusion);
                float NdotV = saturate(dot(N, V));
                float3 F0 = lerp(float3(0.04, 0.04, 0.04), baseColor, metallic);
                float3 F_IBL = F_Schlick(NdotV, F0);
                float3 specularGI = reflection * F_IBL; 

                finalColor += diffuseGI + specularGI;
                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/Meta"
    }
    
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
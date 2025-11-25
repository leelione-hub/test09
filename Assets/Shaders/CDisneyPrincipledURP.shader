// DisneyPrincipledURP.shader
Shader "Universal Render Pipeline/Custom/Disney Principled"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo (RGB) Smoothness(A)", 2D) = "white" {}
        [MainColor]   _BaseColor("Color", Color) = (1,1,1,1)

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicMap("MetallicMap",2D) = "black"{}
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5          // 实际使用 roughness = 1-smoothness
        _RoughnessMap("RoughnessMap",2D) = "white"{}
        
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Float) = 1.0

        _OcclusionMap("Occlusion", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Range(0.0,1.0)) = 1.0

        // Disney 特有参数
        _Subsurface("Subsurface", Range(0.0, 1.0)) = 0.0
        _Specular("Specular", Range(0.0, 1.0)) = 0.5
        _SpecularTint("Specular Tint", Range(0.0, 1.0)) = 0.0
        _Anisotropy("Anisotropy", Range(0.0, 1.0)) = 0.0
        _Sheen("Sheen", Range(0.0, 1.0)) = 0.0
        _SheenTint("Sheen Tint", Range(0.0, 1.0)) = 0.5
        _Clearcoat("Clearcoat", Range(0.0, 1.0)) = 0.0
        _ClearcoatRoughness("Clearcoat Roughness", Range(0.0, 1.0)) = 0.0

        // 简单透射（玻璃、玉石等）
        _Transmission("Transmission", Range(0,1)) = 0.0
        _ThicknessMap("Thickness Map", 2D) = "black" {}   // R通道表示厚度
        _IOR("Index of Refraction", Range(1.0, 3.0)) = 1.5

        [Toggle] _AlphaClipping("Alpha Clipping", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
        [Enum(Off,0,On,1)] _ZWrite("ZWrite", Float) = 1
    }

    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "Queue"="Geometry"}

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull Back

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            // URP 宏
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile _ _SCREEN_SPACE_OCCLUSION

            // 材质关键词
            #pragma shader_feature_local _ALPHACLIPPING_ON
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _TRANSMISSION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            TEXTURE2D(_BaseMap);             SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);             SAMPLER(sampler_BumpMap);
            TEXTURE2D(_OcclusionMap);        SAMPLER(sampler_OcclusionMap);
            TEXTURE2D(_ThicknessMap);        SAMPLER(sampler_ThicknessMap);
            TEXTURE2D(_MetallicMap);         SAMPLER(sampler_MetallicMap);
            TEXTURE2D(_RoughnessMap);        SAMPLER(sampler_RoughnessMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _Cutoff;

                half _Metallic;
                half _Smoothness;

                half _BumpScale;
                half _OcclusionStrength;

                half _Subsurface; // 0 = opaque, 1 = transparent (unused here)
                half _Specular;
                half _SpecularTint;
                half _Anisotropy;
                half _Sheen;
                half _SheenTint;
                half _Clearcoat;
                half _ClearcoatRoughness;
                half _Transmission;
                half _IOR;
            CBUFFER_END

            // ====================== 常用工具函数 ======================
            half DisneyLuminance(half3 color) { return dot(color, half3(0.2126, 0.7152, 0.0722)); }
            half Square(half x) { return x*x; }
            half3 SafeNormalize(half3 v) { return normalize(v + 1e-6); }

            // Schlick Fresnel
            half3 F_Schlick(half3 f0, half f90, half u) { return f0 + (f90 - f0) * pow(1.0 - u,5); }
            half F_Schlick(half f0, half f90, half u) { return f0 + (f90 - f0) * pow(1.0 - u,5); }
            half Pow5(half x) { half x2 = x*x; return x2*x2*x; }

            // GGX/Trowbridge-Reitz NDF
            half D_GGX(half NoH, half roughness)
            {
                half a = roughness * roughness;
                half a2 = a * a;
                half f = (NoH * a2 - NoH) * NoH + 1.0;
                return a2 / max(PI * f * f, 1e-6);
            }

            // Smith Joint GGX Visibility
            half V_SmithGGXCorrelated(half NoV, half NoL, half roughness)
            {
                half a2 = roughness * roughness;
                half lambdaV = NoL * sqrt((NoV - a2 * NoV) * NoV + a2);
                half lambdaL = NoV * sqrt((NoL - a2 * NoL) * NoL + a2);
                return 0.5 / max(lambdaV + lambdaL, 1e-6);
            }

            // Disney Diffuse (normalized energy-conserving)
            half Fd_Burley(half NoV, half NoL, half LoH, half roughness)
            {
                half f90 = 0.5 + 2.0 * roughness * LoH * LoH;
                half lightScatter = F_Schlick(1.0, f90, NoL);
                half viewScatter  = F_Schlick(1.0, f90, NoV);
                return lightScatter * viewScatter * (1.0 / PI);
            }

            // Sheen (布料绒毛)
            half3 SheenBRDF(half3 sheenColor, half LoH)
            {
                half sheen = Pow5(1 - LoH);
                return sheenColor * sheen;
            }

            // Clearcoat (Disney 25% fixed)
            half D_GGX_Clearcoat(half NoH, half roughness)
            {
                roughness = lerp(0.1, 1.0, roughness); // clearcoat 更光滑
                half a = roughness * roughness;
                half a2 = a * a;
                half d = (NoH * a2 - NoH) * NoH + 1.0;
                return a2 / (PI * d * d);
            }

            // ====================== 主函数 ======================
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                half3 normalWS    : TEXCOORD2;
                half4 tangentWS   : TEXCOORD3; // xyz: tangent, w: sign
                half3 viewDirWS   : TEXCOORD4;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5);
                float4 fogFactorAndVertexLight : TEXCOORD6; // x: fogFactor, yzw: vertex light
                float4 shadowCoord : TEXCOORD7;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);

                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.positionWS = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;
                output.normalWS = normalInput.normalWS;
                output.tangentWS = half4(normalInput.tangentWS.xyz, input.tangentOS.w * GetOddNegativeScale());
                output.viewDirWS = viewDirWS;

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

                half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                output.fogFactorAndVertexLight.x = fogFactor;
                output.fogFactorAndVertexLight.yzw = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

                output.shadowCoord = GetShadowCoord(vertexInput);
                return output;
            }

            half4 LitPassFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // ===== 采样贴图 =====
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                half4 metallicMap = SAMPLE_TEXTURE2D(_MetallicMap,sampler_MetallicMap,input.uv);
                half4 roughnessMap = SAMPLE_TEXTURE2D(_RoughnessMap,sampler_RoughnessMap,input.uv);
                #ifdef _ALPHACLIPPING_ON
                    clip(baseMap.a - _Cutoff);
                #endif

                half3 albedo = baseMap.rgb;

                half metallic = metallicMap.r;
                half smoothness = _Smoothness;
                half roughness = roughnessMap.r;
                half roughness2 = roughness * roughness;

                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv), _BumpScale);
                half3 normalWS = TransformTangentToWorld(normalTS,
                    half3x3(input.tangentWS.xyz, cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w, input.normalWS));
                normalWS = NormalizeNormalPerPixel(normalWS);

                half3 viewDirWS = SafeNormalize(input.viewDirWS);
                half3 lightDirWS = normalize(_MainLightPosition.xyz);
                half3 halfDirWS = SafeNormalize(lightDirWS + viewDirWS);

                half NoV = saturate(dot(normalWS, viewDirWS));
                half NoL = saturate(dot(normalWS, lightDirWS));
                half NoH = saturate(dot(normalWS, halfDirWS));
                half LoH = saturate(dot(lightDirWS, halfDirWS));

                // ===== Disney 基础颜色分离 =====
                half3 c_diff = lerp(albedo, 0, metallic);                 // 漫反射颜色（金属无漫反射）
                half3 c_spec = lerp(0.08 * _Specular, albedo, metallic);  // 基础镜面颜色（电介质0.08可调）

                // Specular Tint
                half luminance = DisneyLuminance(c_diff);
                c_spec = lerp(c_spec, luminance, _SpecularTint);
                
                // ===== Diffuse =====
                half3 diffuse = c_diff * Fd_Burley(NoV, NoL, LoH, roughness);
                
                
                // ===== Specular GGX =====
                half3 F = F_Schlick(c_spec, 1.0, LoH);
                half D = D_GGX(NoH, roughness2);
                half Vis = V_SmithGGXCorrelated(NoV, NoL, roughness2);
                half3 specular = F * D * Vis;

                //return half4(specular,1);
                // ===== Anisotropy (简化版) =====
                if (_Anisotropy > 0.0)
                {
                    // 简单拉伸粗糙度
                    half aspect = sqrt(1.0 - 0.9 * _Anisotropy);
                    half rx = roughness / aspect;
                    half ry = roughness * aspect;
                    // 这里可以换成更完整的各向异性模型，篇幅原因省略
                }

                // ===== Sheen =====
                half3 sheenColor = lerp(1.0, albedo, _SheenTint);
                half3 sheen = SheenBRDF(sheenColor * _Sheen, LoH);

                // ===== Clearcoat =====
                half Fcc = F_Schlick(0.04, 1.0, LoH) * _Clearcoat;
                half Dcc = D_GGX_Clearcoat(NoH, _ClearcoatRoughness);
                half Vcc = V_SmithGGXCorrelated(NoV, NoL, _ClearcoatRoughness * _ClearcoatRoughness);
                half clearcoat = Fcc * Dcc * Vcc * 0.25 * _Clearcoat;  // 0.25 是Disney固定系数

                // ===== Subsurface 简单近似（用wrap lighting）=====
                half subsurface = _Subsurface * (NoL * 0.5 + 0.5);

                // ===== 最终组合 =====
                half3 color = diffuse * (1 - subsurface) + specular;
                color = color * (1.0 - Fcc) + clearcoat;           // clearcoat 在最上层
                color += sheen;
                color += diffuse * subsurface * half3(0.6, 0.3, 0.3); // 简单红移

                // ===== 主光照 =====
                half3 mainLightColor = _MainLightColor.rgb * NoL;
                #ifdef _MAIN_LIGHT_SHADOWS
                    half shadow = MainLightRealtimeShadow(input.shadowCoord);
                    mainLightColor *= shadow;
                #endif
                half3 radiance = mainLightColor * color;

                // ===== 额外光源 =====
                #ifdef _ADDITIONAL_LIGHTS
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS);
                    half3 L = light.direction;
                    half3 H = SafeNormalize(L + viewDirWS);
                    half thisNoL = saturate(dot(normalWS, L));
                    half thisLoH = saturate(dot(L, H));
                    half thisNoH = saturate(dot(normalWS, H));

                    half3 thisDiffuse = c_diff * Fd_Burley(NoV, thisNoL, thisLoH, roughness);
                    half3 thisF = F_Schlick(c_spec, 1.0, thisLoH);
                    half thisD = D_GGX(thisNoH, roughness2);
                    half thisVis = V_SmithGGXCorrelated(NoV, thisNoL, roughness2);
                    half3 thisSpecular = thisF * thisD * thisVis;

                    radiance += (thisDiffuse + thisSpecular) * light.color * light.distanceAttenuation * thisNoL;
                }
                #endif

                // ===== 环境光 + Fog =====
                half3 indirectDiffuse = SampleSH(normalWS) * c_diff * (1 - metallic);
                half3 indirectSpecular = GlossyEnvironmentReflection(reflect(-viewDirWS, normalWS), roughness, 1.0);

                radiance += indirectDiffuse + indirectSpecular * F_Schlick(c_spec, 1.0, NoV);
                radiance = MixFog(radiance, input.fogFactorAndVertexLight.x);

                return half4(radiance, baseMap.a);
            }
            ENDHLSL
        }

        // ShadowCaster、DepthOnly、Meta 等 Pass 可直接使用 URP 自带的 Lit 模板
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/Meta"
    }

    FallBack "Universal Render Pipeline/Lit"
    //CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.LitShader"
}
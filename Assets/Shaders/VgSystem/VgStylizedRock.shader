Shader "URP/VgSystem/StylizedRock"
{
    Properties
    {
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [Main(Preset, _, off, off)] _PresetGroup("Render Preset", Float) = 0
        [Preset(Preset, LWGUI_Preset_BlendMode)] _BlendMode("Blend Mode Preset", Float) = 0
        [SubEnum(Preset, UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2.0
        [SubToggle(Preset,_ALPHATEST_ON)] _AlphaClip("Alpha Clip", Float) = 0.0
        [SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1.0
        [SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0.0
        [HideInInspector] _SrcBlendAlpha("__srcA", Float) = 1.0
        [HideInInspector] _DstBlendAlpha("__dstA", Float) = 0.0
        [SubEnum(Preset, UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
        [SubToggle(Preset)] _ZWrite("ZWrite", Float) = 1.0

        [Toggle(GRAPHICDRAW_ON)] _GraphicDraw("Use GraphicsBuffer Instances", Float) = 1

        [Main(Base, _, on, off)] _BaseGroup("Base", Float) = 1
        [Sub(Base)][MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Sub(Base)][MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
        [Sub(Base)] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [Sub(Base)] _Alpha("Alpha", Range(0, 1)) = 1
        [Sub(Base)][NoScaleOffset] _MixTexNR("Mix Tex (NR)", 2D) = "bump" {}
        [HideInInspector] _TilingOffset("Tiling Offset", Vector) = (1,1,0,0)
        [Sub(Base)] _RockNormalIntensity("Rock Normal Intensity", Range(0, 5)) = 1
        [Sub(Base)] _RockRoughnessMin("Rock Roughness Min", Range(0, 1)) = 0
        [Sub(Base)] _RockRoughnessMax("Rock Roughness Max", Range(0, 1)) = 1
        
        [Main(Biplanar, _BIPLANAR_ON, off)] _BiplanarGroup("Biplanar", Float) = 0
        [Sub(Biplanar)] _BiplanarRockTiling("Biplanar Rock Tiling", Vector) = (0.3,0.3,0,0)

        [Main(Overlay, _OVERLAY_ON, off)] _OverlayGroup("Overlay", Float) = 0
        [SubToggle(Overlay,_OVERLAYADD_ON)] _overlay("Overlay Add", Float) = 1
        [Sub(Overlay)][NoScaleOffset] _OverlayTex("Overlay Tex", 2D) = "white" {}
        [Sub(Overlay)][NoScaleOffset] _OverlayNormal("Overlay Normal", 2D) = "bump" {}
        [HideInInspector] _OverlayTexScale("Overlay Tex Scale", Range(0, 10)) = 1
        [Sub(Overlay)] _OverlayColor("Overlay Color", Color) = (1,1,1,0)
        [Sub(Overlay)] _BlendScale("Blend Scale", Range(0, 1)) = 0.5
        [Sub(Overlay)] _ColorBlendScale("Color Blend Scale", Range(0, 1)) = 0.5

        [Main(Moss, _USEGROSS, off)] _MossGroup("Moss", Float) = 0
        [Sub(Moss)][NoScaleOffset] _MossBase("Moss Tex", 2D) = "white" {}
        [Sub(Moss)] _MossUV("Moss UV", Vector) = (1,1,0,0)
        [HideInInspector] _MossTint("Moss Tint", Color) = (1,1,1,1)
        [Sub(Moss)] _MossRoughnessMin("Moss Roughness Min", Range(0, 1)) = 0
        [Sub(Moss)] _MossRoughnessMax("Moss Roughness Max", Range(0, 1)) = 1
        [Sub(Moss)] _NoiseMin("Noise Min", Range(-1, 1)) = -0.3
        [Sub(Moss)] _NoiseMax("Noise Max", Range(-1, 1)) = 1
        [Sub(Moss)] _MossContrast("Moss Contrast", Range(0.01, 3)) = 1

        [Main(Terrain, _BLENDTERRAIN_ON, off)] _TerrainGroup("Terrain Blend", Float) = 0
        [Sub(Terrain)] _BlendRange("Blend Range", Vector) = (0,0.2,0,0)
        [Sub(Terrain)] _TerrainBrightness("Terrain Brightness", Float) = 1

        [Main(Paint, _PAINTONLYCOLOR_ON, off)] _PaintGroup("Paint", Float) = 0

        [Main(Lighting, _, off, off)] _LightingGroup("Lighting", Float) = 0
        [SubToggle(Lighting,_SPECULARHIGHLIGHTS)] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [SubToggle(Lighting,_ENVIRONMENTREFLECTIONS)] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [Sub(Lighting)][KeywordEnum(Lambert,HalfLambert)] _Lambert("Diffuse Mode", Float) = 0
        [Sub(Lighting)] _BackBrightness("Back Brightness", Range(-1, 0)) = -1.0
        [Sub(Lighting)] _ShadowStrength("Shadow Strength", Range(0.0, 1.0)) = 1.0
        [SubToggle(Lighting,_SSAO)] _SSAO("Has SSAO", Float) = 0
        [Sub(Lighting)] _AOStrength("SSAO Strength", Range(0.0, 1.0)) = 1.0

    }

    HLSLINCLUDE
        #include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float _Cutoff;
            float _Alpha;
            float _RockRoughnessMax;
            float4 _BaseMap_ST;
        CBUFFER_END

        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);

        struct Attributes
        {
            float3 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float2 uv : TEXCOORD0;
            uint instanceID : SV_InstanceID;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 positionWS : TEXCOORD1;
            float3 normalWS : TEXCOORD2;
        };

        float3 _LightDirection;
        float3 _LightPosition;

        Varyings ForwardVert(Attributes input)
        {
            Varyings output = (Varyings)0;
            UNITY_SETUP_INSTANCE_ID(input);
            float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
            output.positionCS = TransformWorldToHClip(positionWS);
            output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
            output.positionWS = positionWS;
            output.normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));
            return output;
        }

        half VgRockDiffuseTerm(half3 normalWS, half3 lightDirWS)
        {
            half ndl = dot(normalWS, lightDirWS);
            #if defined(_LAMBERT_HALFLAMBERT)
            return saturate(ndl * 0.5h + 0.5h);
            #else
            return saturate(ndl);
            #endif
        }

        half3 VgRockSpecularTerm(half3 normalWS, half3 lightDirWS, half3 viewDirWS, half3 lightColor)
        {
            #if defined(_SPECULARHIGHLIGHTS)
            half3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
            half ndh = saturate(dot(normalWS, halfDir));
            half exponent = lerp(64.0h, 4.0h, saturate(_RockRoughnessMax));
            return lightColor * pow(ndh, exponent);
            #else
            return 0;
            #endif
        }

        half3 VgRockEnvironmentReflection(half3 normalWS, half3 viewDirWS, float3 positionWS, float2 normalizedScreenSpaceUV)
        {
            #if defined(_ENVIRONMENTREFLECTIONS)
            half3 reflectVector = reflect(-viewDirWS, normalWS);
            return GlossyEnvironmentReflection(reflectVector, positionWS, saturate(_RockRoughnessMax), 1.0h, normalizedScreenSpaceUV);
            #else
            return 0;
            #endif
        }

        half4 ForwardFrag(Varyings input) : SV_Target
        {
            half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
            #if defined(_ALPHATEST_ON)
            clip(tex.a * _Alpha - _Cutoff);
            #endif

            half3 albedo = tex.rgb * _BaseColor.rgb;
            half3 normalWS = normalize(input.normalWS);
            half3 viewDirWS = SafeNormalize(_WorldSpaceCameraPos - input.positionWS);
            float2 normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
            float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
            Light mainLight = GetMainLight(shadowCoord);
            half NdotL = VgRockDiffuseTerm(normalWS, mainLight.direction);

            half3 lighting = SampleSH(normalWS);
            lighting += mainLight.color * (mainLight.distanceAttenuation * mainLight.shadowAttenuation * NdotL);
            lighting += VgRockSpecularTerm(normalWS, mainLight.direction, viewDirWS, mainLight.color) * (mainLight.distanceAttenuation * mainLight.shadowAttenuation);
            lighting += VgRockEnvironmentReflection(normalWS, viewDirWS, input.positionWS, normalizedScreenSpaceUV);

            #if defined(_ADDITIONAL_LIGHTS)
            InputData inputData = (InputData)0;
            inputData.positionWS = input.positionWS;
            inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

            half4 shadowMask = half4(1, 1, 1, 1);
            uint meshRenderingLayers = GetMeshRenderingLayer();
            uint pixelLightCount = GetAdditionalLightsCount();

            #if USE_FORWARD_PLUS
            UNITY_LOOP for (uint lightIndex = 0u; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
            {
                FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

                Light light = GetAdditionalLight(lightIndex, input.positionWS, shadowMask);
                half atten = light.distanceAttenuation * light.shadowAttenuation;
                half addNdotL = VgRockDiffuseTerm(normalWS, light.direction);

                #ifdef _LIGHT_LAYERS
                if (!IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                {
                    continue;
                }
                #endif

                lighting += light.color * (atten * addNdotL);
                lighting += VgRockSpecularTerm(normalWS, light.direction, viewDirWS, light.color) * atten;
            }
            #endif

            LIGHT_LOOP_BEGIN(pixelLightCount)
                Light light = GetAdditionalLight(lightIndex, input.positionWS, shadowMask);
                half atten = light.distanceAttenuation * light.shadowAttenuation;
                half addNdotL = VgRockDiffuseTerm(normalWS, light.direction);

                #ifdef _LIGHT_LAYERS
                if (!IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                {
                    continue;
                }
                #endif

                lighting += light.color * (atten * addNdotL);
                lighting += VgRockSpecularTerm(normalWS, light.direction, viewDirWS, light.color) * atten;
            LIGHT_LOOP_END
            #endif

            return half4(albedo * lighting, tex.a * _BaseColor.a * _Alpha);
        }

        Varyings DepthVert(Attributes input)
        {
            return ForwardVert(input);
        }

        half DepthFrag(Varyings input) : SV_Target
        {
            half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
            #if defined(_ALPHATEST_ON)
            clip(tex.a * _Alpha - _Cutoff);
            #endif
            return input.positionCS.z;
        }

        half4 DepthNormalsFrag(Varyings input) : SV_Target
        {
            half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
            #if defined(_ALPHATEST_ON)
            clip(tex.a * _Alpha - _Cutoff);
            #endif
            return half4(normalize(input.normalWS), 0.0);
        }

        Varyings ShadowVert(Attributes input)
        {
            Varyings output = (Varyings)0;
            UNITY_SETUP_INSTANCE_ID(input);
            float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
            float3 normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));

            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
            float3 lightDirectionWS = normalize(_LightPosition - positionWS);
            #else
            float3 lightDirectionWS = _LightDirection;
            #endif

            float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
            #if UNITY_REVERSED_Z
            positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #else
            positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #endif

            output.positionCS = positionCS;
            output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
            return output;
        }

        half4 ShadowFrag(Varyings input) : SV_Target
        {
            half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
            #if defined(_ALPHATEST_ON)
            clip(tex.a * _Alpha - _Cutoff);
            #endif
            return 0;
        }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZWrite[_ZWrite]
            ZTest[_ZTest]
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ForwardVert
            #pragma fragment ForwardFrag
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS
            #pragma shader_feature_local _PAINTONLYCOLOR_ON
            #pragma shader_feature_local_fragment _BLENDTERRAIN_ON
            #pragma shader_feature_local_fragment _USEGROSS
            #pragma shader_feature_local_fragment _BIPLANAR_ON
            #pragma shader_feature_local_fragment _OVERLAY_ON
            #pragma shader_feature_local_fragment _OVERLAYADD_ON
            #pragma shader_feature_local_fragment _LAMBERT_HALFLAMBERT
            #pragma shader_feature_local_fragment _SSAO
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex DepthVert
            #pragma fragment DepthFrag
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }
            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex DepthVert
            #pragma fragment DepthNormalsFrag
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

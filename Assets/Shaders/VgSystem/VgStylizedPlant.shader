Shader "URP/VgSystem/StylizedPlant"
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
        [HideInInspector] _AlphaToMask("__alphaToMask", Float) = 0.0
        [HideInInspector][ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
        [HideInInspector] _QueueOffset("QueueOffset", Float) = 0

        [Toggle(GRAPHICDRAW_ON)] _GraphicDraw("Use GraphicsBuffer Instances", Float) = 1

        [Main(Base, _, on, off)] _BaseGroup("Base", Float) = 1
        [Sub(Base)][MainTexture] _MainTex("Albedo", 2D) = "white" {}
        [Sub(Base)][MainColor] _Color("Color", Color) = (1,1,1,1)
        [Sub(Base)] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [Sub(Base)] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        [Sub(Base)] _Roughness("Roughness", Range(0.0, 1.0)) = 0.5
        [Sub(Base)] _Alpha("Alpha", Range(0, 1)) = 1
        
        [Main(NRM, _NRM_ON, off)] _NRMGroup("NRM", Float) = 0
        [Sub(NRM)][NoScaleOffset] _NRMTex("NRM Tex", 2D) = "white" {}
        [Sub(NRM)] _BumpScale("Normal Intensity", Range(0.0, 3.0)) = 1.0
        [Sub(NRM)] _NormalBack("Normal Back", Range(0, 1)) = 1
        [Sub(NRM)] _RoughnessMin("Roughness Min", Range(0.0, 1.0)) = 0

        [Main(Lighting, _, off, off)] _LightingGroup("Lighting", Float) = 0
        [Sub(Lighting)] _BackFaceShadowInt("BackFaceShaderInt", Range(0, 1)) = 1
        [Sub(Lighting)] _GIInt("GIColor Strength", Range(0, 10)) = 2.5
        [Sub(Lighting)] _MainLightInt("MainLight Strength", Range(0, 10)) = 0.5
        [Sub(Lighting)] _EdgeBrightIntensity("Edge Bright Intensity", Float) = 1
        [Sub(Lighting)] _EdgeBrightScale("Edge Bright Scale", Range(0, 10)) = 5
        [Sub(Lighting)] _EdgeBrightColor("Edge Bright Color", Color) = (1,1,1,0)
        [SubToggle(Lighting,_SPECULARHIGHLIGHTS)] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [SubToggle(Lighting,_ENVIRONMENTREFLECTIONS)] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [Sub(Lighting)][KeywordEnum(Lambert,HalfLambert)] _Lambert("Diffuse Mode", Float) = 0
        [Sub(Lighting)] _BackBrightness("Back Brightness", Range(-1, 0)) = -1.0
        [Sub(Lighting)] _ShadowStrength("Shadow Strength", Range(0.0, 1.0)) = 1.0
        [SubToggle(Lighting,_SSAO)] _SSAO("Has SSAO", Float) = 0
        [Sub(Lighting)] _AOStrength("SSAO Strength", Range(0.0, 1.0)) = 1.0

        [Main(Wind, _WIND_ON, off)] _WindGroup("Wind", Float) = 0
        [Sub(Wind)] _WindDirection("Wind Direction", Vector) = (0,0,0,0)
        [Sub(Wind)] _BendStrength("Bend Strength", Float) = 1
        [Sub(Wind)] _BendSpeed("Bend Speed", Float) = 1
        [Sub(Wind)] _BendWait("Bend Wait", Range(1, 2)) = 1
        [Sub(Wind)] _LeafStrength("Leaf Strength", Float) = 0
        [Sub(Wind)] _WindSpeed("Wind Speed", Float) = 1
        
        [Main(WindLine, _WINDLINE_ON)] _WindLine("Wind Line", Float) = 0
        [Sub(WindLine)][NoScaleOffset] _WindLineTex("Wind Line Tex", 2D) = "white" {}
        [Sub(WindLine)] _WindColorIntensity("Wind Color Intensity", Float) = 1
        [Sub(WindLine)] _WindLineDirection("Wind Line Direction", Range(0, 360)) = 0
        [Sub(WindLine)] _WindLineScale("Wind Line Scale", Float) = 1
        [Sub(WindLine)] _WindLineStrength("Wind Line Strength", Float) = 5
        [Sub(WindLine)] _WindLindSpeed("Wind Line Speed", Float) = 3

        [Main(CirceWind, _CIRCE_WIND_ON, off)] _CirceWindGroup("Circe Wind", Float) = 0
        [Sub(CirceWind)] _CirceWindDirection("Circe Wind Direction", Vector) = (0,0,0,0)
        [Sub(CirceWind)] _CirceWindSpeed("Circe Wind Speed", Range(0, 2)) = 1
        [Sub(CirceWind)] _WindStrength("Wind Strength", Range(0, 1)) = 0.2
        [Sub(CirceWind)] _WindJitter("Wind Jitter", Float) = 0.5
        [Sub(CirceWind)] _WindNoiseSize("Wind Noise Size", Float) = 5
        [Sub(CirceWind)] _NoisePower("Noise Power", Range(0, 5)) = 1

        [Main(Interaction, _, off, off)] _InteractionGroup("Interaction", Float) = 0
        [Sub(Interaction)] _InteractiveStrength("Strength", Range(0, 3)) = 0
        [Sub(Interaction)] _InteractiveRange("Range", Float) = 0

        [Main(Emission, _EMISSION_ON, off)] _EmissionGroup("Emission", Float) = 0
        [Sub(Emission)][HDR] _EmissionColor("Emission Color", Color) = (0,0,0,0)
        [Sub(Emission)][NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
        [Sub(Emission)] _EmissiveIntensity("Emissive Intensity", Range(0.0, 5.0)) = 1

        [Main(SSS, _SSS_ON, off)] _SSSGroup("Subsurface", Float) = 0
        [Sub(SSS)][HDR] _SSSColor("SSS Color", Color) = (2,2,2,0)
        [Sub(SSS)] _SSSDistortion("SSS Distortion", Range(0, 5)) = 1
        [Sub(SSS)] _SSSPower("SSS Power", Float) = 1
        [Sub(SSS)] _SSSScale("SSS Scale", Float) = 1

        [Main(Terrain, _BLEND_TERRAIN_ON, off)] _BlendTerrain("Terrain Blend", Float) = 0
        [SubToggle(Terrain,_USEGROSS)] _UseGross("Use Moss", Float) = 0
        [Sub(Terrain)][NoScaleOffset] _MossBase("Moss Tex", 2D) = "white" {}
        [Sub(Terrain)] _MossUV("Moss UV", Vector) = (1,1,0,0)
        [Sub(Terrain)] _BlendRange("Blend Range", Vector) = (0,0.2,0,0)
        [Sub(Terrain)] _TerrainBrightness("Terrain Brightness", Float) = 1

        [BitMask(Preset)] _Stencil("Stencil ID", Int) = 0

        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0
        [HideInInspector] _StencilComp("Stencil Comparison", Float) = 8
        [HideInInspector] _StencilOp("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask("Stencil Read Mask", Float) = 255
        [HideInInspector] _GUIStencilIndex("GUI Stencil Index", Float) = 101
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "AlphaTest"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
        }

        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZWrite[_ZWrite]
            ZTest[_ZTest]
            Cull[_Cull]
            AlphaToMask[_AlphaToMask]
            Stencil
            {
                Ref [_Stencil]
                Comp [_StencilComp]
                Pass [_StencilOp]
                ReadMask [_StencilReadMask]
                WriteMask [_StencilWriteMask]
            }

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS
            #pragma shader_feature_local_vertex _WIND_ON
            #pragma shader_feature_local_vertex _CIRCE_WIND_ON
            #pragma shader_feature_fragment _BLEND_TERRAIN_ON
            #pragma shader_feature_fragment _TERRAIN_BLEND_BAKED
            #pragma shader_feature_local_fragment _USEGROSS
            #pragma shader_feature_local_fragment _NRM_ON
            #pragma shader_feature_local_fragment _EMISSION_ON
            #pragma shader_feature_local_fragment _SSS_ON
            #pragma shader_feature_local_fragment _LAMBERT_HALFLAMBERT
            #pragma shader_feature_local_fragment _SSAO
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Assets/Shaders/HLSL/VgSystem/Plant/PlantIndirectInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/PlantIndirectForward.hlsl"
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
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local _ _GBUFFER_NORMALS_OCT
            #pragma shader_feature_local_vertex _WIND_ON
            #pragma shader_feature_local_vertex _CIRCE_WIND_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Assets/Shaders/HLSL/VgSystem/Plant/PlantIndirectInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/PlantDepthOnlyPass.hlsl"
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
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local _ _GBUFFER_NORMALS_OCT
            #pragma shader_feature_local_vertex _WIND_ON
            #pragma shader_feature_local_vertex _CIRCE_WIND_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Assets/Shaders/HLSL/VgSystem/Plant/PlantIndirectInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/PlantDepthNormalsPass.hlsl"
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
            #pragma vertex ShadowCasterVertex
            #pragma fragment ShadowCasterFragment
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_vertex _WIND_ON
            #pragma shader_feature_local_vertex _CIRCE_WIND_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Assets/Shaders/HLSL/VgSystem/Plant/PlantIndirectInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/PlantShadowCasterPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

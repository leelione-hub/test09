Shader "URP/VgSystem/M_Simple_Plant"
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
        [Sub(Base)][MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Sub(Base)][MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [Sub(Base)] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [Sub(Base)] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        [Sub(Base)] _Roughness("Roughness Max", Range(0.0, 1.0)) = 0.5
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
        [SubToggle(Lighting,_EDGELIGHT_ON)] _EdgeLight("Edge Light", Float) = 0
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

        [Main(Emission, _EMISSION_ON, off)] _EmissionGroup("Emission", Float) = 0
        [Sub(Emission)][HDR] _EmissionColor("Color", Color) = (0,0,0,0)
        [Sub(Emission)][NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
        [Sub(Emission)] _EmissiveIntensity("Emissive Intensity", Range(0.0, 5.0)) = 1

        [Main(SSS, _SSS_ON, off)] _SSSGroup("Subsurface", Float) = 0
        [Sub(SSS)][HDR] _SSSColor("SSS Color", Color) = (2,2,2,0)
        [Sub(SSS)] _SSSDistortion("SSS Distortion", Range(0, 5)) = 1
        [Sub(SSS)] _SSSPower("SSS Power", Float) = 1
        [Sub(SSS)] _SSSScale("SSS Scale", Float) = 1
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

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS
            #pragma shader_feature_local_vertex _WIND_ON
            #pragma shader_feature_local_fragment _NRM_ON
            #pragma shader_feature_local_fragment _EMISSION_ON
            #pragma shader_feature_local_fragment _SSS_ON
            #pragma shader_feature_local_fragment _EDGELIGHT_ON
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
            #include "Assets/Shaders/HLSL/VgSystem/Plant/M_Simple_PlantInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/M_Simple_PlantForwardPass.hlsl"
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
            #pragma shader_feature_local_vertex _WIND_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/M_Simple_PlantInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/M_Simple_PlantDepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }
            ZWrite On
            Cull[_Cull]
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_vertex _WIND_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/M_Simple_PlantInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/M_Simple_PlantDepthNormalsPass.hlsl"
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
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_vertex _WIND_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/M_Simple_PlantInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Plant/M_Simple_PlantShadowCasterPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

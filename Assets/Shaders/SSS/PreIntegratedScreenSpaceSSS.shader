Shader "Custom/SSS/PreIntegratedScreenSpaceSSS"
{
    Properties
    {
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [Main(Preset, _, off, off)] _PresetGroup("Render Preset", Float) = 0
        [Preset(Preset, LWGUI_Preset_BlendMode)] _BlendMode("Blend Mode Preset", Float) = 0
        [SubEnum(Preset, UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2.0
        [SubToggle(Preset,_ALPHATEST_ON)] _AlphaClip("Alpha Clip", Float) = 0.0
        [Sub(Preset)] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [SubEnum(Preset, UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
        [SubToggle(Preset)] _ZWrite("ZWrite", Float) = 1.0
        [HideInInspector] _AlphaToMask("__alphaToMask", Float) = 0.0
        [HideInInspector][ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
        [HideInInspector] _QueueOffset("QueueOffset", Float) = 0

        [Main(Base, _, on, off)] _BaseGroup("Base", Float) = 1
        [Sub(Base)][MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [Sub(Base)][MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        [Sub(Base)] _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.45
        [Sub(Base)] _SpecularStrength("Specular Strength", Range(0.0, 2.0)) = 0.4
        [Sub(Base)][HDR] _EmissionColor("Emission Color", Color) = (0,0,0,0)
        [Sub(Base)] _EmissionIntensity("Emission Intensity", Range(0.0, 8.0)) = 0.0

        [Main(Normal, _NORMALMAP, off)] _NormalGroup("Normal", Float) = 0
        [Sub(Normal)][NoScaleOffset] _NormalMap("Normal Map", 2D) = "bump" {}
        [Sub(Normal)] _NormalScale("Normal Scale", Range(0.0, 2.0)) = 1.0

        [Main(PreSSS, _PREINTEGRATED_SSS_ON, off)] _PreIntegratedGroup("Pre-Integrated SSS", Float) = 1
        [Sub(PreSSS)][HDR] _SSSColor("SSS Color", Color) = (1.0,0.45,0.35,1.0)
        [Sub(PreSSS)][HDR] _TransmissionColor("Transmission Color", Color) = (1.0,0.35,0.25,1.0)
        [Sub(PreSSS)][NoScaleOffset] _ThicknessMap("Thickness Map", 2D) = "white" {}
        [Sub(PreSSS)][NoScaleOffset] _SSSLUT("Pre-Integrated SSS LUT", 2D) = "white" {}
        [Sub(PreSSS)] _PreIntegratedSSSIntensity("Pre-Integrated Intensity", Range(0.0, 4.0)) = 1.0
        [Sub(PreSSS)] _ThicknessScale("Thickness Scale", Range(0.0, 4.0)) = 1.0
        [Sub(PreSSS)] _CurvatureScale("Curvature Scale", Range(0.0, 4.0)) = 1.0
        [Sub(PreSSS)] _TransmissionIntensity("Transmission Intensity", Range(0.0, 4.0)) = 1.0
        [Sub(PreSSS)] _TransmissionPower("Transmission Power", Range(0.5, 8.0)) = 2.0
        [Sub(PreSSS)] _AmbientIntensity("Ambient Intensity", Range(0.0, 2.0)) = 1.0

        [Main(WrapSSS, _WRAP_SSS_ON, off)] _WrapSSSGroup("Wrap / Thickness SSS", Float) = 0
        [Sub(WrapSSS)][HDR] _WrapSSSColor("Wrap SSS Color", Color) = (1.0,0.5,0.4,1.0)
        [Sub(WrapSSS)] _WrapLighting("Wrap Lighting", Range(0.0, 1.0)) = 0.35
        [Sub(WrapSSS)] _WrapSSSIntensity("Wrap SSS Intensity", Range(0.0, 4.0)) = 1.0
        [Sub(WrapSSS)] _WrapThicknessTransmission("Wrap Transmission", Range(0.0, 4.0)) = 1.0
        [Sub(WrapSSS)] _WrapThicknessPower("Wrap Transmission Power", Range(0.5, 8.0)) = 2.0

        [Main(ScreenSSS, _SCREEN_SPACE_SSS_ON, off)] _ScreenSpaceSSSGroup("Screen-Space SSS", Float) = 0
        [Sub(ScreenSSS)] _ScreenSpaceSSSIntensity("Mask Intensity", Range(0.0, 2.0)) = 1.0
        [Sub(ScreenSSS)] _ScreenSpaceSSSBlurScale("Blur Scale", Range(0.0, 2.0)) = 1.0
        [Sub(ScreenSSS)] _ScreenSpaceSSSDepthWeight("Depth Weight", Range(0.0, 4.0)) = 1.0

        [Main(Lighting, _, off, off)] _LightingGroup("Lighting", Float) = 0
        [SubToggle(Lighting,_SPECULAR_ON)] _Specular("Specular", Float) = 1.0
        [SubToggle(Lighting,_SSS_ADDITIONAL_LIGHTS_ON)] _SSSAdditionalLights("SSS Additional Lights", Float) = 1.0
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
            Blend One Zero
            ZWrite[_ZWrite]
            ZTest[_ZTest]
            Cull[_Cull]
            AlphaToMask[_AlphaToMask]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _NORMALMAP
            #pragma shader_feature_local_fragment _PREINTEGRATED_SSS_ON
            #pragma shader_feature_local_fragment _WRAP_SSS_ON
            #pragma shader_feature_local_fragment _SCREEN_SPACE_SSS_ON
            #pragma shader_feature_local_fragment _SPECULAR_ON
            #pragma shader_feature_local_fragment _SSS_ADDITIONAL_LIGHTS_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSForward.hlsl"
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
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSDepthOnlyPass.hlsl"
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
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthNormalsFragment
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _NORMALMAP
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSDepthNormalsPass.hlsl"
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
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "SSSMask"
            Tags { "LightMode" = "SSSMask" }
            ZWrite Off
            ZTest LEqual
            Cull[_Cull]
            Blend One Zero

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment SSSMaskFragment
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SCREEN_SPACE_SSS_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"
            #include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSMaskPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

Shader "URP/VgSystem/StylizedLeaf"
{
    Properties
    {
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [Main(Preset, _, off, off)] _PresetGroup("Render Preset", Float) = 0
        [Preset(Preset, LWGUI_Preset_BlendMode)] _BlendMode("Blend Mode Preset", Float) = 0
        [SubEnum(Preset, UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2.0
        [SubToggle(Preset,_ALPHATEST_ON)] _AlphaClip("Alpha Clip", Float) = 1.0
        [SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1.0
        [SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0.0
        [HideInInspector] _SrcBlendAlpha("__srcA", Float) = 1.0
        [HideInInspector] _DstBlendAlpha("__dstA", Float) = 0.0
        [SubEnum(Preset, UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
        [SubToggle(Preset)] _ZWrite("ZWrite", Float) = 1.0
        [HideInInspector] _AlphaToMask("__alphaToMask", Float) = 0.0
        [HideInInspector][ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
        [HideInInspector] _QueueOffset("QueueOffset", Float) = 0

        [Toggle(GRAPHICDRAW_ON)] _GraphicDraw("Use GraphicsBuffer Instances", Float) = 0

        [Main(Base, _, on, off)] _BaseGroup("Base", Float) = 1
        [Sub(Base)][MainTexture] _MainTex("Albedo", 2D) = "white" {}
        [Sub(Base)][MainColor] _Color("Color", Color) = (1,1,1,1)
        [Sub(Base)][NoScaleOffset] _NRMTex("NRM Tex", 2D) = "white" {}
        [Sub(Base)][NoScaleOffset] _LeavesRampMap("Ramp Map", 2D) = "white" {}
        [HideInInspector] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        [Sub(Base)] _Roughness("Roughness", Range(0.0, 1.0)) = 0.5
        [Sub(Base)] _RampCount("Ramp Count", Range(0, 1)) = 1
        [Sub(Base)] _Alpha("Alpha", Range(0, 1)) = 1
        [Sub(Base)] _BumpScale("Normal Intensity", Range(0.0, 3.0)) = 1.0
        [SubToggle(Base, _)] _HideCross("Hide Cross", Float) = 1
        [Sub(Base)] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [SubToggle(Base,_USE_NORMAL_BACK_ON)] _UseNormalBack("Use Normal Back", Float) = 0
        [Sub(Base)] _NormalBackIntensity("Normal Back Intensity", Range(0, 1)) = 0

        [Main(Shading, _, off, off)] _ShadingGroup("Shading", Float) = 0
        [Sub(Shading)] _UpColor("Up Color", Color) = (0.3372549,0.5490196,0.07450981,1)
        [Sub(Shading)] _UpDirection("Up Direction", Vector) = (0,1,0,0)
        [Sub(Shading)] _UpScale("Up Intensity", Float) = 2
        [Sub(Shading)] _UpOffset("Up Scale", Float) = 1.5
        [Sub(Shading)] _Brightness("Brightness", Range(1, 10)) = 1
        [Sub(Shading)] _DarkColor("Dark Color", Color) = (0.1372549,0.3568628,0.09019608,1)
        [Sub(Shading)] _BackScale("Back Scale", Float) = 1
        [Sub(Shading)] _BackOffset("Back Offset", Float) = 0.5
        [Sub(Shading)] _AOColor("AO Color", Color) = (0.0627451,0.3960784,0.05490196,1)
        [Sub(Shading)] _AOScale("AO Scale", Range(0, 1)) = 0
        [SubToggle(Shading,_SPECULARHIGHLIGHTS)] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [SubToggle(Shading,_ENVIRONMENTREFLECTIONS)] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [Sub(Shading)][KeywordEnum(Lambert,HalfLambert)] _Lambert("Diffuse Mode", Float) = 0
        [Sub(Shading)] _BackBrightness("Back Brightness", Range(-1, 0)) = -1.0
        [Sub(Shading)] _ShadowStrength("Shadow Strength", Range(0.0, 1.0)) = 1.0
        [SubToggle(Shading,_SSAO)] _SSAO("Has SSAO", Float) = 0
        [Sub(Shading)] _AOStrength("SSAO Strength", Range(0.0, 1.0)) = 1.0

        [Main(Wind, _WIND_ON, off)] _WindGroup("Wind", Float) = 0
        [Sub(Wind)] _WindDirection("Wind Direction", Vector) = (1,0,0,0)
        [Sub(Wind)] _WindSpeed("Wind Speed", Range(0, 2)) = 1
        [Sub(Wind)] _WindStrength("Wind Strength", Range(0, 1)) = 0.2
        [Sub(Wind)] _WindJitter("Wind Jitter", Float) = 0.5
        [Sub(Wind)] _WindNoiseSize("Wind Noise Size", Float) = 5
        [Sub(Wind)] _NoisePower("Noise Power", Range(0, 5)) = 1
        [Sub(Wind)] _LeafStrength("Leaf Strength", Float) = 0.1
        [Sub(Wind)] _BendStrength("Bend Strength", Float) = 1
        [Sub(Wind)] _BendSpeed("Bend Speed", Float) = 1
        [Sub(Wind)] _BendWait("Bend Wait", Float) = 1

        [Main(Interaction, _, off, off)] _InteractionGroup("Interaction", Float) = 0
        [Sub(Interaction)] _InteractiveStrength("Strength", Range(0, 3)) = 0
        [Sub(Interaction)] _InteractiveRange("Range", Float) = 0

        [Main(SSS, _SSS_ON, off)] _SSSGroup("Subsurface", Float) = 0
        [Sub(SSS)][HDR] _SSSColor("SSS Color", Color) = (2,2,2,0)
        [Sub(SSS)] _SSSDistortion("SSS Distortion", Range(0, 5)) = 1
        [Sub(SSS)] _SSSPower("SSS Power", Float) = 1
        [Sub(SSS)] _SSSScale("SSS Scale", Float) = 1

        [BitMask(Preset)] _Stencil("Stencil ID", Int) = 0

        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0
        [HideInInspector] _StencilComp("Stencil Comparison", Float) = 8
        [HideInInspector] _StencilOp("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask("Stencil Read Mask", Float) = 255
        [HideInInspector] _GUIStencilIndex("GUI Stencil Index", Float) = 101
    }

    HLSLINCLUDE
        #include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
        #include "Assets/Shaders/HLSL/VgSystem/VgVertexWind.hlsl"
    ENDHLSL

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
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS
            #pragma shader_feature_local_vertex _WIND_ON
            #pragma shader_feature_local_fragment _USE_NORMAL_BACK_ON
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

            #include "Assets/Shaders/HLSL/VgSystem/Leaf/LeafIndirectInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Leaf/LeafIndirectForword.hlsl"
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
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Assets/Shaders/HLSL/VgSystem/Leaf/LeafIndirectInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Leaf/LeafDepthOnlyPass.hlsl"
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
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Assets/Shaders/HLSL/VgSystem/Leaf/LeafIndirectInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Leaf/LeafDepthNormalsPass.hlsl"
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
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Assets/Shaders/HLSL/VgSystem/Leaf/LeafIndirectInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Leaf/LeafShadowCasterPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

Shader "URP/VgSystem/StylizedGrass"
{
    Properties
    {
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
        [HideInInspector][Toggle(_ALPHATEST_ON)] _AlphaClip("__clip", Float) = 1.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _SrcBlendAlpha("__srcA", Float) = 1.0
        [HideInInspector] _DstBlendAlpha("__dstA", Float) = 0.0
        [HideInInspector] _ZTest("ZTest", Float) = 4
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _BlendModePreserveSpecular("_BlendModePreserveSpecular", Float) = 1.0
        [HideInInspector] _AlphaToMask("__alphaToMask", Float) = 0.0
        [HideInInspector][ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
        [HideInInspector] _Clipping("AlphaClipping", Float) = 0
        [HideInInspector] _QueueOffset("QueueOffset", Float) = 0

        [HideInInspector] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        [HideInInspector] _Roughness("Roughness", Range(0.0, 1.0)) = 1

        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [HideInInspector][MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        _TopIntensity("Top Intensity", Float) = 1.5
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _Alpha("Alpha", Range(0, 1)) = 1

        _Color1("Color1", Color) = (0.3411765,0.4235294,0.1529412,0)
        _Color2("Color2", Color) = (0.6117647,0.8666667,0.3882353,0)
        _ColorUpLevel("Color Up Level", Float) = 0
        _ColorUpFade("Color Up Fade", Range(-1, 1)) = 0.5

        _WindDirection("Wind Direction", Vector) = (1,1,0,0)
        _WindSpeed("Wind Speed", Range(0, 10)) = 0.5
        _WindForce("Wind Force", Range(0, 1)) = 1
        _WindWavesScale("Wind Waves Scale", Range(0, 1)) = 0

        [Toggle(_WINDLINE_ON)] _WindLine("Wind Line", Float) = 0
        [NoScaleOffset] _WindLineTex("WindLine Tex", 2D) = "white" {}
        _WindColorIntensity("Wind Color Intensity", Float) = 1
        _WindLineDirection("WindLine Direction", Range(0, 360)) = 0
        _WindLineScale("WindLine Scale", Float) = 1
        _WindLineStrength("WindLine Strength", Float) = 5
        _WindLindSpeed("WindLine Speed", Float) = 3

        [Toggle(_BLEND_TERRAIN_ON)] _BlendTerrain("Blend Terrain", Float) = 0
        [Toggle(_USEGROSS)] _UseGross("Use Moss", Float) = 0
        [NoScaleOffset] _MossBase("Moss Tex", 2D) = "white" {}
        _MossUV("Moss UV", Vector) = (1,1,0,0)
        _BlendRange("Blend Range", Vector) = (0,0.2,0,0)
        _TerrainBrightness("Terrain Brightness", Float) = 1

        _SSSColorIntensity("SSS Color Intensity", Float) = 1
        _SSSPower("SSS Power", Float) = 1
        _SSSScale("SSS Scale", Float) = 1

        _Strength("Strength", Range(0, 3)) = 1
        _Range("Range", Float) = 1
        _DarkIntensity("Dark Intensity", Range(-1, 1)) = 0
        _DarkScale("Dark Scale", Float) = 0.1
        _CycloneIntensity("Cyclone Intensity", Range(0, 2)) = 1
        _CycloneAmount("Cyclone Amount", Range(0, 5)) = 1
        _CycloneScale("Cyclone Scale", Float) = 0.1
        _CycloneSpeed("Cyclone Speed", Float) = 1

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [KeywordEnum(Lambert,HalfLambert)] _Lambert("Diffuse Mode", Float) = 0
        _BackBrightness("Back Brightness", Range(-1, 0)) = -1.0
        _ShadowStrength("Shadow Strength", Range(0.0, 1)) = 1.0
        [Toggle(_SSAO)] _SSAO("Has SSAO", Float) = 0
        _AOStrength("SSAO Strength", Range(0.0, 1.0)) = 1.0
        [Toggle(GRAPHICDRAW_ON)] _GraphicDraw("Use GraphicsBuffer Instances", Float) = 1

        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0

        [HideInInspector] _StencilComp("Stencil Comparison", Float) = 8
        [HideInInspector] _Stencil("Stencil ID", Float) = 0
        [HideInInspector] _StencilOp("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask("Stencil Read Mask", Float) = 255
        [HideInInspector] _GUIStencilIndex("GUI Stencil Index", Float) = 101
    }

    HLSLINCLUDE
        #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassInput.hlsl"
        #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassForward.hlsl"
        #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassDepthPasses.hlsl"
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

        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZWrite[_ZWrite]
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

            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _BLEND_TERRAIN_ON
            #pragma shader_feature_local_fragment _USEGROSS
            #pragma shader_feature_local_vertex _WINDLINE_ON
            #pragma shader_feature_local_fragment _LAMBERT_HALFLAMBERT
            #pragma shader_feature_local_fragment _SSAO
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull[_Cull]
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
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_vertex _WINDLINE_ON
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
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_vertex _WINDLINE_ON
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
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_vertex _WINDLINE_ON
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}

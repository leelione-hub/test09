Shader "URP/VgSystem/StylizedGrass"
{
    Properties
    {
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0

        [Main(Preset, _, off, off)] _PresetGroup("Render Preset", Float) = 0
        [Preset(Preset, LWGUI_Preset_BlendMode)] _BlendMode("Blend Mode Preset", Float) = 0
        [SubEnum(Preset, UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2.0
        [SubToggle(Preset,_ALPHATEST_ON)] _AlphaClip("Alpha Clip", Float) = 1.0
        [Sub(Preset)] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1.0
        [SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0.0
        [HideInInspector] _SrcBlendAlpha("__srcA", Float) = 1.0
        [HideInInspector] _DstBlendAlpha("__dstA", Float) = 0.0
        [SubEnum(Preset, UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 4
        [SubToggle(Preset)] _ZWrite("ZWrite", Float) = 1.0
        [HideInInspector] _BlendModePreserveSpecular("_BlendModePreserveSpecular", Float) = 1.0
        [HideInInspector] _AlphaToMask("__alphaToMask", Float) = 0.0
        [HideInInspector][ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
        [HideInInspector] _Clipping("AlphaClipping", Float) = 0
        [HideInInspector] _QueueOffset("QueueOffset", Float) = 0

        [HideInInspector] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        [HideInInspector] _Roughness("Roughness", Range(0.0, 1.0)) = 1

        [Toggle(GRAPHICDRAW_ON)] _GraphicDraw("Use GraphicsBuffer Instances", Float) = 1

        [Main(Base, _, on, off)] _BaseGroup("Base", Float) = 1
        [Sub(Base)][MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Sub(Base)][MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [Sub(Base)] _TopIntensity("Top Intensity", Float) = 1.5
        [Sub(Base)] _Alpha("Alpha", Range(0, 1)) = 1

        [Main(Color, _, off, off)] _ColorGroup("Color", Float) = 0
        [Sub(Color)] _Color1("Color 1", Color) = (0.3411765,0.4235294,0.1529412,0)
        [Sub(Color)] _Color2("Color 2", Color) = (0.6117647,0.8666667,0.3882353,0)
        [Sub(Color)] _ColorUpLevel("Color Up Level", Float) = 0
        [Sub(Color)] _ColorUpFade("Color Up Fade", Range(-1, 1)) = 0.5

        [Main(Wind, _, off, off)] _WindGroup("Wind", Float) = 0
        [Sub(Wind)] _WindDirection("Wind Direction", Vector) = (1,1,0,0)
        [Sub(Wind)] _WindSpeed("Wind Speed", Range(0, 10)) = 0.5
        [Sub(Wind)] _WindForce("Wind Force", Range(0, 1)) = 1
        [Sub(Wind)] _WindWavesScale("Wind Waves Scale", Range(0, 1)) = 0

        [Main(WindLine, _WINDLINE_ON)] _WindLine("Wind Line", Float) = 0
        [Sub(WindLine)][NoScaleOffset] _WindLineTex("Wind Line Tex", 2D) = "white" {}
        [Sub(WindLine)] _WindColorIntensity("Wind Color Intensity", Float) = 1
        [Sub(WindLine)] _WindLineDirection("Wind Line Direction", Range(0, 360)) = 0
        [Sub(WindLine)] _WindLineScale("Wind Line Scale", Float) = 1
        [Sub(WindLine)] _WindLineStrength("Wind Line Strength", Float) = 5
        [Sub(WindLine)] _WindLindSpeed("Wind Line Speed", Float) = 3

        [Main(Terrain, _BLEND_TERRAIN_ON, off)] _BlendTerrain("Terrain Blend", Float) = 0
        [SubToggle(Terrain,_USEGROSS)] _UseGross("Use Moss", Float) = 0
        [Sub(Terrain)][NoScaleOffset] _MossBase("Moss Tex", 2D) = "white" {}
        [Sub(Terrain)] _MossUV("Moss UV", Vector) = (1,1,0,0)
        [Sub(Terrain)] _BlendRange("Blend Range", Vector) = (0,0.2,0,0)
        [Sub(Terrain)] _TerrainBrightness("Terrain Brightness", Float) = 1

        [Main(Subsurface, _, off, off)] _SubsurfaceGroup("Subsurface", Float) = 0
        [Sub(Subsurface)] _SSSColorIntensity("SSS Color Intensity", Float) = 1
        [Sub(Subsurface)] _SSSPower("SSS Power", Float) = 1
        [Sub(Subsurface)] _SSSScale("SSS Scale", Float) = 1

        [Main(Interaction, _, off, off)] _InteractionGroup("Interaction", Float) = 0
        [Sub(Interaction)] _Strength("Strength", Range(0, 3)) = 1
        [Sub(Interaction)] _Range("Range", Float) = 1
        [Sub(Interaction)] _DarkIntensity("Dark Intensity", Range(-1, 1)) = 0
        [Sub(Interaction)] _DarkScale("Dark Scale", Float) = 0.1
        [Sub(Interaction)] _CycloneIntensity("Cyclone Intensity", Range(0, 2)) = 1
        [Sub(Interaction)] _CycloneAmount("Cyclone Amount", Range(0, 5)) = 1
        [Sub(Interaction)] _CycloneScale("Cyclone Scale", Float) = 0.1
        [Sub(Interaction)] _CycloneSpeed("Cyclone Speed", Float) = 1

        [Main(Lighting, _, off, off)] _LightingGroup("Lighting", Float) = 0
        [Sub(Lighting)][ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [Sub(Lighting)][ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [Sub(Lighting)][KeywordEnum(Lambert,HalfLambert)] _Lambert("Diffuse Mode", Float) = 0
        [Sub(Lighting)] _BackBrightness("Back Brightness", Range(-1, 0)) = -1.0
        [Sub(Lighting)] _ShadowStrength("Shadow Strength", Range(0.0, 1)) = 1.0
        [SubToggle(Lighting,_SSAO)] _SSAO("Has SSAO", Float) = 0
        [Sub(Lighting)] _AOStrength("SSAO Strength", Range(0.0, 1.0)) = 1.0

        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0
        [HideInInspector] _Control("Control (RGBA)", 2D) = "red" {}
        [HideInInspector] _Splat0("Layer 0 (R)", 2D) = "white" {}
        [HideInInspector] _Splat1("Layer 1 (G)", 2D) = "white" {}
        [HideInInspector] _Splat2("Layer 2 (B)", 2D) = "white" {}
        [HideInInspector] _Splat3("Layer 3 (A)", 2D) = "white" {}
        [HideInInspector] _DiffuseRemapScale0("_DiffuseRemapScale0", Vector) = (1,1,1,1)
        [HideInInspector] _DiffuseRemapScale1("_DiffuseRemapScale1", Vector) = (1,1,1,1)
        [HideInInspector] _DiffuseRemapScale2("_DiffuseRemapScale2", Vector) = (1,1,1,1)
        [HideInInspector] _DiffuseRemapScale3("_DiffuseRemapScale3", Vector) = (1,1,1,1)
        [HideInInspector] _TerrainRoughness("_TerrainRoughness", Float) = 1.0
        [HideInInspector] _TerrainTransformData("_TerrainTransformData", Vector) = (0,0,1,1)
        [HideInInspector] _TerrainColor("_TerrainColor", 2D) = "white" {}

        [HideInInspector] _StencilComp("Stencil Comparison", Float) = 8
        [BitMask(Preset)] _Stencil("Stencil ID", Float) = 0
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
            #pragma shader_feature_fragment _BLEND_TERRAIN_ON
            #pragma shader_feature_fragment _TERRAIN_BLEND_BAKED
            #pragma shader_feature_local_fragment _USEGROSS
            #pragma shader_feature_local_vertex _WINDLINE_ON
            #pragma shader_feature_local_fragment _LAMBERT_HALFLAMBERT
            #pragma shader_feature_local_fragment _SSAO
            #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassForwardPass.hlsl"
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
            #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassDepthOnlyPass.hlsl"
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
            #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassDepthNormalsPass.hlsl"
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
            #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Grass/GrassShadowCasterPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

Shader "URP/VgSystem/StylizedStandardLit"
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

        [Toggle(GRAPHICDRAW_ON)] _GraphicDraw("Use GraphicsBuffer Instances", Float) = 0

        [Main(Base, _, on, off)] _BaseGroup("Base", Float) = 1
        [Sub(Base)][MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Sub(Base)][MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [Sub(Base)] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [Sub(Base)] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        [Sub(Base)] _Roughness("Roughness Max", Range(0.0, 1.0)) = 0.5
        [Sub(Base)] _Alpha("Alpha", Range(0, 1)) = 1

        [Main(CrossFade, _CROSSFADE_ON, off)] _CrossFadeGroup("Cross Fade", Float) = 0
        [Sub(CrossFade)] _CorssFade("Cross Fade", Range(0, 1)) = 0

        [Main(NRM, _NRM_ON, off)] _NRMGroup("NRM", Float) = 0
        [Sub(NRM)][NoScaleOffset] _NRMTex("NRM Tex", 2D) = "bump" {}
        [Sub(NRM)] _BumpScale("Normal Intensity", Range(0.0, 3.0)) = 1.0
        [Sub(NRM)] _RoughnessMin("Roughness Min", Range(0.0, 1.0)) = 0

        [Main(Emission, _EMISSION_ON, off)] _EmissionGroup("Emission", Float) = 0
        [Sub(Emission)][HDR] _EmissionColor("Emission Color", Color) = (0,0,0,0)
        [Sub(Emission)][NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
        [Sub(Emission)] _EmissiveIntensity("Emissive Intensity", Range(0.0, 5.0)) = 1

        [Main(AO, _AO_ON, off)] _AOGroup("AO", Float) = 0
        [Sub(AO)][NoScaleOffset] _AOTex("AO Tex", 2D) = "white" {}
        [Sub(AO)] _AOIntensity("AO Intensity", Range(0, 1)) = 1
        [Sub(AO)] _AOLevels("AO Levels", Range(0, 5)) = 1
        [Sub(AO)] _AOColor("AO Color", Color) = (0,0,0,0)

        [Main(Overlay, _OVERLAYTEX_ON, off)] _OverlayGroup("Overlay", Float) = 0
        [Sub(Overlay)] _OverlayTex("Overlay Texture", 2D) = "white" {}
        [Sub(Overlay)] _OverlayMask("Overlay Mask", 2D) = "white" {}
        [Sub(Overlay)] _OverlayRoughness("Overlay Roughness", Range(0, 2)) = 1
        [Sub(Overlay)] _OverlayColor1("Overlay Color 1", Color) = (0,0,0,0)
        [Sub(Overlay)] _OverlayColor2("Overlay Color 2", Color) = (0,0,0,0)
        [Sub(Overlay)] _OverlayColor3("Overlay Color 3", Color) = (0,0,0,0)

        [Main(VertexPaint, _VERTEX_PAINT_ON, off)] _VertexPaintGroup("Vertex Paint", Float) = 0
        [Sub(VertexPaint)] _MossTex("Moss Tex", 2D) = "black" {}
        [Sub(VertexPaint)][NoScaleOffset] _MossNRM("Moss NRM", 2D) = "bump" {}
        [SubToggle(VertexPaint,_MOSS_HEIGHTTEX_ON)] _mossHeightTex("Use Moss Height Tex", Float) = 0
        [Sub(VertexPaint)][NoScaleOffset] _MossHeightTex("Moss Height Tex", 2D) = "black" {}
        [Sub(VertexPaint)] _MossHeightMax("Moss Height Max", Range(0, 1)) = 0.5
        [Sub(VertexPaint)] _MossHeightMin("Moss Height Min", Range(0, 1)) = 0.5
        [Sub(VertexPaint)] _HightIntensity("Height Intensity", Range(0, 3)) = 1.5
        [Sub(VertexPaint)] _BlendScale("Blend Scale", Float) = 10
        [Sub(VertexPaint)] _BlendIntensity("Blend Intensity", Float) = 0.5
        [HideInInspector] _MossNRMIntensity("Moss Normal Intensity", Range(0, 3)) = 1

        [Main(Terrain, _BLEND_TERRAIN_ON, off)] _TerrainGroup("Terrain Blend", Float) = 0
        [Sub(Terrain)] _SimpleTerrainColor("Simple Terrain Color", Color) = (0.4357,0.5924,0.2179,1)
        [Sub(Terrain)] _BlendRange("Blend Range", Vector) = (0,0.2,0,0)
        [Sub(Terrain)] _TerrainBrightness("Terrain Brightness", Float) = 1

        [Main(Roof, _CLASSIC_ROOF_ON, off)] _RoofGroup("Classic Roof", Float) = 0

        [Main(Lighting, _, off, off)] _LightingGroup("Lighting", Float) = 0
        [SubToggle(Lighting,_SPECULARHIGHLIGHTS)] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [SubToggle(Lighting,_ENVIRONMENTREFLECTIONS)] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [Sub(Lighting)][KeywordEnum(Lambert,HalfLambert)] _Lambert("Diffuse Mode", Float) = 0
        [Sub(Lighting)] _BackBrightness("Back Brightness", Range(-1, 0)) = -1.0
        [Sub(Lighting)] _ShadowStrength("Shadow Strength", Range(0.0, 1.0)) = 1.0
        [SubToggle(Lighting,_SSAO)] _SSAO("Has SSAO", Float) = 0
        [Sub(Lighting)] _AOStrength("SSAO Strength", Range(0.0, 1.0)) = 1.0

        [BitMask(Preset)] _Stencil("Stencil ID", Int) = 0

        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0
        [HideInInspector] _StencilComp("Stencil Comparison", Float) = 8
        [HideInInspector] _StencilOp("Stencil Operation", Float) = 0
        [HideInInspector] _StencilWriteMask("Stencil Write Mask", Float) = 255
        [HideInInspector] _StencilReadMask("Stencil Read Mask", Float) = 255
        [HideInInspector] _GUIStencilIndex("GUI Stencil Index", Float) = -1
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
            #pragma shader_feature_fragment _BLEND_TERRAIN_ON
            #pragma shader_feature_local_fragment _NRM_ON
            #pragma shader_feature_local_fragment _EMISSION_ON
            #pragma shader_feature_local_fragment _AO_ON
            #pragma shader_feature_local_fragment _VERTEX_PAINT_ON
            #pragma shader_feature_local_fragment _MOSS_HEIGHTTEX_ON
            #pragma shader_feature_local_fragment _LAMBERT_HALFLAMBERT
            #pragma shader_feature_local_fragment _SSAO
            #pragma shader_feature_local _OVERLAYTEX_ON
            #pragma shader_feature_local _CLASSIC_ROOF_ON
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
            #include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitForwardPass.hlsl"
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
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitDepthOnlyPass.hlsl"
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
            #pragma shader_feature_local_fragment _NRM_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ GRAPHICDRAW_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitDepthNormalsPass.hlsl"
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
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitShadowCasterPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

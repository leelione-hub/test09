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

        LOD 300

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
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
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
            #include "Assets/Shaders/HLSL/VgSystem/Rock/RockInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Rock/RockForwardPass.hlsl"
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
            #include "Assets/Shaders/HLSL/VgSystem/Rock/RockInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Rock/RockDepthOnlyPass.hlsl"
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
            #include "Assets/Shaders/HLSL/VgSystem/Rock/RockInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Rock/RockDepthNormalsPass.hlsl"
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
            #include "Assets/Shaders/HLSL/VgSystem/Rock/RockInput.hlsl"
            #include "Assets/Shaders/HLSL/VgSystem/Rock/RockShadowCasterPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

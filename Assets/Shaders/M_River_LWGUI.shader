Shader "M/River_LWGUI"
{
    Properties
    {
        [HideInInspector]_Surface("__surface", Float) = 0.0
        [HideInInspector]_Blend("__blend", Float) = 0.0
        [Main(Preset, _, off, off)] _PresetGroup("Render Preset", Float) = 0
        [Preset(Preset, LWGUI_Preset_BlendMode)] _BlendMode("Blend Mode Preset", Float) = 0
        [SubEnum(Preset, UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2.0
        [SubToggle(Preset,_ALPHATEST_ON)] _AlphaClip("Alpha Clip", Float) = 0.0
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
        
        [Main(Base, _, on, off)] _BaseGroup("Base", Float) = 1
        [Sub(Base)] _Strength("Strength", Range(0, 2)) = 1
        [Sub(Base)] _DepthDistance("Depth Distance", Float) = 1
        [Sub(Base)][MainColor] _SurfaceColor("Surface Color", Color) = (0.2705882,0.8313726,0.682353,0.627451)
        [Sub(Base)] _DepthColor("Depth Color", Color) = (0.02745098,0.4627451,0.6509804,0.254902)
        [Sub(Base)] _Refraction("Refraction", Range(0, 1)) = 0.025
        [Sub(Base)] _Roughness("Roughness", Range(0.0, 1.0)) = 0.5
        [Sub(Base)] _FresnelAmount("Fresnel Amount", Float) = 1.1
        [Sub(Base)] _FresnelPower("Fresnel Power", Float) = 5
        [Sub(Base)] _FresnelScale("Fresnel Scale", Float) = 1
        [Sub(Base)] _FresnelColor("Fresnel Color", Color) = (1,1,1,0)

        [Main(Highlight, _, off, off)] _HighlightGroup("Highlight", Float) = 0
        [Sub(Highlight)] _HighLightSize("High Light Size", Range(0.9, 1)) = 0.9
        [Sub(Highlight)] _HighLightScale("High Light Scale", Float) = 12
        [Sub(Highlight)][HDR] _HighLightColor("High Light Color", Color) = (2,2,2,0)

        [Main(Cubemap, _CUBEMAP_ON, off)] _CubemapGroup("Cubemap", Float) = 0
        [Sub(Cubemap)][NoScaleOffset] _Cubemap("Cubemap", CUBE) = "white" {}
        [Sub(Cubemap)] _CubemapRotation("Cubemap Rotation", Range(0, 360)) = 0

        [Main(SSR, _RIVER_SSR_ON, off)] _SSRGroup("SSR", Float) = 0
        [Sub(SSR)] _SSRIntensity("SSR Intensity", Range(0, 2)) = 1
        [Sub(SSR)] _SSRBlend("SSR Blend", Range(0, 1)) = 1
        [Sub(SSR)] _SSRDistortion("SSR Distortion", Range(0, 1)) = 0.1
        [Sub(SSR)] _SSRMaskByFresnel("Mask By Fresnel", Range(0, 1)) = 1
        [Sub(SSR)] _SSRMaskByDepth("Mask By Depth", Range(0, 1)) = 1
        [Sub(SSR)] _SSRValidThreshold("SSR Valid Threshold", Range(0, 1)) = 0.01
        [Sub(SSR)] _SSRStepSize("SSR Step Size", Range(0.05, 4)) = 0.4
        [Sub(SSR)] _SSRMaxDistance("SSR Max Distance", Range(1, 200)) = 40
        [Sub(SSR)] _SSRThickness("SSR Thickness", Range(0.01, 4)) = 0.6
        [Sub(SSR)] _SSREdgeFade("SSR Edge Fade", Range(0, 1)) = 0.15
        [Sub(SSR)] _SSRRayStartBias("SSR Ray Start Bias", Range(0, 1)) = 0.1
        [Sub(SSR)] _SSRMaxSteps("SSR Max Steps", Range(8, 128)) = 48

        [Main(Normal, _, off, off)] _NormalGroup("Normal", Float) = 0
        [Sub(Normal)][NoScaleOffset] _WavesNormal("Waves Normal", 2D) = "bump" {}
        [Sub(Normal)] _WavesNormalIntensity("Waves Normal Intensity", Range(0, 1)) = 0.2
        [Sub(Normal)] _WaveSpeed("Wave Speed", Range(0, 1)) = 0.5
        [Sub(Normal)] _WaveNormalScale("Wave Normal Scale", Float) = 0.1
        [Sub(Normal)] _TilingOffset("Tiling Offset", Vector) = (15,15,0,0)

        [Main(Foam, _ENABLEFOAM_ON, off)] _FoamGroup("Foam", Float) = 0
        [Sub(Foam)] _DepthCutOff("Depth Cut Off", Range(1, 10)) = 10
        [Sub(Foam)] _CoastScale("Coast Scale", Float) = 1
        [Sub(Foam)] _CoastSpeed("Coast Speed", Vector) = (0,0,0,0)
        [Sub(Foam)] _FoamColor("Foam Color", Color) = (0.7490196,1,0.827451,0.7254902)
        [Sub(Foam)] _CoastAlpha("Coast Alpha", Range(0, 1)) = 0.1

        [Main(FoamTex, _FOAMTEX_ON, off)] _FoamTexGroup("Foam Texture", Float) = 0
        [SubToggle(FoamTex,_USEDISTANCETEX_ON)] _UseDistanceTex("Use Distance Tex", Float) = 1
        [Sub(FoamTex)][NoScaleOffset] _FoamTex("Foam Tex (R foamTex G lightTex)", 2D) = "white" {}
        [Sub(FoamTex)][NoScaleOffset] _DistanceMap("Distance Map", 2D) = "white" {}
        [Sub(FoamTex)] _EdgeWidth("Edge Width", Range(0, 1)) = 0.1
        [Sub(FoamTex)] _FoamScale("Foam Scale", Range(0, 2)) = 0.25
        [Sub(FoamTex)] _FoamDepth("Foam Depth", Float) = 1
        [Sub(FoamTex)] _FoamDepthFallOff("Foam Depth Fall Off", Range(0, 5)) = 0
        [Sub(FoamTex)] _FoamTiling("Foam Tiling", Float) = 1
        [Sub(FoamTex)] _FoamWidth("Foam Width", Float) = 1
        [Sub(FoamTex)] _FoamCut("Foam Cut", Range(0, 1)) = 0
        [Sub(FoamTex)] _FoamTexAlpha("Foam Alpha", Range(0, 1)) = 1
        [Sub(FoamTex)] _FoamSpeed("Foam Speed", Vector) = (0,0,0,0)
        [SubToggle(FoamTex,_FOAMSMOOTHEDGE1_ON)] _FoamSmoothEdge1("Smooth Foam", Float) = 0
        [HideInInspector] _FoamTexColor("FoamTex Color", Color) = (1,1,1,0)

        [Main(LightWave, _ENABLEWAVETEX_ON, off)] _LightWaveGroup("Light Wave", Float) = 0
        [Sub(LightWave)] _WaveTexTilingOffset("LightTex Tiling", Vector) = (1,1,0,0)
        [Sub(LightWave)] _NoiseScale("Noise Scale", Float) = 1
        [Sub(LightWave)] _NoiseSpeed("Noise Speed", Range(0, 1)) = 0.1
        [Sub(LightWave)][HDR] _LightColor("Light Color", Color) = (1,1,1,0)
        [Sub(LightWave)] _LightPower("Light Power", Range(1, 10)) = 1

        [Main(Caustic, _ENABLECAUSTIC_ON, off)] _CausticGroup("Caustic", Float) = 0
        [Sub(Caustic)] _CausticSize1("Size", Range(0.01, 10)) = 1
        [Sub(Caustic)] _CausticAngle1("Angle", Range(0, 5)) = 2
        [Sub(Caustic)] _CausticSpeed1("Speed", Range(0, 2)) = 0.1
        [Sub(Caustic)] _CausticThreshold1("Threshold", Vector) = (0,1,0,0)
        [Sub(Caustic)] _CausticBrightness1("Brightness", Float) = 1
        [Sub(Caustic)] _CausticEndDepth1("End Depth", Range(0.01, 30)) = 3
        [Sub(Caustic)] _CausticFarDistance1("Far Distance", Float) = 5
        [Sub(Caustic)] _CausticColorSplit1("Color Split", Range(0, 1)) = 0.1
        [Sub(Caustic)] _CausticColor1("Color 1", Color) = (1,0,0,0)
        [Sub(Caustic)] _CausticColor2("Color 2", Color) = (0,1,0.129231,0)

        [Main(Lighting, _, off, off)] _LightingGroup("Lighting", Float) = 0
        [Sub(Lighting)][ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [Sub(Lighting)][ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [Sub(Lighting)][KeywordEnum(Lambert,HalfLambert)] _Lambert("Diffuse Mode", Float) = 0
        [Sub(Lighting)] _BackBrightness("Back Brightness", Range(-1, 0)) = -1.0
        [Sub(Lighting)] _ShadowStrength("Shadow Strength", Range(0.0, 1.0)) = 1.0
        [SubToggle(Lighting,_SSAO)] _SSAO("Has SSAO", Float) = 0
        [Sub(Lighting)] _AOStrength("SSAO Strength", Range(0.0, 1.0)) = 1.0

        // SRP batching compatibility for Clear Coat (Not used in Lit)
        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
                "Queue" = "Transparent"
            }

            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZWrite[_ZWrite]
            Cull[_Cull]
            AlphaToMask[_AlphaToMask]

            HLSLPROGRAM
            #pragma target 4.5

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _OCCLUSIONMAP
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT_LOW
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            #pragma multi_compile_fog

            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #pragma shader_feature_local_fragment _ENABLEWAVETEX_ON
            #pragma shader_feature_local_fragment _ENABLEFOAM_ON
            #pragma shader_feature_local_fragment _CUBEMAP_ON
            #pragma shader_feature_local_fragment _RIVER_SSR_ON
            #pragma shader_feature_local_fragment _FOAMTEX_ON
            #pragma shader_feature_local_fragment _FOAMSMOOTHEDGE1_ON
            #pragma shader_feature_local _USEDISTANCETEX_ON
            #pragma shader_feature_local_fragment _ENABLECAUSTIC_ON

            #pragma shader_feature_local_fragment _LAMBERT_HALFLAMBERT
            #pragma shader_feature_local_fragment _SSAO

            #define _NORMALMAP 1
            #define REQUIRE_OPAQUE_TEXTURE 1
            #define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
            #define REQUIRES_WORLD_SPACE_POS_INTERPOLATOR

            #include "Assets/Shaders/HLSL/Water/M_River_LWGUIInput.hlsl"
            #include "Assets/Shaders/HLSL/Water/M_River_LWGUIForward.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma multi_compile_instancing

            #include "Assets/Shaders/HLSL/Water/M_River_LWGUIInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

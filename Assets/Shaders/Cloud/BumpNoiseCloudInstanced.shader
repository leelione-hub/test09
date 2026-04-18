Shader "Custom/Cloud/BumpNoiseCloudInstanced"
{
    Properties
    {
        [Main(Noise, _, on, off)] _NoiseGroup("Noise", Float) = 1
        [Sub(Noise)][NoScaleOffset] _NoiseTex("3D Noise", 3D) = "white" {}
        [Sub(Noise)] _NoiseScale("Noise Scale", Float) = 12
        [Sub(Noise)] _NoiseSpeed("Noise Speed (XYZ)", Vector) = (0.02, 0.01, 0.02, 0)
        [Sub(Noise)] _FarNoiseScaleMul("Far Noise Scale Mul", Range(1, 4)) = 2
        [Sub(Noise)] _DetailNoiseScaleMul("Detail Noise Scale Mul", Range(1, 8)) = 2.5
        [Sub(Noise)] _DetailNoiseWeight("Detail Noise Weight", Range(0, 1)) = 0.35

        [Main(Layer, _, off, off)] _LayerGroup("Layer", Float) = 0
        [Sub(Layer)] _LayerThicknessRatio("Layer Thickness Ratio", Range(0.0, 0.2)) = 0.03
        [Sub(Layer)] _FarOffsetMul("Far Offset Mul", Range(1, 4)) = 1.8
        [Sub(Layer)] _DistanceFadeStart("Distance Fade Start", Float) = 50
        [Sub(Layer)] _DistanceFadeRange("Distance Fade Range", Float) = 150

        [Main(Shape, _, off, off)] _ShapeGroup("Shape", Float) = 0
        [Sub(Shape)] _BaseClip("Base Clip", Range(0, 1)) = 0.35
        [Sub(Shape)] _ClipLayerStrength("Clip Layer Strength", Range(0, 1)) = 0.5
        [Sub(Shape)] _ClipCurvePower("Clip Curve Power", Range(0.2, 4)) = 1.6
        [Sub(Shape)] _DensitySoftness("Density Softness", Range(1, 16)) = 6
        [Sub(Shape)] _DitherStrength("Dither Strength", Range(0, 0.2)) = 0.04
        [SubToggle(Shape,_DEPTH_FADE_ON)] _DepthFade("Depth Fade", Float) = 0
        [Sub(Shape)] _DepthFadeDistance("Depth Fade Distance", Float) = 2
        [Sub(Shape)] _OuterAlphaScale("Outer Alpha Scale", Range(0, 2)) = 0.7
        [Sub(Shape)] _InnerAlphaScale("Inner Alpha Scale", Range(0, 2)) = 1.15

        [Main(Lighting, _, off, off)] _LightingGroup("Lighting", Float) = 0
        [Sub(Lighting)][HDR] _BrightColor("Bright Color", Color) = (1, 1, 1, 1)
        [Sub(Lighting)][HDR] _ShadowColor("Shadow Color", Color) = (0.5, 0.55, 0.62, 1)
        [Sub(Lighting)] _BackSssStrength("Back SSS Strength", Range(0, 2)) = 0.6
        [Sub(Lighting)] _BackSssPower("Back SSS Power", Range(0.2, 8)) = 2.5
        [Sub(Lighting)] _BackSssBoost("Back SSS Boost", Range(0, 4)) = 1.5
        [Sub(Lighting)] _NdotLPower("NdotL Power", Range(0.2, 8)) = 1.6
        [Sub(Lighting)] _NdotVPower("NdotV Power", Range(0.2, 8)) = 1.8
        [Sub(Lighting)] _ViewLightingWeight("View Lighting Weight", Range(0, 2)) = 0.5
        [Sub(Lighting)] _ViewShadowSuppress("View Shadow Suppress", Range(0, 1)) = 0.5
        [Sub(Lighting)] _ShadowFadeStart("Shadow Fade Start", Float) = 100
        [Sub(Lighting)] _ShadowFadeRange("Shadow Fade Range", Float) = 10
        [Sub(Lighting)] _HighlightCompression("Highlight Compression", Range(0.5, 4)) = 1.35
        [Sub(Lighting)] _LitDetailStrength("Lit Detail Strength", Range(0, 1)) = 0.35
        [Sub(Lighting)] _CoreShadowStrength("Core Shadow Strength", Range(0, 1)) = 0.4
        [Sub(Lighting)] _FinalAlpha("Final Alpha", Range(0, 1)) = 0.95

        [Main(Render, _, off, off)] _RenderGroup("Render", Float) = 0
        [SubEnum(Render, UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
        [SubToggle(Render)] _ZWrite("Depth Write", Float) = 1
        [SubToggle(Render,_PREPASS_CUTOUT_ON)] _PrepassCutout("Prepass Cutout", Float) = 0
        [Sub(Render)] _PrepassThreshold("Prepass Threshold", Range(0, 1)) = 0.33
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma shader_feature_local_fragment _DEPTH_FADE_ON

            #include "Assets/Shaders/HLSL/Cloud/BumpNoiseCloudInstancedInput.hlsl"
            #include "Assets/Shaders/HLSL/Cloud/BumpNoiseCloudInstancedForward.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma multi_compile_instancing
            #pragma shader_feature_local_fragment _PREPASS_CUTOUT_ON

            #include "Assets/Shaders/HLSL/Cloud/BumpNoiseCloudInstancedDepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            #pragma multi_compile_instancing
            #pragma shader_feature_local_fragment _PREPASS_CUTOUT_ON

            #include "Assets/Shaders/HLSL/Cloud/BumpNoiseCloudInstancedDepthNormalsPass.hlsl"
            ENDHLSL
        }
    }

    CustomEditor "LWGUI.LWGUI"
}

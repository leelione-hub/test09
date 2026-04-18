Shader "URP/Cloud/TessellatedVolumeCloud"
{
    Properties
    {
        [Main(Shape, _, on, off)] _ShapeGroup("Shape", Float) = 1
        [Sub(Shape)][NoScaleOffset] _NoiseTex("Noise Texture", 3D) = "" {}
        [Sub(Shape)] _NoiseScale("Noise Scale", Float) = 8
        [Sub(Shape)] _NoiseSpeed("Noise Speed", Vector) = (0.02, 0.01, 0.015, 0)
        [Sub(Shape)] _Displacement("Displacement", Range(0, 6)) = 1.5
        [Sub(Shape)] _DensityThreshold("Density Threshold", Range(0, 1)) = 0.45
        [Sub(Shape)] _DensitySoftness("Density Softness", Range(0.1, 16)) = 5
        [Sub(Shape)] _Alpha("Alpha", Range(0, 1)) = 0.85

        [Main(Tessellation, _, off, off)] _TessellationGroup("Tessellation", Float) = 0
        [Sub(Tessellation)] _TessellationFactor("Near Tessellation", Range(1, 32)) = 10
        [Sub(Tessellation)] _TessellationMinFactor("Far Tessellation", Range(1, 16)) = 1
        [Sub(Tessellation)] _TessellationStartDistance("Start Distance", Float) = 8
        [Sub(Tessellation)] _TessellationEndDistance("End Distance", Float) = 60

        [Main(Lighting, _, off, off)] _LightingGroup("Lighting", Float) = 0
        [Sub(Lighting)][HDR] _BrightColor("Bright Color", Color) = (1,1,1,1)
        [Sub(Lighting)][HDR] _ShadowColor("Shadow Color", Color) = (0.45,0.52,0.62,1)
        [Sub(Lighting)] _AmbientStrength("Ambient Strength", Range(0, 2)) = 0.35
        [Sub(Lighting)] _BackscatterStrength("Backscatter Strength", Range(0, 3)) = 1
        [Sub(Lighting)] _BackscatterPower("Backscatter Power", Range(0.2, 8)) = 3
        [Sub(Lighting)] _RimStrength("Rim Strength", Range(0, 2)) = 0.3
        [Sub(Lighting)] _RimPower("Rim Power", Range(0.2, 8)) = 2
        [Sub(Lighting)] _NormalSampleOffset("Normal Sample Offset", Range(0.01, 2)) = 0.2
        [Sub(Lighting)] _NormalStrength("Normal Strength", Range(0, 4)) = 1

        [Main(Render, _, off, off)] _RenderGroup("Render", Float) = 0
        [Sub(Render)] _DistanceFadeStart("Distance Fade Start", Float) = 80
        [Sub(Render)] _DistanceFadeRange("Distance Fade Range", Float) = 80
        [Sub(Render)] _EdgeFadePower("Edge Fade Power", Range(0.2, 8)) = 1.5
        [SubEnum(Render, UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.6
            #pragma require tessellation tessHW
            #pragma vertex TessellationVertex
            #pragma hull Hull
            #pragma domain Domain
            #pragma fragment Frag

            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            #include "Assets/Shaders/HLSL/Cloud/TessellatedVolumeCloudInput.hlsl"
            #include "Assets/Shaders/HLSL/Cloud/TessellatedVolumeCloudForward.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "LWGUI.LWGUI"
}

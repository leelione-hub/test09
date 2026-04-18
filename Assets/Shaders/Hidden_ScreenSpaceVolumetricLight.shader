Shader "Hidden/Lighting/ScreenSpaceVolumetricLight"
{
    Properties
    {
        [HideInInspector] _BlitTexture("Source", 2D) = "white" {}
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        }

        Pass
        {
            Name "ScreenSpaceVolumetricLight"
            Tags { "LightMode" = "UniversalForward" }
            // 全屏后处理式 Pass。
            ZWrite Off
            ZTest Always
            Cull Off
            Blend One Zero

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fragment _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "Assets/Shaders/HLSL/Lighting/Hidden_ScreenSpaceVolumetricLightInput.hlsl"
            #include "Assets/Shaders/HLSL/Lighting/Hidden_ScreenSpaceVolumetricLightForward.hlsl"
            ENDHLSL
        }
    }
}

Shader "Hidden/Lighting/ScreenSpaceSSS"
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
            Name "BlurHorizontal"
            ZWrite Off
            ZTest Always
            Cull Off
            Blend One Zero

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment FragBlurHorizontal
            #include "Assets/Shaders/HLSL/Lighting/Hidden_ScreenSpaceSSSInput.hlsl"
            #include "Assets/Shaders/HLSL/Lighting/Hidden_ScreenSpaceSSSForward.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "BlurVertical"
            ZWrite Off
            ZTest Always
            Cull Off
            Blend One Zero

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment FragBlurVertical
            #include "Assets/Shaders/HLSL/Lighting/Hidden_ScreenSpaceSSSInput.hlsl"
            #include "Assets/Shaders/HLSL/Lighting/Hidden_ScreenSpaceSSSForward.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "Composite"
            ZWrite Off
            ZTest Always
            Cull Off
            Blend One Zero

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment FragComposite
            #include "Assets/Shaders/HLSL/Lighting/Hidden_ScreenSpaceSSSInput.hlsl"
            #include "Assets/Shaders/HLSL/Lighting/Hidden_ScreenSpaceSSSForward.hlsl"
            ENDHLSL
        }
    }
}

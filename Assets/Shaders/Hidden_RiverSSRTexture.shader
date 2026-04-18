Shader "Hidden/Water/RiverSSRTexture"
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
            Name "RiverSSRTexture"
            Tags { "LightMode" = "UniversalForward" }
            ZWrite Off
            ZTest Always
            Cull Off
            Blend One Zero

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Assets/Shaders/HLSL/Water/Hidden_RiverSSRTextureInput.hlsl"
            #include "Assets/Shaders/HLSL/Water/Hidden_RiverSSRTextureForward.hlsl"
            ENDHLSL
        }
    }
}

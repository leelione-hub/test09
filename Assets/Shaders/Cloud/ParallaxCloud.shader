Shader "Custom/Cloud/ParallaxCloud"
{
    Properties
    {
        [MainTexture] _MainTex("Cloud RGBA (A = Height)", 2D) = "white" {}
        [HDR] _Color("Tint", Color) = (1, 1, 1, 1)
        [HDR] _BrightColor("Bright Color", Color) = (1, 1, 1, 1)
        [HDR] _ShadowColor("Shadow Color", Color) = (0.55, 0.6, 0.72, 1)

        _UV1Speed("Main UV Speed XY", Vector) = (0.02, 0.0, 0.0, 0.0)
        _UV2TilingSpeed("Disturb UV Tile XY Speed ZW", Vector) = (2.0, 2.0, 0.03, 0.01)

        _Height("Parallax Height", Range(0.0, 0.2)) = 0.05
        _HeightAmount("Height Amount", Range(0.0, 4.0)) = 1.0
        _ViewZBias("View Z Bias", Range(0.0, 1.0)) = 0.42
        _LinearStepCount("Linear Steps", Range(1, 64)) = 24
        _BinaryStepCount("Binary Steps", Range(0, 8)) = 4

        _Alpha("Alpha", Range(0.0, 1.0)) = 1.0
        _MainLightStrength("Main Light Strength", Range(0.0, 2.0)) = 1.0
        _AmbientStrength("Ambient Strength", Range(0.0, 2.0)) = 0.6
        _ForwardScattering("Forward Scattering", Range(0.25, 8.0)) = 2.0
        _RimPower("Rim Power", Range(0.25, 8.0)) = 3.0
        _RimStrength("Rim Strength", Range(0.0, 2.0)) = 0.25
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
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Front

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Assets/Shaders/HLSL/Cloud/ParallaxCloudForward.hlsl"
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/DEPTHONLY"
    }
}

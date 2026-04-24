Shader "URPGenshinToon"
{
    Properties
    {
        [Main(Preset, _, off, off)] _PresetGroup("Render Preset", Float) = 0
        [SubToggle(Preset,_DOUBLE_SIDED)] _DoubleSided("Double Sided", Float) = 0
        [SubEnum(Preset, UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
        [SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0

        [Main(General, _, on, off)] _GeneralGroup("General", Float) = 1
        [Sub(General)][MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [Sub(General)][MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        [Sub(General)] _IsDay("Is Day", Float) = 1

        [Main(Shadow, _, on, off)] _ShadowGroup("Shadow", Float) = 1
        [Sub(Shadow)] _LightMap("Light Map", 2D) = "white" {}
        [Sub(Shadow)] _LightDirectionMultiplier("Light Direction Multiplier", Vector) = (1,1,1,0)
        [Sub(Shadow)] _ShadowOffset("Shadow Offset", Float) = 0
        [Sub(Shadow)] _ShadowSmoothness("Shadow Smoothness", Float) = 0
        [Sub(Shadow)][HDR] _ShadowColor("Shadow Color", Color) = (1,1,1,1)
        [Sub(Shadow)] _ShadowRamp("Shadow Ramp", 2D) = "white" {}
        [Sub(Shadow)] _UseCustomMaterialType("Use Custom Material Type", Float) = 0
        [Sub(Shadow)] _CustomMaterialType("Custom Material Type", Float) = 1

        [Main(Emission, _EMISSION, off)] _EmissionGroup("Emission", Float) = 0
        [Sub(Emission)] _EmissionIntensity("Emission Intensity", Float) = 1

        [Main(Normal, _NORMAL_MAP, off)] _NormalGroup("Normal", Float) = 0
        [Sub(Normal)][Normal] _NormalMap("Normal Map", 2D) = "bump" {}

        [Main(Face, _IS_FACE, off)] _FaceGroup("Face", Float) = 0
        [Sub(Face)] _FaceDirection("Face Direction", Vector) = (0,0,1,0)
        [Sub(Face)] _FaceShadowOffset("Face Shadow Offset", Float) = 0
        [Sub(Face)] _FaceBlushColor("Face Blush Color", Color) = (1,1,1,1)
        [Sub(Face)] _FaceBlushStrength("Face Blush Strength", Float) = 1
        [Sub(Face)] _FaceLightMap("Face Light Map", 2D) = "white" {}
        [Sub(Face)] _FaceShadow("Face Shadow", 2D) = "white" {}

        [Main(Specular, _SPECULAR, off)] _SpecularGroup("Specular", Float) = 0
        [Sub(Specular)] _SpecularSmoothness("Specular Smoothness", Float) = 1
        [Sub(Specular)] _NonmetallicIntensity("Nonmetallic Intensity", Float) = 1
        [Sub(Specular)] _MetallicIntensity("Metallic Intensity", Float) = 1
        [Sub(Specular)] _MetalMap("Metal Map", 2D) = "white" {}

        [Main(Additional, _, off, off)] _AdditionalGroup("Additional Lights", Float) = 0
        [Sub(Additional)] _AdditionalLightDiffuseIntensity("Additional Light Diffuse Intensity", Float) = 0.5
        [Sub(Additional)] _AdditionalLightSpecularIntensity("Additional Light Specular Intensity", Float) = 0.35
        [Sub(Additional)] _AdditionalLightWrap("Additional Light Wrap", Range(0,1)) = 0.5
        [Sub(Additional)] _AdditionalSpecularSmoothness("Additional Specular Smoothness", Float) = 16
        [Sub(Additional)] _AdditionalLightAffectsFace("Additional Light Affects Face", Float) = 0
        [Sub(Additional)] _AdditionalLightShadowStrength("Additional Light Shadow Strength", Range(0,1)) = 1

        [Main(Rim, _RIM, off)] _RimGroup("Rim Light", Float) = 0
        [Sub(Rim)] _RimOffset("Rim Offset", Float) = 1
        [Sub(Rim)] _RimThreshold("Rim Threshold", Float) = 1
        [Sub(Rim)] _RimIntensity("Rim Intensity", Float) = 1

        [Main(Outline, _, on, off)] _OutlineGroup("Outline", Float) = 1
        [Sub(Outline)] _UseSmoothNormal("Use Smooth Normal", Float) = 0
        [Sub(Outline)] _OutlineWidth("Outline Width", Float) = 1
        [Sub(Outline)] _OutlineWidthParams("Outline Width Params", Vector) = (0,1,0,1)
        [Sub(Outline)] _OutlineZOffset("Outline Z Offset", Float) = 0
        [Sub(Outline)] _ScreenOffset("Screen Offset", Vector) = (0,0,0,0)
        [Sub(Outline)] _OutlineColor("Outline Color", Color) = (0,0,0,1)
        [Sub(Outline)] _OutlineColor2("Outline Color 2", Color) = (0,0,0,1)
        [Sub(Outline)] _OutlineColor3("Outline Color 3", Color) = (0,0,0,1)
        [Sub(Outline)] _OutlineColor4("Outline Color 4", Color) = (0,0,0,1)
        [Sub(Outline)] _OutlineColor5("Outline Color 5", Color) = (0,0,0,1)
    }

    Subshader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "Forward"
            Tags {"LightMode" = "UniversalForward"}

            Cull[_Cull]
            ZWrite On
            Blend[_SrcBlend][_DstBlend]

            HLSLPROGRAM

            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fragment _ _WRITE_RENDERING_LAYERS

            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            #pragma shader_feature_local_fragment _DOUBLE_SIDED
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _NORMAL_MAP
            #pragma shader_feature_local_fragment _IS_FACE
            #pragma shader_feature_local_fragment _SPECULAR
            #pragma shader_feature_local_fragment _RIM

            #pragma vertex ForwardPassVertex
            #pragma fragment ForwardPassFragment

            #include "ToonInput.hlsl"
            #include "ToonForwardPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "Outline"
            Tags {"LightMode" = "SRPDefaultUnlit"}

            Cull Front

            HLSLPROGRAM

            #pragma vertex OutlinePassVertex
            #pragma fragment OutlinePassFragment

            #include "ToonInput.hlsl"
            #include "ToonOutlinePass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "LWGUI.LWGUI"
}

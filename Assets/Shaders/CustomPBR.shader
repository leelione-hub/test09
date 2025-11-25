Shader "Custom/CustomPBR"
{
    Properties
    {
        [NoScaleOffset][_MainTexture]_BaseMap ("Albedo", 2D) = "white" {}
        [_MainColor] _BaseColor("基础色",Color) = (1,1,1,1)
        [NoScaleOffset][Texture()]_BumpMap("Normal Map",2D) = "bump"{}
        [NoScaleOffset][Texture()]_MetallicMap("金属度",2D) = "white" {}
        [NoScaleOffset][Texture()]_RoughnessMap("粗糙度",2D) = "white"{}
        [NoScaleOffset][Texture()]_OcclusionMap("Occlusion Map",2D) = "white"{}
        
        _BumpScale("_BumpScale", Float) = 1.0
        _Roughness("Roughness",Range(0,1)) = 0
        _Metallic("Metallic",Range(0,1)) = 0
        _OcclusionStrength("Occlusion Strength", Range(0.0, 1.0)) = 1.0
        
        [Main(SubSurface)] _subSurface("次表面散射",float) = 0
        [Sub(SubSurface)]_Subsurface("0=纯漫反射 1=半透明皮肤", Range(0,1)) = 0
        
        [Main(Sheen)] _sheen("布料",float) = 0
        [Sub(Sheen)] _Sheen("绒布光泽",Range(0,1)) = 0
        [Sub(Sheen)] __SheenTint("0=白 1=跟随 BaseColor", Range(0,1)) = 1
        
        [Main(Clearcoat)] _clearcoat("清漆",float) = 0
        [Sub(Clearcoat)] _Clearcoat("0=无 1=完整车漆", Range(0,1)) = 0
        [Sub(Clearcoat)] _ClearcoatGloss("0=哑 1=亮", Range(0,1)) = 1
        
        [Main(Emisstion,_EMISSION)] emisstion("自发光",float) = 0
        [Sub(Emisstion)][HDR] _EmissionColor("Color",Color) = (0,0,0)
        [Sub(Emisstion)] _EmissionMap("Emission",2D) = "white"{}
        
        
        [Main(Preset, _, on, off)] _PresetGroup ("Preset Samples", float) = 0
		[Preset(Preset, LWGUI_Preset_BlendMode)] _BlendMode ("Blend Mode Preset", float) = 0
    	[SubToggle(Preset,_ALPHATEST_ON)] _AlphaTest("启用透明裁剪", Float) = 0
    	[Sub(Preset)] _Cutoff("透明裁剪阈值", Range(0,1)) = 0.5
		[SubEnum(Preset, UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
		[SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend", Float) = 1
		[SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend", Float) = 0
		[SubToggle(Preset)] _ZWrite ("ZWrite ", Float) = 1
		[SubEnum(Preset, UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 4 // 4 is LEqual
		[SubEnum(Preset, RGBA, 15, RGB, 14)] _ColorMask ("ColorMask", Float) = 15 // 15 is RGBA (binary 1111)
		[BitMask(Preset)] _Stencil ("Stencil", Int) = 0
		[BitMask(Preset, Left, Bit6, Bit5, Bit4, Description, Bit2, Bit1, Right)] _StencilWithDescription ("Stencil With Description", Int) = 0
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            // -------------------------------------
            // Render State Commands
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]
            
            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex   Vert
            #pragma fragment Frag

            // -------------------------------------
            // Material Keywords
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

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _FORWARD_PLUS
            
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "HLSL/BaseCaculate.hlsl"
            

            #include "HLSL/CustomPBR/CustomPBRInput.hlsl"
            #include "HLSL/CustomPBR/CustomPBRForward.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "LWGUI.LWGUI"
}

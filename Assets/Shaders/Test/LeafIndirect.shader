Shader "URP/VgSystem/LeafIndirect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _WindStrength ("Wind Strength", Range(0, 1)) = 0.5
        [Toggle(GRAPHICDRAW_ON)] graphicDraw("使用批处理绘制",float) = 1
        [Main(Wind,_,on,off)] _WindGroup("Wind Properties",float) = 0
        [Sub(Wind)] _WindSpeed("WindSpeed",float) = 1
        [Sub(Wind)] _LeafStrength("LeafStrength",float) = 0.1
        [Sub(Wind)] _BendStrength("BendStrength",float) = 1
        [Sub(Wind)] _BendSpeed("BendSpeed",float) = 1
        [Sub(Wind)] _BendWait("BendWait",float) = 1
        [Sub(Wind)] _WindDirection("WindDirection",Vector) = (1,1,0,0)
        
        [Main(Preset, _, on, off)] _PresetGroup ("Preset Samples", float) = 0
		[Preset(Preset, LWGUI_Preset_BlendMode)] _BlendMode ("Blend Mode Preset", float) = 0
    	[SubToggle(Preset,_ALPHATEST_ON)] _AlphaTest("启用透明裁剪", Float) = 0
    	[Sub(Preset)] _Cutoff("透明裁剪阈值", Range(0,1)) = 0.5
		[SubEnum(Preset, UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
    	[SubToggle(Preset,_ENVIRONMENTREFLECTIONS_OFF)] _EnvironmentReflections_Off("_EnvironmentReflections Off",Float) = 0
		[SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend", Float) = 1
		[SubEnum(Preset, UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend", Float) = 0
		[SubToggle(Preset)] _ZWrite ("ZWrite ", Float) = 1
		[SubEnum(Preset, UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 4 // 4 is LEqual
		[SubEnum(Preset, RGBA, 15, RGB, 14)] _ColorMask ("ColorMask", Float) = 15 // 15 is RGBA (binary 1111)
		[BitMask(Preset)] _Stencil ("Stencil", Int) = 0
		[BitMask(Preset, Left, Bit6, Bit5, Bit4, Description, Bit2, Bit1, Right)] _StencilWithDescription ("Stencil With Description", Int) = 0
    }
    
    HLSLINCLUDE
        #include "../HLSL/VgSystem/VgVertexInput.hlsl"
        #include "../HLSL/VgSystem/VgVertexWind.hlsl"
    ENDHLSL

    SubShader
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
            Name "ForwardLit"
            
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            // Render State Commands
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]
            
            HLSLPROGRAM
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #pragma shader_feature_local_fragment _ALPHATEST_ON

            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // Lighting & shadows
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            
            // LOD Crossfade
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            
            #include "../HLSL/VgSystem/Leaf/LeafIndirectInput.hlsl"
            #include "../HLSL/VgSystem/Leaf/LeafIndirectForword.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }
            
            // Render State Commands
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]
            
            HLSLPROGRAM
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local _ _GBUFFER_NORMALS_OCT
            
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
            
            // LOD Crossfade
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            
            #include "../HLSL/VgSystem/Leaf/LeafIndirectInput.hlsl"
            #include "../HLSL/VgSystem/Leaf/LeafDepthOnlyPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthNormals"
            Tags
            {
                "LightMode" = "DepthNormals"
            }
            
            // Render State Commands
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]
            
            HLSLPROGRAM
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local _ _GBUFFER_NORMALS_OCT
            
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
            
            // LOD Crossfade
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            
            #include "../HLSL/VgSystem/Leaf/LeafIndirectInput.hlsl"
            #include "../HLSL/VgSystem/Leaf/LeafDepthNormalsPass.hlsl"
            ENDHLSL
        }
        

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            
            // Render State Commands
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]
            
            HLSLPROGRAM
            #pragma vertex ShadowCasterVertex
            #pragma fragment ShadowCasterFragment
            
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON
            
            // LOD Crossfade
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            
            // Shadow Keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            
            #include "../HLSL/VgSystem/Leaf/LeafIndirectInput.hlsl"
            #include "../HLSL/VgSystem/Leaf/LeafShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "LWGUI.LWGUI"
}

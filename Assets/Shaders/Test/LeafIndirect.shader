Shader "URP/VgSystem/LeafIndirect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _WindStrength ("Wind Strength", Range(0, 1)) = 0.5
        _BoundsRadius ("Bounds Radius", Float) = 50
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
            #pragma vertex vert
            #pragma fragment frag

            // CBUFFER_START(UnityPerMaterial)
            //     float4 _Color;
            //     float _WindStrength;
            //     float _BoundsRadius;
            //     float4 _MainTex_ST;
            //     float _WindSpeed;
            //     float _LeafStrength;
            //     float _BendStrength;
            //     float _BendSpeed;
            //     float _BendWait;
            //     half4 _WindDirection;
            //     half _Cutoff;
            // CBUFFER_END
            //
            // TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
            //
            // struct Attributes
            // {
            //     float3 positionOS : POSITION;
            //     float3 normal     : NORMAL;
            //     float2 uv         : TEXCOORD0;
            //     float4 color      : COLOR;
            //     uint instanceID : SV_InstanceID;
            // };
            //
            // struct Varyings
            // {
            //     float4 positionCS : SV_POSITION;
            //     float2 uv         : TEXCOORD0;
            // };
            //
            // Varyings vert (Attributes IN)
            // {
            //     WindStruct wind_data;
            //     wind_data.windSpeed = _WindSpeed;
            //     wind_data.vertexColor = IN.color;
            //     wind_data.leafStrength = _LeafStrength;
            //     wind_data.normalOS = IN.normal;
            //     wind_data.positionOS = IN.positionOS.xyz;
            //     wind_data.bendStrength = _BendStrength;
            //     wind_data.bendSpeed = _BendSpeed;
            //     wind_data.bendWait = _BendWait;
            //     wind_data.windDirection = _WindDirection.xy;
            //     
            //     half3 wind = PlantWind(wind_data);    
            //
            //     IN.positionOS.xyz += wind;
            //     float3 worldPos = GetInstanceWorldPosition(IN.positionOS,IN.instanceID);
            //     Varyings OUT;
            //     OUT.positionCS = TransformWorldToHClip(worldPos);
            //     OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);
            //     return OUT;
            // }
            //
            // half4 frag (Varyings input) : SV_Target
            // {
            //     real4 finalColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv);
            //     clip(finalColor.a - _Cutoff);
            //     return finalColor;
            // }
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
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "../HLSL/VgSystem/Leaf/LeafIndirectInput.hlsl"
            #include "../HLSL/VgSystem/Leaf/LeafDirectDepthOnly.hlsl"
            ENDHLSL
        }
        

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float _WindStrength;
                float _BoundsRadius;
                float4 _MainTex_ST;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normal     : NORMAL;
                float2 uv         : TEXCOORD0;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = GetInstanceWorldPosition(input.positionOS,input.instanceID);

            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
            #else
                float3 lightDirectionWS = _LightDirection;
            #endif

                float4 positionCS = TransformWorldToHClip(positionWS);

            #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #endif

                return positionCS;
            }

            Varyings vert (Attributes IN)
            {
                // float3 worldPos = GetInstanceWorldPosition(IN.positionOS,IN.instanceID);
                Varyings OUT;
                OUT.positionCS = GetShadowPositionHClip(IN);
                OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);
                return OUT;
            }

            half4 frag (Varyings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
    CustomEditor "LWGUI.LWGUI"
}

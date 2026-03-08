Shader "URP/VgSystem/LitIndirect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _WindStrength ("Wind Strength", Range(0, 1)) = 0.5
        _BoundsRadius ("Bounds Radius", Float) = 50
        [Toggle(GRAPHICDRAW_ON)] graphicDraw("使用批处理绘制",float) = 1
        
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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // Lighting & shadows
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float _WindStrength;
                float _BoundsRadius;
                float4 _MainTex_ST;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normal     : NORMAL;
                float2 uv         : TEXCOORD0;
                float4 color      : COLOR;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS   : TEXCOORD2;
            };

            Varyings vert (Attributes IN)
            {
                float3 worldPos = GetInstanceWorldPosition(IN.positionOS,IN.instanceID);
                Varyings OUT;
                OUT.positionCS = TransformWorldToHClip(worldPos);
                OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);
                OUT.positionWS = worldPos;
                OUT.normalWS = GetInstanceWorldNormal(IN.normal, IN.instanceID);
                return OUT;
            }

            half4 frag (Varyings input) : SV_Target
            {
                real4 baseColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv);
                clip(baseColor.a - 0.5);

                half3 albedo = baseColor.rgb * _Color.rgb;
                half3 normalWS = normalize(input.normalWS);

                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                half NdotL = saturate(dot(normalWS, mainLight.direction));

                half3 lighting = SampleSH(normalWS);
                lighting += mainLight.color * (mainLight.distanceAttenuation * mainLight.shadowAttenuation * NdotL);

                #if defined(_ADDITIONAL_LIGHTS)
                uint additionalCount = (uint)GetAdditionalLightsCount();
                for (uint i = 0u; i < additionalCount; i++)
                {
                    Light light = GetAdditionalLight(i, input.positionWS, half4(1, 1, 1, 1));
                    half atten = light.distanceAttenuation * light.shadowAttenuation;
                    half addNdotL = saturate(dot(normalWS, light.direction));
                    lighting += light.color * (atten * addNdotL);
                }
                #endif

                return half4(albedo * lighting, baseColor.a * _Color.a);
            }
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
            #pragma vertex vert
            #pragma fragment frag

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float _WindStrength;
                float _BoundsRadius;
                float4 _MainTex_ST;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normal     : NORMAL;
                float2 uv         : TEXCOORD0;
                float4 color      : COLOR;
                uint instanceID : SV_InstanceID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            Varyings vert (Attributes IN)
            {
                float3 worldPos = GetInstanceWorldPosition(IN.positionOS,IN.instanceID);
                Varyings OUT;
                OUT.positionCS = TransformWorldToHClip(worldPos);
                OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);
                return OUT;
            }

            half frag (Varyings input) : SV_Target
            {
                real4 finalColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv);
                clip(finalColor.a - 0.5);
                return input.positionCS.z;
            }
            ENDHLSL
        }
    }
    CustomEditor "LWGUI.LWGUI"
}

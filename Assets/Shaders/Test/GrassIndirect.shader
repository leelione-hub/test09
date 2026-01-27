Shader "URP/VgSystem/GrassIndirect"
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
        // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // #pragma multi_compile _ GRAPHICDRAW_ON
        // struct GrassInstanceData
        // {
        //     float3 position;
        //     float rotationY;
        //     float2 scale;
        // };
        // struct WindStruct
        // {
        //     half windSpeed;
        //     half4 vertexColor;
        //     half leafStrength;
        //     half3 normalOS;
        //     half3 positionOS;
        //     half bendStrength;
        //     half bendSpeed;
        //     half bendWait;
        //     half2 windDirection;
        // };
        // StructuredBuffer<GrassInstanceData> _InstanceBuffer;
        //
        // float Remap(float inValue, float minold ,float maxOld, float minNew, float maxNew)
        // {
        //     return (minNew + (inValue - minold) * (maxNew - minNew) / (maxOld - minold));
        // }
        //
        // float3 GetInstanceWorldPosition(float3 positionOS,uint instanceID)
        // {
        //     #ifdef GRAPHICDRAW_ON
        //     GrassInstanceData data = _InstanceBuffer[instanceID];
        //
        //     float c = cos(data.rotationY);
        //     float s = sin(data.rotationY);
        //
        //     float3 pos = positionOS;
        //     
        //     pos.xz *= data.scale.x;
        //     pos.y *= data.scale.y;
        //     float3 rotated;
        //     rotated.x = pos.x * c - pos.z * s;
        //     rotated.z = pos.x * s + pos.z * c;
        //     rotated.y = pos.y;
        //
        //     float3 worldPos = rotated + data.position;
        //     return worldPos;
        //     #else
        //     return TransformObjectToWorld(positionOS);
        //     #endif
        //     
        // }
        // // 简单的风动画
        // float3 ApplyWind(float3 position, float3 normal, float strength)
        // {
        //     float windTime = _Time.y * 0.5;
        //     float windX = sin(position.x * 0.1 + windTime) * 0.1;
        //     float windZ = cos(position.z * 0.1 + windTime) * 0.1;
        //     
        //     float3 wind = float3(windX, 0, windZ) * strength;
        //     return position + normal * wind;
        // }
        //
        // half3 PlantWind(WindStruct windData)
        // {
        //     float3 objToWorld = mul( GetObjectToWorldMatrix(), float4( float3( 0,0,0 ), 1 ) ).xyz;
        //     float objXZ = objToWorld.x + objToWorld.z;
        //     float a = windData.windSpeed * _TimeParameters.x * windData.vertexColor.g + objXZ;
        //     half f1 = sin(a);
        //     half f2 = windData.vertexColor.r;
        //     half f3 = windData.leafStrength;
        //     half3 f4 = windData.normalOS;
        //     
        //
        //     half b = windData.positionOS.y * Remap(windData.bendStrength,0,1,0,0.1) * windData.vertexColor.b;
        //
        //     float c = cos(windData.bendSpeed * _TimeParameters.x + objXZ);
        //     
        //     half2 d = b * sign(c) * (1 - pow(1 - abs(c) ,windData.bendWait)) * windData.windDirection;
        //     
        //     half3 finalWind = (f1 * f2 * f3 * f4) + half3(d.x,0.001,d.y);
        //
        //     return finalWind;
        // }
        #include "../HLSL/VgSystem/VgVertexInput.hlsl"
        #include "../HLSL/VgSystem/VgVertexWind.hlsl"
        //#include "UnityIndirect.cginc"
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
                WindStruct wind_data;
                wind_data.windSpeed = 1;
                wind_data.vertexColor = IN.color;
                wind_data.leafStrength = 0.1;
                wind_data.normalOS = IN.normal;
                wind_data.positionOS = IN.positionOS.xyz;
                wind_data.bendStrength = 1.5;
                wind_data.bendSpeed = 1;
                wind_data.bendWait = 1.2;
                wind_data.windDirection = half2(1,1);
                
                half3 wind = PlantWind(wind_data);    
                IN.positionOS.xyz += wind;
                float3 worldPos = GetInstanceWorldPosition(IN.positionOS,IN.instanceID);
                Varyings OUT;
                OUT.positionCS = TransformWorldToHClip(worldPos);
                OUT.uv = TRANSFORM_TEX(IN.uv,_MainTex);
                return OUT;
            }

            half4 frag (Varyings input) : SV_Target
            {
                real4 finalColor = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv);
                clip(finalColor.a - 0.5);
                return finalColor * _Color;
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
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
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
            Name "DephtOnly"
            
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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            

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
                WindStruct wind_data;
                wind_data.windSpeed = 1;
                wind_data.vertexColor = IN.color;
                wind_data.leafStrength = 0.1;
                wind_data.normalOS = IN.normal;
                wind_data.positionOS = IN.positionOS.xyz;
                wind_data.bendStrength = 1.5;
                wind_data.bendSpeed = 1;
                wind_data.bendWait = 1.2;
                wind_data.windDirection = half2(1,1);
                
                half3 wind = PlantWind(wind_data);    
                IN.positionOS.xyz += wind;
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

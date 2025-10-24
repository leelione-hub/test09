Shader "Custom/CFlowMap"
{
    Properties
    {
        // Specular vs Metallic workflow
        _WorkflowMode("WorkflowMode", Float) = 1.0

        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        
        _FlowMap("FlowMap",2D) = "white"{}
        _FlowSpeed("_FlowSpeed",Range(-10,10)) = 0
    }

    SubShader
    {
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
        }
        LOD 300

        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
                "Queue" = "Transparent"
            }
            

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex vertex
            #pragma fragment fragment

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
            

            TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
            TEXTURE2D(_FlowMap);        SAMPLER(sampler_FlowMap);
            float4 _BaseMap_ST;

            float _FlowSpeed;
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float4 color        : COLOR;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord     : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                float4 positionCS               : SV_POSITION;
                float4 normalWS                 : TEXCOORD1;
                float4 vertColor                : TEXCOORD2;
            };

            ///////////////////////////////////////////////////////////////////////////////
            //                  Vertex and Fragment functions                            //
            ///////////////////////////////////////////////////////////////////////////////

            // Used in Standard (Physically Based) shader
            Varyings vertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                VertexPositionInputs position_inputs = GetVertexPositionInputs(input.positionOS);
                output.positionCS = position_inputs.positionCS;
                VertexNormalInputs normal_inputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS.xyz = normal_inputs.normalWS;
                output.uv = TRANSFORM_TEX(input.texcoord,_BaseMap);
                output.vertColor = input.color;
                return output;
            }

            // Used in Standard (Physically Based) shader
            void fragment(
                Varyings input
                , out half4 outColor : SV_Target0
            )
            {

                float4 dir = SAMPLE_TEXTURE2D(_FlowMap,sampler_FlowMap,input.uv) * 2 - 1;
                //outColor = dir;

                float2 uv = frac(input.uv + dir.rg * _FlowSpeed);

                float phase1 = frac(_Time.y * 0.1 * _FlowSpeed);
                float phase2 = frac(_Time.y * 0.1 * _FlowSpeed + 0.5);

                float2 uv1 = input.uv + dir * phase1;
                float2 uv2 = input.uv + dir * phase2;

                float4 color1 = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,uv1);
                float4 color2 = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,uv2);

                float blend = abs((0.5 - phase1) / 0.5);
                

                float4 finalColor = lerp(color1,color2,blend);
                
                outColor = finalColor;
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
Shader "Hidden/Vegetation/TerrainBlendBaker"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            ZWrite Off
            ZTest Always
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_Control);
            SAMPLER(sampler_Control);
            TEXTURE2D(_Splat0);
            SAMPLER(sampler_Splat0);
            TEXTURE2D(_Splat1);
            SAMPLER(sampler_Splat1);
            TEXTURE2D(_Splat2);
            SAMPLER(sampler_Splat2);
            TEXTURE2D(_Splat3);
            SAMPLER(sampler_Splat3);

            float4 _Splat0_ST;
            float4 _Splat1_ST;
            float4 _Splat2_ST;
            float4 _Splat3_ST;
            half4 _DiffuseRemapScale0;
            half4 _DiffuseRemapScale1;
            half4 _DiffuseRemapScale2;
            half4 _DiffuseRemapScale3;

            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.uv = float2((input.vertexID << 1) & 2, input.vertexID & 2);
                output.positionCS = float4(output.uv * 2.0f - 1.0f, 0.0f, 1.0f);
                output.uv.y = 1.0f - output.uv.y;
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half4 splatControl = SAMPLE_TEXTURE2D(_Control, sampler_Control, input.uv);
                half weight = dot(splatControl, half4(1, 1, 1, 1));
                splatControl /= max(weight, HALF_MIN);

                float2 uv0 = input.uv * _Splat0_ST.xy + _Splat0_ST.zw;
                float2 uv1 = input.uv * _Splat1_ST.xy + _Splat1_ST.zw;
                float2 uv2 = input.uv * _Splat2_ST.xy + _Splat2_ST.zw;
                float2 uv3 = input.uv * _Splat3_ST.xy + _Splat3_ST.zw;

                half4 diffAlbedo0 = SAMPLE_TEXTURE2D(_Splat0, sampler_Splat0, uv0);
                half4 diffAlbedo1 = SAMPLE_TEXTURE2D(_Splat1, sampler_Splat1, uv1);
                half4 diffAlbedo2 = SAMPLE_TEXTURE2D(_Splat2, sampler_Splat2, uv2);
                half4 diffAlbedo3 = SAMPLE_TEXTURE2D(_Splat3, sampler_Splat3, uv3);

                half3 blended = 0.0h;
                blended += diffAlbedo0.rgb * (_DiffuseRemapScale0.rgb * splatControl.r);
                blended += diffAlbedo1.rgb * (_DiffuseRemapScale1.rgb * splatControl.g);
                blended += diffAlbedo2.rgb * (_DiffuseRemapScale2.rgb * splatControl.b);
                blended += diffAlbedo3.rgb * (_DiffuseRemapScale3.rgb * splatControl.a);
                return half4(blended, 1.0h);
            }
            ENDHLSL
        }
    }
}

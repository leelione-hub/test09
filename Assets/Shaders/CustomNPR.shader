Shader "Custom/URP_AnimeNPR"
{
    Properties
    {
        [Header(Base Textures)]
        _BaseMap("Albedo", 2D) = "white" {}
        _BaseColor("Color Tint", Color) = (1,1,1,1)
        
        _LightMap("Light Map",2D) = "white"{}
        _MetalMap("Metal Map",2D) = "white"{}
        _ShadowRampMap("ShadowRampMap",2D) = "black"{}
        _ShadowSmoothness("ShadowSmooth",Range(0,1)) = 0.5
        
        [Header(Specular)]
        _StrokeRange("StrokeRange",Float) = 0.3
        _PatternRange("PatternRange",Float) = 1
        _MetalInternsity("MetalInternsity",Range(0,1)) = 0
        
        [Main(Body , _, off, off)] _body("BodyType",Float) = 1
        [KWEnum(Body, Body, _BODY, BodyFace, _FACE, Hair, _HAIR)] _enum ("KWEnum", float) = 0
        [Sub(Body)][ShowIf(_enum, Equal, 1)] _FaceShadowMap("FaceShadow Map",2D) = "black"{}
        [Sub(Body)][ShowIf(_enum, Equal, 1)] _FaceShadowColor("FaceShadowColor",Color) = (0.8,0.8,0.8,1)
        [Sub(Body)][ShowIf(_enum, Equal, 1)] _FaceShaowOffset("FaceShaowOffset",Range(-0.5,0.5)) = 0
        [Sub(Body)][ShowIf(_enum, Equal, 1)] _FaceShadowMapPow("FaceShadowMapPow",Range(0,1)) = 0.3
        [Sub(Body)][ShowIf(_enum, Equal, 2)] _HairDarkShadowSmooth("HairShadowSmooth",Range(-1,1)) = -0.5
        [Sub(Body)][ShowIf(_enum, Equal, 2)] _HairDarkShadowArea("HairDarkShadowArea",Range(-1,1)) = 0
        [Sub(Body)][ShowIf(_enum, Equal, 2)] _HairSmoothShadowIntensity("HairSmoothShadowIntensity",Range(0,1)) = 1
        [Sub(Body)][ShowIf(_enum, Equal, 2)] _HairRange("HairRange",Range(0,1)) = 0
        [Sub(Body)][ShowIf(_enum, Equal, 2)] _HairViewSpecularThreshold("HairViewSpecularThreshold",Range(0,5)) = 0.3
        [Sub(Body)][ShowIf(_enum, Equal, 2)] _HairSpecAreaBaseline("HairSpecAreaBaseline",Float) = 0.1
        [Sub(Body)][ShowIf(_enum, Equal, 2)] _HairAccGroveBaseline("HairAccGroveBaseline",Float) = 0.1
        
        [Main(Specular)] _specular("Specular",Float) = 1
        
        [Main(Emission,_EMISSION)] _emission("Emission",Float) = 1
        [Sub(Emission)] _EmissionIntensity("Emission Intensity",Float) = 0.1
        
        [Main(EdgeLight,_EDGELIGHT)] _edgelight("EdgeLight",Float) = 0
        [Sub(EdgeLight)] _EdgeWidth("EdgeLight Width",Range(0,1)) = 0.1
        [Sub(EdgeLight)] _EdgeColor("EdgeLight Color",Color) = (1,1,1)
        [Sub(EdgeLight)] _EdgeIntensity("EdgeLight Intensity",Float) = 1
        
        [Toggle] _InNight("InNight",Float) = 0

        [Header(Outline)]
        _OutlineColor("Outline Color", Color) = (0,0,0,1)
        _OutlineWidth("Outline Width", Range(0, 1)) = 0.002
    }

    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque" 
            "RenderPipeline"="UniversalPipeline" 
            "Queue"="Geometry" 
        }
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Cull Back

            HLSLPROGRAM
            #pragma vertex CustomNPRForwardVert
            #pragma fragment CustomNPRForwardFrag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma shader_feature _HAIR
            #pragma shader_feature _FACE
            #pragma shader_feature _BODY
            #pragma shader_feature_fragment _EMISSION
            #pragma shader_feature _EDGELIGHT

            #include "Assets/Shaders/HLSL/CustomNPR/CustomNPRInput.hlsl"
            #include "Assets/Shaders/HLSL/CustomNPR/CustomNPRForward.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ZTest LEqual
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma vertex CustomNPRDepthOnlyVertex
            #pragma fragment CustomNPRDepthOnlyFragment
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            #include "Assets/Shaders/HLSL/CustomNPR/CustomNPRInput.hlsl"
            #include "Assets/Shaders/HLSL/CustomNPR/CustomNPRDepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 vertexColor : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;
                float _OutlineWidth;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;

                half outlineIntensity = input.color.a;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                half3 normalVS = TransformWorldToViewNormal(normalInput.normalWS);
                float2 outlineDir = normalize(normalVS.xy);
                float outlineScale = _OutlineWidth * 0.05 * step(0.5, outlineIntensity) * outlineIntensity;

                outlineDir.x *= _ScreenParams.y / max(_ScreenParams.x, 1.0);
                vertexInput.positionCS.xy += outlineDir * outlineScale * vertexInput.positionCS.w;
                
                output.positionCS = vertexInput.positionCS;
                output.vertexColor = input.color.rgb;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half3 finalColor = input.vertexColor * _OutlineColor.rgb;
                return half4(finalColor, 1);
            }
            ENDHLSL
        }
        
        UsePass "Universal Render Pipeline/Lit/DEPTHNORMALS"
        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"
    }
    CustomEditor "LWGUI.LWGUI"
}

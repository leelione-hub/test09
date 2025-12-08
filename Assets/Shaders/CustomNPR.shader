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
        
        [Main(Body,_BODY)] _body("Body",Float) = 1
        [KWEnum(Body, Body, _BODY, BodyFace, _FACE, Hair, _HAIR)] _enum ("KWEnum", float) = 0
//        [Sub(Body)][ShowIf(_enum, Equal, 0)] _key1_Float1 ("Key1 Float", float) = 0
//		[Sub(Body)][ShowIf(_enum, Equal, 1)] _key2_Float2 ("Key2 Float", float) = 0
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
        //[Sub(Body)]_BodyShadowSmooth("BodyShadowSmooth",Range(0,1)) = 0.5
        
        //[Main(Hair,_HAIR)] _hair("Hair",Float) = 0
       
        
//        [Main(Face,_FACE)] _face("Face",Float) = 0
        
        
        [Main(Specular)] _specular("Specular",Float) = 1
        
        
        
        [Toggle] _InNight("InNight",Float) = 0

        [Header(Outline)]
        _OutlineColor("Outline Color", Color) = (0,0,0,1)
        _OutlineWidth("Outline Width", Range(0, 0.05)) = 0.002
    }

    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque" 
            "RenderPipeline"="UniversalPipeline" 
            "Queue"="Geometry" 
        }

        // =======================================================
        // Pass 1: Outline (背面描边)
        // =======================================================
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front // 剔除正面，只渲染背面
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color    : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 vertexColor: TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;
                float _OutlineWidth;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // 简单的法线外扩
                half outlineIntensity = input.color.a;
                float3 positionOS = input.positionOS.xyz + input.normalOS * _OutlineWidth * 0.1 * step(0.5,outlineIntensity) * outlineIntensity;;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(positionOS);
                
                output.positionCS = vertexInput.positionCS;
                output.vertexColor = input.color.rgb;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half3 finalColor = input.vertexColor * _OutlineColor;
                return half4(finalColor,1);
            }
            ENDHLSL
        }

        // =======================================================
        // Pass 2: Main Lighting (卡通渲染主体)
        // =======================================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma shader_feature _HAIR
            #pragma shader_feature _FACE
            #pragma shader_feature _BODY

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 color : Color;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 vertexColor  : TEXCOORD3;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _ShadowColor;
                half4 _FaceShadowColor;
                float _ShadowThreshold;
                float _ShadowSmoothness;
                real4 _SpecularColor;
                float _FaceShaowOffset;
                float _FaceShadowMapPow;
                float _Glossiness;
                float _SpecularThreshold;
                float _MetalInternsity;
                real4 _RimColor;
                float _RimPower;
                float _RimThreshold;
                float _CurvatureScale;
                float _HairDarkShadowSmooth;
                float _HairDarkShadowArea;
                float _HairSmoothShadowIntensity;
                float _HairRange;
                float _StrokeRange;
                float _PatternRange;
                float _HairViewSpecularThreshold;
                float _HairSpecAreaBaseline;
                float _HairAccGroveBaseline;
                half _InNight;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_LightMap);SAMPLER(sampler_LightMap);
            TEXTURE2D(_MetalMap);SAMPLER(sampler_MatelMap);
            TEXTURE2D(_FaceShadowMap);SAMPLER(sampler_FaceShadowMap);
            TEXTURE2D(_ShadowRampMap);SAMPLER(sampler_ShadowRampMap);

            float RoughnessToSpecularExponent(float roughness)
            {
                return sqrt(2 / (roughness + 2));
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.vertexColor = input.color;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 1. 基础数据准备
                float3 N = NormalizeNormalPerPixel(input.normalWS);
                float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);
                half4 vertexColor = input.vertexColor;
                
                real4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                real4 lightMap = SAMPLE_TEXTURE2D(_LightMap,sampler_LightMap,input.uv);
                //real4 metalMap = SAMPLE_TEXTURE2D(_MetalMap,sampler_MatelMap,V.xy * 0.5 + 0.5);
                
                
                // 2. 获取主光源信息 (方向, 颜色, 阴影衰减)
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                real3 L = normalize(mainLight.direction);
                real3 lightColor = mainLight.color;
                real shadowAttenuation = mainLight.shadowAttenuation; // 接收物体投影

                // 3. Lambert Diffuse (N dot L)
                real NdotL = saturate(dot(N, L));
                real3 H = normalize(V + L);
                real NdotH = saturate(dot(N,H));
                real NdotV = saturate(dot(N,V));
                float ndotLRaw = dot(N,L);

                //lambert AO
                float lambert = NdotL;
                real lambertAO = lambert * saturate(lightMap.g);
                real lambertRampAO = smoothstep(0,_ShadowSmoothness,lambertAO);

                //日夜状态
                half dayOrNight = (1 - step(0.1,_InNight)) * 0.5 + 0.03;

                //lambert系数(采样): 半lambert采样, 偏移半lambert采样
                float halfSampler = saturate(lambertRampAO * 0.5 + 0.5);
                //half halfSampler = smoothstep(-1,0.75,lambertRampAO) /*saturate(lambertRampAO * 0.5 + 0.5)*/;
                half rampOffset = step(0.5,vertexColor.g) == 1 ? vertexColor.g : vertexColor.g - 1;
                float adjustedHalfSampler = saturate(halfSampler + rampOffset);
                //float adjustedHalfSampler = saturate(pow(saturate(lambertAO + 1 - _ShadowSmoothness),2));
                //return adjustedHalfSampler;
                half3 diffuse = 0;
                half3 specualr = 0;

                #ifdef _BODY
                ///漫反射diffuse: Ramp+AO
                float rampV = saturate(lightMap.a * 0.45 + dayOrNight);
                float2 rampUV = float2(adjustedHalfSampler,rampV);
                half4 rampShadow = SAMPLE_TEXTURE2D(_ShadowRampMap,sampler_ShadowRampMap,rampUV);
                diffuse = lerp(rampShadow,lightColor, lambertRampAO) * albedo;
                #endif
               
                
                #ifdef _FACE
                float facerampV = saturate(lightMap.a * 0.45 + dayOrNight);
                float2 facerampUV = float2(adjustedHalfSampler,facerampV);
                half4 facerampShadow = SAMPLE_TEXTURE2D(_ShadowRampMap,sampler_ShadowRampMap,facerampUV);
                float sinx = sin(_FaceShaowOffset);
                float cosx = cos(_FaceShaowOffset);
                float2x2 rotationOffset = float2x2(cosx,-sinx,sinx,cosx);

                float3 Front = unity_ObjectToWorld._12_22_32;
                float3 Right = unity_ObjectToWorld._13_23_33;
                float2 LightDir = mul(rotationOffset,mainLight.direction.xz);
                //计算xz平面下的关照角度
                float FrontL = dot(normalize(Front.xz),normalize(LightDir));
                float RightL = dot(normalize(Right.xz),normalize(LightDir));
                RightL = -(acos(RightL) / PI - 0.5) * 2;

                float2 lightData = float2(SAMPLE_TEXTURE2D(_FaceShadowMap,sampler_FaceShadowMap,input.uv.xy).r,
                    SAMPLE_TEXTURE2D(_FaceShadowMap,sampler_FaceShadowMap,float2(-input.uv.x,input.uv.y)).r);
                lightData = pow(abs(lightData),_FaceShadowMapPow);
                float lightAttenuation = step(0,FrontL) * min(step(RightL,lightData.x),step(-RightL ,lightData.y));
                //float lightAttenuation = step(0,FrontL) * min(smoothstep(RightL- 0.01,RightL + 0.01,lightData.x),smoothstep(-RightL - 0.01,-RightL + 0.01,lightData.y));
                diffuse = lerp(facerampShadow, lightColor, lightAttenuation) * albedo;
                lightMap.r = 0;
                #endif
                

                #ifdef _HAIR
                // 1级影+2级影+AO
                float hairMapUV_U = smoothstep(_HairDarkShadowSmooth,_HairDarkShadowArea,ndotLRaw);
                float shadowUpperBound = step(ndotLRaw,_HairDarkShadowSmooth);
                float isHair = step(0.11,lightMap.r) - step(0.9,lightMap.r);
                float litHair = step(_HairDarkShadowArea,ndotLRaw);
                //1级暗部阴影
                float vDark = saturate(0.35 + dayOrNight);
                float2 uvDark = float2(adjustedHalfSampler,vDark);
                //float2 uvDark = float2(hairMapUV_U,vDark);
                real4 hairShadowD = SAMPLE_TEXTURE2D(_ShadowRampMap,sampler_ShadowRampMap,uvDark);
                //2级亮阴影
                float vLight = saturate(0.45 + dayOrNight);
                float2 uvLight = float2(adjustedHalfSampler,vLight);
                //float2 uvLight = float2(hairMapUV_U,vLight);
                real4 hairShadowL = SAMPLE_TEXTURE2D(_ShadowRampMap,sampler_ShadowRampMap,uvLight);
                real3 shadowHair = lerp(hairShadowD,hairShadowL,hairMapUV_U) * step(ndotLRaw,_HairDarkShadowArea);
                float lightSmoothArea = step(_HairDarkShadowArea,ndotLRaw);
                float3 lightShadowSmooth = 0.5 * _HairSmoothShadowIntensity * hairShadowL * lightSmoothArea * shadowUpperBound;
                
                half3 diffuseHair = (shadowHair + litHair) * albedo * isHair + lightShadowSmooth * isHair;
                half3 diffuseHairAccessory = albedo * step(lightMap.r ,_HairRange);
                half aoArea = lightMap.g;
                diffuse = (diffuseHair + diffuseHairAccessory) * aoArea;
                diffuse += hairShadowD * (1 - aoArea) * albedo;
                #endif
                
                /// =======高光========
                #ifdef _BODY
                // 不管所谓的高光分层了，直接将lightmap.b通道作为粗糙度lihtmap.r作为金属度
                float specularPow = pow(NdotV, RoughnessToSpecularExponent(lightMap.b));
                float3 NormalVS = mul(unity_MatrixV,N);
                half4 MetalMap = SAMPLE_TEXTURE2D(_MetalMap,sampler_MatelMap,NormalVS.xy);
                //float metalRef = MetalMap.r * step(0.98,lightMap.r);
                //specualr = (metalRef + 0.5) * albedo * specularPow * lightMap.b;
                half metal = step(0.98,lightMap.r);
                specualr = MetalMap.r * metal * albedo + (1 - metal) * lerp(0.04,albedo,lightMap.r) * specularPow * lightMap.b;
                #endif

                #ifdef _HAIR
                float3 viewPosWS = GetCurrentViewPosition();
                float disY = smoothstep(-0.5,0.5, input.positionWS.y - viewPosWS. y);
                float3 UP = normalize(unity_ObjectToWorld._11_21_31);
                float UpDotV = saturate(dot(UP,V));
                float hairSpecularMask = disY * lightMap.b;
                specualr = hairSpecularMask * ndotLRaw;
                #endif
                
                
                return half4(specualr + diffuse ,1);
            }
            ENDHLSL
        }
        
        UsePass "Universal Render Pipeline/Lit/DEPTHONLY"
        UsePass "Universal Render Pipeline/Lit/DEPTHNORMALS"
        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"
    }
    CustomEditor "LWGUI.LWGUI"
}
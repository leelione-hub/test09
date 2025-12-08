Shader "Custom/URP_DebugTools"
{
    Properties
    {
        [Header(Base Settings)]
        _BaseMap("Base Texture", 2D) = "white" {}

        [Header(Debug Settings)]
        // 使用 KeywordEnum 生成下拉菜单，Unity 会自动生成对应的 Keyword
        [KeywordEnum(None, Tex_RGB, Tex_R, Tex_G, Tex_B, Tex_A, VertColor_RGB, VertColor_R,VertColor_G,VertColor_B,VertColor_A, Normal_World, Normal_Object, Tangent, Bitangent, UV_Coords, UV_Checkerboard, WorldPos_Grid)] 
        _DebugMode("Debug Mode", Float) = 0
        
        [Header(Checkerboard Settings)]
        _GridFrequency("Grid Frequency", Float) = 10.0
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
            Name "DebugPass"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            // 定义所有的 Keyword，对应上面的属性
            #pragma multi_compile _DEBUGMODE_NONE _DEBUGMODE_TEX_RGB _DEBUGMODE_TEX_R _DEBUGMODE_TEX_G _DEBUGMODE_TEX_B _DEBUGMODE_TEX_A _DEBUGMODE_VERTCOLOR_RGB _DEBUGMODE_VERTCOLOR_R _DEBUGMODE_VERTCOLOR_G _DEBUGMODE_VERTCOLOR_B _DEBUGMODE_VERTCOLOR_A _DEBUGMODE_NORMAL_WORLD _DEBUGMODE_NORMAL_OBJECT _DEBUGMODE_TANGENT _DEBUGMODE_BITANGENT _DEBUGMODE_UV_COORDS _DEBUGMODE_UV_CHECKERBOARD _DEBUGMODE_WORLDPOS_GRID

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 color : COLOR; // 顶点色
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 normalOS : TEXCOORD3;
                float3 tangentWS : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 positionWS : TEXCOORD6;
            };

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            float _GridFrequency;

            Varyings vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.uv = input.uv;
                
                output.normalWS = normalInput.normalWS;
                output.normalOS = input.normalOS; // 传递物体空间法线
                output.tangentWS = normalInput.tangentWS;
                
                // 顶点色默认白色，防止模型没有顶点色时显示全黑
                output.color = input.color; 
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                half4 finalColor = half4(1, 1, 1, 1);
                float4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                // ====================================================
                // Mode 0: None / Texture RGB (默认显示贴图)
                // ====================================================
                #if defined(_DEBUGMODE_NONE) || defined(_DEBUGMODE_TEX_RGB)
                    finalColor = texColor;

                // ====================================================
                // Mode: Texture Channels (贴图单通道检查)
                // ====================================================
                #elif defined(_DEBUGMODE_TEX_R)
                    // 以灰度显示 R 通道，方便观察数值
                    finalColor = half4(texColor.rrr, 1); 
                #elif defined(_DEBUGMODE_TEX_G)
                    finalColor = half4(texColor.ggg, 1);
                #elif defined(_DEBUGMODE_TEX_B)
                    finalColor = half4(texColor.bbb, 1);
                #elif defined(_DEBUGMODE_TEX_A)
                    finalColor = half4(texColor.aaa, 1);

                // ====================================================
                // Mode: Vertex Colors (顶点色检查)
                // ====================================================
                #elif defined(_DEBUGMODE_VERTCOLOR_RGB)
                    finalColor = input.color;
                #elif defined(_DEBUGMODE_VERTCOLOR_R)
                    finalColor = half4(input.color.rrr, 1);
                #elif defined(_DEBUGMODE_VERTCOLOR_G)
                    finalColor = half4(input.color.ggg, 1);
                #elif defined(_DEBUGMODE_VERTCOLOR_B)
                    finalColor = half4(input.color.bbb, 1);
                #elif defined(_DEBUGMODE_VERTCOLOR_A)
                    finalColor = half4(input.color.aaa, 1);

                // ====================================================
                // Mode: Normals (法线检查)
                // ====================================================
                #elif defined(_DEBUGMODE_NORMAL_WORLD)
                    // 将法线从 [-1, 1] 映射到 [0, 1] 以便显示
                    finalColor = half4(normalize(input.normalWS) * 0.5 + 0.5, 1);
                #elif defined(_DEBUGMODE_NORMAL_OBJECT)
                    finalColor = half4(normalize(input.normalOS) * 0.5 + 0.5, 1);

                // ====================================================
                // Mode: Tangents & Bitangents (切线空间检查)
                // ====================================================
                #elif defined(_DEBUGMODE_TANGENT)
                    finalColor = half4(normalize(input.tangentWS.xyz) * 0.5 + 0.5, 1);
                #elif defined(_DEBUGMODE_BITANGENT)
                    // 计算副切线 (Bitangent) = Cross(Normal, Tangent) * Tangent.w
                    // Tangent.w 决定了坐标系的旋向性 (-1 或 1)
                    float3 bitangent = cross(input.normalWS, input.tangentWS.xyz) * input.tangentWS.w;
                    finalColor = half4(normalize(bitangent) * 0.5 + 0.5, 1);

                // ====================================================
                // Mode: UVs (UV检查)
                // ====================================================
                #elif defined(_DEBUGMODE_UV_COORDS)
                    // 直接显示 UV，RG通道对应 XY
                    finalColor = half4(input.uv.x, input.uv.y, 0, 1);
                
                #elif defined(_DEBUGMODE_UV_CHECKERBOARD)
                    // 棋盘格：用于检查 UV 拉伸和密度
                    float2 uvScaled = input.uv * _GridFrequency;
                    float2 uvFloor = floor(uvScaled);
                    // 简单的异或逻辑生成棋盘
                    float checker = fmod(uvFloor.x + uvFloor.y, 2.0);
                    // 黑白棋盘
                    finalColor = half4(checker, checker, checker, 1);

                // ====================================================
                // Mode: World Pos Grid (世界坐标密度检查)
                // ====================================================
                #elif defined(_DEBUGMODE_WORLDPOS_GRID)
                    // 根据世界坐标生成网格，检查模型大小或浮点精度
                    float3 posScaled = input.positionWS * _GridFrequency; // 调整网格大小
                    float3 posFrac = frac(posScaled);
                    // 简单的边缘检测
                    float gridLine = step(0.95, posFrac.x) || step(0.95, posFrac.y) || step(0.95, posFrac.z);
                    finalColor = lerp(half4(0.2, 0.2, 0.2, 1), half4(1, 1, 0, 1), gridLine);

                #endif

                return finalColor;
            }
            ENDHLSL
        }
    }
}
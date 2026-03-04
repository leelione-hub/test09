Shader "HiZ/HiZDepthBlit"
{
    Properties
    {
        [HideInInspector] _DepthTexture("Depth Texture", 2D) = "black" {}
        [HideInInspector] _InvSize("Inverse Size", Vector) = (0, 0, 0, 0)
        [HideInInspector] _MipLevel("Mip Level", Int) = 0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        
        Pass
        {
            Name "HiZ_DEPTH_BLIT"
            
            Cull Off
            ZWrite Off
            ZTest Always
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            
            #pragma multi_compile _ HIZ_REVERSED_Z
            
            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            sampler2D _DepthTexture;
            float4 _InvSize;
            int _MipLevel;
            
            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            // 深度比较函数
            float CompareDepth(float d1, float d2)
            {
                #if defined(HIZ_REVERSED_Z)
                    return min(d1, d2);
                #else
                    return max(d1, d2);
                #endif
            }
            
            // 4x4降采样
            float HZBReduce(sampler2D depthTex, float2 uv, float2 invSize)
            {
                float4 depths[4];
                
                [unroll]
                for (int y = 0; y < 2; y++)
                {
                    [unroll]
                    for (int x = 0; x < 2; x++)
                    {
                        float2 offset = float2(x - 0.5, y - 0.5) * invSize * 0.5;
                        depths[y * 2 + x] = tex2D(depthTex, uv + offset);
                    }
                }
                
                // 第一级比较
                float4 result;
                result.x = CompareDepth(depths[0].x, depths[0].y);
                result.y = CompareDepth(depths[0].z, depths[0].w);
                result.z = CompareDepth(depths[1].x, depths[1].y);
                result.w = CompareDepth(depths[1].z, depths[1].w);
                
                // 第二级比较
                return CompareDepth(CompareDepth(result.x, result.y), CompareDepth(result.z, result.w));
            }
            
            float frag(v2f i) : SV_Target
            {
                // 如果是第0层，直接从原始深度纹理采样
                if (_MipLevel == 0)
                {
                    return tex2D(_DepthTexture, i.uv).r;
                }
                
                // 生成下一层Mipmap
                return HZBReduce(_DepthTexture, i.uv, _InvSize.xy);
            }
            
            ENDCG
        }
    }
}

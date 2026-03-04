Shader "HiZ/DebugDepthDisplay"
{
    Properties
    {
        [_MainTex]_DepthTexture("Depth Texture", 2D) = "black" {}
        _MipLevel("Mip Level", Int) = 0
        _ShowDepth("Show Depth", Int) = 1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        
        Pass
        {
            Name "DEBUG_DEPTH_DISPLAY"
            
            Cull Off
            ZWrite Off
            ZTest Always
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            
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
            
            UNITY_DECLARE_TEX2D(_DepthTexture);
            int _MipLevel;
            int _ShowDepth;
            
            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            // 将深度值可视化为颜色
            float3 DepthToColor(float depth)
            {
                // 非线性深度可视化
                depth = saturate(depth);
                
                // 使用热力图颜色方案
                float3 color;
                if (depth < 0.5)
                {
                    // 近处：红色到黄色
                    color = lerp(float3(1, 0, 0), float3(1, 1, 0), depth * 2);
                }
                else
                {
                    // 远处：黄色到蓝色
                    color = lerp(float3(1, 1, 0), float3(0, 0, 1), (depth - 0.5) * 2);
                }
                
                return color;
            }
            
            fixed4 frag(v2f i) : SV_Target
            {
                float depth;
                
                // 采样指定Mipmap层级
                #if defined(SHADER_API_D3D11) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL)
                    depth = _DepthTexture.SampleLevel(sampler_DepthTexture, i.uv, 0).r;
                #else
                    // 对于不支持SampleLevel的API，使用tex2Dlod
                    depth = tex2Dlod(_DepthTexture, float4(i.uv, 0, 0)).r;
                #endif
                
                if (_ShowDepth == 0)
                {
                    // 只显示灰度
                    return fixed4(depth, depth, depth, 1);
                }
                
                // 将深度转换为颜色
                float3 color = DepthToColor(depth);
                
                // 添加网格线以显示Mipmap结构
                float2 grid = frac(i.uv * 16);
                float gridLine = step(0.95, grid.x) + step(0.95, grid.y);
                color = lerp(color, float3(0, 0, 0), gridLine * 0.3);
                
                return fixed4(color, 1);
            }
            
            ENDCG
        }
    }
}

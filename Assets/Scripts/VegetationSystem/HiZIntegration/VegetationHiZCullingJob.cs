using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using UnityEngine;

namespace VegetationSystem.HiZIntegration
{
    /// <summary>
    /// Vegetation Chunk的HiZ剔除Job
    /// 在CPU端执行HiZ遮挡剔除
    /// </summary>
    [BurstCompile]
    public struct VegetationHiZCullingJob : IJobParallelFor
    {
        [ReadOnly] public NativeArray<ChunkInfoForJob> Chunks;
        [ReadOnly] public NativeArray<uint> VisibleChunkGuids;
        [WriteOnly] public NativeArray<byte> Results;
        
        // HiZ参数
        [ReadOnly] public float4x4 VP;
        [ReadOnly] public float DepthBias;
        [ReadOnly] public int BaseWidth;
        [ReadOnly] public int BaseHeight;
        [ReadOnly] public int MipCount;
        [ReadOnly] public bool UseReversedZ;
        
        // 注意：由于无法直接从Job访问GPU纹理，
        // CPU模式需要先将深度金字塔回读到CPU内存
        // 这里提供一个简化版本，实际使用时需要根据深度数据做判断
        
        public void Execute(int index)
        {
            var chunk = Chunks[index];
            
            // 默认可见
            Results[index] = 0;
            
            // 检查是否在可见列表中
            bool isInVisibleList = false;
            for (int i = 0; i < VisibleChunkGuids.Length; i++)
            {
                if (VisibleChunkGuids[i] == chunk.guid)
                {
                    isInVisibleList = true;
                    break;
                }
            }
            
            // 不在视锥体内，跳过
            if (!isInVisibleList)
            {
                Results[index] = 0; // 虽然不在视锥体内，但不是被HiZ剔除的
                return;
            }
            
            // 计算Chunk包围盒在屏幕空间的投影
            float3 center = chunk.center;
            float3 extents = chunk.extents;
            
            // 执行HiZ剔除测试
            bool isOccluded = HiZOcclusionTest(center, extents);
            
            // 0 = 可见, 1 = 被HiZ剔除
            Results[index] = isOccluded ? (byte)1 : (byte)0;
        }
        
        /// <summary>
        /// HiZ遮挡测试
        /// </summary>
        private bool HiZOcclusionTest(float3 center, float3 extents)
        {
            // 定义包围盒的8个角点
            int3[] offsets = new int3[8]
            {
                new int3(1, 1, 1),
                new int3(1, 1, -1),
                new int3(1, -1, 1),
                new int3(1, -1, -1),
                new int3(-1, 1, 1),
                new int3(-1, 1, -1),
                new int3(-1, -1, 1),
                new int3(-1, -1, -1)
            };
            
            float2 minUV = new float2(-10000f,-10000f);
            float2 maxUV = new float2(100000f, 10000f);
            float minZ = float.MaxValue;
            float maxZ = float.MinValue;
            
            bool anyVisible = false;
            
            // 计算所有角点在裁剪空间的坐标
            for (int i = 0; i < 8; i++)
            {
                float3 cornerWorld = center + extents * offsets[i];
                float4 cornerClip = math.mul(VP, new float4(cornerWorld, 1.0f));
                
                // 如果在相机后面，视为可见
                if (cornerClip.w <= 0)
                {
                    anyVisible = true;
                    continue;
                }
                
                cornerClip.xyz /= cornerClip.w;
                
                // 转换到UV空间 [0, 1]
                float2 uv = cornerClip.xy * 0.5f + 0.5f;
                
                // 检查是否在屏幕内
                if (uv.x >= 0 && uv.x <= 1 && uv.y >= 0 && uv.y <= 1)
                {
                    anyVisible = true;
                }
                
                minUV = math.min(minUV, uv);
                maxUV = math.max(maxUV, uv);
                minZ = math.min(minZ, cornerClip.z);
                maxZ = math.max(maxZ, cornerClip.z);
            }
            
            // 如果所有点都在屏幕外或相机后面，视为被剔除
            if (!anyVisible)
            {
                return true;
            }
            
            // 限制UV范围到屏幕内
            minUV = math.clamp(minUV, 0.0f, 1.0f);
            maxUV = math.clamp(maxUV, 0.0f, 1.0f);
            
            // 计算合适的Mipmap级别
            float2 boundsSize = maxUV - minUV;
            float maxSize = math.max(boundsSize.x, boundsSize.y);
            int mipmapLevel = CalculateMipmapLevel(maxSize);
            
            // 计算Mipmap尺寸
            int mipWidth = BaseWidth >> mipmapLevel;
            int mipHeight = BaseHeight >> mipmapLevel;
            
            // 扩展采样范围
            float2 expand = new float2(1.0f / mipWidth, 1.0f / mipHeight);
            minUV -= expand;
            maxUV += expand;
            minUV = math.clamp(minUV, 0.0f, 1.0f);
            maxUV = math.clamp(maxUV, 0.0f, 1.0f);
            
            // 注意：由于Job无法直接访问GPU纹理，这里返回假阳性（视为可见）
            // 实际实现需要将深度数据回读到CPU，或者在GPU端执行剔除
            // 为了完整性，这里保留剔除逻辑框架
            
            // TODO: 从回读的深度数据中采样并比较
            // float sampledDepth = SampleHiZDepth(minUV, maxUV, mipmapLevel);
            // 
            // if (UseReversedZ)
            // {
            //     return minZ > sampledDepth + DepthBias;
            // }
            // else
            // {
            //     return maxZ < sampledDepth - DepthBias;
            // }
            
            return false; // 默认可见
        }
        
        /// <summary>
        /// 计算合适的Mipmap级别
        /// </summary>
        private int CalculateMipmapLevel(float screenSpaceSize)
        {
            if (screenSpaceSize <= 0) return 0;
            
            int mipmapLevel = 0;
            float size = 1.0f;
            
            for (int i = 0; i < MipCount; i++)
            {
                if (screenSpaceSize >= size)
                {
                    mipmapLevel = i;
                    break;
                }
                size *= 0.5f;
            }
            
            return math.clamp(mipmapLevel, 0, MipCount - 1);
        }
        
        /// <summary>
        /// 从HiZ纹理采样深度（需要深度数据回读到CPU）
        /// </summary>
        private float SampleHiZDepth(float2 minUV, float2 maxUV, int mipmapLevel)
        {
            // 这个方法需要深度金字塔数据在CPU端可用
            // 实现方式：
            // 1. 使用AsyncGPUReadback将深度纹理回读到NativeArray
            // 2. 在该Job中读取回传的深度数据
            
            // 目前返回一个占位值
            return UseReversedZ ? 1.0f : 0.0f;
        }
    }
}

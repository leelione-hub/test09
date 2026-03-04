# HiZ深度金字塔调试指南

## 问题描述
深度金字塔显示所有深度值为0，可能的原因：
1. Compute Shader参数未正确设置
2. 坐标计算不匹配
3. 相机深度纹理未正确获取

## 已应用的修复

### 1. 修复Compute Shader参数设置
**文件**: `HizDepthPyramid.cs`

**问题**: `BuildDepthPyramidCompute` 方法中未设置 `_HizDepthTextureBaseWidth` 和 `_HizDepthTextureBaseHeight` 参数。

**修复**: 在方法开始处添加：
```csharp
cmd.SetComputeIntParam(_depthPyramidCS, HizDepthTextureBaseWidthId, _baseSize.x);
cmd.SetComputeIntParam(_depthPyramidCS, HizDepthTextureBaseHeightId, _baseSize.y);
```

### 2. 添加有效性检查
**文件**: `HizDepthPyramid.cs`

**修复**: 在 `CalculateBaseSize` 方法中添加空值和零尺寸检查：
```csharp
if (cameraDepthTexture == null || cameraDepthTexture.width == 0 || cameraDepthTexture.height == 0)
{
    Debug.LogError("[HiZ DepthPyramid] 相机深度纹理无效");
    return;
}
```

### 3. 添加详细注释
**文件**: `HizDepthPyramid.cs`

为 `GetMipCoord` 方法添加了详细的内存布局说明和计算公式。

### 4. 添加坐标验证工具
**文件**: `HiZDiagnosticUtility.cs`, `HiZRuntimeDiagnostics.cs`, `HiZQuickTest.cs`

提供了运行时诊断工具，可以：
- 验证C#和Shader的坐标计算是否一致
- 分析深度金字塔内容
- 创建可视化纹理

## 调试步骤

### 步骤1：启用Debug模式
在 `HizSettings` 中启用 `enableDebug`：
```csharp
var settings = new HizSettings
{
    enableDebug = true,
    // ... 其他设置
};
```

这将输出详细的构建日志，包括：
- 基础尺寸计算
- DepthBlit 线程组信息
- GenMipmap 写入位置和线程组信息

### 步骤2：运行坐标验证
在场景中附加 `HiZQuickTest` 组件，或使用 `HizDepthPyramid` 的 Context Menu "验证坐标计算"。

### 步骤3：检查深度金字塔内容
使用 `HiZDiagnosticUtility.AnalyzeDepthPyramid` 方法来检查每个mip层级的内容。

### 步骤4：可视化深度金字塔
使用 `HiZDiagnosticUtility.CreateVisualizationTexture` 方法创建可视化纹理，检查mip布局。

## 坐标计算验证

### C# 公式
```csharp
public void GetMipCoord(int mipLevel, out int startX, out int startY)
{
    if (mipLevel == 0)
    {
        startX = 0;
        startY = 0;
        return;
    }
    
    int xOffset = baseWidth;  // Mip 0 宽度
    for (int i = 1; i < mipLevel; i++)
    {
        xOffset += Mathf.Max(1, baseWidth >> i);
    }
    
    startX = xOffset;
    startY = 0;
}
```

### Shader 公式
```hlsl
int GetMipStartX(int mipmapLevel, int baseWidth)
{
    if (mipmapLevel == 0) return 0;
    
    int xOffset = baseWidth;  // Mip 0 宽度
    for (int i = 1; i < mipmapLevel; i++)
    {
        xOffset += max(1, baseWidth >> i);
    }
    return xOffset;
}
```

### 示例计算 (BaseWidth = 1024)
| Mip | 起始X | 大小 | 计算过程 |
|-----|-------|------|----------|
| 0 | 0 | 1024x1024 | - |
| 1 | 1024 | 512x512 | 1024 |
| 2 | 1536 | 256x256 | 1024 + 512 |
| 3 | 1792 | 128x128 | 1024 + 512 + 256 |

## 内存布局

```
纹理内存布局 (1024x1024基础尺寸):
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    Mip 0 (1024x1024)                        │ ← 坐标 (0, 0)
│                                                             │
│                                                             │
├──────────────────────────┬──────────────────────────────────┤
│      Mip 1 (512x512)     │        Mip 2 (256x256)           │ ← 坐标 (1024, 0) 和 (1536, 0)
│                          │                                  │
├──────────────────────────┼──────────────────────────────────┤
│  Mip 3 (128x128)  │ Mip 4 (64x64) │ ...                     │ ← 继续横向排列
└─────────────────────────────────────────────────────────────┘
```

## 常见问题

### 1. 所有深度值为0
- 检查 `_CameraDepthTexture` 是否有有效数据
- 检查 `DepthBlit` kernel 是否正确执行
- 检查 Compute Shader 参数是否正确设置

### 2. Mip 1+ 深度值异常
- 检查坐标计算是否匹配（C# vs Shader）
- 检查 `GenMipmap` kernel 的线程组数量
- 检查 `preCoordOffset` 计算是否正确

### 3. 特定平台问题
- 检查 `HIZ_REVERSED_Z` 宏是否正确设置
- 检查 Compute Shader 是否被支持
- 检查纹理格式是否兼容

## 矩阵问题修复

### 问题：VP矩阵变换错误

**原因**: Unity 使用列主序矩阵，但 HLSL 的 `mul(vector, matrix)` 期望行向量乘法。

**修复**: 
1. C# 端传递转置矩阵：`computeShader.SetMatrix(VPMatrixId, vp.transpose)`
2. Shader 端使用：`mul(float4(worldPos, 1.0), _HiZ_VP)`

### 验证VP矩阵

使用 `HiZMatrixValidator` 组件：
1. 附加到场景中的 GameObject
2. 设置测试点和相机
3. 点击 "验证VP矩阵" 按钮
4. 检查输出日志中的坐标变换是否正确

### 预期输出
```
测试点世界坐标: (0, 0, 5, 1)
测试点在裁剪空间(Shader): (x, y, z, w) 
测试点 NDC: (x, y, z)  // 应该在 [-1, 1] 范围内
测试点 UV: (u, v)      // 应该在 [0, 1] 范围内
测试点深度: d          // 应该在 [0, 1] 范围内
```

## 下一步调试建议

1. **验证相机深度纹理**: 确保 `_CameraDepthTexture` 包含有效的深度数据
2. **验证Compute Shader执行**: 检查是否有GPU错误
3. **验证坐标计算**: 使用 `HiZQuickTest` 验证C#和Shader计算一致
4. **验证纹理写入**: 使用 `HiZDiagnosticUtility` 检查实际写入的数据
5. **验证VP矩阵**: 使用 `HiZMatrixValidator` 确保矩阵变换正确
6. **验证深度比较**: 检查 Reversed Z 的处理是否正确

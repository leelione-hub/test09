# LeafIndirect Shader Passes

## 文件说明

### LeafDepthOnlyPass.hlsl
**DepthOnly Pass** - 用于深度预渲染

**功能：**
- 输出深度值 (`positionCS.z`)
- 支持 Alpha Test (`_ALPHATEST_ON`)
- 支持 LOD Crossfade
- 包含风动效果 (PlantWind)
- GPU Instancing 支持

**使用场景：**
- Depth Prepass
- 深度纹理生成
- SSAO 等后处理效果

### LeafDepthNormalsPass.hlsl
**DepthNormals Pass** - 用于法线/深度纹理生成

**功能：**
- 输出世界空间法线 (RGBA)
- 支持 Alpha Test
- 支持法线贴图 (`_NORMALMAP`)
- 支持 Octahedron 法线编码 (`_GBUFFER_NORMALS_OCT`)
- 包含风动效果
- GPU Instancing 支持

**使用场景：**
- SSAO (Screen Space Ambient Occlusion)
- SSR (Screen Space Reflections)
- 延迟渲染 GBuffer

### LeafShadowCasterPass.hlsl
**ShadowCaster Pass** - 用于阴影投射

**功能：**
- 支持方向光、点光源、聚光灯阴影
- 支持 Alpha Test（透明物体阴影）
- 支持阴影偏移（Shadow Bias）
- 支持 LOD Crossfade
- 包含风动效果
- GPU Instancing 支持

**使用场景：**
- 实时阴影投射
- 静态/动态阴影

### LeafIndirectInput.hlsl
材质属性定义和共享数据结构

### LeafIndirectForword.hlsl
ForwardLit Pass 的前向渲染实现

## URP Lit 模式对比

| Pass | URP Lit | LeafIndirect |
|------|---------|--------------|
| ForwardLit | ✓ | ✓ |
| DepthOnly | ✓ | ✓ (新) |
| DepthNormals | ✓ | ✓ (新) |
| ShadowCaster | ✓ | ✓ (新) |
| Meta | ✓ | - |
| Universal2D | ✓ | - |

## 关键字 (Keywords)

### DepthOnly Pass
```
_ALPHATEST_ON          - 启用 Alpha Test
_GBUFFER_NORMALS_OCT   - 使用 Octahedron 法线编码
LOD_FADE_CROSSFADE     - LOD 交叉淡入淡出
```

### DepthNormals Pass
```
_NORMALMAP             - 使用法线贴图
_ALPHATEST_ON          - 启用 Alpha Test
_GBUFFER_NORMALS_OCT   - 使用 Octahedron 法线编码
LOD_FADE_CROSSFADE     - LOD 交叉淡入淡出
```

### ShadowCaster Pass
```
_ALPHATEST_ON                - 启用 Alpha Test
LOD_FADE_CROSSFADE           - LOD 交叉淡入淡出
_CASTING_PUNCTUAL_LIGHT_SHADOW - 点光源/聚光灯阴影
```

## 注意事项

1. **风动效果一致性**
   - DepthOnly、DepthNormals 和 ShadowCaster pass 都应用了与 ForwardLit 相同的风动效果
   - 确保阴影、深度和法线都使用变形后的几何体

2. **Alpha Test**
   - 在 DepthOnly、DepthNormals 和 ShadowCaster 中都支持 Alpha Test
   - 确保透明裁剪阈值 (`_Cutoff`) 与 ForwardLit 一致

3. **阴影偏移 (Shadow Bias)**
   - ShadowCaster pass 支持 Normal Bias 和 Depth Bias
   - 在 URP Asset 中调整阴影偏移设置

4. **性能优化**
   - 如果不需要 SSAO/SSR，可以禁用 DepthNormals pass
   - 对于不透明物体，URP 通常会自动跳过 DepthOnly pass
   - 阴影距离可以在 URP Asset 中调整

## 使用示例

### 在 VegetationSystem 中使用
```csharp
// 材质会自动使用正确的 pass
// DepthOnly: 用于深度预渲染
// DepthNormals: 用于 SSAO
// ShadowCaster: 用于阴影投射
Graphics.RenderMeshIndirect(renderParams, mesh, argsBuffer);
```

### 手动指定 Pass
```csharp
// 获取 DepthOnly pass
int depthOnlyPass = material.FindPass("DepthOnly");

// 获取 DepthNormals pass
int depthNormalsPass = material.FindPass("DepthNormals");

// 获取 ShadowCaster pass
int shadowCasterPass = material.FindPass("ShadowCaster");
```

### 检查阴影是否启用
```csharp
// 确保物体投射阴影
MeshRenderer renderer = GetComponent<MeshRenderer>();
renderer.shadowCastingMode = ShadowCastingMode.On;

// 或者仅接收阴影
renderer.shadowCastingMode = ShadowCastingMode.Off;
renderer.receiveShadows = true;
```

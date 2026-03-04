# VegetationSystem HiZ 集成

将HiZ遮挡剔除系统集成到VegetationSystem中，提供GPU级别的植被遮挡剔除。

## 集成方式

### 方式1：使用 VegetationHizIntegrator 组件（推荐）

这是最轻量的集成方式，不需要修改原有代码。

#### 步骤

1. **确保场景中已有HiZSystem和VegetationSystemObject**

2. **添加集成组件**
   ```
   选中VegetationSystemObject -> GameObject -> Vegetation System -> Add HiZ Integration
   ```
   或手动添加 `VegetationHizIntegrator` 组件

3. **配置参数**
   - **Enable HiZ Culling**: 是否启用HiZ剔除
   - **Culling Mode**: 
     - GPU: 在Compute Shader中执行HiZ剔除（性能最好）
     - CPU: 在Job中执行HiZ剔除（更灵活，但需要GPU回读）
   - **Depth Bias**: 深度偏差，防止闪烁
   - **Culling Frame Interval**: 剔除频率

4. **使用支持HiZ的Compute Shader**
   将 `VegetationHiZCulling.compute` 拖到 `cullingCS` 字段

#### 工作原理

- **GPU模式**: 
  1. VegetationSystem先在CPU端进行Chunk级别的视锥体剔除
  2. VegetationHizIntegrator设置HiZ参数到Compute Shader
  3. Compute Shader在进行LOD选择时，额外执行HiZ遮挡测试
  4. 被遮挡的实例不会被添加到可见列表

- **CPU模式**:
  1. VegetationSystem完成Chunk剔除后
  2. VegetationHizIntegrator执行Job，对每个可见Chunk进行HiZ测试
  3. 被遮挡的Chunk从可见列表中移除

### 方式2：使用 VegetationSystemObjectHiZ 组件（完整功能）

这个方式替换了原有的Update和CSDispatch逻辑，提供最完整的HiZ支持。

#### 步骤

1. **替换组件**
   将 `VegetationSystemObject` 替换为 `VegetationSystemObjectHiZ`

2. **配置HiZ Compute Shader**
   在Inspector中设置：
   - `Hiz Culling Compute Shader`: `VegetationHiZCulling.compute`
   - `Original Culling Compute Shader`: 原版的`frustumCullingShader.compute`

3. **配置参数**
   与方式1相同

#### 额外功能

- 支持运行时切换HiZ开关
- 独立的HiZ Kernel，避免分支开销
- 调试面板显示剔除统计

## 文件说明

```
HiZIntegration/
├── VegetationHizIntegrator.cs          # 集成组件（方式1）
├── VegetationHiZCullingJob.cs          # CPU剔除Job
├── VegetationSystemObjectHiZ.cs        # 完整HiZ支持组件（方式2）
├── VegetationHiZCulling.compute        # 支持HiZ的Compute Shader
└── Editor/
    └── VegetationHizIntegratorEditor.cs # 编辑器工具
```

## 使用建议

### GPU模式 vs CPU模式

| 特性 | GPU模式 | CPU模式 |
|------|---------|---------|
| 性能 | ⭐⭐⭐ 最好 | ⭐⭐ 好 |
| 精度 | ⭐⭐⭐ 精确到实例 | ⭐⭐ 精确到Chunk |
| 延迟 | ⭐⭐⭐ 无 | ⭐ 有1帧延迟 |
| 灵活性 | ⭐⭐ 受CS限制 | ⭐⭐⭐ 可自定义逻辑 |

**推荐**: 使用GPU模式，除非你需要特殊的剔除逻辑。

### 参数调优

#### Depth Bias（深度偏差）
- **值太小**: 可能出现闪烁（植被快速出现/消失）
- **值太大**: 剔除不够积极，性能提升有限
- **建议值**: 0.001 ~ 0.05

#### Culling Frame Interval（剔除频率）
- **值=1**: 每帧剔除，响应最快
- **值>1**: 降低CPU开销，但可能出现"闪现"
- **建议值**: 1~3

#### Bounds Padding（包围盒扩展）
- 给Chunk的包围盒添加额外的空间
- 防止因为浮点精度问题导致的错误剔除
- **建议值**: 0.5 ~ 2.0

## Compute Shader说明

### Kernel

- `CullInstances`: 原版剔除核函数，支持可选HiZ
- `CullInstancesWithHiZ`: 强制启用HiZ的核函数

### 新增参数

```hlsl
Texture2D<float> _HizDepthTexture;   // HiZ深度金字塔
float4 _HizTextureSize;               // 纹理尺寸 (w, h, mipCount, 0)
float4x4 _HiZ_VP;                     // 视投矩阵
float _HizDepthBias;                  // 深度偏差
bool _EnableHiZCulling;               // 是否启用HiZ
int _HizReversedZ;                    // 是否使用Reversed Z
```

## 调试

### 查看剔除统计

启用 `Show Debug Info`，在Console中查看：
- 总Chunk数
- 视锥剔除后的Chunk数
- HiZ剔除的Chunk数
- 最终可见Chunk数

### 可视化被剔除的Chunk

启用 `Show Culled Chunks`，在Scene视图中：
- 红色线框 = 被HiZ剔除的Chunk

### 运行时切换

在游戏运行时，按GUI按钮可以实时切换HiZ开关，观察性能变化。

## 性能优化建议

1. **Chunk大小**: 确保Chunk大小合适（建议10m x 10m ~ 50m x 50m）
   - 太小：Chunk数量多，剔除开销大
   - 太大：剔除精度低，效果差

2. **植被密度**: 对于密集的植被，HiZ效果最明显

3. **遮挡物**: 确保场景中有足够的遮挡物（建筑物、山丘等）

4. **LOD配合**: HiZ剔除与LOD系统配合，远距离的植被会被提前剔除

## 常见问题

### Q: 植被闪烁
A: 增加 `Depth Bias` 值，或增加 `Bounds Padding`

### Q: 没有性能提升
A: 
- 检查HiZ系统是否正常工作
- 确保场景中有遮挡物
- 检查剔除率统计，如果剔除率为0，说明没有物体被遮挡

### Q: 部分植被消失
A: 
- 检查该植被的Chunk包围盒是否正确
- 增加 `Bounds Padding`
- 检查深度纹理是否正确生成

### Q: 编辑器中报错"找不到HiZ System"
A: 确保场景中存在带有 `HizSystem` 组件的游戏对象

## 兼容性

- 支持的平台与HiZSystem相同（需要Compute Shader支持）
- 支持URP渲染管线
- 支持PC、Android（中高端）、iOS

## 技术支持

如有问题，请检查：
1. HiZSystem是否正常工作
2. Compute Shader是否正确编译
3. 深度纹理是否正确生成
4. 查看Console中的日志信息

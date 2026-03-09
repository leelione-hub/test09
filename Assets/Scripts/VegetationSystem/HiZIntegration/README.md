# VegetationSystem HiZ 集成

当前植被渲染链路已经统一到 `VegetationSystemObjectHiZ + VegetationRenderFeature`。

## 当前架构

1. `VegetationRenderFeature` 在主相机 `beginCameraRendering` 时触发一次剔除，并提交阴影 caster。
2. `VegetationRenderPass` 在配置的 `RenderPassEvent` 中执行 `CommandBuffer.DrawMeshInstancedIndirect` 的 forward 渲染。
3. `VegetationSystemObjectHiZ` 负责：
   - CPU Chunk 视锥剔除
   - HiZ 参数绑定
   - Compute Shader 实例剔除和 LOD 分流
   - indirect args 更新

## 使用方式

1. 使用 `VegetationSystemObjectHiZ` 替代旧的 `VegetationSystemObject`。
2. 在 URP Renderer 上挂载 `VegetationRenderFeature`。
3. 在 `VegetationSystemObjectHiZ` 上配置：
   - `Hiz Culling Compute Shader`: `VegetationHiZCulling.compute`
   - `Original Culling Compute Shader`: 原始视锥剔除 Compute Shader

## 保留文件

```text
HiZIntegration/
├── Rendering/
│   └── VegetationRenderFeature.cs
├── VegetationSystemObjectHiZ.cs
├── VegetationHiZCulling.compute
└── README.md
```

## 说明

- 旧的 `VegetationHizIntegrator` 和 CPU Job 路径已删除。
- `VegetationSystemObjectHiZ` 中保留了一个空 `Update()`，这是为了屏蔽基类旧的 `Update -> CSDispatch -> Render` 路径，不是冗余代码。
- `supportSceneView` 只影响 SceneView 是否复用这套结果，不会改成按 SceneView 重新做一套剔除。

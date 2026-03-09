# HiZ System

当前 `HiZSystem` 目录只保留深度金字塔主链路，用来给植被 HiZ 剔除提供 `_HizDepthTexture`。

## 当前职责

- `HizSystem`：生命周期和配置入口
- `HizDepthPyramid`：从相机深度生成金字塔
- `HizRenderFeature`：把深度金字塔构建插入到 URP
- `HizPlatformCompatibility`：平台与深度格式适配

## 使用方式

1. 在场景里放置一个 `HizSystem`
2. 配置：
   - `HiZDepthPyramid.compute`
   - `HiZDepthBlit.shader`
3. 在 URP Renderer Asset 中启用 `HizRenderFeature`
4. 由植被系统读取 `HizSystem.Instance.GetDepthPyramid()`

## 文件结构

```text
HiZSystem/
├── Core/
│   ├── HizPlatformCompatibility.cs
│   ├── HizSettings.cs
│   └── HizSystem.cs
├── Rendering/
│   ├── HizDepthPyramid.cs
│   └── HizRenderFeature.cs
├── Shaders/
│   ├── HiZDepthBlit.shader
│   └── HiZDepthPyramid.compute
├── Editor/
│   └── HizSystemEditor.cs
└── README.md
```

## 说明

- 旧的通用对象 HiZ 剔除、Debug 面板、示例脚本已经移除。
- 现在这套代码不再负责“给普通 Renderer 做可见性开关”，只负责深度金字塔本身。

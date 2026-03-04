# HiZ (Hierarchical Z-Buffer) 遮挡剔除系统

这是一个功能完整的HiZ遮挡剔除系统，适用于Unity URP渲染管线。

## 功能特性

- ✅ **一键开关**：支持运行时动态启用/禁用
- ✅ **Debug面板**：清晰的调试信息和可视化
- ✅ **跨平台兼容**：支持PC、Android、iOS、Mac
- ✅ **Reversed Z处理**：自动适配不同平台的深度格式
- ✅ **性能优化**：异步GPU回读，Compute Shader加速
- ✅ **平台适配**：自动检测并适配低端移动设备

## 快速开始

### 1. 创建HiZ系统

**方法1：通过菜单**
```
GameObject -> HiZ System -> Create HiZ System
```

**方法2：手动创建**
1. 创建空GameObject，命名为"HiZ System"
2. 附加`HizSystem`组件
3. 配置Compute Shader和Shader引用

### 2. 配置Shader资源

在Inspector中点击"自动查找Shader资源"按钮，或手动设置：
- `HiZDepthPyramid.compute` - 深度金字塔生成
- `HiZCulling.compute` - 剔除计算
- `HiZDepthBlit.shader` - Fallback深度生成
- `HiZDebugDisplay.shader` - Debug显示

### 3. 注册剔除对象

**方法1：自动注册**
1. 创建`HizSimpleIntegrator`组件
2. 启用"Auto Register On Start"

**方法2：手动添加组件**
为需要剔除的对象添加`HizCullingObject`组件

**方法3：代码注册**
```csharp
var cullingObject = gameObject.AddComponent<HizCullingObject>();
HizSystem.Instance.RegisterCullingObject(cullingObject);
```

### 4. 配置URP Render Feature

在URP Renderer Asset中添加`HizRenderFeature`

## 使用示例

```csharp
using HiZSystem;

public class MyGameObject : MonoBehaviour, IHizCullingObject
{
    public Vector3 BoundsCenter => transform.position;
    public Vector3 BoundsExtents => Vector3.one;
    public bool IsActive => gameObject.activeInHierarchy;
    
    public void OnCulled()
    {
        GetComponent<Renderer>().enabled = false;
    }
    
    public void OnVisible()
    {
        GetComponent<Renderer>().enabled = true;
    }
    
    void OnEnable()
    {
        HizSystem.Instance?.RegisterCullingObject(this);
    }
    
    void OnDisable()
    {
        HizSystem.Instance?.UnregisterCullingObject(this);
    }
}
```

## 架构说明

### 核心组件

- **HizSystem**: 主管理器，协调所有子系统
- **HizDepthPyramid**: 生成深度金字塔
- **HizCullingManager**: 管理剔除对象并执行剔除
- **HizPlatformCompatibility**: 平台兼容性检测

### 渲染流程

1. **深度金字塔生成**: 从相机深度图生成多级Mipmap
2. **视锥体剔除**: 先进行粗粒度的视锥体剔除
3. **HiZ剔除**: 使用深度金字塔进行精确剔除
4. **结果应用**: 通过回调通知对象可见性变化

### 平台适配

系统自动检测以下平台特性：
- Compute Shader支持
- Reversed Z使用情况
- 设备性能等级
- 渲染API类型

## 常见问题

### Q: 为什么对象被错误剔除？
A: 检查以下设置：
- 增加`Depth Bias`值
- 检查`Bounds Padding`是否足够
- 确保对象包围盒计算正确

### Q: 低端设备性能问题？
A: 启用以下设置：
- `Auto Adjust For Platform`
- `Low End Mobile Fallback`
- 增加`Culling Frame Interval`
- 降低`Base Resolution`

### Q: 闪烁问题？
A: 
- 增加深度偏差值
- 检查Reversed Z设置是否正确
- 确保Mipmap采样时使用足够的边缘扩展

## 文件结构

```
HiZSystem/
├── Core/
│   ├── HizSystem.cs              # 主管理器
│   ├── HizSettings.cs            # 配置
│   ├── HizPlatformCompatibility.cs # 平台兼容
│   └── HizCullingObject.cs       # 剔除对象组件
├── Rendering/
│   ├── HizDepthPyramid.cs        # 深度金字塔
│   └── HizRenderFeature.cs       # URP RenderFeature
├── Culling/
│   └── HizCullingManager.cs      # 剔除管理器
├── Debug/
│   └── HizDebugPanel.cs          # Debug面板
├── Shaders/
│   ├── HiZDepthPyramid.compute   # 深度金字塔CS
│   ├── HiZCulling.compute        # 剔除CS
│   ├── HiZDepthBlit.shader       # Fallback Shader
│   └── HiZDebugDisplay.shader    # Debug显示
└── Editor/
    └── HizSystemEditor.cs        # 编辑器工具
```

## 性能建议

1. **合理设置Mipmap级别**：太高会增加带宽，太低会降低精度
2. **控制剔除对象数量**：每帧处理的对象数有上限
3. **调整剔除频率**：对于静态场景可以降低更新频率
4. **使用合适的深度格式**：移动端使用RHalf，桌面端使用RFloat

## 技术支持

如有问题，请检查：
1. 平台是否支持Compute Shader
2. URP设置是否正确
3. Shader是否正确编译
4. 查看Debug面板的错误信息

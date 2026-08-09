# 设备能力与游戏开发工具链

版本：0.6.2-alpha
实测日期：2026-08-09

## 结论

这台设备可以用于 Blender + Godot 的 3D 游戏开发，并且当前项目已经在本机完成资产生成、
导入、Forward+ 渲染、Jolt 物理、完整主线回归和 Windows x86_64 交叉导出链路。

它更适合“独立游戏高画质开发机 / 720p 验证机”，不适合把集成显卡当作 4K、光追或大型
开放世界的最终性能目标机。制作上应坚持小关卡流送、有限动态灯、可切换画质和可复用材质。

## 实测配置

| 项目 | 当前设备 |
|---|---|
| CPU | AMD Ryzen 5 PRO 4650U，6 核 12 线程 |
| 内存 | 15 GiB 可用系统内存 |
| GPU | AMD Renoir 集成显卡，PCI ID `1002:1636` |
| 图形 API | Vulkan 1.3.255 |
| Linux 驱动 | Mesa RADV 23.2.1 |
| 系统 | Ubuntu 22.04.5 LTS，Linux 6.8 |
| 项目验证分辨率 | 1280×720 |

Renoir 使用共享内存。Godot 显示的渲染资源字节数是相对监控值，并不等同于独立显卡的
“显存占用”。

## 已固定的工具

| 工具 | 版本 | 位置 | 用途 |
|---|---:|---|---|
| Godot Standard | 4.7.1 Stable | `/home/cenkai/game_dev_tools/godot/4.7.1/` | 编辑、测试、Linux/Windows 导出 |
| Blender | 4.5.12 | `/home/cenkai/game_dev_tools/blender/4.5.12/blender` | 角色生成、绑定、动画与 glTF 导出 |
| Godot Windows 模板 | 4.7.1 Stable x86_64 | `~/.local/share/godot/export_templates/4.7.1.stable/` | Windows release 导出 |
| 物理后端 | Jolt Physics | Godot 内置 | 刚体、配重机关和碰撞 |

项目没有依赖 Mono/C#、闭源 Godot 插件或系统级 Blender 安装，因此工具目录可单独备份。

## 已在本机跑通的工作

- Blender 脚本构建 53 骨角色并导出 glTF/GLB。
- Godot 导入 14 个角色网格、39,840 个三角面和 7 个独立动画。
- 写实材质运行时增强：皮肤 SSS、眼睛 Clearcoat、头发各向异性。
- Forward+：SSR、SSAO、SSIL、SDFGI、体积雾、Glow、Filmic。
- 2048×2048 PBR 地表、实时水面、粒子雨、门户预览和动态灯光。
- 双时相异步流送，正常状态最多驻留 2 个完整关卡。
- Jolt 独立物理线程与可推动记忆石配重机关。
- Linux 本机回归与 Windows x86_64 交叉导出。

## 推荐工作方式

### 建模与动画

- 角色或关键建筑在 Blender 单独文件中制作；不要把整张城市塞进一个源文件。
- 高模用于烘焙，进入 Godot 的游戏网格保留合理拓扑与切线。
- 贴图优先 2K；只有主角面部或英雄物件经过显存测量后才考虑 4K。
- 当前 Run、Jump、Fall、Land 已是独立 Action，并补有脚踝、头部和手部二级运动；正式动作
  捕捉仍应补起步、急停、转身、坡面适配和不同落差着地。

### Godot 场景

- 一个章节拆成“此岸 / 雨忆”两张可独立实例化的场景。
- 重复建筑和植被优先 MultiMesh 或合批；城市当前仍有进一步合批空间。
- 只让必要的 OmniLight3D 投射阴影。
- 高画质用于美术验收，集显调试时可以切“均衡”或“性能”。

### 目标平台

- 开发基线：Linux + Vulkan。
- 首个玩家包：Windows 10/11 x86_64。
- 推荐玩家显卡：支持 Vulkan 1.2 的独立显卡；集显可使用均衡或性能档。
- 当前没有 macOS、Web、Android 或主机平台的发行承诺。

## 风险与边界

- 高画质城市是当前最重场景；性能报告必须使用有真实显示表面的 Vulkan 路径，纯 headless
  的 64×64 零 Draw Call 数据无效。
- 集成显卡和系统内存共享带宽，Blender 渲染、Godot 编辑器和游戏不要同时跑重任务。
- Windows 包目前不做代码签名，SmartScreen 可能显示未知发布者；校验 SHA-256 后运行。
- 本机不能原生执行 Windows EXE；Windows 交付采用 Godot 官方模板导出、PE 静态校验、
  PCK 内容校验和 Linux 同资源运行回归，仍建议在真实 Windows 10/11 做最终玩家验收。

## 官方依据

- [Godot 4.7 系统要求](https://docs.godotengine.org/en/4.7/about/system_requirements.html)
- [Godot 导出项目](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)
- [Godot Windows 导出](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html)
- [Blender 4.5 LTS 手册](https://docs.blender.org/manual/en/4.5/)

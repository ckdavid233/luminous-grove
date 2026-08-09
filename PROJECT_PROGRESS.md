# 微光林地：雨的名字 — 项目进度快照

快照日期：2026-08-09  
工程版本：0.6.2-alpha
引擎：Godot 4.7.1 Stable  
当前分支：`main`

## 当前可交付状态

这是一个可从开场走到三种结局的第三人称 3D 叙事冒险 alpha。当前代码、测试和设计文档已
统一到 campaign v6；本快照首次把之前只存在于工作目录的实现与文档纳入 Git 版本历史。

已完成并验证的本轮问题修复：

- 交互：真实 `E` 输入可触发风铃；射线失焦时有附近候选兜底。
- 暂停：真实 `Esc` 可打开，暂停状态接收真实鼠标点击；画质、继续和全屏按钮可用。
- 移动：加速／减速、空中控制、土狼时间、跳跃缓冲、落地冲击和胶囊碰撞已调校。
- 环境：65×65 可碰撞地形、54 棵有树干碰撞的树、15 个岸石碰撞、16,000 草簇。
- 角色：14 个网格、53 根骨骼、39,840 个导入三角面、14 个材质表面、7 套独立动作。
- 水体：椭圆接触边界；空中移动不产生脚步波纹；入水／出水生成扩散环和水滴。

本轮精细化已完成并接入运行时：

- 地表：新增生成式雨后森林地表 Base Color，接入地表材质并保留原始生成文件。
- 植被：Blender 叶片改为带中心脊线的六边形叶片，补 UV 叶缘／叶脉色差和软风动；三种
  树的源文件与 GLB 已重新导出。
- 角色：脚踝、头部、手部加入二级重叠运动；7 套动作从 14 条骨骼轨道提升到 19 条轨道。
- 水面：增加交互波峰、内外环高光和低强度自发光；一次交互生成三层不同速度的扩散环及
  28–59 个水滴。

## 自动化与实机证据

```text
REGRESSION_OK tests=21
RELEASE_SMOKE_OK build=0.6.2-alpha campaign=6 quality=high echo_async=ready
```

目标设备为 Ryzen 5 PRO 4650U / Renoir 集成显卡，1280×720 真实 Vulkan 表面实测：

- 高画质：13.8 FPS，P95 73.491 ms，用于画面验收；
- 性能档：38.8 FPS，P95 26.820 ms，作为该集成显卡的建议游玩档。

当前已保存的视觉证据位于 `previews/`（该目录被 Git 忽略，避免提交大量生成截图）；重新
生成方式和验收标准见 `TESTING_AND_ACCEPTANCE.md` 与 `PERFORMANCE_REPORT.md`。

## Windows 发行状态

0.6.1-alpha Windows x86_64 便携包已在本机导出并完成；0.6.2-alpha 的精细化资产已通过
Linux/Vulkan 验收，尚未重新导出 Windows 包：

- 官方 Godot 4.7.1 release 模板导出；
- EXE 为 PE32+ x86-64 GUI executable；
- 导出 PCK 通过 Linux 同版本 `--release-smoke`；
- ZIP `unzip -t` 通过，SHA-256 为
  `23b7d7a0a57c39f36b63a8fcad1f36aab05b686c7463ba6b8760ddfc262e3c28`。

发行包位于本机 `releases/`，按 `.gitignore` 不进入源码仓库；构建命令、文件哈希和人工验收
要求见 `WINDOWS_BUILD_AND_RELEASE.md`。由于构建机是 Linux，真实 Windows 10/11 启动、
驱动、全屏、手柄和 SmartScreen 仍是发布前人工验收项。

## 下一阶段：角色与镜头精修、用户二维素材包

当前一次性收包范围为 27 张 PNG，完整命名、尺寸、提示词、Alpha 和许可记录要求见
`USER_ASSET_PACKAGE_BRIEF.md`。素材包应命名为 `luminous_grove_asset_pack_v2.zip`，并包含
`manifest.csv`、每张图的提示词及 `generation_notes.txt`。

收到素材后，下一次提交应记录：角色跨图一致性、材质无缝检测、透明边缘、图集切片、Godot
材质预览，以及实际接入了哪些运行时文件。与此同时，角色起步／急停／转身和面部表情仍是
从“工程精细化”走向最终美术定稿的下一批工作。

## 主要入口

- 状态总览：`IMPLEMENTATION_STATUS.md`
- 变更记录：`CHANGELOG.md`
- 测试规范：`TESTING_AND_ACCEPTANCE.md`
- 性能报告：`PERFORMANCE_REPORT.md`
- Windows 构建：`WINDOWS_BUILD_AND_RELEASE.md`
- 用户素材清单：`USER_ASSET_PACKAGE_BRIEF.md`
- Godot 工程：`game/`
- Blender 构建脚本：`tools/`

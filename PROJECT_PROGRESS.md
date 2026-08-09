# 微光林地：雨的名字 — 项目进度快照

快照日期：2026-08-10
工程版本：0.6.2-alpha
引擎：Godot 4.7.1 Stable  
当前分支：`feature/art-refinement-0.6.2`

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

本次“林地湖区材质、视觉、光照与交互升级”已完成的工程化改造：

- 材质管线：`build_user_pbr.gd` 改为扫描材质导入与完整性校验，不再从 Albedo 亮度伪造
  Normal/Roughness；建立 `SurfaceProfile`/`SurfaceLibrary`，登记干土、湿泥、苔藓、石、木和水。
- 运行资源：接入 Poly Haven CC0 的 Forest Ground 01、Mud Forest、Forest Leaves 02 和
  Pine Bark、Mossy Rock 4K PBR（英雄近景目标 8K）；AO、Cavity、Height 和 SHA-256/许可
  登记见 `MATERIAL_LIBRARY_SOURCES.md`、`MATERIAL_LIBRARY_SHA256.txt`。
- 地形与着色：渲染网格提升到 129×129，碰撞仍为独立 65×65 HeightMap；地表加入坡度、岸线、
  噪声分层、视差、AO/Cavity、细节法线和雨后湿润联动。
- 湖面与植被：水面改为 32 槽有界事件池，加入双层法线、Fresnel、深度吸收、岸线泡沫、反射
  探针和湿度粗糙度；飞溅和脚印采用池化；草、叶片响应雨势和角色局部弯曲。
- 光照：增加湖面与神龛反射探针、湖面反射补光和湿润联动；保留 Forward+、SDFGI、SSAO、
  SSIL、SSR 与体积雾，不引入首轮昼夜循环。
- 交互与物理：SurfaceProbe、土/泥/木/石 PhysicsMaterial、斜坡湿泥减速与石面滑动、浅水
  反馈、脚步水纹、脚印池、双脚 SkeletonIK3D 和刚体接触反馈已接入；现有水体信号保持兼容。
- 资源与动画：`MaterialProfile` 统一承载六类 PBR 贴图与物理字段；Walk/Run 以动画相位触发
  脚步，距离检测保留为异常 fallback；刚体入/出水浮力、阻力和边界事件，以及角色/刚体近场
  草叶弯曲已接入。
- 全流程：`gameplay_test.gd` 已从风铃、三记忆、神龛、双时相档案、Jolt 配重、城市回路、雨眼
  试炼走到潮汐结局并验证完成态恢复；新增真实附近交互提示检查，避免只靠测试直接调用机关。

## 自动化与实机证据

```text
REGRESSION_OK tests=23
RELEASE_SMOKE_OK build=0.6.2-alpha campaign=6 quality=high echo_async=ready
```

目标设备为 Ryzen 5 PRO 4650U / Renoir 集成显卡。本轮已在 `DISPLAY=:1` 的真实 X11/Vulkan
表面以 1280×720 重测：

- 高画质：8.4 FPS，P95 120.904 ms，P99 123.745 ms，显存监视值约 3.06 GB，用于画面验收；
- 平衡：10.3 FPS，P95 100.224 ms，P99 110.850 ms；
- 性能档：17.6 FPS，P95 59.794 ms，P99 106.463 ms，暂不能宣称为 30 FPS 建议档。

当前已保存的视觉证据位于 `previews/`（该目录被 Git 忽略，避免提交大量生成截图）；重新
生成方式和验收标准见 `TESTING_AND_ACCEPTANCE.md` 与 `PERFORMANCE_REPORT.md`。

真实 Vulkan 截图已覆盖地面、泥滩、树皮、湖面、水花、脚印和角色动作，前后对比与 SHA-256
见 `VISUAL_VALIDATION_REPORT.md`。当前视口仍是 1280×720，4K 纹理已加载但 3840×2160
输出与帧时需要原生 4K 显示设备复测；JSON 原始结果保留在 `performance_runtime*.json`。

## Windows 发行状态

0.6.2-alpha Windows x86_64 便携包已在本机重新导出并完成 PCK 自检；真实 Windows 启动仍需
人工验收：

- 官方 Godot 4.7.1 release 模板导出；
- EXE 为 PE32+ x86-64 GUI executable；
- 导出 PCK 通过 Linux 同版本 `--release-smoke`；
- ZIP `unzip -t` 通过，更新材质与水花逻辑后的 SHA-256 为
  `d4977f49eaae9543b7a1c7cef7ae0f391f38bc8dcdbf76f79f0a848f9f116e06`（564,943,923 bytes）。

发行包位于本机 `releases/`，按 `.gitignore` 不进入源码仓库；构建命令、文件哈希和人工验收
要求见 `WINDOWS_BUILD_AND_RELEASE.md`。由于构建机是 Linux，真实 Windows 10/11 启动、
驱动、全屏、手柄和 SmartScreen 仍是发布前人工验收项。

## 下一阶段：8K 英雄资产、原生桌面性能复测与角色镜头精修

4K runtime 已接入，下一阶段只为英雄镜头启用 8K，并在原生桌面/独立 GPU 上重新测量高质量档
P95（目标约 41.7 ms）；当前 Renoir/X11 实测未达标，再继续角色起步／急停／转身和面部
表演资产。

当前一次性收包范围为 27 张 PNG，完整命名、尺寸、提示词、Alpha 和许可记录要求见
`USER_ASSET_PACKAGE_BRIEF.md`。素材包应命名为 `luminous_grove_asset_pack_v2.zip`，并包含
`manifest.csv`、每张图的提示词及 `generation_notes.txt`。

收到素材后，下一次提交应记录：角色跨图一致性、材质无缝检测、透明边缘、图集切片、Godot
材质预览，以及实际接入了哪些运行时文件。与此同时，角色起步／急停／转身和面部表情仍是
从“工程精细化”走向最终美术定稿的下一批工作。

## Goal：后续推进目标清单

接下来要把“已能完整通关的工程精细化”推进到可验收的美术与发行质量：在原生桌面和独立 GPU
上复测 4K 地表、湖石扫描材质、湖面反射、湿润联动、脚印和角色动作，记录显存与 P95/P99
并决定 8K 英雄材质的可用范围；继续补齐起步／急停／转身、坡面 IK 和面部表演资产，完善
刚体／浅水／植被反馈的边界案例；把整条主线按玩家路径再走通，记录每个交互提示、门控和失败
恢复点，确保不会迷路或卡关；在真实 Windows 10/11 与至少两类 GPU 上完成启动、输入、存档、
全屏、物理和发行包验收，继续定位剩余 Godot ObjectDB RefCounted/Texture RID 清理警告，最后
同步更新许可、SHA-256、截图、性能报告和 Git 发布记录。

## 主要入口

- 状态总览：`IMPLEMENTATION_STATUS.md`
- 变更记录：`CHANGELOG.md`
- 测试规范：`TESTING_AND_ACCEPTANCE.md`
- 性能报告：`PERFORMANCE_REPORT.md`
- Windows 构建：`WINDOWS_BUILD_AND_RELEASE.md`
- 用户素材清单：`USER_ASSET_PACKAGE_BRIEF.md`
- Godot 工程：`game/`
- Blender 构建脚本：`tools/`

# 《微光林地：雨的名字》文档总索引

版本：0.6.2-alpha
校准日期：2026-08-09
权威实现目录：`/home/cenkai/game_dev_plan/game`

## 状态标记

- **已实装**：存在于当前 Godot 工程，并有运行或自动化验证。
- **已验证**：有可重复执行的测试、测量结果或产物校验。
- **计划**：尚未进入当前可执行版本，不应理解为已完成。
- **历史**：保留用于追踪设计演变，不代表当前实现。

文档发生冲突时，以本索引标记为“权威”的文档、当前代码和自动化测试结果为准；
历史稿和研究稿不能覆盖运行事实。

## 面向玩家与交付

| 文档 | 用途 | 状态 |
|---|---|---|
| [GAMEPLAY_AND_CONTROLS.md](GAMEPLAY_AND_CONTROLS.md) | 操作、玩法、主线结构、分支与存档 | 权威、已实装 |
| [game/README.md](game/README.md) | 启动工程、运行游戏和开发入口 | 权威、已实装 |
| [WINDOWS_BUILD_AND_RELEASE.md](WINDOWS_BUILD_AND_RELEASE.md) | Windows 包内容、运行要求、验证和重建 | 权威、已导出并校验 |
| [build/README.md](build/README.md) | 构建目录和旧 PCK 说明 | 权威 |
| [CHANGELOG.md](CHANGELOG.md) | 版本变更记录 | 权威 |

## 设计与内容

| 文档 | 用途 | 状态 |
|---|---|---|
| [NARRATIVE_DESIGN.md](NARRATIVE_DESIGN.md) | 四幕主线、角色、节点和结局条件 | 权威、已实装 |
| [ART_DIRECTION.md](ART_DIRECTION.md) | 视觉语言、材质、灯光和特效预算 | 权威、已实装 |
| [MATERIAL_LIBRARY_SOURCES.md](MATERIAL_LIBRARY_SOURCES.md) | 扫描材质来源、许可、运行规格和替换规则 | 权威、持续登记 |
| [MATERIAL_LIBRARY_SHA256.txt](MATERIAL_LIBRARY_SHA256.txt) | 仓库内运行贴图逐文件校验和 | 权威、已生成 |
| [CHARACTER_PIPELINE.md](CHARACTER_PIPELINE.md) | Blender 到 Godot 的写实角色管线 | 权威、已验证 |
| [USER_ASSET_PACKAGE_BRIEF.md](USER_ASSET_PACKAGE_BRIEF.md) | 用户后续生成素材的命名与规格 | 计划、待素材包 |
| [ACT_I_ORIGINAL_DESIGN.md](ACT_I_ORIGINAL_DESIGN.md) | 第一版概念稿 | 历史、只读参考 |

## 工程、设备与验证

| 文档 | 用途 | 状态 |
|---|---|---|
| [DEVICE_CAPABILITY_AND_TOOLCHAIN.md](DEVICE_CAPABILITY_AND_TOOLCHAIN.md) | 本机能力、Godot/Blender 工具链和限制 | 权威、已验证 |
| [TECHNICAL_DESIGN.md](TECHNICAL_DESIGN.md) | 当前真实架构、状态机、渲染和存档 | 权威、已实装 |
| [STREAMING_AND_PORTAL_ARCHITECTURE.md](STREAMING_AND_PORTAL_ARCHITECTURE.md) | 双时相流送、门户与内存预算 | 权威、已验证 |
| [TESTING_AND_ACCEPTANCE.md](TESTING_AND_ACCEPTANCE.md) | 测试矩阵、验收命令和通过标准 | 权威、已验证 |
| [PERFORMANCE_REPORT.md](PERFORMANCE_REPORT.md) | 目标设备的 Vulkan 实测 | 权威、随版本重测 |
| [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) | 完成项、缺口、风险和下一阶段 | 权威 |
| [EFFECT_RESEARCH.md](EFFECT_RESEARCH.md) | 外部特效方案调研与采用判断 | 研究；采用状态以正文为准 |

## 当前产品边界

当前版本是一条可从开场走到三结局的 3D 高画质独立游戏 alpha，不是只有一张场景的
概念演示。它已经包含四幕、双时相切换、异步关卡流送、物理解谜、顺序回路、叙事分支、
实时过场、写实人物和可靠存档。

当前 Windows x86_64 便携 ZIP 已生成并通过压缩完整性、PE32+ 静态识别、导出 PCK 自检
和 23 项工程回归；由于构建机只有 Linux，Windows EXE 的真实系统启动仍是发布前验收项。

仍未完成的正式商业化工作包括：专业配音与混音、动作与表情精修、完整无障碍选项、
多语言资源化、Windows 代码签名、安装器、广泛硬件兼容测试和外部玩家节奏测试。这些项目
在文档中必须明确标成计划，不能写作已实装。

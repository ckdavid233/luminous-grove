# 实现状态

版本：0.6.2-alpha
更新：2026-08-10
总体状态：可完整通关的高画质 Windows/Linux alpha

## 当前结论

项目已经从单幕原型扩展为四幕可完成流程。运行时代码、剧情文档和测试都以 campaign v8 为准；
旧文档中不存在的 QuestService、组件化 Player 和“计划中的扩充玩法”不再被描述为现状。

## 完成矩阵

| 范围 | 状态 | 证据 |
|---|---|---|
| 第一幕林地 | 已实装 | 风铃、3 记忆、神龛、2 姿态选择 |
| 第二幕档案 | 已实装 | alignment 分支锚点顺序 + 三环符文校准、倒影、Jolt 配重、跨时相铭名透镜、城门 |
| 第三幕城市 | 已实装 | 双时相、3 残响、4 行灯、2 证词、雨眼门 |
| 第四幕雨眼 | 已实装 | 双时相道路、3 印记、3 试炼、3 结局 |
| 双时相切换 | 已验证 | 100 次往返、层与碰撞正确、无重复实例 |
| 世界流送 | 已验证 | threaded load、LRU、缓存忽略、常驻上限 2 |
| 门户 | 已验证 | 640×360、反相层、离屏/距离节流 |
| 玩家 | 已验证 | 键鼠/手柄、平滑加减速、空中控制、土狼时间、跳跃缓冲、交互、检查点 |
| 写实角色 | 已验证 | 14 网格、53 骨、39,840 三角面、14 材质、7 套独立动作、19 条骨骼轨道 |
| 高画质渲染 | 已验证 | Forward+ 全特效与三档切换 |
| 扫描 PBR 材质管线 | 已实装 | MaterialProfile/SurfaceProfile、6 个显式 `.tres` profile、Poly Haven CC0 4K runtime、AO/Cavity/Height 校验 |
| 林地地表分层 | 已实装 | 129×129 渲染网格、65×65 碰撞网格、坡度/岸线/湿润/视差 Shader |
| 湖面事件与反射 | 已实装 | 32 槽水纹池、16 槽飞溅池、双层法线/Fresnel/深度吸收/焦散/太阳闪光/泡沫、湖区反射探针 |
| 地表探测与脚步 | 已实装 | SurfaceProbe、6 类表面、动画相位脚步+距离 fallback、24 槽脚印池、坡面法线双脚 SkeletonIK3D |
| 刚体与植被反馈 | 已实装 | Jolt 摩擦/质量、浅水浮力/阻力/事件、角色与刚体近场草叶弯曲 |
| 全流程可玩性 | 已验证 | 真实附近交互提示 + ObjectiveGuide 目标距离提示 + 四幕全流程、三结局、完成态恢复 |
| 物理 | 已验证 | Jolt 独立线程、14+ 章节刚体、可完成配重 |
| 过场 | 已实装 | 7 类主线序列 + 3 尾声，字幕与跳过 |
| 保存 | 已验证 | schema v2、备份恢复、旧档迁移、完成态恢复 |
| Linux 运行 | 已验证 | Godot 4.7.1 本机完整回归 |
| Windows x86_64 | 已导出 | 官方 release 模板、PE32+、独立 PCK |
| 自动化 | 已验证 | 25/25 回归通过 |

## 主线规模

- 17 个主状态；
- 约 30 个门控推进事件；
- 3 个记忆、3 个锚点、3 个档案机关；
- 3 个城市残响、4 盏行灯、2 个证词方向；
- 3 个雨眼印记、3 个共振试炼；
- 3 个最终结局；
- 9 段实时过场类别（其中尾声有 3 个变体）。

设计时长目标 60–90 分钟，尚未经过外部玩家实测，不能当作已验证时长。

## 画面与内容

### 已完成

- Poly Haven Mossy Forest CC0 色调映射 4K PanoramaSkyMaterial、Filmic、Glow；原始 HDR/EXR 外置；
- SSR、SSAO、SSIL、SDFGI、体积雾；
- 4K PBR 地面、树皮、叶片、路径、湖石、神龛石；
- 65×65 可碰撞高度地形、54 棵有树干碰撞的多级分枝树、16,000 个风动草簇；
- 雨后森林地表生成式 Base Color、带 UV 叶脉的六边形叶片和软风动；
- 椭圆湖盆、高细分水面 Shader、多源涟漪、交互波峰、内外环高光，以及三层入水／出水
  扩散环与水滴；
- 城市雨、档案悬浮水、雨眼风暴、花瓣、萤火；
- 角色皮肤 SSS、眼睛 Clearcoat、头发各向异性；
- 角色脚踝、头部和手部二级运动已写回每个 Action；
- 运行时角色增加呼吸、步态重心、起停惯性和转身侧倾；服装与鞋材质恢复 authored normal map，
  跨时相切换后的交互目标会主动刷新。
- 高 / 均衡 / 性能三档实时切换。
- 扫描 PBR 运行目录和材质来源登记；环境材质具备 Albedo、Normal、Roughness、AO，近景
  目录具备 Cavity/Height（当前运行贴图为 4K，8K 英雄原包外置）。
- `content/materials/profiles/` 的六个资源是运行时唯一表面映射；地表 Shader、湖岸石和树皮
  PBR 创建函数直接从 profile 读取贴图，避免视觉材质与物理表面标签分叉。
- 林地地表使用独立高密度渲染网格与低密度 HeightMap 碰撞，避免视觉高度和物理高度混淆。
- 森林树木已接入实际近/中/远几何 LOD：半径 15m 内保留扫描 GLB，中景使用分层枝条与五簇低面数
  树冠，远景使用两层枝条与四簇树冠 MultiMesh；`environment_geometry_test.gd` 校验 54 棵树总数、
  各级代理面数和画质档可见距离，避免远景重复圆球冠层。
- 湖面使用 Fresnel、双层法线、深度吸收、岸线泡沫、湿度粗糙度和反射探针；雨滴、脚步、入水、
  出水、落水和刚体落水统一进入 `emit_surface_event`，最多保留 32 个事件。
- 湖面高画质运行路径额外启用双层焦散、屏幕折射/反射混合、太阳闪光、220 个雨滴与 180 个水面
  闪烁粒子；飞溅池扩为 16 个根节点、5 层扩散环和高密度水滴。
- 土、泥、苔藓、石、木、水具备表面采样和物理参数；湿泥减速、石面坡滑、浅水阻力、落地冲击、
  脚印和双脚 IK 已接入角色运行时。
- 脚部与交互射线、SurfaceProbe 和恢复落点复用 `PhysicsRayQueryParameters3D`，水体飞溅根节点
  改为湖体所有并在运行时退出时清理材质/粒子引用；当前仍有少量 Godot 退出时序警告待定位。
- `MaterialProfile` 作为 `SurfaceProfile` 基类统一持有 Albedo、Normal、Roughness、AO、Cavity、
  Height 与物理字段；Walk/Run 的动画时间相位触发脚步，距离检测仅在动画不可用时工作。
- 刚体可注册到湖面反馈，获得受淹比例浮力、水平阻力、入/出水事件和边界校正；草地 Shader 同时
  接收角色与最多 7 个刚体的局部弯曲球。
- 全流程回归不再只检查脚本状态：开场会将玩家放到风铃附近，通过附近候选和提示 UI 发起真实
 交互；后续所有叙事节点也统一经 `PlayerController.request_interaction()` 驱动，档案配重由玩家
  实际推动 Jolt 刚体进入踏板，然后完成城市、雨眼和完成态恢复。每个阶段目标还会校验
  `get_prompt()` 非空且目标在当前叙事阶段可交互，避免“目标节点存在但玩家没有可用提示”的软卡关。
- AnimationTree 保留作状态图和工具检查，但运行时用 AnimationPlayer 的物理时钟直接驱动 GLB；测试会
  比对 `upperarm_l` 的真实骨骼姿态。低于虚空阈值时，Player 会验证检查点、重置速度/交互计时并发出
  `void_recovered`，Main 显示恢复提示，避免流送地面缺失造成永久掉落。
- 第二幕新增 `ArchiveCipherConsole`：R 转动当前环、E 确认当前环，三环目标由 alignment 分支与锚点
  语义线索决定；错误确认会重置并发出线索，只有完成后才会开放跨时相三机关。

### 仍需专业资产

- 主角起步、急停、转身、坡面适配和表情动画；
- 朔与城市居民模型；
- 更丰富的模块化城市立面、室内和地标；
- 专业 UI 图标、Windows 应用图标和启动画面；
- 原创音乐、环境拟音、配音与最终混音。

## 工程质量

### 已完成

- 资源与代码按 `core / game / content / shaders / tests` 分区；
- 脚本导出为编译 GDScript，发布包排除 tests/tools/source_art；
- 关键逻辑都有稳定 ID，避免按节点路径保存；
- 章节可异步卸载并重新加载；
- 存档损坏有上一版本备份；
- 发布 PCK 具备自检入口 `--release-smoke`。

### 技术债

- `game/main/main.gd` 超过 2,000 行，下一阶段必须拆编排、HUD 和画质控制。
- 程序化关卡的单对象数量偏多，城市需要 MultiMesh/合批和灯光 LOD；林地目前已完成近/中/远树
  几何 LOD，但仍需在独立 GPU 上确认中远景切换的视觉连续性。
- Main/Player 退出前现在会停止 process/physics/input，清空脚部 IK、交互查询与 SurfaceProbe；
  WorldStreamer/EchoRuins 也会先清理 surface override。普通 smoke/动画测试的告警不再稳定复现，
  但完整回归和 4K 捕获仍偶发 ObjectDB/Texture RID，尚未达到零泄漏。
- Main 最终 teardown 现在还会扫描脚本字段并清空生成的 Resource/RefCounted 容器，覆盖交互物发光材质、
  档案机关核心材质和 AnimationTree playback；`runtime_teardown_test.gd` 已增加断言。该改动收紧了
  项目可控引用，但不能替代 Godot/Jolt 内存检查，当前仍不宣称零泄漏。
- 最新退出路径再提前停止所有脚本子节点，并显式清理 SurfaceLibrary/WetnessController 注册表；Player、
  SurfaceProbe、PhaseShift 的 Jolt direct-space wrapper 不再使用链式临时引用。该修复避免了项目层面
  可控引用继续增长，但 Jolt 独立物理线程的 RefCounted 告警仍会在 smoke、流送、4K 或多场景顺序中
  间歇出现，当前仍需 Godot/Jolt 内存检查或升级构建才能宣称零泄漏。
- 部分大型场景回归仍有少量 Godot ObjectDB RefCounted/Texture RID leak warning（功能与流送结果
  通过）；WorldStreamer/InteractiveLake/4K 捕获视口和 Main 运行时引用解绑已增加退出清理，且
  `runtime_teardown_test.gd` 会断言网格、MultiMesh、粒子、3 个 Camera3D 和 WorldEnvironment 已
  脱钩；Player 的控制器、SurfaceProbe、AnimationTree、SkeletonIK 和脚部目标引用也已在
  `_exit_tree()` 释放，但 WorldStreamer 现在还会收束 pending threaded request、断开流送节点
  Callable，PhaseShift/Cinematic 也有显式 shutdown。相机默认“自动选下一个”时序已修正为
  `clear_current(false)`，但退出告警仍会随测试时序、4K SubViewport 和渲染器变化，需继续用 Godot
  内存检查定位剩余资源，当前不能宣称零泄漏。
- RainRiftPortal 现在先解绑 `alternate_texture`、QuadMesh 材质和预览相机，再在 Main 仍处于活动树
  时同步释放预览 SubViewport 与运行时环形子树；门户回归新增解绑断言。单独 smoke 复验的 ObjectDB
  提示曾消失，但完整回归仍会随退出时序出现；可见门户/4K 捕获仍可能报告 7 Texture RID 或通用
  ObjectDB，零泄漏继续保持未通过。
- 本轮继续把 `EchoRuins.shutdown()` 接入 WorldStreamer 的运行时卸载路径，并将地面旧版 PBR
  fallback 改为按需加载；相机清理后普通 1280×720 Vulkan 捕获的 7 个 Texture RID 不再稳定复现，
  但 `--verbose`、4K SubViewport 或不同退出时序仍可能报告 Texture RID/通用 RefCounted，说明剩余
  告警还需在真实 GPU/Windows 环境用 Godot 内存检查区分渲染器 transient buffer 与项目引用。
- GPUParticles3D 退出时会先清理每个 draw pass 的 PrimitiveMesh 材质，再解除 pass 引用；这是降低
  渲染线程残留风险的防御性清理，不能替代完整回归与 4K 捕获的零泄漏验收。
- 回归脚本退出前显式丢弃 `PackedScene` 局部引用，历史 24 项 headless 回归的通用 ObjectDB 提示曾
  从 3 个降为 2 个；本轮完整回归按退出时序为 1–3 个，剩余提示仍无法在当前 Godot/Jolt 构建中
  定位到项目对象，真实 Vulkan 捕获的 7 个 Texture RID 也仍需实体 Windows/Godot 内存检查确认。
- 临时 1280×720 Vulkan A/B 探针关闭反射探针、环境、粒子、水体和门户后仍固定报告 7 个 Texture RID，
  说明剩余数量更像根窗口/Vulkan transient render target；ObjectDB 仍随退出时序变化，需实体 Windows
 及 Godot 内存检查确认，探针脚本已删除。
- 画质档具备固定 FSR 3D 缩放（高 1.00、均衡 0.77、性能 0.59），并新增默认关闭的可选按帧动态
  分辨率（`--dynamic-resolution` 或 `LUMINOUS_DYNAMIC_RESOLUTION=1`，范围 0.35 至当前档位基线）；
  仍没有逐项高级设置，动态控制也必须在目标硬件上重新调校。
- NarrativeDirector 现在由 `ObjectiveGuide` 将当前风铃、记忆、档案、城市和雨眼交互投影到屏幕边缘，
  并显示距离；`gameplay_test.gd` 在完整潮汐流程中新增 15 个目标存在性断言，结局后确认目标清空。
- 没有输入重映射、字幕缩放或色盲设置。
- 真实 Vulkan X11 捕获已完成；`VISUAL_VALIDATION_REPORT.md` 保存地面、泥滩、树皮、湖面、水花、
  脚印和角色动作的前后对比。常规截图为 1280×720，同时已用独立 Vulkan `SubViewport` 输出并
  校验地面、湿泥、树木、湖面、水花和角色的 3840×2160 PNG；另已在临时 3840×2160 X11 mode
  完成湖面原生窗口截图。实体 4K 显示器、Windows 驱动和高质量 P95 仍需复测。
- `c521730` 后的 `particlefix4k` 复验重新覆盖地面、湿泥、树皮、湖面、水花、脚印前后和角色动作，
  所有输出均为 3840×2160 RGB；哈希与退出告警记录见 `VISUAL_VALIDATION_REPORT.md`。
- 4K runtime 已入库；8K 英雄材质仍需按真实 GPU 显存预算启用，Mossy Rock 湖石已完成扫描
  替换。当前 Godot 4.7.1 构建对 `.hdr`/`.exr` 没有资源加载器，运行包已改用同一 CC0
  Mossy Forest 的 4096×2048 tonemapped JPG PanoramaSkyMaterial；原始 HDR/EXR 仍外置，最终
  未裁剪 HDR 光照需在支持导入器的构建中复验，见 `MATERIAL_LIBRARY_SOURCES.md`。
- `performance_runtime_4k_matrix.json` 记录了同一真实 Vulkan Renoir 设备的 4K 画质/FSR 诊断矩阵；
  即使性能档 0.59 缩放也只有 7.3 FPS（P95 143.789 ms），因此高质量 P95 目标必须在更强实体
  GPU/原生桌面上重测，并继续做场景 LOD、合批和光照成本优化。
- 当前近/中/远几何 LOD 版本的独立诊断保存在 `performance_runtime_4k_lod_matrix.json`：高画质 30 帧
  P95 460.946 ms、均衡 60 帧 P95 262.851 ms、性能 60 帧 P95 130.228 ms；LOD 已通过几何、质量
  档和 teardown 回归，但仍只是短样本诊断。`VISUAL_VALIDATION_REPORT.md` 新增的 `lodsplit4k_*`
  哈希覆盖当前代码版本的 4K 地面、湿泥、树皮、湖面、水花、脚印前后与角色动作证据。
- 动态分辨率通过真实 Vulkan Renoir 1280×720 短采样验证：高画质启用后自动降至 0.35，60 帧平均
  21.3 FPS、P95 51.041 ms；这证明控制器进入 GPU 路径，但不是 4K/Windows 性能目标通过证据，原始
  结果见 `performance_runtime_dynamic_resolution_720.json`。

## 设备与性能

目标机是 Ryzen 5 PRO 4650U + Renoir 集显 + 15 GiB。高画质档用于画面验收，不是该集显上的
60 FPS 档；本轮 1280×720 X11 实测高画质 8.4 FPS、平衡 13.3 FPS、性能档 29.3 FPS，
高质量 P95 目标未达成。准确数字见
`PERFORMANCE_REPORT.md`。正式发行还需针对多台 Windows 独显/集显建立矩阵。

## Windows 交付状态

- Godot 4.7.1 官方 Windows x86_64 release 模板已 CRC 校验；
- Windows Desktop preset 已加入；
- EXE + PCK 结构已导出；
- v0.6.2-alpha 发布目录已包含玩家 README 与构建清单；重新导出清理逻辑后的 ZIP 已通过
  `unzip -t`，PCK 通过同版本 `--release-smoke`；
- 当前 PCK SHA-256 为 `6416d46ee5592b91c50cfeb5f28fa9e831bd6c8bdfebc34dfc54f8b986f97357`（538,736,844 bytes）；
- ZIP SHA-256 为 `4891a22f474825072cedd0fe7bd81274948dd4cc596466954f7c2974bf245fee`（576,248,808 bytes）；
- 不含签名、安装器、自动更新和崩溃上报；
- 本机没有 Windows 运行环境，仍需真实 Windows 10/11 人工启动验收。

最终文件名与哈希以 `WINDOWS_BUILD_AND_RELEASE.md` 和 release 目录为准。

## 下一阶段优先级

1. 在实体 4K 原生桌面/独立 GPU 和 Windows 上重跑 0.6.2 材质、湖面和反射探针捕获，以高质量
   P95 ≤ 41.7 ms 作为验收目标，并保存 GPU/驱动信息；当前 X11 Renoir 原生 4K 探针结果未达标。
2. 在实机捕获确认显存预算后为英雄镜头启用 8K，同步更新 `MATERIAL_LIBRARY_SHA256.txt` 与许可凭证。
3. 在真实 Windows 10/11 上完成两台以上 GPU 的启动、保存、全屏、手柄和物理交互验收。
4. 外部玩家盲测主线，记录完成时长、迷路点和机关重试次数。
5. 拆分 main.gd，消除测试退出资源泄漏警告；补材质切换、湿润联动、IK 和水纹池的 GPU 回归。
6. 制作起步、急停、转身、坡面适配、表情与朔的表演资产；城市继续合批、灯光 LOD 和动态分辨率优化。
7. 补无障碍、按键重映射、音频设置、多语言资源、签名、图标和安装器。

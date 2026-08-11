# 微光林地：雨的名字 — 项目进度快照

快照日期：2026-08-11
工程版本：0.6.2-alpha
引擎：Godot 4.7.1 Stable  
当前分支：`feature/art-refinement-0.6.2`

## 2026-08-11 最终视觉复验（收尾提交）

本轮把试玩反馈对应的四条链路都落到可验证实现：角色在 GLB 动画上叠加可逆的脊柱、肩臂、腿部、头部
骨骼层，Walk/Run/Interact 采样可见的重心与伸手阶段；低于 y=-1.75 会回到经过过滤的安全检查点并
清空速度/交互状态；配重石回位后跨时相同步铭名透镜；档案三环现在由锚点符号、alignment 顺序、第一环
偏移和五进制封印组成，错误确认会重置并保留线索。

画质重制新增自定义蓝金天空、电影级 LUT/暗角/胶片颗粒、暖色神龛反弹光与冷色湖面轮廓光；地形保持
129×129 高密度渲染网格，草簇升级为八片弯曲叶片，近景树叶接入带 alpha cutout 的叶片图集并补充
近景树冠填充、树根外翻和地表植物图集，同时保留树皮扫描 PBR。湖面实际恢复屏幕折射/反射采样，保留双层法线、Fresnel、深度吸收、焦散、岸线泡沫和
水纹/飞溅池；雨水改为可读的细雨条、低发光水滴和池化软泡沫。

真实 Vulkan 1280×720 截图与 SHA-256 已更新到 `VISUAL_VALIDATION_REPORT.md`。3840×2160 证据使用
`LUMINOUS_RENDER_SCALE=0.5` 输出目标尺寸（不是原生 1.0 性能结论）。完整 `./tools/run_regression.sh`
已通过 `REGRESSION_OK tests=25`，Windows 包已在收尾代码落盘后重新导出；当前环境没有 Windows，不能
把 Linux PCK smoke 当作 Windows 实机启动证明。

当前重新导出的便携包位于 `releases/LuminousGrove-Windows-x86_64-v0.6.2.zip`，大小 578,607,845
bytes，SHA-256 为 `4b77d92bab1d91165b52c8d23d0b4969dee7d02ca81eb96f37eb49cc45b3e4da`；PCK smoke
输出 `RELEASE_SMOKE_OK build=0.6.2-alpha campaign=8 quality=high echo_async=ready`。

本次收尾提交同步更新了发布 PCK 的运行时植物图集白名单；目录包核心校验为 EXE
`430307b1ec7e4039de2ee783f9cd4f7191276e7c33f1c6450946f36763154277`、PCK
`e15ee9de223a8715e6d4f3eaf6d97f01c356490fad1eae079608028b5e85b01f`。仓库之后不再继续扩展功能，
仅保留目标 Windows 设备上的启动、输入、驱动和性能验收。

## 2026-08-11 画质重制与试玩反馈修复

本轮把“能跑的原型”继续推向重制版镜头：角色不再只依赖根节点摆动，而是在 GLB 动画之上叠加
躯干重心、反向摆臂、起停前倾、呼吸和交互伸手的骨骼层；第三人称相机缩短到 3.15m、FOV 调整为
53°，让动作和服装材质在实际玩法镜头中可读。水面把过大的 Gerstner 波幅、屏幕反射扭曲和闪光
压低，保留 Fresnel、低幅双层法线、深度吸收、岸线泡沫和反射探针；水花池增加带噪声的软泡沫接触层，
雨滴与水面闪烁粒子改为更小、更低发光的材质，避免白色粒子盖住湖面。中远景树冠从圆球代理提升为
30/20 张分层叶片卡，树叶沿高度、实例和风相位产生色差与摆动。真实 Vulkan 截图已重新生成：
`previews/godot_prototype.png`、`forest_tree_detail.png`、`realistic_lake.png`、
`realistic_lake_splash.png`；SHA-256 与动作截图索引见 `VISUAL_VALIDATION_REPORT.md`。

本轮还把虚空恢复阈值提前到 y=-1.75 并保留安全检查点，三环档案谜题增加最终封印轮（步数和除以五取余），
配重回位后由 NarrativeDirector 重同步铭名透镜和玩家交互目标。`player_animation_test.gd`、
`presentation_test.gd`、`interactive_water_test.gd` 与完整 `REGRESSION_OK tests=25` 已通过；Windows 包
需在本轮提交后重新导出。

## 当前可交付状态

这是一个可从开场走到三种结局的第三人称 3D 叙事冒险 alpha。当前代码、测试和设计文档已
统一到 campaign v8；本快照首次把之前只存在于工作目录的实现与文档纳入 Git 版本历史。

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
  Normal/Roughness；建立 `SurfaceProfile`/`SurfaceLibrary`，并用 `content/materials/profiles/*.tres`
  显式登记干土、湿泥、苔藓、石、木和水。
- 运行资源：接入 Poly Haven CC0 的 Forest Ground 01、Mud Forest、Forest Leaves 02 和
  Pine Bark、Mossy Rock 4K PBR（英雄近景目标 8K）；AO、Cavity、Height 和 SHA-256/许可
  登记见 `MATERIAL_LIBRARY_SOURCES.md`、`MATERIAL_LIBRARY_SHA256.txt`。
- 地形与着色：渲染网格提升到 129×129，碰撞仍为独立 65×65 HeightMap；地表加入坡度、岸线、
  噪声分层、视差、AO/Cavity、细节法线和雨后湿润联动。
- 森林几何：54 棵树按空间半径拆为近景扫描 GLB、中景双冠低面数代理和远景共享低面数树干/树冠
  MultiMesh；近景材质仍保留完整树皮/叶片扫描 PBR，中远景代理关闭阴影并随画质档调整可见距离，
  避免把远景 GLB 三角形全部压到 4K 像素预算中。
- 湖面与植被：水面改为 32 槽有界事件池，加入双层法线、Fresnel、深度吸收、岸线泡沫、反射
  探针和湿度粗糙度；飞溅和脚印采用池化；草、叶片响应雨势和角色局部弯曲。
- 光照：增加湖面与神龛反射探针、湖面反射补光和湿润联动；保留 Forward+、SDFGI、SSAO、
  SSIL、SSR 与体积雾，不引入首轮昼夜循环。
- 交互与物理：SurfaceProbe、土/泥/木/石 PhysicsMaterial、斜坡湿泥减速与石面滑动、浅水
  反馈、脚步水纹、脚印池、双脚 SkeletonIK3D 和刚体接触反馈已接入；坡面测试确认脚部目标
  法线随接触面旋转，现有水体信号保持兼容。
- 资源与动画：`MaterialProfile` 统一承载六类 PBR 贴图与物理字段；Walk/Run 以动画相位触发
  脚步，距离检测保留为异常 fallback；刚体入/出水浮力、阻力和边界事件，以及角色/刚体近场
  草叶弯曲已接入。
- 林地 Shader 和岸石/树皮 PBR 创建函数现在直接读取上述 profile 的贴图，SurfaceProbe、脚部
  射线、交互查询和恢复落点复用查询参数，水花根节点由湖体统一拥有并在退出时释放 GPU 资源。
- 全流程：`gameplay_test.gd` 已从风铃、三记忆、神龛、双时相档案、Jolt 配重、城市回路、雨眼
  试炼走到潮汐结局并验证完成态恢复；所有叙事交互均走玩家 `request_interaction()`，配重通过
  实际推动刚体触发踏板；同时保留真实附近交互提示、15 个目标引导存在性断言，以及每阶段
  `get_prompt()` 非空/`can_interact()` 合同校验，避免只靠测试直接调用机关或让玩家在跨时相关卡中迷路。
- 本轮玩家反馈修复：跨时相返回此岸时强制重同步透镜可用状态并刷新玩家交互目标；失效目标不会
  再拦截下一次 E。档案锚点改为按 alignment 分支的顺序密码，错误顺序不会消耗锚点且会保留重试；
  配重→透镜路径加入真实回归断言。
- 本轮运行时修复：AnimationTree 的假状态不再阻塞 GLB 动画，角色改为直接 AnimationPlayer 物理时钟
  播放，并新增真实骨骼姿态位移断言；坠入虚空会回到经过校验的安全检查点、清空速度并恢复输入。
- 本轮谜题升级：第二幕新增三环 ArchiveCipherConsole，R 转动、E 确认，线索随 alignment 分支变化；
  错误确认会重置并显示语义提示，完成校准后才开放倒影、Jolt 配重和铭名透镜，存档版本升至 v8。
- 本轮湖面升级：水面 Shader 加入更深的吸收色、屏幕折射/反射混合、焦散双层、太阳闪光和更强双层法线；
  水滴提升至 220、增加 180 个水面闪烁粒子，飞溅扩为 5 层环与 48–124 个水滴。
- 角色与森林视觉补强：玩家新增呼吸、步态重心、起停惯性和转身侧倾的二级运动，服装/鞋材质恢复
  authored normal map；中远景树木改为分层枝条与 5/4 簇状树冠，切换距离与近景 GLB 分离，减少
  截图中重复“圆球树冠”的假感。
- 退出与流送：旧版地面 PBR 兜底贴图改为按需加载；WorldStreamer 在关卡卸载前调用关卡级
  `shutdown()`，Echo Ruins 会解绑生成 Mesh 的 PBR 贴图与材质；Vulkan 捕获脚本会预热并释放
  临时相机/Viewport 引用；GPUParticles3D 在解除 draw pass 前也会清理 PrimitiveMesh 材质，避免
  验证工具本身扩大退出告警，但零泄漏结论仍未通过。
- HDRI 运行路径：Godot 4.7.1 无法直接加载 HDR/EXR，本轮将 Poly Haven Mossy Forest CC0
  tonemapped JPG 下采样为 4096×2048，接入 `PanoramaSkyMaterial`，并以 SHA-256 和 4K Vulkan
  湖面截图记录；未将外置原始 HDR/EXR 伪装成已验证运行资源。

## 自动化与实机证据

```text
REGRESSION_OK tests=25
RELEASE_SMOKE_OK build=0.6.2-alpha campaign=8 quality=high echo_async=ready
```

最新全流程复验把所有叙事节点统一改为 `PlayerController.request_interaction()` 路径，档案配重由
玩家实际推动 Jolt 刚体进入踏板；输出 `GAMEPLAY_TEST_OK stage=complete resident=2
archive_mechanisms=3 city_traces=3 relays=4 rain_eye_seals=3 trials=3 ending=tidal_order
restore=rain_eye`，随后 25 项回归仍为 `REGRESSION_OK tests=25`。这证明自动化交互合同和完成态恢复
未回退，但不替代真实玩家人工走查；完整回归退出的通用 ObjectDB 提示会按退出时序在 1–3 个间变化。

本轮新增 `runtime_teardown_test.gd`，验证退出时 76 个 Mesh、12 个 MultiMesh、6 组粒子、3 个
Camera3D 和 WorldEnvironment 的运行时引用均已解绑；24 项回归全部通过，但剩余 ObjectDB/Texture
RID 警告仍未达到零泄漏验收。

随后测试退出路径显式丢弃 `PackedScene` 局部引用，末次 24 项 headless 回归仍为
`REGRESSION_OK tests=24`，通用 ObjectDB 提示在不同退出时序下为 1–3 个；这只证明测试句柄清理有所改善，
不能替代
Godot/Jolt 内存检查或真实 Windows/4K 设备上的零泄漏验收。

门户退出顺序已补强：`alternate_texture`、曲面材质和预览相机在 SubViewport 释放前解绑，门户回归
增加断言；单独 smoke 复验曾不再出现 ObjectDB，但完整回归仍会随退出时序报告，真实 4K 湖面
复验仍报告 7 个 Texture RID，因此仍需 Windows/实体 4K 内存检查。

本轮又补充 Main/Player 的退出前 process、physics、IK、交互查询和 SurfaceProbe 清理，并在
WorldStreamer/EchoRuins 释放前解绑 surface override；24 项回归仍通过。最新真实 Vulkan 4K 湖面
复验仍为 7 个 Texture RID 与 1 个 ObjectDB，说明项目引用清理已加强但渲染器/Jolt 退出资源仍未
完成零泄漏验收。

最新一轮又把 Main 的停止范围扩展到所有脚本子节点，并让 SurfaceLibrary、WetnessController、Player、
SurfaceProbe 和 PhaseShift 在同一退出窗口释放注册表、物理查询和场景引用；这避免了退出阶段继续产生
新的查询对象，但 Jolt 独立线程的通用 RefCounted 警告仍会随测试时序出现，需在升级的 Godot/Jolt
构建或实体 Windows 实机上继续定位，不能把当前回归通过误认为零泄漏。

本轮引用探针又发现风铃、神龛、档案机关以及 AnimationTree playback 的生成 Resource 仍会在 Main
结束前留在脚本字段；已加入递归 RefCounted 释放边界，并在 `runtime_teardown_test.gd` 增加交互物、
档案机关和播放状态断言。24 项回归仍通过，但剩余通用 ObjectDB/4K Texture RID 仍需 Godot/Jolt
内存检查与实体 Windows/4K 设备确认。

追加的临时 1280×720 Vulkan A/B 探针分别关闭反射探针、环境、粒子、水体和门户，仍得到 7 个 Texture
RID；这为“根窗口/渲染器 transient target”假设提供了更强证据，但不是零泄漏证明，后续仍需 Godot
内存检查和实体 Windows/4K 设备确认。

目标设备为 Ryzen 5 PRO 4650U / Renoir 集成显卡。本轮已在 `DISPLAY=:1` 的真实 X11/Vulkan
表面以 1280×720 重测：

- 高画质（原生 1.00）：8.4 FPS，P95 121.219 ms，P99 124.506 ms，显存监视值约 3.06 GB，用于画面验收；
- 平衡（FSR 0.77）：13.3 FPS，P95 78.047 ms，P99 80.342 ms；
- 性能档（FSR 0.59）：29.3 FPS，P95 36.994 ms，P99 61.053 ms，已接近但仍未达到 30 FPS 的 P95 预算。
- 3840×2160 原生 X11 窗口探针（高画质 1.00）：2.0 FPS，平均 494.680 ms，P95 503.819 ms，P99
  525.618 ms，显存监视值约 4.03 GB；证明 4K Forward+ 路径有效，但高画质不可玩。

追加的 4K 90 帧诊断矩阵见 `performance_runtime_4k_matrix.json`：高画质原生 P95 502.835 ms，
高画质 FSR 0.59 P95 257.868 ms，均衡 P95 295.162 ms，性能档 P95 143.789 ms；这确认当前
Renoir 设备的 4K 瓶颈同时来自像素量和场景几何/特效，不能用单一缩放开关宣称达标。

近/远树几何 LOD 改动后又保留了独立的 `performance_runtime_4k_lod_matrix.json` 诊断：高画质
30 帧 P95 460.946 ms、均衡 60 帧 P95 262.851 ms、性能 60 帧 P95 130.228 ms。该改动已通过
环境几何、三档质量和 teardown 回归，并重新生成 `lodsplit4k_*` 全套地面、湿泥、树皮、湖面、
水花、脚印前后和角色动作截图；截图哈希见 `VISUAL_VALIDATION_REPORT.md`，但性能仍未达到高质量
41.7 ms 目标，不能把短样本当正式验收。

新增的动态分辨率控制器默认关闭，仅在 `--dynamic-resolution` 或
`LUMINOUS_DYNAMIC_RESOLUTION=1` 下运行；它按平滑帧时在 0.35 至当前画质档基线之间调节 FSR 3D
缩放。Renoir 1280×720 真实 Vulkan 60 帧诊断降到 0.35 后 P95 为 51.041 ms，结果见
`performance_runtime_dynamic_resolution_720.json`；该控制器已进入质量回归，但实体 4K/Windows
目标仍需重新测量，不能把该短样本写成性能通过。

当前已保存的视觉证据位于 `previews/`（该目录被 Git 忽略，避免提交大量生成截图）；重新
生成方式和验收标准见 `TESTING_AND_ACCEPTANCE.md` 与 `PERFORMANCE_REPORT.md`。

真实 Vulkan 截图已覆盖地面、泥滩、树皮、湖面、水花、脚印和角色动作，前后对比与 SHA-256
见 `VISUAL_VALIDATION_REPORT.md`；同时已用独立 Vulkan `SubViewport` 输出并校验 3840×2160
材质截图，并用临时 3840×2160 X11 mode 完成湖面原生窗口截图。JSON 原始结果保留在
`performance_runtime*.json`。`c521730` 后又以 `CAPTURE_PREFIX=particlefix4k` 重新输出全部
地面、湿泥、树皮、湖面、水花、脚印前后和角色动作截图；实体 4K 显示设备与 Windows 性能仍需复测。

## Windows 发行状态

0.6.2-alpha Windows x86_64 便携包已在本机重新导出并完成 PCK 自检；真实 Windows 启动仍需
人工验收：

- 官方 Godot 4.7.1 release 模板导出；
- EXE 为 PE32+ x86-64 GUI executable；
- 导出 PCK 通过 Linux 同版本 `--release-smoke`；
- ZIP `unzip -t` 通过；本轮三环谜题、直接动画、虚空恢复与湖面 Shader 修复后已重新导出 PCK，
  SHA-256 为 `e15ee9de223a8715e6d4f3eaf6d97f01c356490fad1eae079608028b5e85b01f`
  （541,289,800 bytes）。ZIP SHA-256 为
  `4b77d92bab1d91165b52c8d23d0b4969dee7d02ca81eb96f37eb49cc45b3e4da`
  （578,607,845 bytes）。

发行包位于本机 `releases/`，按 `.gitignore` 不进入源码仓库；构建命令、文件哈希和人工验收
要求见 `WINDOWS_BUILD_AND_RELEASE.md`。由于构建机是 Linux，真实 Windows 10/11 启动、
驱动、全屏、手柄和 SmartScreen 仍是发布前人工验收项。

## 收尾后的唯一待办：目标 Windows 设备验收

源码与功能开发在本提交后冻结；仅需在真实 Windows 10/11 设备完成启动、输入、全屏、驱动、性能
和至少一轮完整流程验收，并把结果作为发行记录，不再继续扩大本仓库功能范围。

4K runtime 已接入，原生 X11 3840×2160 窗口已完成实测但 P95 仍远超 41.7 ms；下一阶段只为
英雄镜头启用 8K，并在实体 4K 桌面/独立 GPU/Windows 上重新测量高质量档，再继续角色起步、
急停、转身和面部表演资产。

当前一次性收包范围为 27 张 PNG，完整命名、尺寸、提示词、Alpha 和许可记录要求见
`USER_ASSET_PACKAGE_BRIEF.md`。素材包应命名为 `luminous_grove_asset_pack_v2.zip`，并包含
`manifest.csv`、每张图的提示词及 `generation_notes.txt`。

收到素材后，下一次提交应记录：角色跨图一致性、材质无缝检测、透明边缘、图集切片、Godot
材质预览，以及实际接入了哪些运行时文件。与此同时，角色起步／急停／转身和面部表情仍是
从“工程精细化”走向最终美术定稿的下一批工作。

## Goal：后续推进目标清单

下一阶段以“可验收的唯美写实与稳定发行”为目标：先在实体 4K 桌面、Windows 10/11 和至少两类
GPU 上重跑地面、湿泥、树皮、湖石扫描材质、湖面反射、湿润联动、脚印和角色动作的截图与帧时，
明确 4K/8K 英雄材质的显存预算并把高质量 P95 压到 ≤41.7 ms；当前已用 Godot 支持的 CC0
tonemapped PanoramaSkyMaterial 解除运行格式阻塞，仍需在支持 HDR/EXR 的导入器上复验未裁剪光照；再补齐主角起步／急停／转身、
坡面 IK 稳定性、脚步动画相位、面部表演以及朔和城市居民等专业资产，完成 HDRI、许可和 SHA-256
登记；按真实玩家路径复测交互提示、门控、失败回退和三结局，修正迷路或卡关点；针对
WorldStreamer、InteractiveLake、4K SubViewport 和 Jolt 交互的 ObjectDB/Texture RID 清理警告定位
到具体引用并实现零泄漏，补齐性能、湿润、IK、水纹、刚体和植被的 GPU 回归；最后完善动态分辨率、
合批/LOD、输入重映射、字幕/色盲、音频、签名、图标和安装器，重新导出并校验 Windows 包后提交
Git。当前 3840×2160 Vulkan 离屏与 X11 原生窗口截图已通过，但实体 Windows 实机、多 GPU、性能
目标和零泄漏仍是明确未解决项。

## Goal：本次试玩反馈后的下一轮目标

下一轮要把“工程上可运行”推进到“美术与谜题可定稿”：为主角补充专业的起步、急停、转身、坡面
重心和面部表演资产，并评估更高精度身体/头发网格；继续用树皮与叶片扫描材质、真实叶片卡、枝条
风场和近中远 LOD 做树木 A/B 截图，清理草簇重复与中景穿帮；围绕三环符文与跨时相机关做至少一次外部
玩家盲测，记录错误确认、提示可读性、推石头后透镜可达率和迷路点，再调整线索强度；在 Windows
实机和多 GPU 上复测透镜、Jolt 刚体、水纹、IK、湿泥减速及高质量 P95 ≤41.7ms，继续定位
ObjectDB/Texture RID 警告，并在完成性能、输入重映射、字幕/无障碍、音频和签名验收前不要宣称最终发行。

## 主要入口

- 状态总览：`IMPLEMENTATION_STATUS.md`
- 变更记录：`CHANGELOG.md`
- 测试规范：`TESTING_AND_ACCEPTANCE.md`
- 性能报告：`PERFORMANCE_REPORT.md`
- Windows 构建：`WINDOWS_BUILD_AND_RELEASE.md`
- 用户素材清单：`USER_ASSET_PACKAGE_BRIEF.md`
- Godot 工程：`game/`
- Blender 构建脚本：`tools/`

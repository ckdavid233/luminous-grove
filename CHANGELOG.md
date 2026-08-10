# 变更记录

## 0.6.2-alpha — 2026-08-09

### 林地湖区材质、视觉、光照与交互升级

- 接入 Poly Haven Mossy Forest CC0 的 4096×2048 tonemapped JPG 运行天空，使用
  `PanoramaSkyMaterial` 替代当前构建不支持的 HDR/EXR 直接导入；新增资产 SHA-256、材质完整性
  断言和 1280×720/3840×2160 真实 Vulkan 湖面复验。原始未裁剪 HDR/EXR 继续外置，不宣称等价的
  HDR 光照验收。
- 继续收紧退出顺序：Main 会先停止所有脚本子节点的 process/physics/input 回调，SurfaceLibrary 与
  WetnessController 提前清空运行时注册表；Player、SurfaceProbe、PhaseShift 的 Jolt 查询改为显式
  持有并在同一帧释放 direct-space wrapper。24 项功能回归保持通过，但 Jolt 独立线程、4K SubViewport
  和渲染器退出时序仍会偶发 ObjectDB/Texture RID，未达到零泄漏验收。
- 加入 Main/Player 退出前的 process、physics、IK、交互查询与 SurfaceProbe 清理，并在
  WorldStreamer/EchoRuins 释放前解绑 MeshInstance3D 的 surface override；24 项回归仍全部通过，
  4K 捕获的 Texture/ObjectDB 警告继续作为未关闭技术债记录。
- 调整 RainRiftPortal 退出顺序：先释放 `alternate_texture`、曲面材质和预览相机，再回收
  SubViewport；新增门户解绑断言。单独 smoke 复验的 ObjectDB 提示曾消失，但完整回归仍会
  随退出时序出现，4K/可见门户仍保留渲染器 Texture RID 检查项。
- 复核 Poly Haven Mossy Forest HDRI 导入：当前 Godot 4.7.1 Linux 构建对 `.hdr` 与 `.exr` 均无
  资源加载器，未将未验证天空纹理放进运行包；导入链路、许可与 SHA-256 登记保留为后续目标。

- 将 `build_user_pbr.gd` 改为扫描 PBR 导入/校验工具，停止依据 Albedo 亮度伪造 Normal 和
  Roughness；新增 `SurfaceProfile`、`SurfaceLibrary`、`SurfaceProbe` 和材质来源/校验和清单。
- 接入 Poly Haven CC0 Forest Ground 01、Mud Forest、Forest Leaves 02、Pine Bark、Mossy Rock
  的 4K runtime 贴图；地表 Shader 支持 AO/Cavity/Height、视差、坡度/岸线分层和雨后湿润联动。
- 林地渲染网格提升为 129×129，碰撞保持 65×65 HeightMap；湖面加入 Fresnel、双层法线、深度
  吸收、岸线泡沫、反射探针和 32 槽有界水纹事件池；飞溅与脚印改为池化。
- 增加湖面/神龛电影光照补光、局部反射、草叶受角色弯曲和湿度驱动；角色接入表面物理反馈、
  湿泥减速/石面滑动、落地冲击与双脚 SkeletonIK3D。
- `MaterialProfile` 统一承载六类 PBR 贴图和物理参数；Walk/Run 动画相位触发脚步，异常时回退
  到距离检测；刚体获得浅水浮力/阻力/入出水事件，草地接收角色与刚体局部弯曲。
- 全流程测试增加附近交互提示和真实 `request_interaction()` 检查，并从风铃完整走到潮汐结局、
  验证完成态恢复；WorldStreamer 与湖面事件池增加退出清理。
- 新增六个可审计的 `MaterialProfile` `.tres` 资源，地表 Shader、岸石和树皮 PBR 直接读取 profile；
  增加坡面法线脚部 IK 回归，并复用 SurfaceProbe/脚部/交互/恢复落点查询参数以降低临时 RID。
- 水花根节点改由 `InteractiveLake` 所有，门户、脚印 Tween 和环境射线增加退出清理；已记录仍会
  偶发出现的 Godot ObjectDB/Texture RID 警告，当前不宣称零泄漏。
- 本轮补充幂等 `Main.shutdown()`、SurfaceProfile 物理材质缓存释放、门户停止处理和回归场景的
  显式 teardown 等待；当时 23 项回归全部通过，但退出时仍观察到少量通用 ObjectDB/Texture RID
  警告，继续列为下一阶段内存检查任务。
- 新增统一 `Main._release_runtime_references()` 与 `runtime_teardown_test.gd`，在退出前解绑网格、
  MultiMesh、粒子、音频和环境引用；回归套件扩展为 24 项，仍保留 ObjectDB/Texture RID 警告作为
  未完成的零泄漏验收项。
- 角色退出时补齐控制器、SurfaceProbe、AnimationTree、SkeletonIK 和脚部目标引用释放；24 项回归
  仍通过，但部分场景仍有少量 ObjectDB 警告，继续列为内存检查任务。
- WorldStreamer 退出时现在会收束未完成的 threaded PackedScene 请求，并断开流送实例及子节点的
  信号 Callable；AnimationTree 同步解除 anim_player 引用。退出警告已减少但仍偶发，当前仍不宣称零泄漏。
- 本轮进一步将 Main 与 WorldStreamer 的递归断开限制为脚本对象回调，保留 Control、Viewport、
  Skeleton3D 等 Godot 原生内部连接，避免退出阶段误断连接产生错误；24 项回归仍通过，ObjectDB
  警告继续按未完成技术债记录。
- Main 现在显式调用 `PhaseShiftController.shutdown()` 与 `CinematicDirector.shutdown()`，清掉可复用
  的物理查询、场景引用和失效 Tween；`runtime_teardown_test.gd` 新增对应断言。真实 Vulkan
  1280×720 地面/湖面捕获不再出现 ObjectDB 警告，4K SubViewport 与渲染器仍保留 Texture RID
  检查项。
- 地面材质的旧版 PBR 兜底贴图改为按需 `load()`，正常 `MaterialProfile` 路径不再由脚本常量
  全局持有旧贴图；WorldStreamer 在运行时卸载前会调用关卡级 `shutdown()`，Echo Ruins 会先解绑
  生成 Mesh 的材质贴图和材质引用。捕获脚本也会预热并显式释放验证相机、Viewport 引用；24 项
  回归仍通过，Renoir 新旅程 Vulkan 捕获仍报告 7 个 Texture RID，故继续保留为未完成的零泄漏
  技术债。
- `Main.shutdown()` 现在在子系统清理前后都用 `Camera3D.clear_current(false)` 清除游戏、过场和
  门户相机，避免 Godot 默认自动选中下一个相机而重新激活渲染缓冲；`runtime_teardown_test.gd`
  新增 3 个相机断言。24 项回归仍通过，剩余通用 ObjectDB/Texture RID 告警具有时序与渲染器差异，
  尚未达到零泄漏验收。
- 捕获脚本现在独立处理 `CAPTURE_PREFIX`、`CAPTURE_ONLY` 和窗口模式，补齐带前缀的 4K 前后对比
  截图索引；退出时先清除临时相机并等待 Main/流送子节点完成 `_exit_tree()` 再解绑 SubViewport。
  该调整提升了复验可重复性，但 1280×720 与 4K Vulkan 仍可能报告 Texture RID/ObjectDB，未改变
  零泄漏验收结论。
- 2026-08-10 通过临时 Vulkan teardown 矩阵区分了根窗口、验证相机、Main shutdown、queue-free 和
  4K SubViewport 的退出行为；延迟或立即 free 均未稳定消除 7 个 Texture RID，因此没有合入未经
  证实的退出改动。删除探针后 24 项回归仍通过，零泄漏继续等待 Windows/实体 4K 与 Godot 内存检查。
- 新增屏幕空间目标引导：根据 NarrativeDirector 阶段指向当前交互目标并显示距离；城市、档案馆和
  雨眼的跨时相目标均由流送实例解析，结局后自动清空。完整流程测试新增 15 个目标存在性断言，
  4K 湖面/水花复验通过；Windows PCK/ZIP 已重新导出并更新哈希，真实 Windows 启动仍待实机。
- 均衡/性能画质接入固定 FSR 3D 缩放（0.77/0.59），并把 `render_scale` 写入 Vulkan 性能 JSON；
  Renoir 1280×720 性能档由 17.6 FPS 提升到 29.3 FPS、P95 由 59.794ms 降至 36.994ms，仍待
  原生桌面和独立 GPU 复测。
- 性能与截图入口新增 `PERFORMANCE_RESOLUTION=3840x2160` 和 `CAPTURE_NATIVE=1`；在真实
  Renoir Vulkan Forward+ 的 3840×2160 X11 mode 完成高画质采样（平均 511.061 ms、P95 966.345 ms）
  与湖面原生窗口截图，结果证明 4K 路径有效但目标性能未达成。
- Windows/PCK release smoke 改为允许冷启动材质与 threaded PCK 最多 3600 帧；探针忽略开发者存档，
  固定从林地基线确认 Echo Ruins 异步加载，并在成功标志后直接退出；本轮导出包已通过 Linux 同版本
  自检和 ZIP 完整性检查。源目录 headless 仍可能出现 1 个通用 ObjectDB 清理警告，未宣称零泄漏。
- RainRiftPortal 退出时同步释放预览 SubViewport、环形子树和测试相机，避免门户运行时资源依赖
  parent traversal；24 项回归和 4K 湖面复验通过，但 7 个 Texture RID/通用 ObjectDB 告警仍需实体
  Windows/4K 内存检查区分 transient buffer 与项目引用。
- 回归套件从 21 项扩展为 23 项，新增材质完整性和表面交互测试；真实 Vulkan 性能基线保留，
  当前容器仅能运行 64×64 headless CPU 冒烟。

### 美术精细化

- 新增生成式雨后森林地表 Base Color，保留湿土、苔藓和落叶的低频变化，并接入 Godot
  地表 Shader；原始生成图继续作为项目内可审计的运行时资产。
- Blender 树叶由旧的菱形卡片改为带中心脊线的六边形 lanceolate 叶片，补充 UV 边缘／叶脉
  着色和软风动；三种树的 `.blend` 源文件与 GLB 已重新导出。
- 角色动作增加脚踝、头部、手部的二级重叠运动，7 套 Action 现在每套保留 19 条骨骼轨道，
  让 Walk／Run／Jump／Land／Interact 不再像刚性姿态切换。
- 水面 Shader 增加交互波峰、内外环高光和克制自发光；入水／出水改为三层扩散环并增加
  上抛水滴数量，强化水纹的时间层次。

### 验证

- 保留真实 Vulkan 1280×720 主场景、树木近景、湖面／飞溅和角色动作前后对比，并新增通过
  `SubViewport` 生成且尺寸断言为 3840×2160 的地面、湿泥、树木、湖面、水花和角色截图；
  原生 4K 桌面帧时仍待有 3840×2160 显示 surface 的设备复测，避免把离屏图像冒充性能验收。
- 23 项回归保持通过；Renoir 本轮真实 X11/Vulkan 实测高画质 8.4 FPS（P95 120.904 ms），性能档
  17.6 FPS（P95 59.794 ms）；这组数据只代表当前 VNC/X11 表面，原生 4K 与 Windows 仍待复测。
- 工程版本推进为 `0.6.2-alpha`；用户素材包仍可按 `USER_ASSET_PACKAGE_BRIEF.md` 接入，
  不将概念图冒充最终 3D 资产。

## 0.6.1-alpha — 2026-08-01

### 实测问题修复

- 修正 Godot 4 的 Escape、Shift、Enter、F5、F9 与方向键键码；暂停菜单现在可由真实
  Escape 打开，并能在暂停状态接收真实鼠标点击、画质切换与继续按钮。
- 交互由单一准星射线扩展为射线优先、附近候选兜底，并以真实 `E` 输入验证风铃交互。
- 移动加入平滑加速／减速、空中控制、土狼时间、跳跃缓冲、落地冲击阈值和更小胶囊，
  避免出生、小台阶误播落地与碰撞卡顿。
- 湖面改用椭圆接触范围和角色脚底高度判断；空中水平移动不再生成脚步波纹，入水与
  出水均生成扩散环和上抛水滴。

### 画面与资产

- 重建 65×65 高度地形与对应 HeightMapShape；湖底成为可行走浅盆。
- 重建三种树：根系、锥形树干、两级分枝和数千片带弧度的小叶；54 棵树均有树干碰撞。
- 草地改为 16,000 个分散小簇、弯曲窄叶和风动，均衡／性能档按预算降低可见数量。
- 湖岸岩石和芦苇改为 MultiMesh，并为大型岩石加入稀疏碰撞。
- 角色 GLB 增加独立 Run、Jump、Fall、Land，连同 Idle、Walk、Interact 共 7 套动作；
  新增腰带、斜挎带、记忆袋、扣件和雨纹饰件。
- 调整阴影、环境色、地表色、角色补光和稳定湖面着色，移除旧草图集的发行引用。

### 验证与性能

- 回归扩展为 21 项，新增真实输入、移动状态和环境几何／物理覆盖。
- Renoir 1280×720 性能档实测 38.4 FPS、P95 27.191 ms；高画质档保留全特效，
  实测 13.6 FPS、P95 75.260 ms。
- 新增真实 Vulkan 主场景、树木近景、水面／飞溅、角色动作和暂停菜单截图验收。

## 0.6.0-alpha — 2026-08-01

### 主线与玩法

- 将原来的“3 锚点 → 城市”扩成“3 锚点 → 跨时相倒影 → Jolt 配重 → 铭名透镜”。
- 将“3 城市残响 → 雨眼”扩成 4 盏交替行灯和朔的证词分支。
- 将“3 雨眼印记 → 结局”扩成 3 段交替共振试炼。
- 潮汐结局加入可解释的双前置条件；合流和守界保持常驻可选。
- campaign 状态从 v4 升级为 v6，并迁移旧短战役保存。

### 操作与成品体验

- 新增冲刺、100 点体力、跳跃、镜头 FOV/步幅反馈和掉落检查点。
- 新增 Xbox/通用手柄移动、观察、跳跃、交互、切换、冲刺、暂停映射。
- 新增暂停菜单、全屏切换、菜单保存和三档运行时画质。
- 新增章节名与全战役进度条。

### 技术

- SaveService 升级到 schema v2：版本、时间戳、旋转、临时文件验证、上一档备份和损坏恢复。
- 新增通用 StoryResonator、JoltCounterweightPlate 和 PushableMemoryStone。
- 高画质默认保留 SSR、SSAO、SSIL、SDFGI、体积雾、Glow 和 45 m 阴影。
- Windows 导出改用官方 TPZ 的 Range 按文件提取，避免无意义下载全部平台模板。
- 生成 Windows x86_64 便携 Release：独立 EXE + PCK + 玩家说明 + 构建清单。

### 验证

- 回归从 16 项扩到 18 项。
- 时相耐久从 12 次提升到 100 次。
- 完整自动流程覆盖 3 档案机关、4 城市回路、3 雨眼试炼、潮汐结局和完成态恢复。
- 导出 PCK 自检通过；最终 ZIP 4 个条目通过 `unzip -t`，SHA256 已随包提供。

## 0.5.0-alpha — 2026-07-31

- 完成四幕紧凑技术战役：林地、沉雨档案、行灯之城、雨眼。
- 加入三结局、实时过场、双时相异步流送和 640×360 门户预览。
- 集成写实 MPFB 角色、Jolt Physics、Forward+ 全特效和高质量水面。
- 建立最初 16 项回归与 1280×720 Renoir 基准。

## 0.1–0.4 — 历史原型

- 从第一幕概念、程序化林地、神龛互动逐步扩成可切换时相的技术原型。
- 历史设计保存在 `ACT_I_ORIGINAL_DESIGN.md`；不再作为当前状态依据。

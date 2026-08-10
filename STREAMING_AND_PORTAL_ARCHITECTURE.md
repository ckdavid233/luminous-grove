# 《微光林地：雨的名字》流送与雨隙门户架构

版本：0.6.2-alpha（已接入运行时）
目标设备：Ryzen 5 PRO 4650U、15 GiB、Renoir 集成显卡  
原则：切换响应、状态可靠和内存上限优先；高画质效果按档位控制

## 1. 雨隙的运行规则

获得能力后，玩家可按 `Q` 或手柄 `Y` 在同一地点切换：

- **此岸（Present）**：湿润青绿、现实中的残损状态。
- **雨忆（Echo）**：冷蓝或暖金的记忆状态，几何、碰撞、灯光和机关不同。

切换保留角色水平位置、朝向和速度，活动时相才拥有碰撞与脚本处理。相反时相已经
预载，因此按键瞬间不会再从磁盘同步读取。玩家可先从 640×360 门户窗口观察另一侧，
再决定是否切换。

当前真正使用差异的内容包括：

- 林地／档案馆：相位道路、两侧不同位置的记忆锚点、跨时相倒影机关。
- 沉雨档案馆：Jolt 刚体石块压住配重板，解锁后续铭名透镜。
- 行灯之城：4 盏行灯交替分布在此岸／雨忆，必须按固定顺序共振。
- 雨眼：3 个封印之后还有 3 段按顺序、跨时相完成的共振试炼。

## 2. 当前层级与所有权

```text
Main                         # 常驻协调器
├── Player                   # 跨章节保留
├── NarrativeDirector        # campaign v7 唯一剧情真相源
├── CinematicDirector
├── UI / PauseOverlay
├── WorldHost
│   └── WorldStreamer        # 请求、实例、激活、LRU 驱逐
└── RainRiftPortal
    └── AlternatePhaseViewport
```

完整章节场景：

```text
content/levels/echo_ruins/echo_ruins.tscn
content/levels/lantern_city/lantern_city_present.tscn
content/levels/lantern_city/lantern_city_echo.tscn
content/levels/rain_eye/rain_eye_present.tscn
content/levels/rain_eye/rain_eye_echo.tscn
```

Player、NarrativeDirector、UI 和过场导演不属于可驱逐关卡。每个关卡根节点拥有自己的
几何、碰撞、灯光、交互物和持久化 ID；场景对象只发语义事件，不自行推进主线。

## 3. 后台加载协议

1. `ResourceLoader.load_threaded_request()` 发起 PackedScene 请求。
2. `WorldStreamer._process()` 每帧轮询 `load_threaded_get_status()`。
3. 只有状态为 `THREAD_LOAD_LOADED` 时才调用 `load_threaded_get()`。
4. `instantiate()` 与 `add_child()` 在主线程完成。
5. 新实例先隐藏，关闭处理和碰撞，再挂入 `WorldHost`。
6. 双时相都准备好后才允许切换；UI 在未完成时显示加载状态。
7. 章节交接完成后驱逐旧章节，使完整关卡实例回到上限 2。

完整流送 PackedScene 使用 `ResourceLoader.CACHE_MODE_IGNORE`，避免旧关卡被全局缓存强
留。贴图、角色和 Shader 等外部共享资源仍通过 Godot 引用计数安全复用。

## 4. 驻留和驱逐

### 驻留预算

- 普通双时相章节：当前关卡此岸 + 雨忆，最多 2 个完整实例。
- 林地阶段：常驻主林地，异步准备 Echo Ruins；进入后仍保持可控上限。
- 章节交接：短暂加载下一组，完成绑定后立即释放上一组。
- 实测从城市进入雨眼后 `resident_levels = 2`、`resident_limit = 2`。

### 驱逐顺序

1. 停止旧场景音频、粒子和脚本处理。
2. 关闭碰撞层与碰撞掩码。
3. 从 `WorldHost` 移除并 `queue_free()`。
4. 清理实例、PackedScene 和加载请求的强引用。
5. 等待延迟释放帧，验证旧 Node 已消失。
6. 被驱逐的相同路径可以再次发起线程加载并重新实例化。

不使用“清空所有缓存”的粗暴方案，因为它可能破坏仍由角色、UI 或另一时相共享的资源。

## 5. 门户渲染预算

- `SubViewport + ViewportTexture`，内部固定 640×360。
- 2× MSAA，不做递归门户。
- 门户在相机视锥外或相机后方时停更。
- 可见但较远时每 4 帧更新；靠近且位于视线中心时请求逐帧更新。
- 超过约 28 米停止更新。
- 门户只显示目标时相视觉层；非活动时相的脚本和碰撞保持关闭。

性能档的后续优化点是降低门户内部比例和远距离更新频率，高画质档不因此被覆盖。

## 6. 切换与安全恢复

一次切换按以下顺序完成：

1. 确认能力已获得、目标场景已加载且当前不在过场／暂停状态。
2. 记录角色 Transform、速度和当前检查点。
3. 关闭旧时相碰撞，启用新时相碰撞。
4. 切换可见层、环境、交互绑定和门户预览目标。
5. 保留角色运动状态；若玩家跌到 `y < -6.5`，恢复至最近检查点。

当前版本已经有掉落恢复，但还没有通用的“新时相形状重叠后寻找最近安全锚点”系统。
因此高速移动平台与狭窄墙体重叠仍属于后续需要专门补强的边界。

## 7. Jolt 物理边界

- 项目显式选择 Jolt Physics，并启用独立 3D 物理线程。
- Player 使用 `CharacterBody3D`；可推记忆石使用 `RigidBody3D`。
- 配重板是 `Area3D`，只有符合组别与质量逻辑的石块进入后才完成机关。
- 视觉湖面不承担碰撞；水体碰撞使用简化形状。
- 非活动时相的 `CollisionObject3D` 被禁用，避免隔着时相发生物理交互。

自动物理测试真实施加推动冲量并完成配重机关，最近一次结果：

```text
JOLT_PHYSICS_TEST_OK displacement=16.979 affected=1 stack_peak=1.042
final_speed=1.448 counterweight=solved
```

## 8. 章节与剧情状态

流送由剧情阶段驱动，但不拥有剧情判断。campaign v7 的 17 个稳定阶段为：

```text
intro → find_bell → gather_memories → awaken_shrine → memory_alignment
→ rift_ready → archive_search → archive_mechanisms → archive_restored
→ city_gate → lantern_city → city_relays → city_council
→ rain_eye → rain_eye_trials → final_decision → complete
```

`NarrativeDirector` 决定何时请求城市／雨眼，`Main` 连接具体场景与事件，
`WorldStreamer` 只负责资源生命周期。存档恢复会先重建剧情状态，再加载目标章节与双时相，
不会依赖上次运行中的临时 Node。

## 9. 过场与跳过

`CinematicDirector` 使用镜头段字典驱动位置、观察点、时长、FOV、字幕和结束事件。
过场期间 Player 输入被锁定；跳过与自然播放共享同一个幂等结束路径，因此不会漏发剧情
事件或重复推进。章节 CG 结束后摄像机平滑交回玩家。

## 10. 已验证验收项

- 线程请求未完成时不调用阻塞取回。
- 两时相未就绪时无法切换。
- 连续 **100 次**时相切换后，关卡实例数不增长。
- LRU 驱逐后 WorldStreamer 不保留 PackedScene 强引用。
- 延迟释放帧后旧 Node 消失；相同路径可再次异步加载。
- 城市进入雨眼后完整关卡常驻数恢复为 2。
- 门户离屏停更，活动预览层随时相正确反转。
- CG 跳过和自然完成得到同一剧情结果。
- Forward+、Vulkan、Jolt 与独立物理线程均在目标 Linux 设备实际运行。

仍需在真实 Windows 机器验证驱动差异、Alt-Tab／全屏恢复、手柄热插拔以及长时间章节往返。

# 测试与验收规范

版本：0.6.2-alpha
最近全量回归：2026-08-10

## 一键回归

```bash
bash /home/cenkai/game_dev_plan/tools/run_regression.sh
```

通过标志：

```text
REGRESSION_OK tests=24
```

真实 Vulkan 视觉复验：

```bash
DISPLAY=:1 /home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --path /home/cenkai/game_dev_plan/game \
  --script res://tests/capture_surface_validation.gd
```

4K 材质与湖面离屏复验（每次只跑一个镜头以控制显存峰值）：

```bash
DISPLAY=:1 CAPTURE_RESOLUTION=3840x2160 CAPTURE_ONLY=ground \
  /home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --path /home/cenkai/game_dev_plan/game \
  --script res://tests/capture_surface_validation.gd
```

将 `CAPTURE_ONLY` 改为 `wet_mud`、`tree` 或 `lake` 可分别验证湿泥、树木和湖面（水花）；脚本
会断言输出 PNG 必须为 3840×2160。该命令验证 4K Vulkan 渲染目标，不替代原生 4K 桌面帧时。

原生 4K X11 窗口复验（先用 `xrandr` 将 `DISPLAY=:1` 的输出切到 3840×2160；完成后恢复原分辨率）：

```bash
DISPLAY=:1 CAPTURE_NATIVE=1 CAPTURE_RESOLUTION=3840x2160 CAPTURE_ONLY=lake \
  /home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --path /home/cenkai/game_dev_plan/game \
  --script res://tests/capture_surface_validation.gd
```

该入口直接读取 3840×2160 X11 窗口，不使用 SubViewport；当前 Renoir 结果已记录在
`VISUAL_VALIDATION_REPORT.md`，不代表实体 4K 面板或 Windows 驱动。

地面、泥滩、树皮、湖面、水花、脚印和角色动作的前后截图哈希见
`VISUAL_VALIDATION_REPORT.md`；截图目录 `previews/` 不进入 Git。

Godot 编辑器级解析检查：

```bash
/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --headless --path /home/cenkai/game_dev_plan/game --editor --quit
```

## 24 项自动化覆盖

| 测试 | 主要验收 |
|---|---|
| `environment_capability_test.gd` | Forward+ 环境能力与关键效果属性 |
| `environment_geometry_test.gd` | 65×65 地形、54 棵树、15 个岸石碰撞、16,000 草簇与椭圆湖面 |
| `realistic_character_import_test.gd` | 14 网格、53 骨、39,840 三角面、14 材质、7 套动画、19 条骨骼轨道 |
| `player_import_test.gd` | 角色场景和 7 套动画资源可导入 |
| `player_animation_test.gd` | Idle/Walk/Run/Jump/Fall/Land/Interact 状态、写实材质和动画相位脚步事件 |
| `movement_regression_test.gd` | 平滑加速、步行／冲刺速度、跳跃／坠落／落地状态和回到 Idle |
| `save_service_test.gd` | schema v2、原子替换、备份恢复、v1 迁移 |
| `smoke_test.gd` | 主场景、角色、神龛、风铃和异步 Echo 加载 |
| `world_streamer_test.gd` | LRU 驱逐、缓存忽略、释放后重新加载 |
| `jolt_physics_test.gd` | 独立线程、连续碰撞、刚体冲量、档案配重机关 |
| `cinematic_director_test.gd` | 过场开始、字幕、跳过和结束恢复 |
| `interactive_water_test.gd` | 空中移动无脚步波纹、入水／出水状态、扩散环与水滴效果 |
| `material_library_test.gd` | 6 个 MaterialProfile `.tres` 映射、6 张 PBR 贴图完整性、扫描 CC0 运行资源和表面摩擦关系 |
| `surface_interaction_test.gd` | SurfaceProbe、PhysicsMaterial、脚印池、坡面法线双脚 IK、32 槽水纹事件接口 |
| `runtime_teardown_test.gd` | shutdown 后网格、MultiMesh、粒子、WorldEnvironment、PhaseShift 查询/节点引用和 Cinematic Tween 引用解绑 |
| `presentation_test.gd` | PBR 套装、粒子图集和程序音频 |
| `quality_settings_test.gd` | 三档画质、默认高画质和暂停菜单 |
| `input_regression_test.gd` | 真实 Escape、暂停中真实鼠标点击、画质按钮和真实 E 交互 |
| `phase_shift_test.gd` | 100 次往返、层掩码、碰撞隔离、单实例常驻 |
| `portal_preview_test.gd` | 640×360 反相门户、更新节流 |
| `lantern_city_level_test.gd` | 双时相桥、列车、16 刚体、3 残响、4 回路、2 证词 |
| `rain_eye_level_test.gd` | 7 段道路、14 刚体、3 印记、3 试炼、3 结局 |
| `narrative_finale_test.gd` | 三结局、潮汐门槛、campaign v6 与旧档迁移 |
| `gameplay_test.gd` | 从真实附近风铃交互到潮汐结局、章节流送、保存和完成态恢复 |

## 关键通过结果

- 完整主线：`stage=complete`。
- 档案机关：3/3，其中配重由真实 Jolt 刚体触发。
- 城市残响：3/3；行灯回路：4/4；证词分支：2 选 1。
- 雨眼印记：3/3；共振试炼：3/3。
- 结局：合流、守界、潮汐均可到达；潮汐错误条件会被拒绝。
- 正常流送：`resident_levels=2`、`resident_limit=2`。
- 100 次时相切换后只保留一份 Echo 关卡实例。
- 存档：主档损坏时成功恢复上一备份。

## 性能测试规则

纯 `--headless` 会把 Godot 4.7 降为 64×64 且 Draw Call 为 0，此结果只能作为 CPU 冒烟，
不得用于 GPU 验收。
正式性能数据必须同时满足：

1. 日志明确显示 `Vulkan ... Forward+` 和目标 GPU；
2. 基线必须为 `actual_resolution=[1280,720]`；原生 4K 探针必须为
   `actual_resolution=[3840,2160]`（同时保留 `requested_resolution`）；
3. Draw calls 和 primitives 大于 0；
4. Vulkan surface 无创建失败；
5. 明确指定并在结果中记录高画质或性能档；
6. 结果必须包含 `render_scale`，并保存原始 JSON；高画质默认 1.0，均衡/性能默认 0.77/0.59。

结果中的 `measurement_mode` 必须为 `real_vulkan` 才能进入性能报告；
`headless_cpu_smoke` 只证明测试脚本和资源加载可完成。

入口：

```text
game/tests/performance_test.gd
game/tests/performance_chapters_test.gd
```

原生 4K 高画质性能探针：

```bash
DISPLAY=:1 PERFORMANCE_RESOLUTION=3840x2160 \
  /home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --path /home/cenkai/game_dev_plan/game \
  --script res://tests/performance_test.gd
```

性能档 FSR 比例可用 `LUMINOUS_RENDER_SCALE=0.5` 或 `--render-scale=0.5` 临时覆盖；覆盖结果应
使用 `PERFORMANCE_OUTPUT=/absolute/path/result.json` 另存，不能覆盖默认高画质 4K 证据。

## Windows 包验收

Windows ZIP 发布前必须满足：

- 使用 Godot 4.7.1 官方 `windows_release_x86_64.exe` 模板。
- `file` 识别为 PE32+ x86-64 GUI executable。
- EXE 与 PCK 都存在，PCK 不是旧开发包。
- PCK 在 Linux 同版本 Godot 中通过 `--release-smoke`，确认版本、campaign v6、默认高画质
  和 Echo Ruins 异步加载；24 项完整回归在未过滤的工程目录单独执行。
- ZIP 可无错误列出与解压。
- 生成 SHA-256 清单和构建清单。
- 不包含 `tests/`、`.godot/`、Blender 源文件和开发工具。
- 在真实 Windows 10/11 上进行最终启动、输入、保存、全屏和退出验收。

## 人工验收清单

- 键鼠和 Xbox 布局分别走完至少一次主线。
- 每个时相切换点检查玩家不会落入无碰撞区域。
- 三个画质档各切换三次，场景灯光和 UI 不丢失。
- 城市移动列车不把玩家永久卡入建筑。
- 推石至少从三个角度可完成，压力板反馈清楚。
- 暂停时物理、粒子逻辑和剧情计时停止，恢复后控制正常。
- 断电式测试：保存过程中终止进程，下一次仍能读取主档或备份。

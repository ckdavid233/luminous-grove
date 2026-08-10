# Luminous Grove: The Name of Rain

版本：0.6.2-alpha
中文名：《微光林地：雨的名字》  
引擎：Godot 4.7.1 Stable

这是一条可从开场走到三种结局的第三人称 3D 叙事冒险 alpha。当前版本包含四幕、
双时相即时切换、物理配重、顺序回路、分支证词、异步关卡流送、实时镜头、写实角色、
三档画质和可靠存档。关卡仍是紧凑 alpha，设计目标 60–90 分钟尚未经过外部玩家计时，
不等同于 3.5–5 小时商业成品。

## Windows 玩家运行

发行目录：

```text
/home/cenkai/game_dev_plan/releases/LuminousGrove-Windows-x86_64-v0.6.2/
```

ZIP 解压后必须把以下两个文件放在同一目录：

```text
LuminousGrove.exe
LuminousGrove.pck
```

双击 `LuminousGrove.exe`。这是 64 位便携版，没有安装器、自动更新或代码签名。首次运行
若 Windows SmartScreen 提示未知发布者，应只从自己校验过 SHA256 的包继续。0.6.1 基线包已
完成官方模板导出、PE32+ 静态识别和 PCK 运行自检；0.6.2 精细化资产与目标引导已重新导出，
但没有 Windows/Wine，真实 Windows 驱动、全屏和手柄热插拔仍需在目标机验证。

详细说明见 `../WINDOWS_BUILD_AND_RELEASE.md`。

## Linux／编辑器运行

```bash
/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --path /home/cenkai/game_dev_plan/game
```

Godot 编辑器可直接打开：

```text
/home/cenkai/game_dev_plan/game/project.godot
```

默认渲染器是 Vulkan Forward+，项目显式使用 Jolt Physics。低于目标能力的驱动或无 Vulkan
环境没有作为当前 Release 支持范围验证。

## 操作

| 动作 | 键鼠 | Xbox／通用手柄 |
|---|---|---|
| 移动 | `WASD`／方向键 | 左摇杆 |
| 观察 | 鼠标 | 右摇杆 |
| 冲刺 | `Shift` | `LB` |
| 跳跃 | `Space` | `A` |
| 交互 | `E` | `X` |
| 切换此岸／雨忆 | `Q` | `Y` |
| 跳过过场 | `Enter` | `B` |
| 暂停／返回 | `Esc` | `Start` |
| 快速保存／加载 | `F5` / `F9` | 暂停菜单可保存 |
| 释放／重新捕获鼠标 | `M` | — |

雨隙能力需要先推进林地与神龛教学。冲刺消耗体力；掉出关卡会回到最近交互、切换或
章节检查点。

HUD 会在屏幕边缘显示当前目标与距离，跨时相目标会随关卡流送和时相切换更新；这只是导航提示，
不会替代交互距离、碰撞或剧情门控。

## 主线

```text
微光林地：风铃 → 3 枚湖忆 → 神龛对齐 → 林地选择
沉雨档案馆：3 锚点 → 倒影 → Jolt 配重 → 铭名透镜
行灯之城：3 城市踪迹 → 4 盏交替行灯 → 朔的证词
雨眼：3 封印 → 3 段交替试炼 → 三种终局
```

合流与守界始终可选；潮汐结局要求林地选择 `return_to_lake`，并在城市证词中选择
`trust_shuo`。存档 campaign 版本为 6，旧短战役状态会迁移到合法新阶段。

## 画质与存档

- 默认高画质：SSR、SSAO、SSIL、SDFGI、体积雾、Glow、45 米阴影。
- 平衡：保留 SSR、SSAO 与体积雾，关闭 SSIL/SDFGI，缩短阴影。
- 性能：关闭 SSR、SSAO、SSIL、SDFGI、体积雾和高成本角色材质，降低草量与阴影距离。
- 暂停菜单可切换画质和全屏；设置保存在 `user://settings.cfg`。
- 存档为 schema v2，包含位置、旋转、剧情、世界状态、版本与时间戳。
- 写入先验证临时文件，再替换主档；损坏时可尝试上一份备份。

## 自动验证

完整 24 项回归：

```bash
/home/cenkai/game_dev_plan/tools/run_regression.sh
```

快速冒烟：

```bash
/home/cenkai/game_dev_plan/tools/run_smoke_test.sh
```

导出 PCK 自检：

```bash
/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --headless \
  --main-pack /home/cenkai/game_dev_plan/releases/LuminousGrove-Windows-x86_64-v0.6.2/LuminousGrove.pck \
  -- --release-smoke
```

成功标志：

```text
RELEASE_SMOKE_OK build=0.6.2-alpha campaign=7 quality=high echo_async=ready
```

## 本机林地基准

Ryzen 5 PRO 4650U / 15 GiB / Renoir 集显，1280×720、真实 X11/Vulkan 表面：

- 当前高画质（原生 1.00）：8.4 FPS，P95 121.219 ms（画面验收档）。
- 当前均衡（FSR 0.77）：13.3 FPS，P95 78.047 ms。
- 当前性能档（FSR 0.59）：29.3 FPS，P95 36.994 ms（接近但尚未达到 30 FPS P95 预算）。
- 可选动态分辨率默认关闭；启动时加入 `--dynamic-resolution` 或设置
  `LUMINOUS_DYNAMIC_RESOLUTION=1` 可让 FSR 3D 缩放按帧时在 0.35–当前档位基线之间调节。
- 0.6.0 章节参考：行灯之城 14.3–14.4 FPS，雨眼 31.2–32.0 FPS；本次林地重构后未重跑。
- 城市进入雨眼后完整关卡常驻数为 2。

完整方法和原始 JSON 见 `../PERFORMANCE_REPORT.md`。纯 `--headless` 的 64×64 零 Draw call
结果无效，不用于宣传性能。

## 工程入口

- 主场景：`game/main/main.tscn`
- 主协调器：`game/main/main.gd`
- 剧情真相源：`game/narrative/narrative_director.gd`
- Player：`game/player/player.gd`
- 流送器：`core/world_streamer/world_streamer.gd`
- 存档：`core/save/save_service.gd`
- 测试：`tests/`
- Windows 导出：`export_presets.cfg`

## 文档

- `../DOCUMENTATION_INDEX.md`
- `../GAMEPLAY_AND_CONTROLS.md`
- `../NARRATIVE_DESIGN.md`
- `../TECHNICAL_DESIGN.md`
- `../TESTING_AND_ACCEPTANCE.md`
- `../PERFORMANCE_REPORT.md`
- `../WINDOWS_BUILD_AND_RELEASE.md`

# 《微光林地：雨的名字》目标设备性能报告

版本：0.6.2-alpha
测量日期：2026-08-09
引擎：Godot 4.7.1 Stable  
渲染路径：Vulkan Forward+

本轮复验记录：2026-08-10。代码已新增 MaterialProfile、动画脚步、刚体水体反馈和植被局部
弯曲，但当前容器只有 TTY；Vulkan 可枚举到 `AMD Unknown (RADV RENOIR)`，无法创建 Wayland/X11
surface。尝试启动临时 Xorg 时返回 `parse_vt_settings: Cannot open /dev/tty0 (Permission denied)`，
因此本轮没有伪造新的 GPU 帧时或截图。

## 1. 结论

这台设备可以完成 Godot 开发、Blender 资产处理和完整战役运行。最近一次有效的
1280×720 真实 Vulkan 基线中，高画质档为 13.8 FPS，性能档为 38.8 FPS。高画质用于
画面验收；Renoir 集显实际游玩应选择性能档，当前没有 60 FPS 结论。

本次林地湖区材质、视觉、光照与交互改造已经完成代码和资源接入，但当前执行容器没有可用的
Wayland/X11 显示表面，无法重新取得 GPU 帧时。因此下表的真实 Vulkan 数字保持为改造前的
可复验基线，不能宣称已经达到计划中的高质量 P95 ≤ 41.7 ms；必须在有显示设备的目标机上重跑。

三档画质已经接入运行时。章节表保留历史参考数据，并明确不冒充本次材质改造后的重测结果。

本轮实际接入的高质量项还包括：扫描 PBR 的 AO/Cavity/Height 映射、湖面/神龛反射探针、32 槽
水纹事件、脚印池、双脚 IK、浅水刚体浮力/阻力和角色/刚体近场植被弯曲。它们的 GPU 成本必须
在有显示 surface 的设备上重新测量。

## 2. 实测设备

| 项目 | 实测值 |
|---|---|
| CPU | AMD Ryzen 5 PRO 4650U，6 核 12 线程 |
| 内存 | 15 GiB 可见内存 |
| GPU | AMD Renoir 集成显卡，设备 ID `1002:1636` |
| Vulkan | 1.3.255 |
| 驱动 | Mesa RADV 23.2.1 |
| 系统 | Ubuntu 22.04.5 LTS，Linux 6.8 |
| 测试分辨率 | 1280×720 |

Renoir 使用共享系统内存。`Performance.RENDER_VIDEO_MEM_USED` 是 Godot 的渲染资源
监视值，并不等于一张独立显卡的专用显存占用；这里保留原始值，供同机版本间比较。

## 3. 高画质档内容

- PhysicalSky、Filmic 色调映射和 Glow。
- SSR、SSAO、SSIL、SDFGI 与体积雾。
- 45 米阴影范围。
- 湖面折射、Fresnel、焦散和岸边泡沫。
- 写实人物皮肤 SSS、眼睛 Clearcoat 和头发各向异性。
- 640×360 另一时相门户预览。
- Jolt 物理与独立 3D 物理线程。

这是画质优先档，不是自动动态分辨率档。暂停菜单可切换“高画质／平衡／性能”，设置
会保存到 `user://settings.cfg`。

## 4. 有效测量方法

纯 `--headless` 环境会退化为 64×64、零 Draw call，不能代表实际 GPU 表现，因此结果只
记录为 CPU 冒烟，不得用于 GPU 验收。有效基线使用 Weston headless 的真实 Wayland/Vulkan
表面，让 Forward+、材质、门户和屏幕空间效果真正参与渲染；本轮容器没有该显示表面。

林地基准：

1. 加载主场景并进入默认高画质档。
2. 预热 60 帧。
3. 连续采样 600 个 `process_frame` 间隔。
4. 记录平均帧时间、P95、P99、Draw calls、Primitives 和渲染资源监视值。

章节基准：

1. 异步加载行灯之城双时相。
2. 每个时相预热 45 帧并采样 240 帧。
3. 异步进入雨眼，确认城市双场景已被驱逐。
4. 以相同方式测试雨眼双时相，并验证完整关卡常驻上限仍为 2。

测试入口：

```text
game/tests/performance_test.gd
game/tests/performance_chapters_test.gd
```

机器可读原始结果（`measurement_mode` 标识有效 Vulkan 或 headless 冒烟）：

```text
/home/cenkai/game_dev_plan/performance_runtime.json
/home/cenkai/game_dev_plan/performance_runtime_balanced.json
/home/cenkai/game_dev_plan/performance_runtime_performance.json
/home/cenkai/game_dev_plan/performance_chapters.json
```

## 5. 结果

### 最近一次有效真实 Vulkan 基线（材质改造前）

| 指标 | 高画质 | 性能 |
|---|---:|---:|
| 样本帧 | 600 | 600 |
| 平均 FPS | 13.8 | 38.8 |
| 平均帧时间 | 72.384 ms | 25.782 ms |
| P95 | 73.491 ms | 26.820 ms |
| P99 | 75.468 ms | 27.165 ms |
| Draw calls | 397 | 247 |
| Primitives | 5,715,718 | 495,760 |
| 渲染资源监视值 | 1,254,167,456 bytes | 773,468,464 bytes |

### 本轮改造后的 headless CPU 冒烟（无效 GPU 指标）

| 档位 | 实际分辨率 | 平均帧时间 | P95 | Draw calls | GPU 指标 |
|---|---:|---:|---:|---:|---|
| 高 | 64×64 | 6.900 ms | 7.526 ms | 0 | 不可用 |
| 均衡 | 64×64 | 6.900 ms | 7.499 ms | 0 | 不可用 |
| 性能 | 64×64 | 6.900 ms | 7.637 ms | 0 | 不可用 |

这三行只用于确认测试脚本、画质切换和资源加载没有卡死；由于渲染退化，不能与上面的
1280×720 Vulkan 帧时直接比较。

### 0.6.0 行灯之城与雨眼参考（0.6.1 未重跑）

| 场景 | FPS | 平均帧 | P95 | P99 | Draw calls | Primitives | 渲染资源 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 城·此岸 | 14.3 | 69.997 ms | 92.319 ms | 99.005 ms | 598 | 119,860 | 1,771,865,344 B |
| 城·雨忆 | 14.4 | 69.385 ms | 78.897 ms | 80.464 ms | 576 | 65,970 | 1,771,865,344 B |
| 雨眼·此岸 | 31.2 | 32.092 ms | 42.630 ms | 43.258 ms | 407 | 348,200 | 1,772,439,824 B |
| 雨眼·雨忆 | 32.0 | 31.220 ms | 40.516 ms | 40.763 ms | 188 | 227,486 | 1,772,439,824 B |

章节测试结束状态：

```text
resident_levels = 2
resident_limit = 2
renderer = forward_plus
resolution = 1280×720
```

## 6. 解读与瓶颈

- 行灯之城是最重场景；独立建筑构件、灯光、湿地反射、体积雾和门户共同提高了
  Draw calls，不能只用三角面数解释性能。
- 雨眼的 Primitives 较多但对象和材质批次数较低，因此帧率明显高于城市。
- 现有真实 Vulkan 基线中的高画质 primitives 已经较高；本轮又加入扫描 PBR、反射探针、
  32 槽水纹和脚印池，必须重新捕获后才能判断增量成本。
- 性能档关闭屏幕空间／全局光／体积雾和高成本角色材质，减少草量与阴影，达到
  38.8 FPS，且 P99 维持在 27.165 ms。
- 城市进入雨眼后完整关卡实例回到 2，说明异步流送与 LRU 驱逐没有随章节累计实例。
- P95/P99 是当前最重要的流畅度指标；城市此岸 P99 约 99 ms，仍存在肉眼可见卡顿。

## 7. 当前优化顺序

在不破坏高画质档的前提下，优先处理：

1. 城市场景静态合批或 MultiMesh，降低 598 次 Draw call。
2. 门户按距离进一步降低更新频率，并为性能档降低内部渲染比例。
3. 为城市灯光、角色 SSS 和复杂材质建立距离 LOD。
4. 在有显示表面的设备上补齐平衡档同规格基准，并为性能档继续建立 30 FPS 帧时间预算。
5. 在真实 Windows AMD、NVIDIA、Intel 三类机器上记录帧时间、驱动版本和崩溃日志。
6. 以 30 FPS 为这台集显的性能档现实目标；高端独显再验证 60 FPS。

## 8. 可复验边界

- 结果只代表上述 Linux/Mesa/Renoir 设备，不代表 Windows 驱动或独立显卡。
- Windows Release 已完成官方模板导出和 PCK 等价自检，但当前设备没有 Windows/Wine，
  因此性能表不能作为 Windows 可执行文件的实机帧率。
- 每次修改材质、灯光、门户分辨率、角色网格或场景构件后，都应重新生成两份 JSON，
  并在文档中保留测量日期与版本。

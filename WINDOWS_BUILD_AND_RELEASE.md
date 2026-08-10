# 《微光林地：雨的名字》Windows 构建与发行

版本：0.6.2-alpha
构建日期：2026-08-10
目标：64 位 Windows 便携 Release

## 1. 可交付物

目录版：

```text
/home/cenkai/game_dev_plan/releases/LuminousGrove-Windows-x86_64-v0.6.2/
```

压缩包：

```text
/home/cenkai/game_dev_plan/releases/LuminousGrove-Windows-x86_64-v0.6.2.zip
```

最终 ZIP：

```text
size: 576,041,003 bytes
SHA256: 5c4c4e1d5271044e74b93125cfdfc0463d98f9906d5803c1c7064a3faf2a00f2
integrity: unzip -t passed, 4 entries, no errors
```

目录中的核心文件：

| 文件 | 用途 | 大小 |
|---|---|---:|
| `LuminousGrove.exe` | Godot 4.7.1 Windows x86_64 Release 程序 | 109,071,872 bytes |
| `LuminousGrove.pck` | 游戏脚本、场景、模型、贴图与音频资源 | 538,714,448 bytes |
| `README.txt` | 玩家启动、操作与故障排除 | 随包 |
| `BUILD_MANIFEST.txt` | 构建来源、验证结果与核心文件哈希 | 随包 |

EXE 与 PCK 必须保持同目录。当前是免安装便携包，没有安装器、卸载器、自动更新、
云存档或代码签名。

## 2. 玩家运行

1. 在 Windows 上完整解压 ZIP，不要直接在压缩软件预览中运行。
2. 确认 `LuminousGrove.exe` 与 `LuminousGrove.pck` 在同一目录。
3. 双击 `LuminousGrove.exe`。
4. 首次启动进入默认高画质；若帧率低，按 `Esc` 打开暂停菜单并切换平衡／性能档。

建议验证目标为 Windows 10/11 64 位、带当前 Vulkan 驱动的 AMD／NVIDIA／Intel GPU。
本项目使用 Forward+，没有为不支持 Vulkan 的旧驱动建立 Compatibility 渲染发行版。
Godot 官方当前要求与平台说明可查阅
[System requirements](https://docs.godotengine.org/en/4.7/about/system_requirements.html)。

## 3. 当前已完成验证

- 官方 Godot 4.7.1 Windows x86_64 Release 模板按 ZIP 成员 CRC 提取成功。
- 导出命令退出码为 0。
- `file` 将 EXE 识别为 `PE32+ executable (GUI) x86-64`。
- Linux 上用相同版本 Godot 直接加载导出的 PCK，得到：

```text
RELEASE_SMOKE_OK build=0.6.2-alpha campaign=6 quality=high echo_async=ready
```

- 自检覆盖主场景启动、campaign v6、默认高画质和 Echo Ruins 异步加载。
- 工程侧 24 项回归还覆盖真实输入、移动状态、水体边界、环境几何与碰撞。
- 本次 PCK 包含 ObjectiveGuide 目标距离提示；脚本回归会隐藏 HUD 引导并验证每个主线阶段都有可解析目标。
- ZIP 已通过 `unzip -t` 完整性检查，4 个条目无错误；SHA256 已写入同名 `.sha256` 文件。
- 本轮 teardown 清理逻辑更新后重新导出的 PCK 为 538,714,448 bytes，SHA-256 为
  `205c26f8ed7bc46a1f0926ef8634c128808dd87510b72363e45da5bbe8fe655f`。

PCK 自检证明导出的游戏数据与脚本可由 4.7.1 运行时读取；它不等于执行 Windows EXE。
release smoke 会忽略开发者用户存档，从林地基线验证 Echo Ruins 异步加载，并在成功标志后直接
结束探针进程。源码和导出 PCK headless 自检仍可能出现 1 个通用 Godot ObjectDB 清理警告，真实
Vulkan 运行还观察到纹理 RID 泄漏；这些是尚未关闭的技术债，不能等同于零泄漏。
当前设备没有 Windows 或 Wine，因此不能声称已经完成真实 Windows 启动、驱动、全屏、
音频、手柄热插拔和 SmartScreen 测试。

## 4. Windows 实机最终验收

在公开分发前，至少在一台真实 Windows 10/11 x64 机器完成：

1. 从 ZIP 解压并双击启动，无缺失 DLL／PCK 错误。
2. 新游戏完成风铃、一次交互、跳跃、冲刺与雨隙切换。
3. `Esc` 暂停、三档画质、窗口／全屏切换正常。
4. `F5` 保存、退出、重启、`F9` 加载位置和任务一致。
5. 键鼠与 Xbox 手柄各完成一轮输入；测试断开／重连。
6. 从林地进入城市和雨眼，确认异步加载没有永久卡住。
7. 至少完成一个结局；如验证潮汐结局，先归还湖水并信任朔。
8. 在 AMD、NVIDIA、Intel 中至少覆盖两类 GPU；记录驱动、分辨率、画质档和帧时间。
9. Alt-Tab、最小化恢复、显示器缩放和退出后进程结束正常。
10. 把崩溃日志、截图和用户数据目录位置写入测试记录。

## 5. 模板来源

官方版本入口：

- [Godot 4.7.1 Stable 下载归档](https://godotengine.org/download/archive/4.7.1-stable/)
- [Godot 导出项目文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)

模板来源对象：

```text
https://godot-releases.nbg1.your-objectstorage.com/4.7.1-stable/
Godot_v4.7.1-stable_export_templates.tpz
```

为了避免下载 TPZ 中与本次无关的所有平台模板，工程脚本读取官方 ZIP 中央目录并只用
HTTP Range 提取：

```text
templates/windows_release_x86_64.exe
templates/version.txt
```

提取器：

```text
/home/cenkai/game_dev_plan/tools/fetch_godot_template_member.py
```

本机模板记录：

```text
/home/cenkai/.local/share/godot/export_templates/4.7.1.stable/windows_release_x86_64.exe
size: 109,212,160 bytes
CRC32: 53055154
SHA256: 76269a403bb832599edeee4432a5b7a7e88c018eb5c9c798dfd8289359b0ec07
```

Range 提取不是修改模板；脚本会验证未压缩大小和官方 TPZ 成员 CRC 后才原子替换目标。

## 6. 可重复构建

先运行完整回归：

```bash
/home/cenkai/game_dev_plan/tools/run_regression.sh
```

如模板不存在，提取 Windows Release 成员：

```bash
python3 /home/cenkai/game_dev_plan/tools/fetch_godot_template_member.py \
  --output-dir /home/cenkai/.local/share/godot/export_templates/4.7.1.stable
```

导出：

```bash
/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --headless \
  --path /home/cenkai/game_dev_plan/game \
  --export-release "Windows x86_64 Release" \
  /home/cenkai/game_dev_plan/releases/LuminousGrove-Windows-x86_64-v0.6.2/LuminousGrove.exe
```

PCK 等价自检：

```bash
/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --headless \
  --main-pack /home/cenkai/game_dev_plan/releases/LuminousGrove-Windows-x86_64-v0.6.2/LuminousGrove.pck \
  -- --release-smoke
```

导出过滤器会排除自动测试、工程工具、源美术、早期 Spirit Child 占位角色和未使用的
地表源图和未使用的旧植物图集；运行时使用的写实人物与正式关卡不会被排除。过滤器位于
`game/export_presets.cfg`，修改后必须重新跑 PCK 自检。

## 7. 发布安全与版本策略

- 对外提供 ZIP 时同时提供 SHA256，用户应校验完整包而不是只校验 EXE。
- 未签名 alpha 只适合受控测试；公开商用前应购买代码签名证书或使用可信发行平台。
- 存档 schema 为 2、campaign 为 6；改动稳定 ID 时必须提供迁移测试。
- `0.6.2-alpha` 的版本号、文件说明和产品名已经写入 Windows 导出预设。
- 新素材只有在来源、条款和运行时导入全部通过后才能进入下一包。
- 发布包不应包含 `tests/`、构建脚本、Blend 源文件、提示词原图或用户私有素材记录。

# 林地湖区实机视觉验证报告

验证日期：2026-08-10
工程版本：0.6.2-alpha
引擎：Godot 4.7.1 Stable，Vulkan Forward+
显示表面：`DISPLAY=:1` / X11 VNC-0（1600×900，60 Hz）
GPU：AMD Ryzen 5 PRO 4650U Renoir 集成显卡，RADV，Vulkan 1.3.255
常规截图视口：1280×720

这次验证是真实 Vulkan 渲染，不是 `--headless` CPU 冒烟。常规前后对比使用 X11 表面可见的
1280×720 窗口；另通过真实 Vulkan `SubViewport` 完成了不依赖桌面尺寸的 3840×2160 离屏截图，
并在 X11 VNC 临时 3840×2160 mode 上完成了原生窗口湖面截图。实体 4K 显示器和 Windows 驱动
仍需单独复测。

## 复验命令

```text
env DISPLAY=:1 godot --path game --script res://tests/capture_forest_detail.gd
env DISPLAY=:1 godot --path game --script res://tests/capture_water.gd
env DISPLAY=:1 godot --path game --script res://tests/capture_surface_validation.gd
env DISPLAY=:1 CAPTURE_RESOLUTION=3840x2160 CAPTURE_ONLY=ground godot --path game --script res://tests/capture_surface_validation.gd
env DISPLAY=:1 CAPTURE_RESOLUTION=3840x2160 CAPTURE_ONLY=wet_mud godot --path game --script res://tests/capture_surface_validation.gd
env DISPLAY=:1 CAPTURE_RESOLUTION=3840x2160 CAPTURE_ONLY=tree godot --path game --script res://tests/capture_surface_validation.gd
env DISPLAY=:1 CAPTURE_RESOLUTION=3840x2160 CAPTURE_ONLY=lake godot --path game --script res://tests/capture_surface_validation.gd
# 先将 DISPLAY=:1 的输出切换到 3840×2160，再运行原生窗口验证：
env DISPLAY=:1 CAPTURE_NATIVE=1 CAPTURE_RESOLUTION=3840x2160 CAPTURE_ONLY=lake godot --path game --script res://tests/capture_surface_validation.gd
```

`CAPTURE_RESOLUTION=3840x2160` 会把主场景放入独立的 Vulkan `SubViewport`，并在保存 PNG 前断言
实际图像尺寸；`CAPTURE_ONLY` 用于降低一次验证的显存峰值。该路径不是把 1280×720 图片放大。
`CAPTURE_NATIVE=1` 会跳过 SubViewport，直接从当前 X11 窗口读取，调用者必须先提供 3840×2160
显示 mode。

`before_*` 图片来自精细化提交前的 `d95f417` 临时工作树，使用相同的 Vulkan 相机脚本和
机位；`after_*` 图片来自当前精细化工作树。截图目录 `previews/` 被 `.gitignore` 忽略，
本报告保存路径、尺寸、SHA-256 和复验条件，避免把大量二进制截图塞进源码仓库。

## 前后对比证据

| 项目 | 改造前 | 改造后 | 验证重点 |
|---|---|---|---|
| 林地地面 | `previews/before_ground.png`<br>`SHA-256 4de1b9896b56e17c989858a1c3d9613a8e72c49f0f322393f78a6bb8b5ac0d27` | `previews/after_ground.png`<br>`SHA-256 31a04fb3308ae5d07c2bd3d4c449d3c8608ce18a54aa23a7541b30461932bbe7` | 扫描 Albedo/Normal/AO/Height、宏观色彩、湿润和近景细节 |
| 湖岸湿泥 | `previews/before_wet_mud.png`<br>`SHA-256 f93f1501a9eafce2bc0895572288666983e7b8fbe41ea49fd2022e114cfd3385` | `previews/after_wet_mud.png`<br>`SHA-256 c93b0e65a68b04a37af5d081182972e72ebeeb2158dd493b477abcd30ef5a4d5` | 湿泥过渡、湖石扫描材质、浅水边缘与泡沫 |
| 树皮/树冠 | `previews/before_forest_tree_detail.png`<br>`SHA-256 0c31d1c3a29d230d9980a33fdf8dd9e1cd20cb7c4902c88fc517de5250caca16` | `previews/forest_tree_detail.png`<br>`SHA-256 864d4534bc9868e2b4d8e1bf340a7ddc52823cfceca1290b1ab7e08ecaa4fb34` | Pine Bark PBR、叶片软风动、近景树干法线 |
| 湖面 | `previews/before_realistic_lake.png`<br>`SHA-256 03bdea4f5874da360861ade2cc2fd88bb1cbae5d80a7b72cbf680630c74945e5` | `previews/realistic_lake.png`<br>`SHA-256 1baad159a102e169d8a35de0dfbf82d448cdaf915af8f2f9517f3748fb09a0ea` | 双层法线、Fresnel、深度吸收、湿润粗糙度、反射探针 |
| 入水/落水水花 | `previews/before_realistic_lake_splash.png`<br>`SHA-256 f66443ec0d859a48df44b269b1e47b756f3d5ca5061a450f82248e23c1e4fc13` | `previews/realistic_lake_splash.png`<br>`SHA-256 2db90456496c628d26cb89939cdcc9eb4ffa3bfb119155533b156bbbbb132243` | 三层扩散环、池化水滴；改造后截图已清楚看到水纹事件 |
| 脚印空场 | `previews/before_footprints_before.png`<br>`SHA-256 03bedb91633b3dabfe62c5f3050249e393b6df9161bdab5c6fe83a379157f7f8` | `previews/after_footprints_before.png`<br>`SHA-256 aadcff648ff4da5e059764998541e64faf56f58d450c4b0f871882cd013cd628` | 同一机位的无脚印基准 |
| 脚印反馈 | `previews/before_footprints_after.png`<br>`SHA-256 c52f6dd0177382b7a2c695f0ca5061ca53155dae5b2bd480b30364a557337938` | `previews/after_footprints_after.png`<br>`SHA-256 4a5a5f7fe93fa12d672c874b2235ef07ca4ed6c0bf0cd37c7acfd05a867daa05` | 新增脚印池；改造后使用平滑 Alpha 和脚尖/足弓/脚跟轮廓 |
| 角色交互动作 | `previews/before_character_clean.png`<br>`SHA-256 761ea57362836f59b7c415b50f408f1bebdad9e0dd6076d94b4f4d14cec6d3a7` | `previews/after_character_clean.png`<br>`SHA-256 818d5200466446c1ae536530982191aaa3c289a3499bf98ab8d4dfae251243a3` | 无 UI 干扰的 Interact 姿态、角色材质与脚部落地关系 |

> 注：脚印“改造前”来自旧工作树（当时没有 `FootprintPool`，两张图均为空场）；这组证据明确
> 表示“功能从无到有”。脚印纹理本身是运行时 96×160 程序纹理，不是外部图片素材。

## 3840×2160 Vulkan 离屏证据

以下文件由同一台 Renoir 设备的真实 Vulkan `SubViewport` 生成，`file` 检查均为
`PNG image data, 3840 x 2160, 8-bit/color RGB`。它们证明 4K 目标尺寸、扫描材质、湖石和水面
事件可以在运行时完成渲染；由于不是原生 4K 桌面，不能替代原生桌面帧时验收。

| 镜头 | 文件 | SHA-256 |
|---|---|---|
| 地面 | `previews/after_ground_4k.png` | `9e27e61e48cdfabb2012eda9daa754a18357b9f2a591c5ddd4b34b7a06776c10` |
| 湿泥 | `previews/after_wet_mud_4k.png` | `230b7c6136b120168f3a20e9adff79c6ac6d6c511a251710a3be605ab3a9931b` |
| 树皮/树冠 | `previews/after_tree_detail_4k.png` | `8cb5833106f3b8929c79891fa9bb5ee6c04ee76683e51a2c0dbc7d6aeeaeaf86` |
| 湖面 | `previews/after_lake_4k.png` | `09db4b5643bb2e85d9494e195f1b4ee0ca984cfef1ebde1e300de5eb7c3b25c1` |
| 湖面水花 | `previews/after_lake_splash_4k.png` | `fb37eb138e575f3ba9030054365e51fa4f2cf7518fed83138a886f22cb668550` |
| 角色动作 | `previews/after_character_clean_4k.png` | `5ee50a151722298485ed4398df435a5d671d35b129653d350dffc5cd344bd6b6` |

### 2026-08-10 相机清理后带前缀复验

为验证 `CAPTURE_PREFIX` 不会吞掉 `CAPTURE_ONLY`，本轮使用独立前缀逐镜头运行 4K Vulkan
SubViewport；每个进程都输出 `SURFACE_VALIDATION_CAPTURE_OK`、`size=(3840, 2160)`，并确认
设备为 AMD Renoir Forward+。截图目录仍被 Git 忽略，以下哈希作为可复验索引：

| 镜头 | 文件 | SHA-256 |
|---|---|---|
| 地面 | `previews/goal_ground_ground_4k.png` | `b23aa6ba8108e463d72226592d0a4e2c706bc062e427130ee9e96fb7f30f9c6e` |
| 湿泥 | `previews/goal4k_wet_mud_wet_mud_4k.png` | `1b3284f9c40b5e07d1ac6fad6515e82bc18fd06da1ca189b59220ad326635549` |
| 树皮/树冠 | `previews/goal4k_tree_tree_detail_4k.png` | `84c55211a61f32b0d37019f045e136f54f9fb884e95ec356c1f1eeac46ad31f5` |
| 湖面 | `previews/goal4k_lake_lake_4k.png` | `e6e5b4fe07daba6e2946a5c954601d14ddb0e4108a390640337fcadc3652c3fd` |
| 湖面水花 | `previews/goal4k_lake_lake_splash_4k.png` | `837b183ebbc3bb7ceb995cfb08f38fd4fa566ee5230613fca4e5f1c65cf99eba` |
| 脚印空场 | `previews/goal4k_footprints_footprints_before_4k.png` | `e423fd63c6dc133824031f2ea71aa9e72eb4e7024f060e76ec6508a34b995984` |
| 脚印反馈 | `previews/goal4k_footprints_footprints_after_4k.png` | `2b0df46a588d2dc37b5638c37d2965bb184204b6627cc0c4643c56f713b041b7` |
| 角色动作 | `previews/goal4k_character_character_clean_4k.png` | `1cf86120300313aa55af7b6d58fdfaf2440b11adb2dc58b02bdc0e32d926cb55` |

这组复验只证明 4K 目标和材质/事件路径确实在真实 Vulkan 设备上渲染，不等同于实体 4K
桌面性能。随后追加的 `teardown_probe`（同一 Vulkan 设备、1280×720 与 4K 均复测）确认
退出时序调整可以偶尔消掉 ObjectDB，但不能稳定消除 7 个 Texture RID；1280×720 复测仍出现
`7 Texture + 1 ObjectDB`，因此零泄漏验收保持未通过。

### 2026-08-10 退出时序定向拆分

为避免把渲染器 transient buffer 误判成项目引用，本轮在同一 `DISPLAY=:1` Renoir Vulkan 设备上
用临时探针拆分了根窗口、验证相机、`Main.shutdown()`、`queue_free()` 和独立 `SubViewport`：
不主动触发场景 teardown 的根窗口探针可干净退出；加入验证相机或在同帧执行 `shutdown()`/释放
视口时，会重新出现 7 个 Texture RID，ObjectDB 数量则随 SubViewport 所有权和退出顺序在 0–2
之间变化。延迟等待或改用立即 `free()` 都没有在正式截图路径上稳定消除告警，因此本轮没有把
未经证实的退出改动合入运行时代码，零泄漏仍保留为待在 Windows/实体 4K 与 Godot 内存检查下
完成的验收项。探针文件已删除，工作树没有测试残留。

删除探针后完整 `./tools/run_regression.sh` 重新通过 `REGRESSION_OK tests=24`；日志中仍有少量
通用 ObjectDB 清理提示，但没有 `SCRIPT ERROR` 或解析错误。验证结束后用户存档已恢复到基准
SHA-256：`f2b6348d80f1106784a3f4eda3a4686654c921fc7fee87656553f74858aeb997`。

### 2026-08-10 目标引导接入后的 4K 湖面复验

目标引导与流程目标断言接入后，重新用真实 Vulkan Renoir Forward+ 输出湖面和水花；两张图均为
 `3840×2160`，并输出 `SURFACE_VALIDATION_CAPTURE_OK`。引导在 `--script` 捕获模式下自动隐藏，
因此不会污染材质前后对比画面：

| 镜头 | 文件 | SHA-256 |
|---|---|---|
| 湖面 | `previews/objectiveguide4k_lake_4k.png` | `431bd9177eb631bb33bab31a40b37c66df02a61b9024f55bc96db48b618ff081` |
| 湖面水花 | `previews/objectiveguide4k_lake_splash_4k.png` | `767e8f6a5e2944fa35d53598cb7e8a2b65a8557f4f7cae0a019ed3d07370d360` |

同一份最终源码在最后一次 `CAPTURE_PREFIX=objectiveguide_final4k` 复验中再次输出
`SURFACE_VALIDATION_CAPTURE_OK`；当前证据哈希为：

| 镜头 | 文件 | SHA-256 |
|---|---|---|
| 湖面 | `previews/objectiveguide_final4k_lake_4k.png` | `b0758f8f0e01d4f6348928bbbf90cfa3cb33c29d38ef71615ed27e29f2a50b16` |
| 湖面水花 | `previews/objectiveguide_final4k_lake_splash_4k.png` | `a8827a6ec6330f0512955dc678eba7a59fc6c3d65a29e89fb34aacbe53eb5a5c` |

### 2026-08-10 条件式 HUD 引导后的最新 4K 湖面复验

在 `b92a6aa` 的当前源码上重新运行 `CAPTURE_PREFIX=postconditional4k`、
`CAPTURE_RESOLUTION=3840x2160`、`CAPTURE_ONLY=lake`。日志再次确认真实设备为
`Vulkan 1.3.255 - Forward+ - AMD RADV RENOIR`，并输出 `SURFACE_VALIDATION_CAPTURE_OK`；
两张 PNG 均通过 `file` 的 3840×2160、8-bit RGB 校验：

| 镜头 | 文件 | SHA-256 |
|---|---|---|
| 湖面 | `previews/postconditional4k_lake_4k.png` | `811541c08beb57bfd9b2396589bd76267523c3d50ceb11a47815b8ce602ebb41` |
| 湖面水花 | `previews/postconditional4k_lake_splash_4k.png` | `215410f144e351ef271611162bd84241b7dc337a1632bf5dc1fe71b5813bf2d6` |

该次捕获仍出现 7 个 Texture RID 与 1 个通用 ObjectDB 清理提示，因此新增截图证明
当前源码的湖面、反射、水花与 4K 材质路径没有回退，但不改变零泄漏未通过的结论。

### 2026-08-10 门户同步释放后的 4K 复验

在门户预览 SubViewport、环形子树和测试相机增加同步/显式释放后，重新运行同一真实 Vulkan
湖面捕获。两张 PNG 仍为 3840×2160、8-bit RGB，画面路径没有回退：

| 镜头 | 文件 | SHA-256 |
|---|---|---|
| 湖面 | `previews/portalshutdown4k_lake_4k.png` | `ab8cd1503dca0f0069fb8e42419f2c2628f31d3aaa0c3f86609f241559039430` |
| 湖面水花 | `previews/portalshutdown4k_lake_splash_4k.png` | `92e3e61d77c9f570c4839ea17c65da84ce6314e2554a6d4b94ae0664c019d563` |

该版本在 `runtime_teardown_test` 与 `portal_preview_test` 中确认门户子树会被释放，但 4K
SubViewport 退出仍报告 7 个 Texture RID 与 1 个通用 ObjectDB；这部分仍需实体 Windows/4K
设备与 Godot 内存检查进一步区分引擎 transient buffer 和项目引用，不能宣称零泄漏。

### 2026-08-10 门户 ViewportTexture 解绑顺序修复后的 4K 复验

本轮把 `RainRiftPortal.shutdown()` 的顺序调整为先清空 `alternate_texture`、QuadMesh 材质和
预览相机，再释放 SubViewport，并在 `portal_preview_test.gd` 增加解绑断言。使用同一台真实
Vulkan Renoir Forward+ 设备执行：

```text
DISPLAY=:1 CAPTURE_PREFIX=portalfix4k CAPTURE_RESOLUTION=3840x2160 CAPTURE_ONLY=lake \
  Godot_v4.7.1-stable_linux.x86_64 --path game --script res://tests/capture_surface_validation.gd
```

两张图通过 3840×2160、8-bit RGB 校验；本次捕获日志只剩 7 个 Texture RID，没有再出现通用
ObjectDB 行，说明项目门户引用解绑得到改善，但可见门户/其他退出时序仍需实体 Windows/4K
内存检查，不能据此宣称零泄漏：

| 镜头 | 文件 | SHA-256 |
|---|---|---|
| 湖面 | `previews/portalfix4k_lake_4k.png` | `1007cb8284bcd81b54056cefc32c2ba126c83f10c2245144bb8233fcb1150fd3` |
| 湖面水花 | `previews/portalfix4k_lake_splash_4k.png` | `50d237fa0c9b8252ba32f450f2ea9e95846ee59757ad5d36e7baa540c27c7686` |

### 2026-08-10 Main/Player 查询清理后的 4K 复验

本轮新增 Main/Player 退出前的 process、physics、IK、交互查询和 SurfaceProbe 清理，并在
WorldStreamer/EchoRuins 解绑 MeshInstance3D surface override 后，用同一真实 Vulkan Renoir
Forward+ 设备重新捕获湖面：

```text
DISPLAY=:1 CAPTURE_PREFIX=playershutdown4k CAPTURE_RESOLUTION=3840x2160 CAPTURE_ONLY=lake \
  Godot_v4.7.1-stable_linux.x86_64 --path game --script res://tests/capture_surface_validation.gd
```

图片均通过 `3840×2160`、8-bit RGB 校验；视觉路径没有回退，但日志仍报告 7 个 Texture RID 与
1 个 ObjectDB，因此只能证明查询/材质解绑改动未破坏实机渲染，不能宣称零泄漏：

| 镜头 | 文件 | SHA-256 |
|---|---|---|
| 湖面 | `previews/playershutdown4k_lake_4k.png` | `abdace0eb27bbdc7907b4aa289468e26ae9a43058241afa15b480d7f44cb51c1` |
| 湖面水花 | `previews/playershutdown4k_lake_splash_4k.png` | `0fa3051744b673de70032d4b42655e91a32178f2cf41f79ea99644a4666ca23a` |

### Profile 映射后的湖面复验

在显式 `MaterialProfile` 接入地表 Shader 后，重新用真实 Vulkan `SubViewport` 单独捕获地面、湿泥、
树木和湖面；所有 PNG 均通过 `file` 校验为 3840×2160 RGB，证明 profile 贴图映射没有让材质或
湖面/水花路径回退：

| 镜头 | 文件 | SHA-256 |
|---|---|---|
| 地面 | `previews/finalprofile_ground_4k.png` | `1b8d87cfeb461a826c6abdc9099d217f2231b128714618226f3f0a4478afe0a7` |
| 湿泥 | `previews/finalprofile_wet_mud_4k.png` | `4a7d887e5c4cfbf8d56b5126cf331b85258f1beb69060aca436b7a3f97c66eef` |
| 树皮/树冠 | `previews/finalprofile_tree_detail_4k.png` | `45eae1363d94c5e568a724632c68b07dd904bf32f67bd0a50e9a813329a5efd7` |
| 湖面 | `previews/finalprofile_lake_4k.png` | `a24b21bdf2c244dba1f329d4b408f8398600257548507463a6d536f58217d1bc` |
| 湖面水花 | `previews/finalprofile_lake_splash_4k.png` | `50b0ab3b2debb4e8e2e226ab3994b378b2f19fb682322b6b9df1d5a9355210d5` |
| 脚印空场 | `previews/finalprofile_footprints_before_4k.png` | `5b4029a091a444bd468bdffc2bc74248a620654a3308184acae7a728459c4683` |
| 脚印反馈 | `previews/finalprofile_footprints_after_4k.png` | `32c8498765c9acece80764e266354b8a92a5faff9aa3c2e2017dbcd2ebf8b707` |
| 角色动作 | `previews/finalprofile_character_clean_4k.png` | `251512d2b00fc3586d61c02d1692d4a505a2534a93d1e3d80f49850c0692dcf2` |

本轮显式 shutdown 与资源缓存释放改动后，湖面单镜头再次在同一真实 Vulkan SubViewport 复验：
`previews/postshutdown_lake_4k.png`，尺寸 3840×2160，SHA-256 为
`063cae2ce3ed10f6879f53da13eb255557e029061a87a0d414b8a05abf6ad988`。该复验保持湖面反射和
水纹路径有效；退出时仍报告 7 个 Texture RID 与 1 个通用 RefCounted，不能视为零泄漏。

控制器 teardown 补丁后重新用 `DISPLAY=:1` 的 Renoir Vulkan Forward+ 捕获地面和湖面；相机清理
改为 `clear_current(false)` 后，普通 1280×720 单镜头不再稳定复现旧的 7 个 Texture RID，但
退出时序、`--verbose` 或 4K SubViewport 仍可能出现 Texture RID/通用 ObjectDB。4K 湖面当前
截图为 `after_lake_4k.png`/`after_lake_splash_4k.png`，仍需将这些提示与 Godot 渲染器资源释放
进一步区分。

本轮又将地面旧版 PBR fallback 改为按需加载，并把 Echo Ruins 材质解绑接入 WorldStreamer 卸载；
最新 `CAPTURE_ONLY=ground` 真实 Vulkan 记录仍为 `Vulkan 1.3.255 - Forward+ - AMD RADV RENOIR`，
截图成功，但不同退出时序仍会出现通用 ObjectDB 或 Texture RID。该结果已保留在
`/tmp/luminous-grove-camera-vulkan-probe.log`，所以当前报告继续把零泄漏列为未完成验收。

在加入 `Main._release_runtime_references()` 后重新执行同一 4K 湖面离屏捕获（历史记录）：
`previews/postteardown_lake_4k.png`，尺寸 3840×2160，SHA-256 为
`76399e976f1d48339cd848c46e87e46c2895592c42957cb77fa1d534a2cd248d`。截图和 Vulkan 渲染均通过，
但当时 Godot 退出时仍报告 7 个 Texture RID 与 1 个 ObjectDB 实例；运行时引用解绑已覆盖主要节点，
剩余引擎资源仍需内存检查确认。相机 `clear_current(false)` 修复后的新结果见上方，告警会随退出
时序变化，不能把历史数字当成当前固定值。

## 3840×2160 X11 原生窗口证据

在同一 AMD Renoir Vulkan 设备上临时将 `VNC-0` 切到 3840×2160 mode，使用
`CAPTURE_NATIVE=1` 直接捕获湖面：

| 镜头 | 文件 | SHA-256 | 说明 |
|---|---|---|---|
| 湖面 | `previews/native4k_lake_4k.png` | `9bab7007c090701d167eab3407822b28196507406f1e0d9126358c5997787c8e` | `actual_resolution=3840×2160`, Forward+ |

## 视觉结论与剩余项

- 地面、泥滩、树皮、湖面和角色动作均已在真实 Vulkan 表面完成同机位前后对比。
- 水花最初截图不可见，原因是波面深度写入遮住了低位环；现已把环抬到波峰上方并加入低强度
  自发光，截图可复现三层环和水滴。
- 4K runtime 贴图、3840×2160 Vulkan 离屏目标和 X11 原生窗口湖面截图均已确认加载并输出；
  实体 4K 显示设备、Windows 驱动和高质量帧时仍需最终验收。
- 角色起步、急停、转身、面部表演和坡面 IK 的艺术资产仍是后续内容；运行时坡面法线对齐已由
  `surface_interaction_test.gd` 覆盖，不应以当前 Interact 单帧截图宣称表演资产全部完成。
- 历史截图脚本退出时曾看到 7 个 Godot Texture RID 和 1 个通用 RefCounted 清理提示；当前已补
  `Camera3D.clear_current(false)` 的前后两阶段清理，但不同退出时序、4K SubViewport 和渲染器
  仍可能报告 Texture RID/ObjectDB，尚未定位到全部资源的退出时序，不能宣称“零泄漏”。

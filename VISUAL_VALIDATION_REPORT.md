# 林地湖区实机视觉验证报告

验证日期：2026-08-10
工程版本：0.6.2-alpha
引擎：Godot 4.7.1 Stable，Vulkan Forward+
显示表面：`DISPLAY=:1` / X11 VNC-0（1600×900，60 Hz）
GPU：AMD Ryzen 5 PRO 4650U Renoir 集成显卡，RADV，Vulkan 1.3.255
截图视口：1280×720

这次验证是真实 Vulkan 渲染，不是 `--headless` CPU 冒烟。画面采样使用项目运行时的 4K
扫描贴图；截图视口受当前 X11 表面限制为 1280×720，因此“4K 纹理已加载并参与渲染”已验证，
“3840×2160 输出与 4K 帧时”仍需在原生 4K 显示设备上复测。

## 复验命令

```text
env DISPLAY=:1 godot --path game --script res://tests/capture_forest_detail.gd
env DISPLAY=:1 godot --path game --script res://tests/capture_water.gd
env DISPLAY=:1 godot --path game --script res://tests/capture_surface_validation.gd
```

`before_*` 图片来自精细化提交前的 `d95f417` 临时工作树，使用相同的 Vulkan 相机脚本和
机位；`after_*` 图片来自当前精细化工作树。截图目录 `previews/` 被 `.gitignore` 忽略，
本报告保存路径、尺寸、SHA-256 和复验条件，避免把大量二进制截图塞进源码仓库。

## 前后对比证据

| 项目 | 改造前 | 改造后 | 验证重点 |
|---|---|---|---|
| 林地地面 | `previews/before_ground.png`<br>`SHA-256 4de1b9896b56e17c989858a1c3d9613a8e72c49f0f322393f78a6bb8b5ac0d27` | `previews/after_ground.png`<br>`SHA-256 532de97fa44ed296dd85eda84d8464f6a87fda55863e3363eb8d1d185f713e70` | 扫描 Albedo/Normal/AO/Height、宏观色彩、湿润和近景细节 |
| 湖岸湿泥 | `previews/before_wet_mud.png`<br>`SHA-256 f93f1501a9eafce2bc0895572288666983e7b8fbe41ea49fd2022e114cfd3385` | `previews/after_wet_mud.png`<br>`SHA-256 c93b0e65a68b04a37af5d081182972e72ebeeb2158dd493b477abcd30ef5a4d5` | 湿泥过渡、湖石扫描材质、浅水边缘与泡沫 |
| 树皮/树冠 | `previews/before_forest_tree_detail.png`<br>`SHA-256 0c31d1c3a29d230d9980a33fdf8dd9e1cd20cb7c4902c88fc517de5250caca16` | `previews/forest_tree_detail.png`<br>`SHA-256 864d4534bc9868e2b4d8e1bf340a7ddc52823cfceca1290b1ab7e08ecaa4fb34` | Pine Bark PBR、叶片软风动、近景树干法线 |
| 湖面 | `previews/before_realistic_lake.png`<br>`SHA-256 03bdea4f5874da360861ade2cc2fd88bb1cbae5d80a7b72cbf680630c74945e5` | `previews/realistic_lake.png`<br>`SHA-256 1baad159a102e169d8a35de0dfbf82d448cdaf915af8f2f9517f3748fb09a0ea` | 双层法线、Fresnel、深度吸收、湿润粗糙度、反射探针 |
| 入水/落水水花 | `previews/before_realistic_lake_splash.png`<br>`SHA-256 f66443ec0d859a48df44b269b1e47b756f3d5ca5061a450f82248e23c1e4fc13` | `previews/realistic_lake_splash.png`<br>`SHA-256 2db90456496c628d26cb89939cdcc9eb4ffa3bfb119155533b156bbbbb132243` | 三层扩散环、池化水滴；改造后截图已清楚看到水纹事件 |
| 脚印空场 | `previews/before_footprints_before.png`<br>`SHA-256 03bedb91633b3dabfe62c5f3050249e393b6df9161bdab5c6fe83a379157f7f8` | `previews/after_footprints_before.png`<br>`SHA-256 aadcff648ff4da5e059764998541e64faf56f58d450c4b0f871882cd013cd628` | 同一机位的无脚印基准 |
| 脚印反馈 | `previews/before_footprints_after.png`<br>`SHA-256 c52f6dd0177382b7a2c695f0ca5061ca53155dae5b2bd480b30364a557337938` | `previews/after_footprints_after.png`<br>`SHA-256 4a5a5f7fe93fa12d672c874b2235ef07ca4ed6c0bf0cd37c7acfd05a867daa05` | 新增脚印池；改造后使用平滑 Alpha 和脚尖/足弓/脚跟轮廓 |
| 角色交互动作 | `previews/before_character_clean.png`<br>`SHA-256 761ea57362836f59b7c415b50f408f1bebdad9e0dd6076d94b4f4d14cec6d3a7` | `previews/after_character_clean.png`<br>`SHA-256 818d5200466446c1ae536530982191aaa3c289a3499bf98ab8d4dfae251243a3` | 无 UI 干扰的 Interact 姿态、角色材质与脚部落地关系 |

> 注：脚印“改造前”来自旧工作树（当时没有 `FootprintPool`，两张图均为空场）；这组证据明确
> 表示“功能从无到有”。脚印纹理本身是运行时 96×160 程序纹理，不是外部图片素材。

## 视觉结论与剩余项

- 地面、泥滩、树皮、湖面和角色动作均已在真实 Vulkan 表面完成同机位前后对比。
- 水花最初截图不可见，原因是波面深度写入遮住了低位环；现已把环抬到波峰上方并加入低强度
  自发光，截图可复现三层环和水滴。
- 4K runtime 贴图已确认加载；当前视口不是 4K，需在 3840×2160 显示设备上完成最终验收。
- 角色起步、急停、转身、面部表演和坡面 IK 的艺术资产仍是后续内容，不应以当前 Interact
  单帧截图宣称全部完成。
- 截图脚本退出时仍会看到少量 Godot Texture RID 清理提示；完整流程功能通过，但需要后续
  用 Godot 内存检查继续定位 RefCounted/渲染资源的退出时序。

# Godot 4 高级视觉特效调研与采用记录

版本：0.6.2-alpha
调研快照：2026-07-30  
目标引擎：Godot 4.7.1

## 1. 当前采用结论

发行工程没有直接复制下列第三方水体或后期插件。当前高画质栈使用 Godot 原生
Forward+ 能力与项目内 Shader，避免同时引入多套互相争抢深度、屏幕纹理和调色的
实现。外部项目仅作为技术参考；真正复制代码前必须重新核对 Commit、许可证和 4.7.1
兼容性。

已接入：

- PhysicalSkyMaterial。
- SSR、SSAO、SSIL、SDFGI。
- 体积雾、Filmic 色调映射和克制 Glow。
- 项目内湖泊 Shader：多层波浪、深度吸收、折射、Fresnel、焦散和泡沫。
- 门户 SubViewport、记忆微光粒子和雨滴／水面反馈。
- 三档质量开关，高画质为默认档。

未接入：FFT 海洋、第三方体积云、全屏色差包、递归门户和插件式后处理栈。

## 2. 水体候选

| 项目 | 主要技术 | 许可证／目标版本快照 | 本项目判断 |
|---|---|---|---|
| [2Retr0/GodotOceanWaves](https://github.com/2Retr0/GodotOceanWaves) | GPU Compute FFT、波谱、白沫和海雾 | 仓库标示 MIT；面向 Godot 4.x | 适合开放海洋，林地小湖暂不引入 |
| [tessarakkt/godot4-oceanfft](https://github.com/tessarakkt/godot4-oceanfft) | Tessendorf FFT、Compute Shader、浮力 | 仓库标示 MIT；开发分支变化较快 | 技术强但集成与集显成本高，保留研究 |
| [LesusX/Water-Shader](https://github.com/LesusX/Water-Shader) | Gerstner 波、深度着色、折射、焦散和泡沫 | 仓库标示 MIT；调研时面向 Godot 4.5 | 功能组合最接近湖泊，仅参考思路 |
| [antzGames/Godot-Foam-Water](https://github.com/antzGames/Godot-Foam-Water) | 噪声波、双法线、深度折射和岸边泡沫 | 仓库标示 MIT；调研时说明测试于 4.6.1 | 可作为较轻水体与泡沫兼容参考 |
| [sjb8100/godot-WaterPack](https://github.com/sjb8100/godot-WaterPack) | Godot 3 时代水体包 | 仓库标示 MIT；旧渲染接口 | 排除，不为 4.7.1 迁移旧管线 |

Stars、最后推送日期等指标变化很快，不再写入权威设计文档；选型以代码、许可证、目标
版本和目标设备实测为准。

## 3. 其他候选

| 项目 | 技术 | 判断 |
|---|---|---|
| [ArseniyMirniy/Godot-4-Color-Correction-and-Screen-Effects](https://github.com/ArseniyMirniy/Godot-4-Color-Correction-and-Screen-Effects) | 调色、暗角、色差、Panini 等 | 可参考调色组织；默认不启用色差和重暗角 |
| [MangoButtermilch/Godot-volumetric-renderer](https://github.com/MangoButtermilch/Godot-volumetric-renderer) | Raymarch 体积云／星云 | 与原生体积雾叠加成本高，暂不接入 |
| [MythicalLight/GodotVolumetricClouds](https://github.com/MythicalLight/GodotVolumetricClouds) | Godot 4 体积云 | 目标设备收益不足，暂不接入 |

这些链接是研究入口，不代表它们的代码已包含在发行包，也不构成对持续兼容性的保证。

## 4. 项目内湖泊实现

当前湖面针对封闭林地和剧情镜头，不模拟开放海洋：

- 四层不同方向、波长和低幅度的顶点波。
- 几何法线结合微表面法线涟漪。
- 深度缓冲重建与 Beer–Lambert 风格的深浅吸收。
- 屏幕空间折射和距离受限的模糊。
- 浅水焦散、岸边深度泡沫和少量波峰泡沫。
- Fresnel 反射与物理粗糙度。
- 独立简化碰撞／交互区域；视觉水面不充当物理碰撞。

SSR 无法反射屏幕外物体，因此主线信息不能只靠倒影表达。所有关键机关同时有空间位置、
发光、提示文字或声音反馈。

## 5. 门户与时相特效

- 另一时相由 640×360 SubViewport 渲染，不使用递归门户。
- 视锥外停更、远处降频，避免固定双倍渲染成本。
- 切换使用短时雨痕遮罩、色彩过渡和环境响应；不在切换帧同步读盘。
- 青色代表当前秩序，暖金代表保存记忆，潮汐结局只加入少量紫色中间态。
- 粒子图集仍使用工程占位资源，收到 `vfx_memory_motes_atlas.png` 和
  `vfx_rain_splash_atlas.png` 后再做正式切片与 Alpha 验证。

## 6. 性能与画质决策

当前 Renoir 集显的高画质实测显示，行灯之城约 14 FPS，是最需要优化的章节。后续优先
降低 Draw call、门户远距更新和灯光／材质复杂度，不先叠加体积云或另一套水体插件。

任何新特效必须回答三个问题：

1. 它是否改善主线焦点、时相辨识或关键情绪？
2. 它能否在高／平衡／性能档中明确降级或关闭？
3. 它是否在真实 Vulkan 表面而非无渲染 headless 环境通过帧时间测量？

## 7. 第三方接入规则

如果未来把外部实现放入正式工程，必须：

1. 固定仓库 URL 与 Commit SHA。
2. 保存当时的 LICENSE 与版权声明。
3. 记录修改点，不把参考思路误写成自研或反之。
4. 放入 `addons/` 或明确的 `third_party/` 目录。
5. 在 Godot 4.7.1 完成导入、运行、PCK 导出和目标平台测试。
6. 重新跑林地、城市和雨眼基准，比较 P95/P99 与渲染资源监视值。
7. 在发布清单中列出所有实际随包分发的第三方代码与资产。

当前 0.6.1-alpha 的 Windows 发布包不包含本页候选仓库的第三方源代码。

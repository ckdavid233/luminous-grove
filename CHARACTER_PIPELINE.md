# 写实角色管线

版本：0.6.1-alpha  
角色：霁（Ji）  
目标：在 Renoir 集成显卡可承受的范围内，建立可重复、可验证、可继续换装和重定向
动画的写实人形基础。

## 1. 当前资产

| 项目 | 当前结果 |
|---|---:|
| Blender 源文件 | `art_source/realistic_player/ji_realistic.blend` |
| Godot glTF | `game/content/characters/realistic_player/ji_realistic.glb` |
| GLB 大小 | 23,186,916 bytes |
| 网格 | 14 |
| Blender 源顶点 | 21,744 |
| Godot 导入三角面 | 39,840 |
| 骨骼 | 53 |
| 源动画 | Idle / Walk / Run / Jump / Fall / Land / Interact |
| 运行时状态 | Idle / Walk / Run / Jump / Fall / Land / Interact |
| 材质／表面 | 14；含身体、眼睛、头发、服装、鞋与旅行饰件 |

角色使用真实人体比例和游戏骨架。现阶段的衣服、脸型与发型是稳定工程占位，不是
最终美术定稿；收到用户角色设定图后，会在这个骨架和运行时材质框架上迭代。

## 2. 来源与许可记录

- MPFB 2.0.17，安装为 Blender 扩展 `bl_ext.user_default.mpfb`。
- MakeHuman System Assets 作为基础人体、眼睛、头发、衣服和身体部件来源。
- MakeHuman 官方将 System Assets 标为 CC0，可用于闭源游戏；发布项目时仍应保留
  本记录和原始下载哈希，方便资产审计。

本地归档：

```text
/home/cenkai/game_dev_research/mpfb2-latest.zip
SHA256 47725c9cf99a70a61d863319be6ec3ce9e29916bec5de95a22a34e9f10ca6db0

/home/cenkai/game_dev_research/makehuman_system_assets_cc0.zip
SHA256 b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107
```

权威说明：

- [MPFB 2.0.17 发布说明](https://static.makehumancommunity.org/mpfb/releases/release_2017.html)
- [MPFB 入门文档](https://static.makehumancommunity.org/mpfb/docs/getting_started.html)
- [MakeHuman System Assets / CC0](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html)
- [闭源游戏使用说明](https://static.makehumancommunity.org/mpfb/faq/use_in_closed_source.html)

用户之后提供的生成图片需在素材包 `manifest.csv` 中另行记录平台条款；概念图许可
不能自动替代 3D 模型、字体或音频的许可。

## 3. 确定性构建

入口：

```bash
/home/cenkai/game_dev_tools/blender/4.5.12/blender \
  --background \
  --python /home/cenkai/game_dev_plan/tools/build_realistic_character.py
```

脚本固定：

- 随机种子 `20260731`。
- 年轻、女性、东亚基础参数。
- 米制单位。
- `game_engine` 骨架。
- 高精度眼球、长发、眉毛、睫毛、牙齿、舌头。
- 一体式便装和鞋。
- 骨骼绑定的旅行腰带、斜挎带、记忆袋、扣件和雨纹饰件。
- 不使用细分修改器，烘焙身体变形和遮挡助手。
- 导出 Tangent、材质和所有 Action。

输出顺序：

1. MPFB 创建源人物。
2. 创建专用 Godot 导出副本。
3. 烘焙形态和修改器、删除 Helper。
4. 应用深青服装、黑发等美术定向。
5. 程序化建立 Idle、Walk、Run、Jump、Fall、Land、Interact Action。
6. 保存 `.blend`。
7. 导出单文件 `.glb`。
8. 渲染角色预览。

## 4. 动画

| 动画 | Blender 帧 | 24 FPS 时长 | 用途 |
|---|---:|---:|---|
| Idle | 1–48 | 2.00 s | 呼吸、脊柱和头部轻微摆动 |
| Walk | 1–24 | 1.00 s | 左右接触、经过和手臂反摆 |
| Run | 1–18 | 0.75 s | 更大的步幅、前倾和手臂驱动 |
| Jump | 1–20 | 0.83 s | 起跳收势与空中展开 |
| Fall | 1–24 | 1.00 s | 空中稳定和下落预备 |
| Land | 1–14 | 0.58 s | 冲击吸收与重心回正 |
| Interact | 1–42 | 1.75 s | 双手向前触碰记忆／机关 |

Godot 运行时新建 `AnimationTree` 状态机：

```text
Idle <-> Walk <-> Run
Idle/Walk/Run -> Jump -> Fall -> Land -> Idle
Idle/Walk/Run -> Interact -> Idle/Walk/Run
```

移动转场使用短交叉淡化。Idle、Walk、Run 与 Fall 在运行时循环；Jump、Land 和 Interact
由对应状态触发。7 个状态各自使用 GLB 中的独立 Action，不再用加速 Walk 伪装 Run。

当前动画没有 Root Motion，角色位移由 `CharacterBody3D` 驱动，因此时相切换和 Jolt
碰撞的速度状态不会受动画轨迹破坏。运行时速度为步行 5 m/s、冲刺 8 m/s；冲刺消耗
100 点体力并在短暂延迟后恢复。跌落到安全高度以下会回到最近检查点。

## 5. Godot 写实材质

`CharacterVisualQuality` 在实例化时为每个表面创建场景局部材质副本，避免修改 glTF
共享导入资源。

- 皮肤：SSS、Skin Mode、Transmittance、0.42–0.62 粗糙度限制。
- 眼睛：Clearcoat 0.72、低 Clearcoat Roughness。
- 头发：有 Tangent 时启用 Anisotropy，双面显示。
- 牙齿：较弱 Clearcoat。
- 舌头：轻量 SSS。
- 全部角色贴图：Linear + mipmap + anisotropic filtering。
- 项目全局 SSS 质量：3。

这套配置追求电影画质并接受较低 FPS，符合当前项目要求。面部近景定稿前不继续无上限
提升 SSS 或贴图尺寸。

## 6. 自动验证

```bash
/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --headless \
  --path /home/cenkai/game_dev_plan/game \
  --script res://tests/realistic_character_import_test.gd

/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64 \
  --headless \
  --path /home/cenkai/game_dev_plan/game \
  --script res://tests/player_animation_test.gd
```

验收项：

- 一个共享 Skeleton3D。
- 53 根指定骨骼，包含 Root、骨盆、脊柱、头、四肢。
- 14 个网格、14 个表面和 39,840 个导入三角面。
- 7 套独立动画，每套 14 条骨骼轨道且时长正确。
- AnimationTree 从 Idle 启动，并能进入 Walk、Run、Jump、Fall、Land、Interact。
- 腰带、斜挎带、记忆袋、扣件和雨纹饰件在 Run／Jump／Interact 中跟随骨架。
- 皮肤、眼睛、头发和牙齿分别命中运行时材质规则。

## 7. 已知缺口与下一步

收到 `USER_ASSET_PACKAGE_BRIEF.md` 中的角色设定后：

1. 先锁定霁的面部身份和服装轮廓。
2. 增加面部 BlendShape：眨眼、眉形、视线、基础口型和六种剧情表情。
3. 在现有独立 Run／Jump／Fall／Land 基础上增加起步、急停、左右转身、坡面适配和
   不同落差的着地变体。
4. 用 Godot Humanoid 骨架配置验证外部动作重定向。
5. 为近景建立面部 LOD；第三人称远景关闭高成本表情更新。

Godot 的人形重定向参考：

- [Retargeting 3D skeletons](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/retargeting_3d_skeletons.html)
- [SkeletonProfileHumanoid](https://docs.godotengine.org/en/latest/classes/class_skeletonprofilehumanoid.html)

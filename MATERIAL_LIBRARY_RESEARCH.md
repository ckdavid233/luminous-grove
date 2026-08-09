# 高精度材质库调研与接入方案

调研日期：2026-08-09  
适用工程：Godot 4.7.1 Forward+、Blender 4.5.12、Jolt Physics

## 结论

当前项目已经停止把 Albedo 亮度当作 Normal/Roughness 来源，运行时接入照片扫描 PBR，并在
Godot 中完成干土、湿泥、落叶苔藓三层地表混合。当前仓库已接入 4K runtime 贴图，8K 英雄
近景原包保持外置；下一步只在真实 Vulkan 捕获确认显存预算后启用 8K 特写。

接入证据：`game/game/world/material_profile.gd`、`game/game/world/surface_profile.gd`、
`game/content/materials/material_library.json`、`MATERIAL_LIBRARY_SOURCES.md`、
`MATERIAL_LIBRARY_SHA256.txt`、`game/tools/build_user_pbr.gd` 和材质完整性回归测试。

## 候选库

### 1. 首选：Poly Haven（CC0）

Poly Haven 的材质为照片扫描、无缝 PBR，提供 8K 级别和完整贴图，不需要注册，许可为 CC0：

- [Forest Ground 01](https://polyhaven.com/a/forrest_ground_01)：干草、落叶、枝条、苔藓土，
  适合林地主地表。
- [Mud Forest](https://polyhaven.com/a/mud_forest)：湿泥、压实土、落叶和木枝，适合湖边、
  雨后脚印区域。
- [Forest Leaves 02](https://polyhaven.com/a/forest_leaves_02)：厚落叶和苔藓覆盖，适合
  树下阴影层。
- [Pine Bark](https://polyhaven.com/a/pine_bark) 或 [Metasequoia Bark](https://polyhaven.com/a/metasequoia_bark)：
  替换当前程序化树皮。
- [Mossy Forest HDRI](https://polyhaven.com/a/mossy_forest)：作为 Blender 预览与 Godot 高画质
  环境光参考。

这些页面提供 Diffuse、Normal (GL)、Rough、AO/Rough/Metal 和 Displacement；Godot 使用
Normal (GL)，不要误用 DirectX Normal。Poly Haven 的[许可页](https://polyhaven.com/license)
确认资产按 CC0 发布。

### 2. 次选：ambientCG（CC0）

- [Ground 086](https://ambientcg.com/view?id=Ground086)：近期照片扫描，标签包含森林、土路、
  岩石，提供 1K–8K PBR 下载。
- [Ground 067](https://ambientcg.com/view?id=Ground067)：森林土、碎石和泥土的备用层。

ambientCG 全库按页面说明以 CC0 发布，适合补充岩石、泥、树皮和城市湿墙。其 8K PNG 包体积
很大，项目内建议保留 4K 运行时图和 8K 源文件。

### 3. 最高质量付费路线：Poliigon / Substance 3D Assets

- [Poliigon 免费和付费材质](https://www.poliigon.com/free)：适合树皮、湿石、布料、泥土等
  英雄材质；[许可说明](https://help.poliigon.com/en/articles/8749749-asset-use-licensing)
  允许将材质作为游戏等更大作品的一部分，个人、商业和团队许可范围不同，必须保存购买凭证。
- [Adobe Substance 3D Assets](https://www.adobe.com/products/substance3d/assets.html)：有大量可调
  参数材质，商业使用要求将资产嵌入更大的游戏作品，不能单独再分发；在 Substance 中烘焙成
  Godot 使用的 PBR 图，不把 SBSAR 当作 Godot 运行时依赖。

### 4. Quixel Megascans（仅从 Fab 当前许可取得）

[Fab 的 Forest Floor](https://www.fab.com/listings/dae56d09-862c-4f77-9e72-a41281c49633)
提供 Basecolor、Normal、AO、Cavity、Roughness、Gloss、Displacement 等扫描贴图。
[Fab Standard License](https://www.fab.com/eula?lang=en) 明确允许在兼容工具中使用，不局限于
Unreal，并允许将资产嵌入商业作品；但旧的 UE-only/Quixel Bridge 获取记录不能直接套用，
下载时必须保存 Fab 许可类型和订单/领取记录。

## 为什么当前材质显得假

- `game/tools/build_user_pbr.gd` 从 Albedo 亮度推导 Normal 与 Roughness，不是真实扫描数据。
- `game/shaders/forest_terrain.gdshader` 只采样 Albedo、Normal、Roughness，缺 AO、Cavity、
  Height 和湿润遮罩。
- 整片森林主要使用同一套地表，缺少干土、湿泥、落叶苔藓的物理尺度和坡度/水边混合。
- Height/Parallax 只能产生视觉深度，不能代替碰撞；真实地形仍必须由 HeightMapShape3D 或
  几何碰撞体提供。

## 后续接入顺序

1. 保持已登记的 Poly Haven 4K runtime，并保持 Normal(GL)、AO、Roughness、Cavity、Height
   的命名和导入约定；湖石已补齐 Mossy Rock 真实扫描来源。
2. Blender 中按真实尺寸检查地表约 2–3 m/材质单元、树皮按树干周长展开，替换前后做 4×4
   无缝与镜头闪烁检查。
3. 英雄镜头单独启用 8K 和深度视差；性能档继续使用 4K runtime、简化视差和较短阴影，不改变
   HeightMapShape3D 碰撞。
4. 在真实 Vulkan 表面重跑材质、湖面、湿润和反射探针的 P95/P99，更新性能报告和哈希清单。

## 物理真实性方案

Godot 项目已经在 `project.godot` 中启用 Jolt Physics；材质包不会自动带来物理真实性。
下一轮应保留 Jolt，并新增可测试的物理材质：土壤、湿木、岩石、金属和水面分别配置摩擦、
弹性、质量与阻尼。角色继续使用 CharacterBody3D 胶囊作为稳定控制体，刚体道具使用真实质量、
惯性和连续碰撞；若需要全身受力，再单独增加布料/摆件/布娃娃，而不是把主角直接改成不可控
的全刚体。

Godot 的 Height/Parallax 只改变光照和视差，不会修改物理形状；当前实现明确将视觉 Height
与独立 `HeightMapShape3D` 碰撞分开，并由环境几何和材质回归测试检查渲染/碰撞网格规格。

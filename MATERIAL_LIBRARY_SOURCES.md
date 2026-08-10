# 材质来源与入库清单

本文件是高分辨率原始材质的外置登记表。仓库只提交经过裁切、导入和验证的运行时资源；原始
8K/16K 包、订单凭证和 HDRI 源文件不直接进入 Git。

## 首轮林地湖区

| 运行 ID | 推荐来源 | 许可 | 运行规格 | 当前状态 |
|---|---|---|---|---|
| `forest_ground` | [Poly Haven Forest Ground 01](https://polyhaven.com/a/forrest_ground_01) | CC0 | 当前 4K runtime，8K source 外置 | 已下载并接入扫描 PBR |
| `forest_mud` | [Poly Haven Mud Forest](https://polyhaven.com/a/mud_forest) | CC0 | 当前 4K runtime，8K source 外置 | 已下载并接入扫描 PBR |
| `forest_leaves` | [Poly Haven Forest Leaves 02](https://polyhaven.com/a/forest_leaves_02) | CC0 | 当前 4K runtime，8K source 外置 | 已下载并接入扫描 PBR |
| `pine_bark` | [Poly Haven Pine Bark](https://polyhaven.com/a/pine_bark) | CC0 | 当前 4K runtime，8K source 外置 | 已下载并接入树皮 |
| `lake_stone` | [Poly Haven Mossy Rock](https://polyhaven.com/a/mossy_rock) | CC0 | 当前 4K runtime，8K source 外置 | 已下载并接入湖岸石 |
| `forest_hdr` | [Poly Haven Mossy Forest](https://polyhaven.com/a/mossy_forest) | CC0 | 4K tonemapped JPG runtime，原始 4K/16K HDR/EXR 外置 | 已转换并接入 PanoramaSkyMaterial |

英雄近景可选 [Fab Forest Floor](https://www.fab.com/listings/dae56d09-862c-4f77-9e72-a41281c49633)、
Poliigon 或 Substance 3D。使用前必须记录订单/领取凭证、版本、下载日期、SHA256 和对应的
[Fab Standard License](https://www.fab.com/eula?lang=en) 或供应商许可。

当前已下载运行贴图的逐文件校验和见 `MATERIAL_LIBRARY_SHA256.txt`。校验和覆盖仓库内的
4K runtime 文件，不代表外置的原始 8K 包；替换分辨率后必须重新生成该清单。

## HDRI 导入与运行格式（2026-08-10）

已从 Poly Haven 获取 Mossy Forest 4K HDR/EXR 源文件并在当前 Godot 4.7.1 Linux 构建中做过
`preload()` 验证；该构建对 `.hdr` 和 `.exr` 都报告 `no resource loaders (unrecognized file
extension)`。本轮保留原始 HDR/EXR 在外置资产盘，并使用同一 Poly Haven CC0 资产提供的
8K tonemapped JPG（下采样为 4096×2048）作为 Godot 支持的运行天空：
`game/content/environments/sky/mossy_forest_tonemapped_4k.jpg`。运行文件已写入
`MATERIAL_LIBRARY_SHA256.txt`，由 `Main._create_environment()` 的 `PanoramaSkyMaterial` 接入；
这解决了当前构建的格式阻塞，但 JPG 是色调映射版本，不等价于未裁剪 HDR 光照，最终高动态范围
版本仍需在具备 HDR/EXR 导入器的构建中复验。

运行图来源记录：
`https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Tonemapped%20JPG/mossy_forest.jpg`，
下载大小 11,070,548 bytes，下载源 SHA-256 为
`6c932e0ac44aba2e5374afbc00ee8a1aa780d32ac1e0bfefd710edb1f7258445`；运行下采样图的 SHA-256
为 `311b9a0e46c5cea8b81cac5440ba7efe33b975d3715b8677b979674b751b9511`。

运行时表面到 `MaterialProfile` 的显式映射位于 `game/content/materials/profiles/`：
`dry_soil.tres`、`wet_mud.tres`、`moss.tres`、`wood.tres`、`stone.tres` 和 `water.tres`。
前五套资源引用扫描 Albedo/Normal/Roughness/AO/Height，并引用对应的 Cavity 运行图；水面使用
程序化 Shader，因此 profile 保留物理、湿润和水纹标签而不伪造 PBR 贴图。

## 替换规则

每套 PBR 必须提供 `albedo`、OpenGL `normal`、`roughness`、`ao`；近景英雄材质再提供
`cavity` 和 `height`。当前本地贴图是可运行 fallback，`material_library.json` 已标记为
`installed_4k_cc0` 的目录已接入地表三层和湖岸石；8K 原包外置，替换分辨率后必须更新状态和 SHA256。

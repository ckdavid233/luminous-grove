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
| `forest_hdr` | [Poly Haven Mossy Forest](https://polyhaven.com/a/mossy_forest) | CC0 | 4K runtime，16K source | 待导入 |

英雄近景可选 [Fab Forest Floor](https://www.fab.com/listings/dae56d09-862c-4f77-9e72-a41281c49633)、
Poliigon 或 Substance 3D。使用前必须记录订单/领取凭证、版本、下载日期、SHA256 和对应的
[Fab Standard License](https://www.fab.com/eula?lang=en) 或供应商许可。

当前已下载运行贴图的逐文件校验和见 `MATERIAL_LIBRARY_SHA256.txt`。校验和覆盖仓库内的
4K runtime 文件，不代表外置的原始 8K 包；替换分辨率后必须重新生成该清单。

## HDRI 导入阻塞（2026-08-10）

已从 Poly Haven 获取 Mossy Forest 4K HDR/EXR 源文件并在当前 Godot 4.7.1 Linux 构建中做过
`preload()` 验证；该构建对 `.hdr` 和 `.exr` 都报告 `no resource loaders (unrecognized file
extension)`，因此本轮没有把未经验证的天空纹理提交到运行包，也没有用 SDR 截图冒充 HDRI 光照。
后续需要在项目允许的导入管线中转换为 Godot 支持的运行格式（或接入专用导入器），再记录实际
运行文件、许可、下载日期和 SHA-256，并重新完成高画质湖区捕获。

运行时表面到 `MaterialProfile` 的显式映射位于 `game/content/materials/profiles/`：
`dry_soil.tres`、`wet_mud.tres`、`moss.tres`、`wood.tres`、`stone.tres` 和 `water.tres`。
前五套资源引用扫描 Albedo/Normal/Roughness/AO/Height，并引用对应的 Cavity 运行图；水面使用
程序化 Shader，因此 profile 保留物理、湿润和水纹标签而不伪造 PBR 贴图。

## 替换规则

每套 PBR 必须提供 `albedo`、OpenGL `normal`、`roughness`、`ao`；近景英雄材质再提供
`cavity` 和 `height`。当前本地贴图是可运行 fallback，`material_library.json` 已标记为
`installed_4k_cc0` 的目录已接入地表三层和湖岸石；8K 原包外置，替换分辨率后必须更新状态和 SHA256。

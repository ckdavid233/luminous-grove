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
| `forest_hdr` | [Poly Haven Mossy Forest](https://polyhaven.com/a/mossy_forest) | CC0 | 4K runtime，16K source | 待下载 |

英雄近景可选 [Fab Forest Floor](https://www.fab.com/listings/dae56d09-862c-4f77-9e72-a41281c49633)、
Poliigon 或 Substance 3D。使用前必须记录订单/领取凭证、版本、下载日期、SHA256 和对应的
[Fab Standard License](https://www.fab.com/eula?lang=en) 或供应商许可。

当前已下载运行贴图的逐文件校验和见 `MATERIAL_LIBRARY_SHA256.txt`。校验和覆盖仓库内的
4K runtime 文件，不代表外置的原始 8K 包；替换分辨率后必须重新生成该清单。

## 替换规则

每套 PBR 必须提供 `albedo`、OpenGL `normal`、`roughness`、`ao`；近景英雄材质再提供
`cavity` 和 `height`。当前本地贴图是可运行 fallback，`material_library.json` 已标记为
`installed_4k_cc0` 的目录已接入地表三层和湖岸石；8K 原包外置，替换分辨率后必须更新状态和 SHA256。

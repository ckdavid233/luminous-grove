# `forest_ground_albedo_v2.png` 生成记录

- 生成日期：2026-08-09
- 生成方式：Codex imagegen 内置图像生成工具
- 输出尺寸：1254 × 1254 px，RGB PNG
- 运行时目标：`game/content/environments/ground/forest_ground_albedo_v2.png`
- 用途：雨后森林地表的 Base Color／Albedo；与现有 Normal、Roughness 贴图组合使用。

## 生成简报

平视不可见、近似俯视的无缝雨后森林地表材质；深青绿色湿土、苔藓、细小落叶和少量
浅色碎屑；低频自然色块，不能出现道路、石块、树根、文字、光照方向或明显重复接缝；
适合 PBR 游戏地表平铺，并保留足够暗部给实时湿润高光和树影。

这张图作为工程精细化的可替换 Base Color，不替代后续用户素材包中的最终材质；若收到
更高分辨率或带完整 ORM 的授权素材，需重新做 4×4 平铺、边缘和远景闪烁验收。

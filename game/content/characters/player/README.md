# Spirit Child（历史占位角色）

`spirit_child.glb` 是早期低多边形验证资产，由以下脚本重复生成：

```text
/home/cenkai/game_dev_plan/art_source/player/create_player.py
```

它只用于保留最初的 glTF、骨骼和 Idle／Walk／Interact 导入实验。0.6.1-alpha 运行时已经
改用：

```text
content/characters/realistic_player/ji_realistic.glb
```

Windows Release 的导出过滤器会排除整个 `content/characters/player/`，因此本占位 GLB
不随当前发行包分发。写实角色的来源、许可、构建和测试见项目根目录
`CHARACTER_PIPELINE.md`。

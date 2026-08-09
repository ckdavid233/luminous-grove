# Stylized Shrine

神龛运行资产可由以下 Blender 脚本重复生成：

```text
/home/cenkai/game_dev_plan/art_source/shrine/create_shrine.py
```

输出：

```text
content/props/shrine/stylized_shrine.glb
```

当前 0.6.1-alpha 状态：

- 约 3 米高的低边数几何。
- 两种石材材质与一组发光水晶材质。
- 由林地主线控制激活、Emission、灯光与互动反馈。
- 作为可重复生成的运行资产随 Windows PCK 分发。

它是稳定的 alpha 资产，不是最终雕刻定稿。收到用户材质底图后，可替换石材 Albedo／
派生数据贴图，但必须保留持久化 ID、碰撞体、交互信号与现有测试契约。

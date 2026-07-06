# 动态颜色

[索引](./index.md) | [English](../en/dynamic-colors.md)

动态颜色让某个高亮通道在 override 生效后继续随时间变化。你保存的不再只是一个固定的 `fg`、`bg` 或 `sp`，而是一份可以被运行时采样的声明式模型。

## 能做什么

动态颜色适合：

- 轻微 pulse 和 breath 效果。
- hue shift。
- 随时间变化的渐变。
- blink 风格强调。
- brightness 和 saturation transform。
- 针对 `fg`、`bg`、`sp` 的独立通道动画。

## TUI 边界

动态颜色运行在 Neovim TUI 的高亮系统里。这意味着：

- 运行时会按时间更新高亮组颜色值。
- 效果是高亮组级别，不是逐字符级别。
- 不能做终端网格上的空间渐变。
- 不能为每个渲染单元维护独立动画 timeline。
- 流畅度受 `dynamic.interval_ms`、终端渲染和 colorscheme 复杂度影响。

这个边界能让功能在不同终端环境里保持稳定。

## Preset

hlcraft 内置这些 preset：

- `pulse`
- `breath`
- `hue`
- `gradient`
- `blink`
- `duotone`

Preset 是起点。它们也会保存为和自定义动态颜色相同的声明式模型，因此可以继续用原始 JSON 编辑器微调。

## 编辑流程

动态颜色从 `FG`、`BG`、`SP` 颜色编辑器进入：

- 按 `d` 为当前通道切换动态模式。
- 按 `m` 循环切换 preset。
- 按 `+` 或 `-` 调整 duration；选中 phase 行时调整 phase。
- 按 `e` 打开原始 JSON 编辑器。
- 结果满意后，在详情视图保存。

工作台会用动画色块作为主要预览。类似 `pulse 2000ms` 的紧凑文本仍然显示，用作元数据和无法播放动画时的 fallback。

## 声明式模型

动态通道是一个包含必填 `version` 和 `timeline` 的表：

```json
{
  "version": 1,
  "preset": "pulse",
  "duration": 2000,
  "loop": "pingpong",
  "phase": 0,
  "interpolation": "smooth",
  "timeline": [
    { "at": 0, "color": "base" },
    { "at": 1, "color": "#ff6699" }
  ],
  "transforms": [
    {
      "type": "brightness",
      "interpolation": "sine",
      "timeline": [
        { "at": 0, "value": 0.8 },
        { "at": 1, "value": 1.2 }
      ]
    }
  ]
}
```

字段含义：

- `version`：当前为 `1`。
- `preset`：可选，表示 preset 或自定义形状的标签。
- `duration`：动画时长，单位毫秒。
- `loop`：`repeat`、`pingpong` 或 `once`。
- `phase`：`0` 到 `1` 之间的偏移。
- `interpolation`：颜色插值模式。
- `timeline`：非空颜色 stop 列表。
- `transforms`：可选数值 transform 列表。

## Timeline Stop

颜色 stop 形态：

```json
{ "at": 0.5, "color": "#88ccff" }
```

`at` 必须在 `0` 到 `1` 之间。

`color` 可以是：

- `base`：当前通道的非动态基础颜色。
- `fg`、`bg` 或 `sp`：其他解析后的颜色通道。
- 具体颜色，例如 `#88ccff`。

## Transform

Transform 形态：

```json
{
  "type": "brightness",
  "timeline": [
    { "at": 0, "value": 0.8 },
    { "at": 1, "value": 1.2 }
  ]
}
```

支持的 transform 类型：

- `brightness`
- `hue_shift`
- `saturation`

Transform 会在基础 timeline 颜色采样之后应用。

## 持久化

动态设置直接保存在条目的 `dynamic` 表里：

```toml
["demo.group"]
"Normal" = { fg = "#d7d7ff", dynamic = { fg = { version = 1, preset = "pulse", duration = 2000, loop = "pingpong", interpolation = "smooth", timeline = [{ at = 0, color = "base" }, { at = 1, color = "#ff6699" }] } } }
```

完整 TOML 模型见 [持久化](./persistence.md)。

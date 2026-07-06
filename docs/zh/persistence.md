# 持久化

[索引](./index.md) | [English](../en/persistence.md)

hlcraft 会把保存后的 override 写成 TOML 文件。这些文件的目标是可读、可人工编辑，并且适合放进你的 Neovim 配置管理。

## 目录

默认持久化目录：

```lua
vim.fn.stdpath('config') .. '/hlcraft'
```

配置方式：

```lua
require('hlcraft').setup({
  persistence = {
    dir = vim.fn.stdpath('config') .. '/hlcraft',
  },
})
```

## TOML Section

每个持久化文件保存一个顶层 TOML section。section 名称来自你在工作台里选择或创建的分组。

```toml
["ui.base"]
"Normal" = { fg = "#d7d7ff", bg = "NONE" }
"NormalFloat" = { bg = "NONE" }
```

高亮条目可以包含：

- 颜色字段：`fg`、`bg`、`sp`。
- 样式字段：`bold`、`italic`、`underline`、`undercurl` 以及其他 Neovim 高亮样式。
- 数值字段，例如 `blend`。
- `dynamic` 通道设置。

## 分组

这里的分组是持久化 section，不是 Neovim 高亮组。它用于把保存的 override 组织到不同 TOML 文件里。

示例：

```text
base
ui.popup
syntax.lua
dynamic.effects
```

如果某个高亮没有持久化分组，hlcraft 会要求你先选择或创建分组，然后才能保存。

## 动态颜色

动态设置和其他字段保存在同一个高亮条目里：

```toml
["demo.group"]
"Normal" = { fg = "#d7d7ff", dynamic = { fg = { version = 1, preset = "pulse", duration = 2000, loop = "pingpong", timeline = [{ at = 0, color = "base" }, { at = 1, color = "#ff6699" }] } } }
```

持久化形态和原始 JSON 编辑器使用同一个声明式模型。

## 加载和重新应用

持久化 override 会在 `require('hlcraft').setup()` 时加载。

也可以在指定事件后重新应用：

```lua
persistence = {
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
    },
  },
}
```

这对 colorscheme 切换很重要，因为 colorscheme 通常会重写高亮组。

## 手工编辑

支持手工编辑，但 schema 是严格的：

- 未知字段会被拒绝。
- 高亮名必须是有效名称。
- 颜色值必须是合法颜色或 `NONE`。
- 动态通道必须能成功归一化。
- 多个加载文件里不能出现重复高亮条目。

手工编辑后建议运行：

```vim
:checkhealth hlcraft
```

健康检查会验证持久化数据能否解析和归一化。

## 保存语义

保存会把当前高亮组的草稿 override 写入它选择的持久化分组。没有保存的草稿修改只在当前会话内存在。

当保存后的 override 变为空时，hlcraft 会清理过期 TOML 条目，并删除不再对应活动分组的过期文件。

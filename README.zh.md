# hlcraft.nvim

[English](./README.md)

`hlcraft.nvim` 是一个用于管理 Neovim 高亮组的交互式工具。

它提供了一个统一入口，让你可以查看高亮组的最终解析结果，按名称或颜色搜索，编辑 override，并将结果持久化为 TOML 文件。

你可以把它当作自己的 Neovim 高亮系统控制台来使用。如果你愿意，也完全可以把它当成一个“主题”插件来使用，只不过这个“主题”不是别人预先定义好的，而是由你自己一步步塑形出来的。

一个很实用的思路是：借助 AI，把你喜欢的主题插件风格提取成 hlcraft 的持久化配置，然后再继续微调。你也可以完全跳过这一步，直接从零开始自由发挥。总之，最终效果始终由你掌控。

## 功能

- 按名称搜索高亮组
- 按颜色相似度搜索高亮组
- 查看最终解析后的 `fg`、`bg`、`sp`、链接、来源和属性
- 在详情编辑器中编辑 override
- 跨会话持久化 override
- 在 colorscheme 变化后自动重新应用持久化 override
- 无外部依赖

## 要求

- Neovim `>= 0.10.0`

## 安装

### lazy.nvim

```lua
{
  '0antinomia/hlcraft.nvim',
  config = function()
    require('hlcraft').setup()
  end,
}
```

### 最小配置

```lua
require('hlcraft').setup()
```

插件会自动注册 `:Hlcraft` 命令。

## 配置

默认配置：

```lua
require('hlcraft').setup({
  from_none = {
    enabled = false,
    scope = 'extended',
  },
  threshold = 100,
  include_sp_in_color_search = false,
  persist_dir = vim.fn.stdpath('config') .. '/.hlcraft',
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
    },
  },
  dynamic = {
    enabled = false,
    interval_ms = 80,
  },
  debounce_ms = 100,
  preview_key = 'z',
})
```

### 选项

#### `from_none`

控制 hlcraft 是否会先应用一套透明背景的基础 preset，再叠加你自己的运行时 override 和持久化 override。

```lua
from_none = {
  enabled = false,
  scope = 'extended',
}
```

- `enabled`：是否启用这个 preset
- `scope = 'core'`：只清理较小范围的基础组，比如 `Normal`、`NormalFloat`、`SignColumn`
- `scope = 'extended'`：额外清理更多 UI 相关组，比如 popup menu、winbar 等

如果你想长期维护一套透明背景风格，可以启用它。

如果你正在找一个一键快速打造透明风格 Neovim 主题的方法，不要犹豫，这就是你需要的。

#### `threshold`

颜色搜索默认使用的距离阈值。

```lua
threshold = 100
```

颜色搜索使用 RGB 欧氏距离。值越小，匹配越严格；值越大，返回结果越宽。

#### `include_sp_in_color_search`

控制是否把 `sp` 字段也纳入颜色匹配。

```lua
include_sp_in_color_search = false
```

启用后，`sp` 颜色匹配的高亮组也会出现在结果中。这在大量使用 underline 或 undercurl 的主题里会更有用。

#### `persist_dir`

持久化 override 所使用的目录。

```lua
persist_dir = vim.fn.stdpath('config') .. '/.hlcraft'
```

默认是 Neovim 配置目录下的一个隐藏目录。hlcraft 可能会在其中创建多个 TOML 文件。

#### `reapply_events`

哪些事件会触发自动重新应用持久化 override。

```lua
reapply_events = {
  enabled = true,
  events = {
    'ColorScheme',
  },
}
```

你可以在 `events` 里同时使用普通事件名和结构化配置：

```lua
reapply_events = {
  enabled = true,
  events = {
    'ColorScheme',
    { event = 'SessionLoadPost', once = false },
  },
}
```

结构化条目支持：

- `event`：autocmd 事件名
- `pattern`：可选的 autocmd pattern
- `once`：是否只执行一次

将 `enabled = false` 可以完全关闭自动重放。

#### `dynamic`

控制已保存的动态颜色 override 是否在运行时播放动画。

```lua
dynamic = {
  enabled = false,
  interval_ms = 80,
}
```

- `enabled`：为 `false` 时，动态配置会被加载和保存，但不会播放
- `interval_ms`：动画 tick 间隔，单位为毫秒

动态颜色配置在现有 `FG`、`BG`、`SP` 编辑器里完成。在颜色编辑器中按 `d` 切换动态模式，按 `m` 在 `rgb` 和 `breath` 间切换，按 `+` / `-` 调整速度。

#### `debounce_ms`

搜索输入更新的 debounce 延迟。

```lua
debounce_ms = 100
```

- `0`：关闭 debounce，立即更新
- `> 0`：输入时等待指定毫秒数后再重新计算结果

#### `preview_key`

用于短暂高亮当前选中高亮组的预览按键。

```lua
preview_key = 'z'
```

只要 hlcraft workspace 处于打开状态，这个键就会作为一个临时的全局普通模式映射存在，所以即使切到别的窗口也仍然能触发。workspace 关闭后，这个映射会自动移除。

将它设为 `false` 可以完全关闭这个功能。

## 使用

打开 workspace：

```vim
:Hlcraft
```

### 搜索

顶部区域有两个输入框：

- `name`：按高亮组名称做大小写不敏感的子串匹配
- `color`：按颜色相似度过滤

这两个过滤条件可以组合使用。

颜色查询支持：

- `#RRGGBB`
- `NONE`

`NONE` 会匹配解析后颜色未设置的高亮组。默认检查 `fg` 和 `bg`；如果启用了 `include_sp_in_color_search`，也会检查 `sp`。

## 持久化

持久化 override 会写入：

```lua
vim.fn.stdpath('config') .. '/.hlcraft'
```

每个文件保存一个顶层 TOML section。section 名称来自你在详情页里明确选择或新建的 group。如果某个 override 没有 group，hlcraft 会要求你先选择或新建一个 group，再进行保存。

动态颜色会保存为 hlcraft 专属的扁平键，比如 `dyn_fg_mode` 和 `dyn_fg_speed`。

持久化 override 会在 `setup()` 时加载，并在配置的 `reapply_events` 上再次应用。

## 健康检查

运行：

```vim
:checkhealth hlcraft
```

会检查：

- Neovim 版本是否兼容
- 持久化目录是否可用
- 持久化目录是否可写

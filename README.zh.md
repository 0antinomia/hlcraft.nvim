# hlcraft.nvim

[English](./README.md)

`hlcraft.nvim` 是一个用于 Neovim 高亮系统的交互式工作台。

它提供统一入口，让你可以查看高亮组、按名称或颜色搜索、编辑 override、预览结果，并将最终选择持久化为 TOML 文件。

你可以把它当作高亮调试工具，也可以把它当作个人主题构建层，或者用它把已有 colorscheme 微调成完全属于自己的最终形态。

## 功能

- 按名称搜索高亮组。
- 按颜色相似度搜索高亮组。
- 查看解析后的 `fg`、`bg`、`sp`、链接、来源和属性。
- 编辑颜色、样式、blend、分组和动态颜色 override。
- 将 override 持久化为可读 TOML 文件。
- 在 colorscheme 变化后自动重新应用持久化 override。
- 无外部依赖。

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

打开工作台：

```vim
:Hlcraft
```

## 文档

- [文档首页](./docs/zh/index.md)
- [配置](./docs/zh/configuration.md)
- [工作台](./docs/zh/workspace.md)
- [动态颜色](./docs/zh/dynamic-colors.md)
- [持久化](./docs/zh/persistence.md)
- [架构](./docs/zh/architecture.md)

## 快速配置

```lua
require('hlcraft').setup({
  transparent = {
    enabled = false,
    scope = 'extended',
  },
  search = {
    threshold = 100,
    include_sp = false,
    debounce_ms = 100,
  },
  persistence = {
    dir = vim.fn.stdpath('config') .. '/hlcraft',
    reapply_events = {
      enabled = true,
      events = {
        'ColorScheme',
      },
    },
  },
  dynamic = {
    interval_ms = 80,
  },
  keymaps = {
    preview = {
      lhs = 'z',
      mode = 'n',
      opts = {
        desc = 'hlcraft flash current highlight',
        silent = true,
        nowait = true,
      },
    },
  },
})
```

配置细节和常见用法见 [配置](./docs/zh/configuration.md)。

## 持久化

保存后的 override 会以 TOML 文件写入 `persistence.dir`。每个文件保存一个顶层 section，每个高亮条目只保存你选择保留的 override 字段。

动态颜色设置会直接保存在每个高亮条目的 `dynamic` 表中。完整模型见 [动态颜色](./docs/zh/dynamic-colors.md) 和 [持久化](./docs/zh/persistence.md)。

## 健康检查

运行：

```vim
:checkhealth hlcraft
```

健康检查会验证 Neovim 兼容性、持久化目录访问、写入能力和 TOML 解析完整性。

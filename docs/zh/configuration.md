# 配置

[索引](./index.md) | [English](../en/configuration.md)

hlcraft 使用声明式配置 schema。未知 key 会被拒绝，嵌套配置组会被校验，所有值会在插件初始化前完成归一化。

## 默认配置

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

## `transparent`

控制 hlcraft 是否在草稿 override 和持久化 override 之前先应用一层透明背景 baseline。

```lua
transparent = {
  enabled = false,
  scope = 'extended',
}
```

- `enabled`：是否启用透明 baseline。
- `scope = 'core'`：清理较基础的高亮组，例如 `Normal`、`NormalFloat`、`SignColumn`。
- `scope = 'extended'`：额外清理更多 UI 相关组，例如 popup menu 和 winbar 相关高亮。

如果你希望透明背景成为最终高亮层的一部分，可以启用这个选项。

## `search`

控制颜色搜索和搜索输入更新节奏。

```lua
search = {
  threshold = 100,
  include_sp = false,
  debounce_ms = 100,
}
```

- `threshold`：颜色搜索使用的 RGB 欧氏距离阈值。必须是 `0` 到 `1000` 之间的有限数字。
- `include_sp`：是否把 `sp` 通道纳入颜色匹配。
- `debounce_ms`：搜索输入更新延迟。设为 `0` 时立即更新。

阈值越低，匹配越严格；阈值越高，结果越宽。

## `persistence`

控制 TOML 文件保存位置，以及持久化 override 在哪些事件后重新应用。

```lua
persistence = {
  dir = vim.fn.stdpath('config') .. '/hlcraft',
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
    },
  },
}
```

默认目录是可见目录。这些文件属于你的 Neovim 配置，不是隐藏缓存。

也可以使用结构化事件：

```lua
persistence = {
  reapply_events = {
    enabled = true,
    events = {
      'ColorScheme',
      { event = 'SessionLoadPost', once = false },
    },
  },
}
```

结构化条目支持：

- `event`：autocmd 事件名。
- `pattern`：可选 autocmd pattern。
- `once`：是否只运行一次。

将 `persistence.reapply_events.enabled = false` 可以关闭自动重新应用。

## `dynamic`

控制动态颜色 override 的运行时刷新节奏。

```lua
dynamic = {
  interval_ms = 80,
}
```

`interval_ms` 必须是 `16` 到 `1000` 之间的有限数字。数值越低越顺滑，但写入高亮组更频繁。

动态颜色细节见 [动态颜色](./dynamic-colors.md)。

## `keymaps.preview`

控制用于短暂标记当前选中高亮组的临时按键。

```lua
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
}
```

只要 hlcraft 工作台打开，这个 keymap 就会存在；工作台关闭后会自动移除。设置 `keymaps.preview = false` 可以禁用。

`mode` 目前只支持普通模式 `'n'`。`opts` 支持 `desc`、`silent` 和 `nowait`。

## 示例配置

```lua
require('hlcraft').setup({
  transparent = {
    enabled = true,
    scope = 'extended',
  },
  search = {
    threshold = 80,
    debounce_ms = 0,
  },
  dynamic = {
    interval_ms = 100,
  },
  keymaps = {
    preview = {
      lhs = '<leader>hp',
      mode = 'n',
      opts = {
        desc = 'hlcraft preview highlight',
        silent = true,
        nowait = true,
      },
    },
  },
})
```

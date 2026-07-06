# hlcraft.nvim 文档

[English](../en/index.md)

`hlcraft.nvim` 是一个用于 Neovim 高亮系统的交互式工作台。它可以查看高亮组、按名称或颜色搜索、编辑 override、预览结果，并将最终选择保存为 TOML 文件。

它既可以作为日常高亮调试工具，也可以作为你自己的主题构建层。保存下来的结果是普通 TOML 文件，可以人工阅读、修改，并在 Neovim 启动或指定事件触发后由 hlcraft 重新应用。

## 阅读入口

- [配置](./configuration.md)：setup 选项、默认值、校验规则和常见配置。
- [工作台](./workspace.md)：交互式 UI、搜索、编辑器和快捷键。
- [动态颜色](./dynamic-colors.md)：preset、自定义 JSON、运行边界和声明式模型。
- [持久化](./persistence.md)：TOML 结构、分组、重新应用和手工编辑注意事项。
- [架构](./architecture.md)：项目结构和模块职责。

## 核心概念

hlcraft 将三类状态分开处理：

- 当前 Neovim 会话里的真实高亮状态。
- 正在交互式编辑、立即生效的草稿 override。
- 保存到 TOML、之后可以重新应用的持久化 override。

因此你可以放心探索。只有明确保存的 override 才会跨会话保留。

## 最小配置

```lua
require('hlcraft').setup()
```

打开工作台：

```vim
:Hlcraft
```

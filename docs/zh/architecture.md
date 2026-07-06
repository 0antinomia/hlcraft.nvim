# 架构

[索引](./index.md) | [English](../en/architecture.md)

本文说明当前项目结构和主要模块职责。

## Runtime 入口

```text
plugin/hlcraft.lua
```

这是 Neovim runtime 入口文件。它只注册 `:Hlcraft`。命令会加载 `require('hlcraft')`，必要时执行 setup，然后打开工作台。

业务逻辑不应该放在 `plugin/` 里。

## 公开 API

```text
lua/hlcraft/init.lua
```

这是公开 Lua facade。它暴露：

- `setup(opts)`
- `is_setup()`
- `open(opts)`
- 高亮搜索辅助方法
- override service facade

内部模块按 `config`、`core`、`dynamic`、`engine`、`persistence`、`ui` 分组。

## 配置

```text
lua/hlcraft/config.lua
lua/hlcraft/config/
```

配置层在初始化前校验和归一化用户选项。schema 是声明式的：

- `spec.lua`：默认值和已知 key 集合。
- `validate.lua`：严格校验和错误消息。
- `normalize.lua`：修剪并归一化已接受的值。
- `schema.lua`：组合 spec、validation、normalization 和 defaults。

## Core

```text
lua/hlcraft/core/
```

Core 模块处理纯高亮和值逻辑：

- 颜色解析和转换。
- 高亮条目归一化。
- 高亮名称和字段元数据。
- 按名称和颜色搜索。
- table、timer、number 辅助逻辑。

这些模块应避免 UI 状态和持久化副作用。

## 动态颜色

```text
lua/hlcraft/dynamic/
```

动态颜色模块定义声明式动画模型：

- 常量和模型校验。
- Preset。
- Timeline 采样。
- 数值 transform。
- 运行时应用循环。

运行时会按时间更新高亮组通道。模型本身保持可序列化，并独立于 UI 状态。

## Engine

```text
lua/hlcraft/engine/
```

Engine 持有 override 状态和 mutation 行为：

- 草稿和持久化 store。
- Patch 校验和归一化。
- Snapshot 和 restore。
- 应用 override 到 Neovim。
- 生命周期和 reapply hook。

UI 通过 service 层调用 engine，不直接修改 store table。

## Persistence

```text
lua/hlcraft/persistence/
```

Persistence 负责 TOML 编码、解析、文件扫描、归一化和 repository 操作。

Repository 边界负责把保存的数据加载为归一化 table，并把归一化 override 保存回 TOML。

## UI

```text
lua/hlcraft/ui.lua
lua/hlcraft/ui/
```

UI 层负责工作台：

- 实例生命周期。
- 窗口和 buffer 管理。
- 搜索和详情 scene。
- 字段编辑器。
- 输入处理。
- 渲染。
- Keymap 和 prompt。

顶层 `lua/hlcraft/ui.lua` 是 facade，负责管理具名 UI 实例。

## 测试

```text
tests/
```

测试按模块边界组织。`tests/run_all.lua` 会列出所有测试文件，并在新增测试文件没有加入列表时失败；只有 helper 文件会被明确忽略。

运行完整测试：

```bash
nix develop -c nvim --headless -u NONE -c 'set rtp+=.' -l tests/run_all.lua
```

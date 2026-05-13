# 工作原理

Claude Desktop 是 Electron 应用，主要 UI 资源位于 `resources/app.asar`。本项目在本机执行补丁，不分发任何 Claude 原始文件或修改后的二进制文件。

## 补丁流程

```text
Claude 安装目录
  -> 备份 Claude.exe / app.asar / locale json
  -> 解包 app.asar
  -> 注入 DOM 运行时翻译层
  -> 补丁 en-US.json / zh-CN.json
  -> 重新打包 app.asar
  -> 计算 ASAR header hash
  -> 写入 Claude.exe
  -> 启动 Claude
```

## 为什么要写入 Claude.exe

Electron 对 `app.asar` 启用了完整性校验。重新打包后，即使文件内容合法，如果 `Claude.exe` 中记录的 ASAR hash 还是旧值，启动时会报：

```text
Integrity check failed for asar archive
```

这里需要写入的是 ASAR header hash，不是整个 `app.asar` 文件的 SHA256。脚本通过 `@electron/asar` 读取 raw header，然后计算 SHA256。

## 翻译层策略

`scripts/patch-asar.cjs` 会向前端 bundle 注入一个小型运行时翻译器：

- 扫描文本节点和常见属性：`placeholder`、`title`、`aria-label` 等。
- 使用 `MutationObserver` 处理动态加载内容。
- 周期性轻量扫描，覆盖页面切换后的延迟渲染。
- 跳过输入框、代码编辑器、`contenteditable` 等用户内容区域。

这个方案比直接搜索替换 bundle 中的压缩字符串更稳，因为 Cowork 部分 UI 会远端动态加载。

## 注入点

当前支持过的 Claude bundle 注入点包括：

- `YFn(o.webContents),o.webContents.on("dom-ready",()=>{xJ()});`
- `Tm(s.webContents),ccr(s.webContents),s.webContents.on("dom-ready",()=>{poA()});`

如果 Claude 更新后 bundle 改动较大，可能需要在 `scripts/patch-asar.cjs` 中添加新的注入点。

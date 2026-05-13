# 贡献指南

欢迎补充翻译、适配新版本 Claude Desktop，或改进安装/恢复流程。

## 补充翻译

编辑：

```text
translations/zh-CN.json
```

原则：

- 保留品牌名：Claude、Anthropic、GitHub、MCP 等。
- 优先补完整句子。
- 对 Cowork 拆分文本导致的混合中英文，也补短片段。
- 不翻译模型生成内容、代码、路径、命令。

## 适配新版本

如果 Claude 更新后提示找不到注入点，检查解包后的：

```text
.vite/build/index.js
.vite/build/mainView.js
.vite/build/mainWindow.js
```

在 `scripts/patch-asar.cjs` 中增加新的 main-process 注入点。

如果完整性哈希无法写入，需要把当前版本 `Claude.exe` 中原始的 64 位 ASAR hash 加到：

```text
scripts/patch-exe-hash.cjs
```

## 提交前检查

```powershell
npm run validate
```

不要提交以下文件：

- `app.asar`
- `Claude.exe`
- `.bak`
- 安装备份
- 本机日志

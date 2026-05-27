# Roblox AI Analyzer - Custom API Version

简化版本，仅支持自定义 API 配置。

## 配置说明

在 UI 中输入以下信息：
- **Base URL**: API 基础地址（例如：https://api.openai.com）
- **API Key**: 你的 API 密钥
- **Model**: 模型名称（例如：gpt-4o-mini）

## 使用方法

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/RobloxAIAnalyzer/main/main.lua"))()
```

配置会自动保存到本地。

## 脚本读取

游戏脚本读取不再使用执行器内置 `decompile`。当前实现会通过 `getscriptbytecode` 读取字节码，并调用 `https://api.lua.expert/decompile` 获取反编译结果，因此需要：

- 执行器支持 `getscriptbytecode`
- 执行器支持外部 HTTP 请求

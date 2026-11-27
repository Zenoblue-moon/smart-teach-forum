# 智教联盟论坛 · Android 第三方客户端

基于 **Flutter** 的智教联盟论坛（[forum.smart-teach.cn](https://forum.smart-teach.cn)）第三方安卓客户端。
论坛底层是 **Flarum**，本项目直接调用其公开的 **Flarum JSON:API**，实现**原生渲染**（非 WebView 套壳）。

> 免责声明：本项目为学习与交流用途的第三方客户端，非官方应用，与智教联盟论坛官方无关。请遵守论坛社区规范使用。

## 功能特性

| 模块 | 功能 |
| --- | --- |
| 首页 | 最新 / 最热 / 最近回复 三个讨论流，下拉刷新、滚动到底自动分页 |
| 板块 | 父标签分组浏览，子板块以彩色胶囊展示，点击进入板块讨论列表 |
| 帖子详情 | 标题、正文 HTML 原生渲染、楼层列表、加载更多、图片全屏缩放预览、复制链接、引用跳转（自动滚动并高亮对应楼层）、已解决/置顶/锁定标签 |
| 搜索 | 关键词检索、最近搜索记录、热门板块快捷入口 |
| 登录 | 内置浏览器 SSO 登录（FoF Passport，跳转 auth.smart-teach.cn 授权后自动提取会话） |
| 发帖 | 标题 + 主板块（必选）+ 子板块（最多 3 个）+ Markdown 正文 |
| 回帖 | 楼层回复、引用回复（自动带入引用块）、Markdown 编辑器 |
| 图片上传 | 相册选图，通过论坛 `fof/upload` 接口上传并自动插入，也支持粘贴图片外链 |
| 通知 | 回复/提及/点赞等分类展示，点击直达楼层，一键全部已读 |
| 个人主页 | 用户信息、主题/回复/积分统计、其发布的主题列表 |
| 我的 | 登录态管理、应用主题（6 套预设 × 3 色）、动态取色、预测式返回、页面过渡动画（5 种）、震动反馈、深色模式 |

Markdown 编辑器支持：粗体、斜体、删除线、行内代码、引用、链接、图片。

## 技术栈

- Flutter 3.0 / Dart 2.17
- 网络：`http` + Flarum JSON:API
- 状态管理：`provider`
- 正文渲染：`flutter_html`
- 图片：`cached_network_image`（缓存）、`photo_view`（全屏预览）
- 本地存储：`shared_preferences`（登录态、最近搜索、主题偏好）
- 图片选择：`image_picker`
- 登录：`webview_flutter`（内置浏览器 SSO）+ 原生 CookieManager 提取会话
- 动态取色：`dynamic_color`（Android 12+）

## 目录结构

```
lib/
├── main.dart                  # 入口
├── app.dart                   # MaterialApp 与主题
├── core/
│   ├── config.dart            # 站点配置
│   ├── api_client.dart        # HTTP 客户端（Cookie/Token 认证）
│   ├── models.dart            # JSON:API 数据模型
│   ├── theme_presets.dart     # 主题预设 / 过渡动画定义
│   ├── utils.dart             # 工具函数
│   └── services/
│       ├── forum_service.dart # 论坛 API 封装
│       ├── app_state.dart     # 登录态 / 设置
│       └── cookie_service.dart# 原生 Cookie 提取
├── features/
│   ├── shell/                 # 主框架（底部导航）
│   ├── home/                  # 首页
│   ├── tags/                  # 板块
│   ├── discussion/            # 帖子详情、图片预览
│   ├── search/                # 搜索
│   ├── notifications/         # 通知
│   ├── compose/               # 发帖 / 回帖
│   ├── auth/                  # 登录
│   └── profile/               # 我的 / 用户主页
└── widgets/                   # 通用组件
```

## 构建 APK

环境要求：Flutter SDK（3.0+）、Android SDK、JDK。

```bash
cd smart_teach_client
flutter pub get
flutter build apk --release
```

生成的安装包位于 `build/app/outputs/flutter-apk/app-release.apk`。

调试运行：

```bash
flutter run
```

## 说明

- 站点主题色取自论坛配置（绿 `#26A03D` / 蓝 `#1068AF`），客户端内置 6 套主题预设（每套 3 色），并支持 Android 12+ 动态取色与深浅色。
- 登录采用内置浏览器 SSO：点击登录后跳转论坛授权页（auth.smart-teach.cn），完成 OAuth 登录后自动提取会话 Cookie 与用户信息，无需手动输入账号密码。
- 写操作（发帖、回帖、通知、上传）需要登录，客户端通过会话 Cookie + CSRF Token 完成认证。
- 预测式返回（Android 13+ 系统手势预览）为预留设置项；当前 Flutter 3.0 引擎尚未完全支持，升级到 Flutter 3.22+ 后可直接生效。
- 点赞（likes）扩展需站点开启；当前客户端未强制依赖该扩展，楼层提供「回复 / 复制链接」操作。

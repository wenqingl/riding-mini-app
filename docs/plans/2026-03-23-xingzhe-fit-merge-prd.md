# 行者骑行数据合并工具 PRD

## 设计决策

**目标：** 开发微信小程序，让用户可以合并行者 App 上分段记录的骑行数据为一条完整轨迹，并自动上传回行者。

**变更类型：** 新功能

**选择的方案：** 方案A（最小可用）— 后端做合并，小程序做展示+授权，先搞定核心流程闭环。

**选择理由：** 聚焦行者单一平台，快速验证核心价值（合并FIT/GPX/TCX并上传），广告后续接入。

**关键取舍：**
- 先只支持行者，不扩展其他平台
- 段间空白直接拼接，不补轨迹
- 广告模式延后，先做功能

**打分：** 8/10

**扣分原因：** 行者 API 写权限（上传接口）尚未验证；微信小程序域名白名单配置待确认。

**最大风险：** 行者 API 是否支持通过接口上传运动数据文件。

## R 内容

### 场景 1: 用户合并多日骑行记录

> 用户进行了一次多日长途骑行，每天骑行结束后主动关闭码表，导致行程被拆分为多条独立记录。用户希望将这些记录合并为一条完整轨迹，以展示完整的骑行路线和累计数据。

```gherkin
Feature: 用户合并多日骑行记录

  @AT-01 @cli
  Scenario: 用户授权登录并查看骑行记录列表
    Given 用户已安装行者 App 并有骑行记录
    When 用户打开小程序并点击"登录行者"
    Then 跳转行者 OAuth 授权页面
    When 用户完成授权
    Then 小程序显示用户的骑行记录列表（含日期、距离、时长）

  @AT-02 @cli
  Scenario: 用户选择多条记录进行合并
    Given 用户已登录且记录列表已加载
    When 用户勾选3条骑行记录（日期连续）
    And 点击"合并"按钮
    Then 系统下载这3条记录的 FIT/GPX/TCX 文件
    And 按时间顺序拼接为一个文件（段间空白不补轨迹）
    And 生成合并后的运动数据文件

  @AT-03 @cli
  Scenario: 合并后的文件自动上传回行者
    Given 合并文件已生成
    When 系统调用行者上传接口
    Then 文件成功上传到用户行者账号
    And 用户在行者 App 中可以看到合并后的新记录

  @AT-04 @cli
  Scenario: 合并后的文件支持下载到本地
    Given 合并文件已生成
    When 用户点击"下载"按钮
    Then 文件保存到用户手机本地

  @AT-05 @cli
  Scenario: 行者授权失败的处理
    Given 用户打开小程序
    When 用户点击"登录行者"但取消授权
    Then 小程序提示"需要授权才能使用"并引导重新授权

  @AT-06 @cli
  Scenario: 合并记录格式不一致的处理
    Given 用户选中的记录包含不同格式（如 FIT 和 GPX）
    When 系统执行合并
    Then 统一转换为目标格式后合并
    And 保留所有有效的运动数据点
```

## F 内容

### 功能组 A: 行者账号授权

```gherkin
Feature: 行者 OAuth 2.0 授权登录

  @FT-01
  Scenario: 发起授权
    Given 用户未登录
    When 用户点击"登录行者"
    Then 跳转行者 OAuth2 授权页面（client_id + redirect_uri + scope=write）

  @FT-02
  Scenario: 授权回调处理
    Given 用户在行者页面完成授权
    When 行者回调到 redirect_uri 并携带 code
    Then 后端用 code 换取 access_token 和 refresh_token
    And 存储 token 到用户会话

  @FT-03
  Scenario: Token 刷新
    Given access_token 已过期
    When 用户发起操作
    Then 后端使用 refresh_token 自动刷新 access_token
    And 操作继续执行不中断

  @FT-04
  Scenario: 取消授权
    Given 用户跳转到行者授权页面
    When 用户点击取消
    Then 回调返回错误码
    And 小程序提示需要授权
```

### 功能组 B: 骑行记录管理

```gherkin
Feature: 获取和展示骑行记录

  @FT-05
  Scenario: 获取记录列表
    Given 用户已授权
    When 进入主页
    Then 调用行者 API 获取骑行记录列表
    And 展示每条记录的日期、距离(km)、时长、起终点

  @FT-06
  Scenario: 选择待合并的记录
    Given 记录列表已展示
    When 用户勾选记录（2条及以上）
    Then 高亮选中项
    And 显示"合并"按钮及选中数量

  @FT-07
  Scenario: 取消选择
    Given 用户已选中若干记录
    When 用户取消勾选某条记录
    Then 更新选中状态
    If 选中数 < 2 则隐藏"合并"按钮
```

### 功能组 C: 文件合并

```gherkin
Feature: FIT/GPX/TCX 文件合并

  @FT-08
  Scenario: 下载原始文件
    Given 用户确认合并
    When 系统逐条调用行者 API 下载文件
    Then 获取每条记录的 FIT/GPX/TCX 原始文件

  @FT-09
  Scenario: 按时间顺序拼接
    Given 所有原始文件已下载
    When 系统解析并按时间戳排序
    Then 按顺序拼接数据点，段间空白不补轨迹
    And 合并总距离 = 各段距离之和
    And 合并总时长 = 各段时长之和（不含空白间隔）

  @FT-10
  Scenario: 多格式统一
    Given 选中记录包含不同格式
    When 系统执行合并
    Then 统一转换为 FIT 格式（或用户指定格式）
    And 保留心率、踏频、功率等传感器数据
```

### 功能组 D: 上传 & 下载

```gherkin
Feature: 合并结果输出

  @FT-11
  Scenario: 自动上传回行者
    Given 合并文件已生成
    When 系统调用行者上传接口
    Then 上传成功，返回新记录 ID
    And 小程序提示"上传成功，可在行者 App 查看"

  @FT-12
  Scenario: 下载到本地
    Given 合并文件已生成
    When 用户点击"下载"
    Then 文件通过微信小程序下载能力保存到手机

  @FT-13
  Scenario: 上传失败重试
    Given 行者上传接口返回错误
    When 错误为临时性（网络超时、服务器5xx）
    Then 自动重试最多3次
    If 仍失败 则提示用户并提供手动下载选项
```

### 功能组 E: 广告 & 商业化（后期）

```gherkin
Feature: 广告变现

  @FT-14
  Scenario: 展示激励广告
    Given 用户点击"合并"按钮
    When 播放激励视频广告
    Then 广告播放完成后执行合并操作

  @FT-15
  Scenario: 广告加载失败
    Given 广告 SDK 加载失败
    When 用户点击"合并"
    Then 允许免费使用（降级策略），记录日志
```

## 概要设计备注

1. **后端技术栈建议**：Node.js/Python + Express/FastAPI，负责 OAuth 代理、文件下载/合并/上传
2. **FIT 文件处理**：使用开源库 fit-sdk 或 python-fitparse 解析和生成 FIT 文件
3. **微信小程序域名要求**：后端域名需 ICP 备案 + HTTPS，在小程序后台配置为合法域名
4. **行者 API 验证重点**：需确认 `/api/v1/records/{id}/export` 下载接口和上传接口的可用性
5. **数据安全**：用户 token 仅在后端存储，不传前端；合并文件临时存储，处理完即删

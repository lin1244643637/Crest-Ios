# 账号与工作空间接口契约

日期：2026-09-14。状态：拟实施契约，未上线。设计依据见 [README.md](README.md)。

全部业务路径以 `/api/v1` 开头，以下均写完整路径。复用现有认证错误包装、Web Cookie 与移动端 Bearer/Keychain 约定。示例中的 ID、令牌和布尔能力仅说明结构，不是真实数据。

## 1. 共用返回结构

### 1.1 账号资料 AccountProfile

```json
{
  "user_id": "user-id",
  "username": "personal_generated_id",
  "phone_masked": "138****1234",
  "has_password": false,
  "must_change_password": false
}
```

`has_password` 必须读取服务端持久化哈希派生；账号设置、登录、刷新和首次设密响应保持一致。手机号可空；不向其他租户成员返回完整手机号。`must_change_password` 保留原有强制改密规则。

### 1.2 当前工作空间 WorkspaceContext

```json
{
  "key": "personal",
  "type": "personal",
  "tenant_id": null,
  "name": "个人空间",
  "role": null,
  "context_version": 1,
  "capabilities": {
    "basic_chat": true,
    "tenant_chat": false,
    "files": false,
    "reconciliation": false,
    "analytics": false,
    "knowledge_base": false,
    "reports": false,
    "tasks": false,
    "manage_members": false,
    "manage_workspace": false
  }
}
```

公司空间 `key="tenant:<tenant_id>"`、`type="tenant"`，名称来自租户，role 来自当前成员资格。capabilities 根据现有角色权限、租户状态与功能开关派生，不新增客户端自授权规则。公司空间 `basic_chat=false`，普通文字可继续在租户聊天内使用，但属于公司历史。

WorkspaceSummary 为上述结构移除 context_version，增加 `status=active|unavailable`；不可用的空间不可选择。个人空间始终 active。空间列表不作为授权凭据，切换时重新查询资格。

### 1.3 登录、注册、刷新响应 SessionResponse

保留现有顶层字段并扩展：

```json
{
  "token": "signed-access-token",
  "refresh_token": "a2.session-id.secret",
  "username": "personal_generated_id",
  "user_id": "user-id",
  "tenant_id": null,
  "role": null,
  "has_password": false,
  "account": {
    "user_id": "user-id",
    "username": "personal_generated_id",
    "phone_masked": "138****1234",
    "has_password": false,
    "must_change_password": false
  },
  "current_workspace": {
    "key": "personal",
    "type": "personal",
    "tenant_id": null,
    "name": "个人空间",
    "role": null,
    "context_version": 1,
    "capabilities": {
      "basic_chat": true,
      "tenant_chat": false,
      "files": false,
      "reconciliation": false,
      "analytics": false,
      "knowledge_base": false,
      "reports": false,
      "tasks": false,
      "manage_members": false,
      "manage_workspace": false
    }
  },
  "workspace_change_reason": null
}
```

移动端返回 refresh_token；Web 沿用 HttpOnly Cookie，不在 JSON 暴露刷新凭据。顶层 tenant_id/role 始终是当前空间值，has_password 与 account.has_password 由同一个转换函数填充。空间列表单独获取，避免登录响应塞入无限列表。

`workspace_change_reason` 取 `null/membership_unavailable/tenant_unavailable`；后两者表示刷新恢复到个人空间。客户端显示一次通知并清除原空间数据，不退出整个账号。

## 2. 手机号预检与免密码注册

| 方法与路径 | 身份 | 请求 | 成功响应 |
| --- | --- | --- | --- |
| `POST /api/v1/auth/phone-status`（新增） | 未登录 | `{phone, country_code}` | `{is_registered, has_password, next_step, can_sms_login}` |
| `POST /api/v1/auth/verifications`（扩展） | 未登录或可选账号 | `{channel:"sms", purpose:"personal_register", target}` | 沿用 `{challenge_id,message,expires_in,resend_after}` |
| `POST /api/v1/auth/verifications/{challenge_id}/confirm`（复用） | 挑战凭据 | `{code}` | 沿用 `{verification_token,expires_in}` |
| `POST /api/v1/auth/personal-register`（新增） | 已验证的注册凭据 | `{verification_token,client_type:"mobile"}` | `201` + SessionResponse |
| `POST /api/v1/auth/login`（调整） | 密码凭据 | 沿用当前参数 | `200` + SessionResponse |
| `POST /api/v1/auth/login/code`（调整） | login 用途凭据 | 沿用当前参数 | `200` + SessionResponse |

phone-status 规范化 country_code 与 phone，拒绝矛盾区号。返回分支固定为：

| 情况 | is_registered | has_password | next_step | can_sms_login |
| --- | --- | --- | --- | --- |
| 无注册或占用记录 | false | null | register | false |
| 已注册、有密码 | true | true | password | 取决于手机号是否已验证和功能开关 |
| 已注册、无密码且手机号已验证 | true | false | sms_login | true |
| 历史未验证占用或身份匹配冲突 | true | null | account_help | false |

预检复用 `user_lookup.py` 的手机号与历史手机用户名解析，不能仅判断新字段造成重复注册。预检返回不代表取得手机号所有权；不返回 user_id、租户或账号详情，不触发短信供应商调用。按 IP 和规范化手机号哈希限流，响应 `Cache-Control: no-store`。

personal_register 是新的独立验证用途，不放宽原 `register` 的邀请校验。只允许短信。target 使用规范化手机号，发送/验证/消费的次数、冷却和有效期复用现有实现；其他用途的 verification_token 不能注册。

personal-register 从已验证凭据读取手机号，不接受客户端另传 user_id/tenant_id/role/password/username。消费单次凭据，创建用户、个人会话，在数据库单事务中提交。数据库手机号唯一约束处理并发竞争；Redis 凭据消费与数据库不是一个事务，失败必须允许用户重新验证恢复，不能声称跨存储原子提交。响应丢失后可用短信登录同一账号。

设置 `extra="forbid"` 校验新增接口的越权字段。个人注册关闭时返回明确不可用错误；验证码登录必须同时开启，否则无密码用户无法再次登录。

## 3. 账号资料、密码与会话

| 方法与路径 | 身份 | 行为与响应 |
| --- | --- | --- |
| `GET /api/v1/auth/me`（新增） | 账号 | `{account,current_workspace,workspace_change_reason}`，不签发新令牌 |
| `POST /api/v1/auth/password/initial`（新增） | 账号 | `{new_password}`；返回 `{account}` |
| `POST /api/v1/auth/change-password`（调整） | 账号 | 复用旧密码校验和既有成功约定，按账号全空间处理安全失效 |
| `POST /api/v1/auth/reset-password`（调整） | reset_password 用途凭据 | 复用短信重置，撤销该账号全部设备会话 |
| `POST /api/v1/auth/refresh`（调整） | refresh 凭据或 Cookie | 轮换刷新凭据，返回 SessionResponse |
| `POST /api/v1/auth/logout`（调整） | refresh 凭据或 Cookie | 幂等撤销本设备会话，租户失效也可退出 |
| `GET /api/v1/auth/contact`（调整） | 账号 | 本人绑定状态，去除单一租户条件 |

首次设密只允许当前哈希为 NULL，复用密码策略。锁用户行或带 NULL 条件更新，两个并发请求只能一个成功；已有密码返回 `409 password_already_set`，不能覆盖密码。该操作不撤销当前或其他设备会话，也不递增 token_version；这是首次设置，后续更新使用 change/reset 路径。

首次设密要求设备会话来源于已验证登录，不能接受仅通过 phone-status 获得的信息。未设密码用户通过其他联系方式/安全设置时必须遵守已有验证要求，不能用空旧密码绕过校验。联系方式变更流程若原来需要当前密码，先完成首次设密再操作。

`GET /auth/me` 遇到租户/资格失效返回 `403 workspace_unavailable`；客户端只对该错误执行一次刷新，得到明确的个人空间恢复响应。直接 `GET /auth/workspaces`、`POST /auth/switch-workspace` 只需要有效账号上下文，可用于恢复。过期/旧 context_version 先刷新，不把 403 全部当作退出登录。

## 4. 工作空间选择、加入与成员管理

| 方法与路径 | 身份 | 请求与响应 |
| --- | --- | --- |
| `GET /api/v1/auth/workspaces`（新增） | 账号 | `?cursor=&limit=`；`{items:[WorkspaceSummary],next_cursor}`，个人空间只在第一页 |
| `POST /api/v1/auth/switch-workspace`（新增） | 账号 | 下方固定选择结构；`{token,account,current_workspace,workspace_change_reason:null}` |
| `POST /api/v1/auth/join-tenant`（调整） | 账号 | 沿用 `{tenant_code}`，创建本人申请，返回原申请响应 |
| `GET /api/v1/auth/join-requests`（新增） | 账号 | 游标分页，返回本人请求的 `{id,target_tenant_id,target_name,status,created_at}` |
| `POST /api/v1/auth/join-requests/{request_id}/cancel`（新增） | 账号 | 仅本人 pending 请求可取消，幂等返回该请求 |
| `POST /api/v1/auth/accept-invite`（新增） | 账号 | `{invite_token}`，新增/恢复有效成员资格，返回 `{workspace}`，不自动切换 |
| `DELETE /api/v1/auth/workspaces/{tenant_id}/membership`（新增） | 账号 | 退出自己的目标租户，`204`；最后管理员返回 409 |

切换个人：

```json
{
  "workspace_type": "personal",
  "tenant_id": null,
  "expected_context_version": 3
}
```

切换公司：

```json
{
  "workspace_type": "tenant",
  "tenant_id": "target-tenant-id",
  "expected_context_version": 3
}
```

这是两个互斥的合法请求，不能把 personal 与非空 tenant_id 混用。客户端不得传 role/capabilities。服务端重查目标 active membership 与 active tenant 后，把 context_version 更新为 4。切换到完全相同空间可幂等返回当前版本的新 token；版本不匹配返回 409，客户端刷新后显示真实状态，不自动重复旧的切换意图。

切换失败保留原会话空间。切换成功没有 refresh_token 字段，原刷新凭据继续有效。新响应必须提交完成后才能返回；旧上下文 token 发起业务请求被拒绝，客户端可通过原 refresh 凭据恢复。

管理端复用已存在的 `/api/v1/admin/users` 和 `/api/v1/admin/join-requests` 路由形状；返回中的现有 `id` 字段继续是账号 ID，role/tenant_id 是本空间成员信息。成员列表按 membership 查；改角色改 membership；“删除用户”接口在工作空间语义中改为移除成员，需同步 Web/Mobile 管理端文案，返回成功前完成资格失效。绝不能继续 `db.delete(user)`。

管理员批准待办只新增目标成员资格，权限必须来自当前工作空间 admin，拒绝跨租户 request_id。租户人数按 active membership 统计。邀请支持现有账号时不重建用户或覆盖密码。已是 active 成员重复申请返回现有成员状态，不能多建 pending 记录。

## 5. 个人聊天

所有 `/basic-chat/*` 要求 `get_current_personal_user`，未登录 401，公司空间 token 403。以下请求不允许 tenant_id、工具清单、知识库 ID、上传路径或模型配置字段。

| 方法与路径（均新增） | 请求 | 成功响应 |
| --- | --- | --- |
| `POST /api/v1/basic-chat/sessions` | `{title?}` | `201` + `{session_id,title,created_at,updated_at}` |
| `GET /api/v1/basic-chat/sessions` | `?cursor=&limit=` | `{items:[SessionSummary],next_cursor}` |
| `GET /api/v1/basic-chat/sessions/{session_id}` | `?cursor=&limit=` | `{session_id,title,messages:[Message],next_cursor}` |
| `PATCH /api/v1/basic-chat/sessions/{session_id}` | `{title}` | `{session_id,title,updated_at}` |
| `DELETE /api/v1/basic-chat/sessions/{session_id}` | 无 | `204`，删除本人会话及消息 |
| `POST /api/v1/basic-chat/messages` | `{session_id,turn_id,message}` | `200 text/event-stream` |

列表默认 limit=20、最大 100；消息默认最近 50 条、最大 100，页内按时间正序供显示，cursor 获取更早消息。相同时间以 ID 作稳定第二排序键；cursor 必须绑定当前 user_id、资源和排序。标题非空、最长 100 个字符；正文上限由服务端配置，超限在调用模型前拒绝。

SessionSummary 为 `{session_id,title,created_at,updated_at}`。Message 为 `{id,turn_id,role,content,status,created_at}`。时间使用北京时间 ISO 格式，带 `+08:00`。空会话在第一次发送前创建；标题首次可从文字确定性截取，避免为标题额外调用模型。

SSE 复用现有 `encode_sse`，示例与现有编码一致：

```text
data: {"type":"meta","session_id":"session-id","turn_id":"client-turn-id","workspace_key":"personal","context_version":4}

data: "你好"

data: "，有什么可以帮你？"

data: [DONE]

```

错误终态：

```text
data: {"type":"error","code":"model_unavailable","message":"暂时无法回复，请稍后重试。","retryable":true}

```

失败后停止输出，不再补 `[DONE]`。如果连接在终态前断开，客户端标为中断，读取会话核实状态。停止按钮取消当前网络 Task；后端关闭生成器和上游流，将该轮标记 cancelled。切换工作空间使用相同取消机制。

同一 user_id+turn_id 相同正文重传：streaming 返回 `409 turn_in_progress`；completed 返回保存结果的流式回放，不再次调用模型；failed/cancelled 返回 `409 turn_not_completed` 及既有状态。相同 turn_id 但正文或会话不同返回 `409 turn_conflict`。删除正在生成的会话需要先将轮次标记取消；生成端提交前重查会话存在及轮次状态，不能复活已删消息。

## 6. 能力发现与开关

扩展现有 `GET /api/v1/auth/capabilities`，保留原字段，增加 `phone_status_enabled/personal_registration_enabled/workspaces_enabled/personal_chat_enabled/initial_password_enabled`。

开关由服务端执行，新接口关闭时仍拒绝直接调用。个人注册启用前要求验证服务、验证码登录、账号级会话、个人聊天已可用；关闭注册不能让已有无密码用户无法登录。首次设密能力不依赖发送短信的开关。运行时工作空间 capabilities 与公共能力发现分别代表“当前权限”和“已上线功能”。

## 7. 错误与客户端处理

认证新增错误沿用现有 AuthFlowError 包装中的 `error_code/message/detail/request_id` 以及可选 retry_after，HTTP 状态保持语义一致。表内为建议新增码，已有同义码优先复用并同步契约；业务 404 继续不泄露对象归属。

| HTTP / error_code | 场景 | 客户端行为 |
| --- | --- | --- |
| 401 / invalid_session | 过期、撤销或无效账号凭据 | 至多刷新一次，失败才退出 |
| 401 / workspace_context_stale | 同设备使用旧空间版本 | 刷新真实上下文；取消旧空间业务请求 |
| 403 / tenant_required | 个人调用租户接口 | 保持账号登录，提示选择公司空间 |
| 403 / personal_workspace_required | 公司上下文调用个人聊天 | 需用户主动切换个人空间 |
| 403 / workspace_unavailable | 成员资格或租户不可用 | 刷新恢复个人或选择其他空间 |
| 409 / workspace_context_conflict | 并发切换导致版本不匹配 | 刷新状态，不自动重复旧动作 |
| 409 / password_already_set | 首次设密覆盖已有密码 | 更新 me，转普通修改密码入口 |
| 409 / phone_already_registered | 注册时手机号被并发占用 | 转登录，不自动用注册凭据登录 |
| 409 / last_workspace_admin | 最后一位管理员退出/移除/降权 | 提示先转交管理员资格 |
| 404 | 非本人的会话、跨租户业务对象 | 展示不存在，不自动换空间寻找 |
| 429 | 手机号预检、短信、聊天频率或额度超限 | 读取 Retry-After 或明确额度错误，不循环重试 |
| 422 | 无效字段或空间结构 | 修正请求，不降级为默认租户 |

新增写操作必须明确幂等或并发语义。验证码仍单次消费；退出/撤销及移除本人资格幂等；审批用状态条件更新；聊天按 turn_id；空间切换按 context_version。各机制互不代替。

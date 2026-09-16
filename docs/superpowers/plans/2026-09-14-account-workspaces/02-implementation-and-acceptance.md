# 逐文件实施、迁移与验收清单

日期：2026-09-14。以下均为待实施任务。业务设计见 [README.md](README.md)，字段和端点见 [01-api-contract.md](01-api-contract.md)。

路径根目录固定为：

- 后端 B：`/Users/blackwave/Documents/duizhangAgent`。
- iOS I：`/Users/blackwave/Documents/Crest`。

下表路径相对各自根目录；“修改/核验”均已确认现有文件存在，“新增”为建议新文件名，尚未创建业务文件。不要把新增文件表当作已实现成果。

## 1. 后端模型和迁移

| 编号 | 类型 | 具体文件（B 下） | 工作与完成条件 |
| --- | --- | --- | --- |
| B01 | 修改 | `src/app/repository/models/user.py` | 用户密码与 tenant_id 可空；保留旧兼容列；加入 `TenantMembership` ORM 映射已有 `tenant_memberships`；申请来源可空。成员唯一约束、状态和外键与迁移一致 |
| B02 | 修改 | `src/app/repository/models/auth_session.py` | 增加 workspace_type/context_version/refresh_token_version；tenant_id 可空；校验 personal/tenant 字段组合；增加按 user_id 撤销的索引 |
| B03 | 新增 | `src/app/repository/models/personal_chat.py` | 两张个人聊天表、所有者复合外键、轮次幂等键和分页索引；无 tenant_id |
| B04 | 修改 | `src/app/repository/models/billing.py` | `LlmUsageRecord` 增加 workspace_type 和作用域约束；个人用量 tenant_id=NULL、user_id 必填；租户用量保持原约束 |
| B05 | 修改 | `src/app/repository/models/__init__.py` | 注册新增 ORM，确保运行时与 Alembic 导入到同一 metadata |
| B06 | 核验/必要时修改 | `alembic/env.py` | 确认新模型纳入迁移 metadata，不改变数据库时区 |
| B07 | 新增 | `alembic/versions/20260914_01_account_workspaces.py` | 账号/会话结构、既有 membership 补约束与用户归属回填；revision 建议 `acw_20260914_01`，down_revision 取实施时实际 head |
| B08 | 新增 | `alembic/versions/20260914_02_personal_chat_usage.py` | 新聊天表、用量作用域及索引；revision 建议 `acw_20260914_02`，依赖 B07 |
| B09 | 新增 | `src/scripts/audit_account_workspaces.py` | 只读输出重复成员、孤立关系、手机号冲突、成员回填覆盖率和旧列依赖摘要；不得输出手机号明文或连接凭据 |

不得重新执行历史 `a1b2c3d4e5f6_add_reconcile_tables_tenant_memberships_indexes.py`。它证明成员表已有迁移定义，但不能据此认定生产表已建立或无数据。新迁移要先核对实际版本链；不随意建第二个 membership 表绕过历史数据。

## 2. 后端认证、工作空间与管理

| 编号 | 类型 | 具体文件（B 下） | 工作与完成条件 |
| --- | --- | --- | --- |
| B10 | 修改 | `src/app/core/deps.py` | 共享令牌/账号/会话检查；新增账号和个人依赖；现有 get_current_user 从当前空间与 membership 返回非空租户、成员角色；每请求查当前资格 |
| B11 | 核验/必要时修改 | `src/app/core/middleware.py` | 排查 Header-only tenant 提取调用；用户业务上下文来自已验证身份，X-Tenant-ID 不授予权限 |
| B12 | 修改 | `src/app/services/auth/token_service.py` | 签发 sid/workspace_type/context_version；用户安全版本继续生效；旧无 sid token 有明确拒绝期限，平台 token 隔离 |
| B13 | 修改 | `src/app/services/auth_session_service.py` | a2 账号级刷新、旧格式兑换、锁内验证与轮换；切换仅更新本会话；停用租户仍可恢复个人；logout 不被失效租户阻挡；辅助方法支持外层事务 |
| B14 | 新增 | `src/app/services/auth/workspace_service.py` | 仅封装本次确实复用的空间列表/选择/权限快照、成员激活/移除、最后管理员保护；不引入通用权限引擎 |
| B15 | 修改 | `src/app/services/auth/user_lookup.py` | 统一手机号预检与登录解析；已验证手机号、旧手机用户名、冲突账号分别处理，不自动合并 |
| B16 | 修改 | `src/app/services/auth/verification_service.py` | personal_register 用途无邀请码；与 register/login/reset 凭据严格区分；可选登录态支持个人；保留供应商、验证码和冷却逻辑 |
| B17 | 修改 | `src/app/services/auth/account_service.py` | 个人注册；首次设密；空哈希安全失败；账号级联系方式/修改密码移除单一租户前提；旧邀请注册也创建 membership |
| B18 | 修改 | `src/app/services/auth/password_service.py` | 空哈希不得传入验证器；首次设密 NULL 条件更新并与普通改密分开；账号操作按 user_id，重置失效覆盖全部空间 |
| B19 | 修改 | `src/app/services/auth/rate_limit_service.py` | 复用限流基础能力接手机号只读预检，返回冷却时间；手机号用哈希构造限流键 |
| B20 | 修改 | `src/app/services/auth/errors.py` | 只补现有码表缺少的错误；保持 AuthFlowError 包装兼容 |
| B21 | 修改 | `src/app/api/v1/auth.py` | 扩展登录 schema、实现预检/注册/首次设密/me/空间/申请/接受邀请路由；单一响应转换函数；preferences 继续租户隔离 |
| B22 | 修改 | `src/app/api/v1/admin.py` | 成员查询、角色、人数、移除改用 membership；审批不覆盖用户租户；禁止租户管理员覆盖账号密码；无来源租户可正常展示 |
| B23 | 修改 | `src/app/services/registration_invite_service.py` | 已有账号接受邀请只激活成员资格，邀请消费与成员写入同一数据库事务；保留过期、撤销、角色及一次性使用规则 |
| B24 | 修改 | `src/app/api/v1/platform_admin.py` | 按指定租户筛成员与人数；全局账号与成员角色操作明确分开；清理原单租户的删除与赋权假设 |
| B25 | 修改 | `src/app/services/tenant_lifecycle_service.py` | 通用租户清除不能凭“有 tenant_id 列”删除全局 User 或账号会话；停用/删除租户只清对应业务/成员；设备上下文恢复个人，个人数据及其他成员资格保留 |
| B26 | 修改 | `src/app/config/settings.py` | 注册/工作空间/个人聊天/首次设密等开关和依赖校验；个人模型、请求大小、输出及额度配置；首次设密不强行依赖 SMS 开关 |

事务是这部分的实施重点。现有注册、密码和会话辅助方法有内部 commit；引入服务后需允许外层控制事务，防止“用户已创建但设备会话失败”或“邀请已消费但成员未创建”。Redis 验证凭据仍按单次消费处理，失败路径明确提示重新验证。

租户清理目前按模型 metadata 扫描 tenant_id 列；保留在 User 上的兼容列不能被当作数据所有权。B25 与个人注册必须同批完成，这不是后续清理项。

## 3. 个人聊天与既有业务隔离

| 编号 | 类型 | 具体文件（B 下） | 工作与完成条件 |
| --- | --- | --- | --- |
| B27 | 新增 | `src/app/api/v1/basic_chat.py` | 个人会话 CRUD、历史分页、SSE 发送；请求拒绝越权字段；依赖 get_current_personal_user |
| B28 | 新增 | `src/app/services/basic_chat_service.py` | 按 user_id 操作个人聊天表；有界上下文、turn_id 幂等、额度与并发占位、流取消和终态持久化；只调用个人 adapter |
| B29 | 修改 | `src/app/model/router.py` | 新增 personal_adapter，从服务端个人配置创建已有适配器，调用链不查询 Tenant 或租户模型缓存 |
| B30 | 修改 | `src/app/model/usage_context.py` | 增加工作空间类型；个人入口可明确清空 tenant_id 而不继承外层；finally 恢复 ContextVar |
| B31 | 修改 | `src/app/model/stats.py` | 用量数据支持 workspace_type 与可空租户，个人 user_id 必填；序列化保留新字段 |
| B32 | 修改 | `src/app/model/base.py` | 把真实用量上下文写入 TokenStats；流取消/异常时显式关闭底层流；保留供应商真实/估算用量标记 |
| B33 | 修改 | `src/app/services/llm_usage_service.py` | 持久化新增作用域且保留 request_id 幂等；不能给个人补 default 租户 |
| B34 | 修改 | `src/app/services/billing_summary_service.py` | 月度租户汇总显式过滤 tenant 作用域；避免 NULL 个人用量被写入租户 BillingSummary 或扣租户额度 |
| B35 | 核验/必要时修改 | `src/workers/billing_worker.py` | 新旧用量载荷兼容，部署先升级消费者；错误保持既有重试约定 |
| B36 | 修改 | `src/app/main.py` | 挂载 basic_chat.router；错误转换与生命周期只复用现有机制 |
| B37 | 复用/核验 | `src/app/services/chat_events.py`、`src/app/api/adapters/sse_chat_adapter.py` | 复用既有文本/元数据/完成/错误事件；个人无业务工具事件。Failed 必须终止流 |
| B38 | 复用/核验 | `src/app/api/v1/chat.py`、`src/app/services/chat_orchestrator.py` | 仍为租户链路；个人不能进入。切换/资格失效时停止后续流事件或工具副作用，保留任务原始租户上下文 |
| B39 | 复用/核验 | `src/app/api/v1/sessions.py`、`src/app/repository/conversation_repository.py` | 租户历史继续 tenant_id+user_id；个人历史不从这里读 |

对 B38 的长流授权复查放在现有编排/交付边界；有副作用的 AgentRequest 仍不可变。如果当前请求对象缺少 sid/context_version，只扩展已有对象及其实际调用链，不另造第二套授权上下文。

上线前从 `app.routes` 导出已挂载路由的递归依赖摘要，覆盖 `/chat`、`/sessions`、`/file`、`/reconcile`、`/analytics`、`/kb`、`/tasks`、`/reports`、连接器、Agent runs、通知和自动化的实际前缀。测试按真实 path 和 method 参数化，不能仅检查函数里是否出现 Depends 字样。业务源码只修改确实缺少门禁/作用域或需要流失效检查的位置。

## 4. iOS 具体文件

| 编号 | 类型 | 具体文件（I 下） | 工作与完成条件 |
| --- | --- | --- | --- |
| I01 | 修改 | `Crest/API/APIClient.swift` | 预检改为 async throws 返回完整状态；注册新 purpose；新增注册/首次设密/me 调用；tenantID/role 可空；拆分完整 SessionResponse 与切换响应 |
| I02 | 新增 | `Crest/Models/WorkspaceModels.swift` | AccountProfile、WorkspaceContext、WorkspaceSummary、Capabilities；明确 unknown 状态默认关闭能力 |
| I03 | 新增 | `Crest/API/WorkspaceAPI.swift` | 空间列表、切换、申请列表/提交/取消、退出、接受邀请；复用 APIClient 的请求和错误处理 |
| I04 | 修改 | `Crest/API/ChatAPI.swift` | 明确个人与租户路径、分页和 DTO 映射；复用 SSE parser；turn_id、取消、完成前断流处理；不接受调用方任意指定 tenant_id |
| I05 | 修改 | `Crest/Session/SessionStore.swift` | 保存服务端账号与空间；序列化 refresh/switch；分开 applySession/applyWorkspace；阻止跨空间自动重试；全局安全失效与空间失效分别处理 |
| I06 | 核验 | `Crest/Session/KeychainStore.swift` | 沿用 refresh token 存储；确认无三段租户格式假设。切换时不删除或覆盖 refresh token |
| I07 | 修改 | `Crest/Views/LoginView.swift` | 接通未注册分支；验证后个人注册直接登录；已注册无密码走验证码；冲突/限流不伪装为未注册 |
| I08 | 修改 | `Crest/Views/RootView.swift` | 恢复期间展示加载；有效空间下进入共用聊天界面；以账号+空间+context_version 重建局部状态 |
| I09 | 修改 | `Crest/Views/ChatView.swift` | 当前模式明确选择 API；个人通用建议、公司业务建议；切换取消全部任务，晚响应丢弃；分页/删除/重命名接对应已存在或新增端点 |
| I10 | 修改 | `Crest/Components/Shared/AppSidebar.swift` | 当前空间名称、选择入口；历史严格属于当前空间；个人不显示公司业务入口 |
| I11 | 新增 | `Crest/Components/Shared/WorkspaceSwitcherSheet.swift` | 个人+公司列表，当前选中、不可用、切换中状态；加入工作空间表单及申请状态复用同一 sheet，不做独立门户页 |
| I12 | 修改 | `Crest/Components/Shared/AppSettingsSheet.swift` | 账号级完善密码入口、当前公司角色；移除/退出工作空间与退出账号分开；保持反馈模式一致 |
| I13 | 新增 | `Crest/Views/InitialPasswordView.swift` | 新密码/确认密码、规则校验、提交和错误；成功更新账号资料并关闭，不重新发短信 |
| I14 | 修改 | `Crest.xcodeproj/project.pbxproj` | 当前工程为显式文件引用，添加新文件 target membership；新增测试 target，不只在目录创建 Swift 文件 |

不要求新建 `PersonalHomeView` 或复制 `BasicChatView`。已有展示足以共用，数据入口在 API 层有明确分支。`APIClient` 当前通用请求函数是 private，I03 接入时只将需要复用的请求 helper 收敛到合适可见性，避免复制网络错误处理。

I08/I09/I10/I12 等文件当前已有用户改动；实施时先读取工作树内容，在现有改动上追加。不要回滚外观和交互变更。

独立 Web/Mobile 仓库也消费后端返回值和管理端操作。它们不是本轮已核对的源码范围，不能虚构其文件路径；发布门槛包括在这些仓库核实 nullable tenant/成员移除文案/空间切换前端支持。旧租户功能兼容由后端回归覆盖，新增个人空间只向支持新契约的客户端开放。

## 5. 测试文件

以下为实施阶段要新增或扩展的测试；本轮方案文档未运行这些业务测试。

| 位置 | 类型 | 必须覆盖 |
| --- | --- | --- |
| B `tests/unit/test_auth_models.py`、`test_auth_refresh_session_model.py` | 扩展 | 空密码/空租户、会员约束、会话空间约束；既有模型仍可用 |
| B `tests/unit/test_auth_account_api.py`、`test_auth_verification_api.py`、`test_auth_user_lookup.py` | 扩展 | 预检无短信、手机号旧用户名兼容、个人注册、验证码用途、无密码登录、首次设密 |
| B `tests/unit/test_auth.py`、`test_auth_token_service.py`、`test_auth_session_service.py` | 扩展 | 个人与租户依赖、令牌版本、a2/旧格式、停用恢复、账号级撤销 |
| B `tests/unit/test_workspace_service.py` | 新增 | 多租户角色、批准/拒绝/重复接受邀请、只移除成员、最后管理员保护 |
| B `tests/unit/test_workspace_api.py` | 新增 | 列表、切换/冲突、申请所有权、个人/公司模式互斥、权限快照 |
| B `tests/unit/test_personal_chat_api.py` | 新增 | 个人 CRUD/分页、跨账号 404、越权字段 422、公司 token 拒绝、SSE 终态 |
| B `tests/unit/test_personal_chat_service.py` | 新增 | 模型输入仅本人文字、无租户工具调用、turn_id 重传不重复生成、取消/崩溃恢复/删除竞态 |
| B `tests/unit/test_personal_tenant_isolation.py` | 新增 | 参数化真实租户路由：个人被拒绝且业务/存储/缓存/派发调用次数为零 |
| B `tests/unit/test_model_router_tenant_config.py`、`test_llm_usage_recording.py`、`test_llm_usage_persistence.py`、`test_billing_summary_service.py` | 扩展 | 个人模型不读租户配置；None 清除作用域；个人用量不入租户账单；真实及估算用量兼容 |
| B `tests/unit/test_tenant_lifecycle_service.py`、`test_platform_admin.py` | 扩展 | 删除/停用 A 公司保留账号、个人数据、B 公司资格；成员角色不能改变全局账号安全属性 |
| B `tests/integration/test_auth_concurrency.py`、`test_auth_redis_atomicity.py` | 扩展 | 同号并发注册、凭据单次消费、首次设密并发、切换/刷新竞争 |
| B `tests/integration/test_account_workspace_migration_postgres.py` | 新增 | 真 PostgreSQL 迁移、回填冲突/唯一键/外键、旧接口在线新增兼容和不可逆降级保护 |
| B `tests/integration/test_workspace_isolation.py` | 新增 | 同一账号双租户、同设备切换、双设备独立、成员撤销后长流/下载/任务权限 |
| I `CrestTests/AuthFlowTests.swift` | 新增 | 四种预检分支、验证码注册、无密码登录、首次设密不丢会话 |
| I `CrestTests/WorkspaceSessionTests.swift` | 新增 | 切换无 refresh_token 响应可用、刷新/切换顺序、失败保持旧态、跨空间不重放 |
| I `CrestTests/ChatWorkspaceTests.swift` | 新增 | 个人/租户路径、晚到响应不串历史、Failed 停流、turn_id 重试、分页所有权 |

iOS 当前未发现 CrestTests target；I14 要真正配置可运行单测，测试网络通过 URLProtocol stub 或现有可注入 URLSession 完成，测试不能依赖真实短信或付费模型。数据库并发和约束用真 PostgreSQL/Redis 的隔离环境，不能仅以 SQLite 测试通过替代。

## 6. 建议实施批次

所有批次属于完整需求；每批完成后有独立验收结果。先打通权限和持久化再接 UI 开关。

| 顺序 | 范围 | 完成门槛 |
| --- | --- | --- |
| 1 | B01-B09：数据结构与只读预检 | 空租户/空密码账号可存；历史关系回填可解释；无数据丢失；异常迁移可阻止 |
| 2 | B10-B14、B21 的空间/会话部分 | 账号能登录恢复；个人请求租户入口被拒；A/B/个人空间切换与会话竞争测试通过 |
| 3 | B15-B26：注册、密码、成员及生命周期 | 手机号验证直接个人登录；设密不踢登录；加入不覆盖原资格；租户删除不伤全局账号 |
| 4 | B27-B39：个人聊天与计量 | 个人 CRUD/SSE 全通；无租户调用；额度有效；个人不入租户账单；长流隔离通过 |
| 5 | I01-I14：iOS 接入 | 新注册直接聊天；设置密码；申请/切换/退出；重启恢复；历史与草稿无跨空间混用 |
| 6 | 联调与受控开放 | 真数据库迁移、并发、安全边界、旧客户端和独立管理端回归全部满足 |

不以“登录接口返回了 tenant_id=null”作为阶段完成。至少需要个人刷新、基本聊天、设密和租户门禁同时可用，才能打开个人注册入口。

## 7. 产品验收表

| 编号 | 操作 | 预期 |
| --- | --- | --- |
| A01 | 输入未注册手机号点继续 | 仅预检，无短信发送和 challenge 记录 |
| A02 | 发送个人注册验证码并确认 | 不要求邀请、用户名、密码，进入个人聊天 |
| A03 | 无密码账号退出后再次登录 | 进入验证码登录，不走密码死路 |
| A04 | 首次完善密码，含双请求并发 | 恰好一次成功，不覆盖密码，不撤销当前会话，后续密码登录可用 |
| A05 | 另一设备读取账号资料 | has_password 与服务端一致，无本地记录偏差 |
| A06 | 个人 token 访问聊天旧接口/文件/对账/分析/知识库 | 403，业务和存储未调用 |
| A07 | 个人聊天要求“读取我公司的账单” | 不调用业务工具，不查询任何租户数据 |
| A08 | 猜测其他个人账号或租户会话 ID | 404，不泄露内容或归属 |
| A09 | 同一账号加入 A、B 公司 | 同时保留个人/A/B，审批不覆盖原归属 |
| A10 | A 为 member、B 为 admin | 仅 B 可执行本空间管理操作，A 不继承 admin |
| A11 | A 切个人，使用切换前 token 发起请求 | 旧 token 不能继续访问 A；刷新恢复个人 |
| A12 | 手机在 A，另一台设备在个人 | 各自独立，同账号空间不互相跳转 |
| A13 | 切换时旧历史/SSE 请求晚返回 | 不写入新空间，不重发旧消息到新空间 |
| A14 | 被移出 A 或 A 停用 | A 后续请求拒绝；刷新进入个人；B 可继续使用 |
| A15 | A 管理员移除成员或删除 A 租户 | 不删账号、不删个人历史、不删 B 资格、不改全局密码 |
| A16 | 个人与 A 分别聊天 | 各自历史独立；个人用量不入 A 的账单 |
| A17 | 断网重传同 turn_id、取消或删除正在生成的会话 | 不重复模型调用，不复活已删除记录，终态正确 |
| A18 | 旧租户账号登录/刷新/对账 | 原业务可用；过渡截止后通过刷新升级，不接受无上下文旧 token 绕过切换 |
| A19 | 忘记密码重置 | 全账号所有空间旧会话失效，与首次设密不同 |
| A20 | 无 membership 或跨租户 request_id/文件 ID | 切换/审批/下载均被拒，不能靠 Header 提权 |

## 8. 发布检查与本次交付状态

发布前记录实际代码基线、Alembic head、客户端最低契约版本、兼容截止时间、开关值、Worker 版本及回退版本。不要在方案里伪造已执行测试、生产表状态或已验证短信供应商能力。

观测聚焦注册成功率、短信登录成功率、刷新与切换失败、个人租户越权拒绝、SSE 中断和作用域用量异常。日志使用 request_id/sid 的脱敏关联，不记录手机号明文、验证码、token 或模型密钥。

本次实际交付：本目录三份 Markdown 方案。本任务未创建表、未新增业务接口、未改 iOS 功能、未运行业务测试、未提交或推送。

交付前已完成静态核对：45 处“修改/核验/复用”的现有源码路径全部存在，三个文件的相对文档链接均有效，5 段 JSON 示例均可解析；认证验证码和管理端接口前缀已对照源码。新增文件名为实施建议，Alembic 实际 head、生产数据和运行结果仍需实施时验证。

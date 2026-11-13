# 分层与依赖方向

## 四层职责

| 层 | 职责 | 允许依赖 |
| --- | --- | --- |
| interfaces（接入层） | 协议适配：HTTP / RPC / MQ 消费者、参数格式校验、响应组装、异常映射 | application |
| application（应用层） | 用例编排、事务边界、权限与幂等、事件发布、外部调用编排 | domain（可少量使用 Spring 事务 / 事件抽象） |
| domain（领域层） | 业务规则、状态与不变式、聚合、值对象、领域服务、领域事件、端口接口 | 仅 JDK 与自身 |
| infrastructure（基础设施层） | 仓储实现、ORM PO 与转换、外部系统适配器 ACL、消息与缓存实现、配置 | domain（实现其端口），不得依赖上层 |

依赖箭头：`interfaces → application → domain ← infrastructure`。infrastructure 通过实现 domain 声明的接口被注入，编译期依赖指向 domain。

## 推荐包结构

优先按限界上下文分包，上下文内部再分层，避免把所有上下文的 domain 混成一个大包：

```
com.example.{context}/
├── interfaces/
│   ├── rest/            XxxController, XxxRequest, XxxResponse
│   ├── mq/              XxxListener
│   └── assembler/       Request/Response 与 Command/DTO 的转换
├── application/
│   ├── service/         XxxAppService / XxxUseCase
│   ├── command/         XxxCommand, XxxQuery
│   ├── dto/             XxxDTO
│   └── assembler/       Domain 与 DTO 的转换
├── domain/
│   ├── model/           聚合根、实体、值对象（可按聚合再分包）
│   ├── service/         领域服务
│   ├── event/           领域事件
│   ├── repository/      仓储接口（端口）
│   ├── gateway/         外部服务端口接口
│   └── exception/       领域异常
└── infrastructure/
    ├── persistence/
    │   ├── po/          XxxPO
    │   ├── mapper/      Mapper / JpaRepository
    │   ├── converter/   Domain 与 PO 转换
    │   └── repository/  XxxRepositoryImpl
    ├── client/          外部系统适配器 + 外部 DTO
    ├── mq/              消息发布 / 消费实现
    └── config/          Spring 配置
```

若项目已按层优先分包（`com.example.domain.order` 等），沿用项目结构，不得为了「标准」而搬迁包。

## 依赖矩阵

| 从 \ 到 | interfaces | application | domain | infrastructure |
| --- | --- | --- | --- | --- |
| interfaces | - | 允许 | 仅读类型（不推荐，宜经 DTO） | 禁止 |
| application | 禁止 | - | 允许 | 禁止（只允许注入 domain 端口，由 infra 实现） |
| domain | 禁止 | 禁止 | - | 禁止 |
| infrastructure | 禁止 | 禁止 | 允许 | - |

具体禁止的 import 样例：

- domain 禁止：`org.springframework.*`、`javax.persistence.*`、`jakarta.persistence.*`、`org.mybatis.*`、`com.baomidou.*`、`com.fasterxml.jackson.*`、`javax.servlet.*`、`jakarta.servlet.*`、`..interfaces..`、`..application..`、`..infrastructure..`。
- application 禁止：`..infrastructure..`（含实现、PO、Mapper）、`javax.persistence.*`、`jakarta.persistence.*`、`..interfaces..`。
- interfaces 禁止：`..domain.repository..`、`..infrastructure..`、`@Transactional`。
- infrastructure 禁止：`..interfaces..`、`..application..`（确有事件监听等例外时，用 domain 层接口解耦并在报告中说明）。

## 对象流转

```
HTTP Request (VO)
  -- interfaces/assembler --> Command / Query
  -- application ----------> 调用聚合行为、读写 Repository 端口
  -- infrastructure ------> Domain <-> PO 转换后落库
  -- application ----------> Domain -> DTO
  -- interfaces/assembler -> Response (VO)
```

转换规则：

- VO / Request / Response 只在 interfaces；Command / Query / DTO 在 application；PO 只在 infrastructure。
- 转换代码放在转换发生层：Domain ↔ PO 在 infrastructure，Domain ↔ DTO 在 application 或 interfaces 的 assembler（项目二选一，保持一致）。
- 禁止领域对象、PO 直接序列化到响应；禁止把 HTTP Request 对象传进领域方法。
- 查询侧（读模型）允许 infrastructure 直接返回专用 DTO 给 application 的 QueryService，但不得复用写模型的聚合与仓储接口；须在报告中说明这是有意偏离。

## 端口与适配器

- 需要持久化时：domain 声明 `XxxRepository` 接口，infrastructure 提供 `XxxRepositoryImpl`。
- 需要外部系统时：domain 声明 `XxxGateway` 接口（参数与返回值均为领域类型），infrastructure 提供适配器，外部 DTO 不得越过适配器边界。
- 需要发布领域事件时：domain 只产生事件对象；由 application 在事务提交后发布，或由 infrastructure 的 Outbox 实现落库，domain 不依赖消息中间件。

## 分层守护

用 ArchUnit 把上述矩阵写成可执行测试，模板见 `assets/templates/ArchUnitLayerTest.java.tpl`。至少覆盖：

1. domain 不依赖任何框架与其他层。
2. application / interfaces / infrastructure 不反向依赖 interfaces。
3. domain 与 infrastructure 的 PO 包之间没有双向依赖。
4. `*RepositoryImpl` 只出现在 infrastructure。

## 落层自检

新增每个文件前回答：它包含业务规则吗（→ domain）？它编排用例或划事务吗（→ application）？它处理协议吗（→ interfaces）？它处理存储或第三方技术细节吗（→ infrastructure）？回答不唯一时，拆分文件而不是塞进一层。

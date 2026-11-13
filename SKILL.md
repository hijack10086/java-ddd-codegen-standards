---
name: java-ddd-codegen-standards
description: 规范 Java 领域驱动设计 DDD 项目的代码生成、修改与评审。当需要新增或修改 Java 接口、聚合根、实体、值对象、领域服务、应用服务、仓储、Controller、DTO、测试，或请求 DDD 分层改造、Java 代码规范检查、Java 代码评审时，应使用本技能；它强制四层依赖方向、聚合边界、事务边界、领域模型与持久化隔离，并在交付前执行构建与分层校验门禁。不适用于非 Java 项目、纯配置或文档改动、架构选型论证。
agent_created: true
---

# Java DDD 代码生成规范

## 目标

生成「分层清晰、领域模型充血、依赖方向单向、可验证」的 Java 代码。先继承项目既有约定，再套用内置规范，最后用可执行检查证明合规。

## 触发与不触发

- 触发：编写 / 修改 / 评审 Java 代码；新增用例、聚合、领域事件、接口、仓储、消息消费者；DDD 分层改造；Java 代码规范自查。
- 不触发：非 Java 代码；纯配置或文档改动；架构选型讨论（只给建议，不生成代码）。

## 优先级规则

1. 项目内已有约定（包结构、命名、基类、工具类、ORM 选型、Java 版本、构建工具、代码风格配置）优先于本技能内置规范。
2. 项目约定与内置规范冲突时，按项目约定实现，并在交付报告中列出冲突项，不擅自「纠正」项目。
3. 项目无约定时，采用 `references/` 中的默认值，并在报告中声明采用了哪些默认假设。
4. 用户明确要求违反某条红线时，先说明后果并取得确认；未确认前不得执行。

## 四条不变量（P0，任何生成都不得破坏）

1. **依赖方向单向**：interfaces → application → domain ← infrastructure。domain 只依赖 JDK 与自身，禁止出现 Spring、JPA、MyBatis、Jackson、Servlet 等框架 import；任何层不得反向依赖上层。
2. **领域模型与持久化隔离**：domain 中只有业务对象，不出现 PO / DO / ORM 注解与数据库字段；ORM 对象留在 infrastructure，转换在同层完成。
3. **聚合边界**：一个事务只修改一个聚合；聚合间只通过 ID 引用；跨聚合一致性用领域事件做最终一致。
4. **事务边界在 application**：domain 不感知事务，Controller 不开事务，外部远程调用不得包在长事务里。

## 工作流

### Step 1 Probe（先探测，后动手）

按 `references/project-context.md` 探测并记录：构建工具与 Java 版本、现有分层包结构、同类构件的命名与基类、ORM 与对象映射方式、测试框架、格式化 / 静态检查 / ArchUnit 配置、团队规范文件。至少打开一个同层同类文件作为风格样本。探测不到的信息列为假设，不要凭空猜测。

### Step 2 Clarify（只在必要时）

仅在聚合边界、用例输入 / 输出契约、兼容版本、并发或幂等要求不明确时提问，一次最多 3 个问题。能从代码推断的信息不得提问。需求已完整时跳过本步。

### Step 3 Plan（列出改动清单）

输出：新增 / 修改文件全路径及所属层、对外接口签名、依赖的既有类、对象转换链路、领域事件与事务边界、测试清单。按 `references/layering.md` 校验每个文件的落层。新增或修改超过 5 个文件时，先把清单交给用户确认再生成。

### Step 4 Generate（按层生成）

以 `assets/templates/` 的骨架起步，遵循 `references/coding-standards.md`；各层细则分别读取 `references/domain-model.md`、`application-layer.md`、`infrastructure.md`、`interfaces.md`。遵循最小改动：不重写无关文件、不顺手重构、不引入未声明依赖、不改动无关配置。新增功能必须同时产出对应测试，见 `references/testing-and-gate.md`。

### Step 5 Gate（验证，不得跳过）

运行 `python scripts/check_changes.py` 做分层与命名静态校验；运行 `python scripts/lint_gate.py` 执行项目已有的编译、静态检查与测试。两项均通过才进入交付。失败时修复后重跑，或如实标注失败原因与未执行项，不得把「未运行」写成「通过」。缺少构建工具或本地工具链时如实记录，禁止擅自安装依赖或修改构建配置来绕过。

### Step 6 Report（固定三段）

1. **改动清单**：文件路径 + 所属层 + 一句话职责。
2. **验证结果**：实际执行的命令、退出码、失败项；未执行项明确标注。
3. **风险与未决项**：采用的默认假设、与项目约定的冲突、遗留 TODO、需要人工确认的业务规则。

## 硬性红线

- 禁止整文件重写、修改无关文件、用占位实现（空方法、返回固定值、TODO 桩）冒充完成品。
- 禁止 domain 层引入框架注解 / 依赖；禁止在 domain 中使用字段注入或静态工具类承载业务规则。
- 禁止贫血模型：只有 getter / setter 的实体加上把逻辑全堆在 Service；禁止公共 setter 暴露聚合内部状态。
- 禁止领域对象直接作为 HTTP 请求 / 响应体；禁止 ORM PO 泄露到 application / domain。
- 禁止吞异常（空 catch）、用异常做流程控制、返回 null 集合、在日志中打印敏感信息、使用 `System.out`。
- 禁止硬编码密钥 / 地址、引入未在 `pom.xml` 或 `build.gradle` 声明的依赖、伪造或跳过验证结果。
- 禁止使用高于项目 Java 版本的语法（例如 Java 8 项目中使用 record、var、sealed）。

## 资源索引

| 场景 | 读取或执行 |
| --- | --- |
| 每次任务开始 | `references/project-context.md` |
| 判断文件落在哪层、对象如何转换 | `references/layering.md` |
| 聚合 / 实体 / 值对象 / 领域事件 / 仓储接口 | `references/domain-model.md` + `assets/templates/` 中对应骨架 |
| 用例 / 应用服务 / 事务 | `references/application-layer.md` + `ApplicationService.java.tpl` |
| 仓储实现 / PO / 外部客户端 | `references/infrastructure.md` + `RepositoryImpl.java.tpl` |
| Controller / VO / 异常映射 | `references/interfaces.md` |
| 命名、异常、日志、类型、Lombok | `references/coding-standards.md` |
| 写测试、分层守护、门禁命令 | `references/testing-and-gate.md` + `ArchUnitLayerTest.java.tpl` |
| 生成后静态自检 | `scripts/check_changes.py` |
| 编译与测试验证 | `scripts/lint_gate.py` |
| 交付前逐项核对 | `references/delivery-checklist.md` |

## 迭代

实际使用中出现规则缺失或误判时，只修改对应的 reference 或脚本，不把细节堆回本文件；保持 SKILL.md 精简可读。

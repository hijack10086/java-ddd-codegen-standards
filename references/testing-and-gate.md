# 测试与验证门禁

生成的功能必须带测试；测试分层与被测代码分层一致。禁止以「环境跑不了」为由默认跳过，只能如实记录。

## 测试分层

| 被测层 | 测试类型 | 约束 |
| --- | --- | --- |
| domain | 纯单元测试 | 不启动 Spring 上下文、不连 DB、不写 `@SpringBootTest`；毫秒级 |
| application | 单元测试 + 事务行为测试 | Mock domain 端口接口；验证调用顺序、异常路径、事件发布 |
| infrastructure | 集成测试 | 用项目已有的 Testcontainers / H2 / 内嵌 DB；验证 PO 与 Domain 双向转换、乐观锁、唯一约束 |
| interfaces | MockMvc / WebTestClient | 验证参数校验、异常映射、响应结构 |
| 全局 | ArchUnit 分层守护 | 把依赖矩阵写成可执行规则，防止分层腐化 |

## 必须覆盖的场景

- 聚合：不变式校验、合法状态流转、非法流转抛异常、领域事件是否产生。
- 值对象：相等性、边界值校验、不可变性（无 setter）、金额精度与币种。
- 应用服务：找不到聚合、幂等重复请求、外部端口失败时的回滚、事件是否在提交后发布。
- 仓储实现：save 后再 findById 能完整还原聚合（含子实体与值对象）。
- 接入层：缺字段 / 越权 / 领域异常映射的响应码。
- 至少一条失败路径测试，禁止只测 happy path。

## 测试写法

- JUnit 版本按项目（4 或 5）；断言库沿用项目（AssertJ / JUnit Assertions），不引入新依赖。
- 结构 `given / when / then`，一个测试方法验证一个行为，方法名描述行为（`confirm_onCreatedOrder_changesStatus`）。
- 用测试专用构造（静态工厂 / `reconstitute`）准备聚合，不通过反射塞字段、不依赖数据库造数据。
- 断言对象状态与异常类型 / 错误码，不只断言「不抛异常」。
- 时间、随机数、ID 生成等不确定性通过传入固定值或 Clock 抽象控制；禁止 `Thread.sleep` 等待异步结果。

## ArchUnit 分层守护

模板见 `assets/templates/ArchUnitLayerTest.java.tpl`。最低要求：

1. domain 包中的类不得依赖 `org.springframework`、`javax.persistence`、`jakarta.persistence`、`org.mybatis`、`com.baomidou`、`com.fasterxml.jackson`。
2. domain 不得依赖 interfaces / application / infrastructure 包。
3. interfaces / application 不得依赖 infrastructure 包。
4. `*RepositoryImpl` 类只驻留 infrastructure 包。
5. 类不应有字段注入的 `@Autowired`。

项目未引入 ArchUnit 时，不擅自加依赖；改用 `scripts/check_changes.py` 做静态检查，并在报告中建议后续补上 ArchUnit。

## 门禁命令

优先使用项目 wrapper，避免依赖本机全局版本：

| 构建 | 命令 |
| --- | --- |
| Maven | `./mvnw -B verify`（Windows：`mvnw.cmd -B verify`）；无 wrapper 时用 `mvn -B verify` |
| Gradle | `./gradlew test`（Windows：`gradlew.bat test`）；也可用 `build` 包含静态检查 |
| 有 Spotless / Checkstyle | 其 check 目标通常已绑定在 `verify` / `check` 中；单独运行 `<plugin>:check` 亦可 |

执行 `python scripts/lint_gate.py --root <项目根目录>` 自动探测构建工具并运行编译与测试；`--dry-run` 只打印将要执行的命令，便于人工确认；`--extra-args` 可追加项目参数。脚本不会格式化代码、不会安装依赖、不会改构建配置。

静态检查单独执行 `python scripts/check_changes.py --root <项目根目录>`，默认读取 git 变更文件；也可 `--paths a.java b.java` 指定文件。输出中 `[BLOCK]` 为必须修复项，`[WARN]` 为需人工确认项。

## 失败处理

1. 编译 / 测试失败 → 定位原因，修复生成的代码后重跑；不得通过删除测试、加 `@Disabled`、`-DskipTests`、放宽断言来「变绿」。
2. 工具链缺失（无 JDK / 无 wrapper / 无网络拉依赖）→ 如实记录未执行项与原因，交付报告中明确标注「未验证」，不得写成通过。
3. `[BLOCK]` 项 → 逐条修复；确因项目既有约定而无法满足的，在报告里列出依据，不静默忽略。
4. 两项检查都通过才输出完成结论；任一项未通过时，结论必须写明失败项。

## 禁止

- 跳过测试、伪造命令输出、把「未运行」表述为「通过」。
- 为了通过检查而修改 `pom.xml` / `build.gradle` / 静态检查配置。
- 生成只覆盖单个分支的测试，或在测试里断言实现细节（调用次数以外的私有状态）。

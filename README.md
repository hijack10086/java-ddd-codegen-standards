# java-ddd-codegen-standards

一个约束 AI Agent 写 Java 代码的规范 Skill：**先探测项目既有约定，再按 DDD 分层生成，最后用可执行门禁证明合规**。装到 Agent 的 skills 目录后，涉及 Java / DDD 的编码、改代码、评审请求会自动加载。

它不生成某个框架的脚手架，而是管住「怎么写才不分层混乱、不破坏聚合边界、不留假实现」这件事。

## 解决什么问题

Agent 写 Java 代码的典型翻车点，本 Skill 逐条对应：

| 常见问题 | 本 Skill 的处理 |
| --- | --- |
| domain 里混进 Spring / JPA 注解，业务逻辑和持久化糊在一起 | 依赖方向不变量 + `check_changes.py` 静态拦截 |
| Service 里全是 getter/setter 拼装，实体退化成数据袋 | 禁止贫血模型，聚合根必须自持状态与行为 |
| 一个事务改多个聚合，跨聚合直接对象引用 | 聚合边界规则：一事务一聚合、跨聚合只用 ID + 领域事件 |
| 直接改整个文件、顺手重构无关代码 | 最小改动红线 + 改动清单先确认 |
| 声称「测试已通过」但根本没跑 | 门禁脚本真实执行，未运行必须标注 |
| 忽略项目本身的包结构与命名习惯 | 项目既有约定 > 内置规范，冲突时报告而非擅改 |

## 安装

Skill 是纯文本 + 两个 Python 脚本，无需构建。放到 Agent 的 skills 目录即可。

**WorkBuddy 用户级（跨项目可用，推荐）**

```bash
git clone https://github.com/hijack10086/java-ddd-codegen-standards.git \
  ~/.workbuddy/skills/java-ddd-codegen-standards
```

Windows（PowerShell）：

```powershell
git clone https://github.com/hijack10086/java-ddd-codegen-standards.git `
  "$env:USERPROFILE\.workbuddy\skills\java-ddd-codegen-standards"
```

**项目级（团队共享）**：克隆到项目内 `.workbuddy/skills/java-ddd-codegen-standards/`，随仓库提交，团队所有人自动生效。

**其他 Agent 工具**：只要支持 `SKILL.md`（YAML frontmatter + Markdown 正文）的加载方式，放到对应 skills 目录即可。

依赖：Python 3.8+（仅门禁脚本需要）；项目侧需要 Maven 或 Gradle，脚本会调用项目自己的命令。

## 目录结构

```
java-ddd-codegen-standards/
├── SKILL.md                    # 触发条件、四条不变量、6 步工作流、硬性红线、资源索引
├── references/                 # 分主题的细则，按需读取
│   ├── project-context.md      # 如何探测项目既有约定
│   ├── layering.md             # 分层职责与依赖矩阵、对象转换链路
│   ├── domain-model.md         # 聚合根 / 实体 / 值对象 / 领域事件 / 仓储接口
│   ├── application-layer.md    # 用例编排、事务边界、DTO 与命令对象
│   ├── infrastructure.md       # 仓储实现、PO、外部客户端、转换器
│   ├── interfaces.md           # Controller / VO / 异常映射
│   ├── coding-standards.md     # 命名、异常、日志、类型、Lombok 使用边界
│   ├── testing-and-gate.md     # 测试策略、ArchUnit 分层守护、门禁命令
│   └── delivery-checklist.md   # 交付前逐项自检（阻断级 / 建议级）
├── scripts/
│   ├── check_changes.py        # 静态校验：分层依赖、命名、内容红线
│   └── lint_gate.py            # 动态门禁：调用项目自己的编译 / 静态检查 / 测试
└── assets/templates/           # 10 个 Java 8 兼容、不依赖 Lombok 的骨架
```

## 核心规则

### 四条不变量（任何生成都不得破坏）

1. **依赖方向单向**：`interfaces → application → domain ← infrastructure`。domain 只依赖 JDK 与自身，不得出现 Spring、JPA、MyBatis、Jackson、Servlet 等 import。
2. **领域模型与持久化隔离**：domain 里只有业务对象；PO / DO / ORM 注解留在 infrastructure，转换在同层完成。
3. **聚合边界**：一个事务只修改一个聚合；聚合间只用 ID 引用；跨聚合一致性靠领域事件做最终一致。
4. **事务边界在 application**：domain 不感知事务，Controller 不开事务，远程调用不包在长事务里。

### 优先级

项目内既有约定（包结构、命名、基类、ORM 选型、Java 版本、构建工具、代码风格配置）**优先于**本 Skill 内置规范。冲突时按项目写法来，并在交付报告中列出冲突项，不擅自「纠正」项目。

### 工作流

`Probe`（探测项目约定）→ `Clarify`（仅在契约不明时提问，最多 3 个）→ `Plan`（改动清单，超 5 个文件先确认）→ `Generate`（按层生成，最小改动，带测试）→ `Gate`（跑校验，失败就修或如实标注）→ `Report`（改动清单 / 验证结果 / 风险与未决项）。

## 使用示例

安装后直接用自然语言提需求即可，例如：

- 「按 DDD 给订单加一个确认用例，含 Controller 和仓储实现」
- 「帮我写 `Payment` 聚合根和对应的值对象、领域事件」
- 「这段 Service 里逻辑全堆在应用层了，按聚合边界重构」
- 「评审这个 PR 的 Java 代码有没有违反分层」
- 「给这个模块补 ArchUnit 分层守护测试」

期望行为：先读你的 `pom.xml` / `build.gradle`、现有包结构和同类文件，给出文件清单再动手，最后附上实际执行的命令与结果。

## 门禁脚本

两个脚本都独立可跑，不依赖 Agent。

**静态校验**（分层依赖、命名、内容红线）：

```bash
python scripts/check_changes.py --root /path/to/project
python scripts/check_changes.py --root . --paths src/main/java/com/x/order/domain/model/Order.java
python scripts/check_changes.py --root . --layer-map "domain=com.x.core,application=com.x.app"
python scripts/check_changes.py --root . --strict      # WARN 也视为阻塞
```

不传 `--paths` 时默认检查 `git status` 里的改动文件（这也是 Agent 交付时最常用的用法）。输出 `[BLOCK]` / `[WARN]` / `[INFO]` 条目，存在 `BLOCK` 时退出码为 1。

实际检查项：

- **跨层依赖**：domain 禁 Spring / JPA / MyBatis / Jackson / Servlet / Lombok 可变注解，且不得反向引用 interfaces / application / infrastructure；application 禁 JPA / MyBatis 与 interfaces / infrastructure；interfaces 禁 infrastructure 与 `domain.repository`；infrastructure 禁 interfaces / application。
- **落层错误**：domain 里出现 `*Impl.java`、`*PO.java` / `*DO.java` / `*Entity.java`；PO / DO 泄漏到 application / interfaces / domain；domain 里的仓储不是 `interface`。
- **事务边界**：`@Transactional` 出现在 domain 或 interfaces。
- **接口层越界**：interfaces 直接引用 `*Repository` / `*Mapper`。
- **内容红线**：`System.out`、`printStackTrace`、`java.util.Date` / `SimpleDateFormat` / `Timestamp`、空 `catch`、`@Autowired` 字段注入；`return null` 与 `TODO` / `FIXME` 记为 `WARN`。
- **无法识别层级**：单独记为 `WARN` 并跳过依赖规则，提示用 `--layer-map` 声明包前缀。

**动态门禁**（真实执行项目自己的构建）：

```bash
python scripts/lint_gate.py --root .                    # 自动识别 Maven / Gradle
python scripts/lint_gate.py --root . --dry-run           # 只打印将执行的命令
python scripts/lint_gate.py --root . --check "mvn spotless:check"   # 追加项目自定义检查
python scripts/lint_gate.py --root . --extra-args "-DskipTests"     # 会被拦截并报错
```

默认命令：Maven 项目执行 `mvn -B verify`（有 wrapper 优先用 `mvnw`），Gradle 项目执行 `gradle test`（有 wrapper 优先用 `gradlew`）；超时 900 秒，失败时只回显最后 25 行日志。跳过测试的参数（`-DskipTests`、`-x test`、`--exclude-task test` 等）会被识别并拒绝执行——不允许靠跳过验证来「通过」门禁。

## 模板

`assets/templates/` 下 10 个骨架，全部 Java 8 语法兼容、不依赖 Lombok，用 `${PLACEHOLDER}` 占位：

| 模板 | 用途 |
| --- | --- |
| `AggregateRoot.java.tpl` | 聚合根（自持状态、行为方法、领域事件注册） |
| `ValueObject.java.tpl` | 值对象（不可变、`equals`/`hashCode`、自校验） |
| `DomainEvent.java.tpl` / `ConcreteDomainEvent.java.tpl` | 领域事件接口与具体事件 |
| `RepositoryPort.java.tpl` | 仓储接口（定义在 domain） |
| `ApplicationService.java.tpl` | 应用服务 / 用例（事务边界） |
| `RepositoryImpl.java.tpl` | 仓储实现（infrastructure） |
| `PersistencePO.java.tpl` | 持久化对象 |
| `AggregateTest.java.tpl` | 聚合单元测试骨架 |
| `ArchUnitLayerTest.java.tpl` | 分层依赖守护测试 |

模板里的 `DomainException`、`ErrorCode`、`DomainEvent`、`XxxConverter` 是示意类，落地时替换成项目已有的类型；项目没有就先补齐，不留空实现。

## 已验证与已知限制

已验证：Skill 结构与打包校验通过；脚本正反用例自测通过（违规样例命中 `[BLOCK]` 并返回 1，合规样例返回 0，自定义 `--layer-map`、`-DskipTests` 拦截、无构建文件时报错均符合预期）。

已知限制，均为有意为之：

- 项目没引入 ArchUnit 时，脚本只做静态检查，**不会**擅自添加该依赖。
- 项目无 Maven / Gradle 工程时，编译门禁会明确报「未验证」，而不是假装通过。
- 脚本做的是文本级规则匹配，不理解业务语义；聚合边界、事务边界这类判断仍依赖人或 Agent 的复核。
- 只覆盖 Java + DDD，不含架构选型论证、性能调优、依赖升级。

## 定制

- **包名不一样**：用 `--layer-map` 指定前缀，例如 `--layer-map "domain=com.acme.core,infrastructure=com.acme.infra"`。
- **团队有额外规范**：直接改对应 `references/*.md`，或把团队规范文件放在项目根，Skill 的 Probe 步骤会优先读取它。
- **规则缺失或误判**：只改对应的 reference 或脚本，不要把细节堆回 `SKILL.md`。

# Java 编码规范

适用于所有层；分层专属规则见对应 reference。项目已有风格配置（Spotless / Checkstyle / EditorConfig）优先。

## 语言版本门禁

- 先按 `project-context.md` 判定 Java 版本，生成代码不得使用更高版本语法。
- Java 8：禁用 `var`、`record`、`sealed`、文本块、`List.of` / `Map.of` / `List.copyOf`、switch 表达式、模式匹配。
- Java 17+：可用 `record` 实现值对象（须在紧凑构造器中校验），`List.copyOf` 返回不可变集合；其余仍按项目风格。

## 命名

| 对象 | 规则 | 示例 |
| --- | --- | --- |
| 包 | 全小写、单数、按业务语义 | `com.example.order.domain.model` |
| 类 | UpperCamelCase，名词；实现带 `Impl` | `OrderRepositoryImpl` |
| 接口 | 不加 `I` 前缀、不加 `Interface` 后缀 | `OrderRepository` |
| 方法 | lowerCamelCase，动词或业务语义 | `confirm()`、`findById()` |
| 常量 | `UPPER_SNAKE_CASE`，`static final` | `MAX_RETRY_TIMES` |
| 测试类 | 被测类名 + `Test` / `IT`（集成测试） | `OrderTest`、`OrderRepositoryIT` |
| 分层后缀 | Controller / AppService / UseCase / Repository / RepositoryImpl / PO / DTO / VO / Converter / Assembler | 按项目既有后缀优先 |

避免 `Manager`、`Util`、`Helper`、`Info`、`Data`、`Processor` 等无业务含义的类名；确需工具类时限定为纯技术用途且放在 infrastructure 或 common 包。

## 不可变性与注入

- 字段优先 `private final`；构造后不变的对象不要在构造后留可变引用（防御性拷贝）。
- 一律构造器注入；禁止 `@Autowired` 字段注入、禁止在 domain / 静态上下文中获取 Spring Bean。
- 集合参数复制后再持有，集合返回不可变视图；禁止返回 `null` 集合，返回空集合。
- 方法参数超过 3 个时封装为 Command / 参数对象；禁止布尔标志参数（用两个语义明确的方法代替）。

## Lombok 使用边界

| 层 | 允许 | 禁止 |
| --- | --- | --- |
| domain | `@Getter`（谨慎）、`@Value`（值对象） | `@Data`、`@Setter`、`@Builder` 绕过校验、`@AllArgsConstructor` 暴露构造 |
| application / interfaces | `@RequiredArgsConstructor`、`@Slf4j` | 字段注入配合 `@Autowired` |
| infrastructure PO | `@Data`、`@Builder` 可用 | 无 |

默认骨架不依赖 Lombok（模板均为纯 Java），只有确认项目已引入 Lombok 时才使用。

## 类型与值

- 金额一律 `BigDecimal`，统一 scale 与 `RoundingMode`；禁止 `double` / `float` 表示金额，禁止用 `BigDecimal` 的 `equals` 比较数值大小（用 `compareTo`）。
- 时间用 `Instant` / `LocalDateTime` / `OffsetDateTime`；禁止 `java.util.Date` / `java.sql.Timestamp` / `SimpleDateFormat`；带时区场景明确时区来源。
- ID 优先强类型值对象 `OrderId`；项目用裸 `Long` 时保持一致，但不得在领域方法里混用两种表示。
- 状态、类型用枚举，禁止魔法字符串与数字常量；枚举持久化映射写在 Converter。
- `Optional` 只用于返回值表达「可能不存在」；禁止作为字段、方法参数、集合元素，禁止对 Optional 调用 `get()` 而不判空（用 `orElseThrow`）。
- 空值入口用 `Objects.requireNonNull` 或项目 `Assert`；禁止散落的 `if (x == null)` 后静默继续。

## 异常与日志

- 领域异常继承项目统一基类，携带 `ErrorCode`；消息面向排障，不面向 UI。
- 禁止空 `catch`、禁止 `catch (Exception e) { return null; }`、禁止用异常做正常流程分支。
- 捕获后必须处理：补充上下文后重抛、转换成领域异常、或明确记录并降级；保留 `cause`。
- 日志用 SLF4J 占位符（`log.info("order {} confirmed", id)`）；`warn` / `error` 带上下文，不打印密码、令牌、身份证、完整报文。
- 禁止 `System.out` / `printStackTrace()`；禁止在循环中打印高频日志。

## 注释与 TODO

- 注释解释 why（约束来源、取舍原因、特殊兼容性），不复述代码做了什么。
- 公有 API、领域行为、非直觉的转换规则写简短 JavaDoc；其余不加模板化注释。
- 生成代码不得留下空实现或占位 TODO；确需留待后续时，写明条件与责任归属，并在交付报告的「未决项」中列出。
- 禁止注释掉大段代码后提交。

## 方法实现

- 方法短小、单一职责；复杂条件抽成有业务名字的私有方法或领域方法。
- 早返回优于深层嵌套；`switch` 必须有 `default` 或穷举处理。
- 不在业务代码里做 `Thread.sleep`、自旋等待、硬编码重试次数；重试策略配置化。
- 常量、地址、开关、密钥一律走配置或常量类，禁止硬编码在类中。

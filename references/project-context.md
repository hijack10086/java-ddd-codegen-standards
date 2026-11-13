# 项目上下文探测

在写任何代码之前先完成探测。目标：让生成的代码看起来像项目里已有的代码，而不是像模板库里的代码。

## 探测清单

| 探测对象 | 提取信息 | 典型位置 |
| --- | --- | --- |
| 构建工具 | Maven / Gradle、模块划分、依赖清单 | `pom.xml`、`build.gradle(.kts)`、`settings.gradle`、`mvnw`、`gradlew` |
| Java 版本 | 语法上限 | `java.version`、`maven.compiler.release`、`maven.compiler.source`、`sourceCompatibility`、`.java-version`、`gradle.properties` |
| 分层结构 | 根包、四层包名、按限界上下文还是按层优先分包 | `src/main/java` 下的目录树 |
| 同类构件 | 命名后缀、基类、接口风格、构造器写法 | 同层的 2 到 3 个已有类 |
| ORM | MyBatis / JPA / MyBatis-Plus、PO 命名、转换方式、主键与乐观锁策略 | `infrastructure/persistence`、`mapper`、`resources/mapper` |
| 对象映射 | MapStruct / 手写 Converter / BeanUtils | `assembler`、`converter`、`mapstruct` 依赖 |
| 事务与事件 | `@Transactional` 用在哪层、事件发布机制、是否有 Outbox | 现有应用服务、配置类 |
| 测试 | JUnit 4 / 5、Mockito、AssertJ、Testcontainers、ArchUnit、H2 | `src/test`、依赖清单 |
| 代码风格 | Spotless / Checkstyle / PMD / EditorConfig、缩进、换行 | 构建插件、`config/`、`.editorconfig` |
| 团队约定 | 显式规则 | `AGENTS.md`、`CONTRIBUTING.md`、`README.md`、docs 目录 |

## Java 版本判定

1. 依次查找 `maven.compiler.release`、`java.version`、`sourceCompatibility`、`maven.compiler.source`。
2. 多模块项目以目标模块的配置为准；父 pom 的版本只作参考。
3. 找不到时按 **Java 8 语法**生成（不用 record、var、sealed、`List.of`、`List.copyOf`、文本块），并在交付报告的「默认假设」中写明。
4. 判定为 Java 17+ 时，值对象可用 `record`，但须保留构造校验（紧凑构造器），且不得因此引入 Lombok。

## 约定识别信号

从已有代码推断，而不是提问：

- 类后缀：`XxxController`、`XxxAppService` / `XxxUseCase`、`XxxRepository` / `XxxRepositoryImpl`、`XxxPO` / `XxxDO` / `XxxEntity`、`XxxConverter`、`XxxAssembler`。
- 统一返回体：`Result<T>`、`ApiResponse<T>`、`ResponseResult`，以及分页对象 `PageResult<T>`。
- 异常体系：`BusinessException`、`DomainException`、`ErrorCode` 枚举。
- ID 类型：裸 `Long` / `String`，还是强类型 `OrderId` 值对象。
- 校验方式：Bean Validation、自写 `Assert`、Guava Preconditions。
- 构造方式：静态工厂 `of/create`、Builder、全参构造。
- 集合返回：是否统一返回不可变集合。

## 冲突处理

| 情况 | 处理 |
| --- | --- |
| 项目用 `service` 包名而非 `application` | 按项目包名落层，在分层校验时说明映射关系 |
| 项目 domain 中已有 JPA 注解 | 视为项目既定取舍；新增代码沿用，不得借机重写既有类；在报告中标为技术债 |
| 项目已有统一基类 / 工具类 | 优先复用，不另造一套 |
| 项目约定违反 P0 红线 | 先沿用现状保证一致性，报告中明确列出风险与整改建议，等用户决定是否专门重构 |
| 探测结果与用户描述冲突 | 以代码事实为准，向用户指出差异 |

## Probe 结果摘要格式

在动手前把以下内容整理成简短清单，供后续步骤引用：

```
构建工具: Maven (mvnw) / Gradle (gradlew)
Java 版本: 17 (来自 maven.compiler.release)
根包: com.example.order
分层: interfaces / application / domain / infrastructure（按上下文分包）
ORM: MyBatis-Plus，PO 后缀 PO，手写 Converter
事务: application 层 @Transactional，事件用 @TransactionalEventListener
测试: JUnit 5 + Mockito + ArchUnit
风格样本: domain/model/Order.java, application/service/PlaceOrderService.java
默认假设: 无统一返回体，沿用裸 DTO；无 ArchUnit，建议新增
```

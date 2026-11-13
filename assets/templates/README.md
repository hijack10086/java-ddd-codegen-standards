# 模板使用说明

这些文件是**骨架，不是可直接交付的成品**。按 `references/project-context.md` 探测到的项目风格改造后再落地：命名后缀、异常基类、统一返回体、ORM 注解、ID 类型、Java 版本语法都要与项目一致。

## 占位符

| 占位符 | 含义 | 示例 |
| --- | --- | --- |
| `${PACKAGE}` | 限界上下文根包 | `com.example.order` |
| `${AGGREGATE}` | 聚合根类名 | `Order` |
| `${VALUE_OBJECT}` | 值对象类名 | `OrderId` |
| `${ID}` | 聚合 ID 类型 | `OrderId` |
| `${EVENT}` | 领域事件类名（过去式） | `OrderConfirmedEvent` |
| `${USE_CASE}` | 应用服务 / 用例类名 | `ConfirmOrderUseCase` |
| `${COMMAND}` | 用例输入 | `ConfirmOrderCommand` |
| `${DTO}` | 用例输出 | `OrderDTO` |
| `${STATUS}` | 聚合状态枚举（默认与聚合根同包 `domain.model`） | `OrderStatus` |
| `${AGGREGATE_LOWER}` | 聚合名的 lowerCamelCase，用于变量名 | `order` |
| `${MAPPER}` | 持久化 Mapper / Repository（infra） | `OrderMapper` |

## 选择规则

| 需求 | 使用模板 |
| --- | --- |
| 新增聚合 | `AggregateRoot.java.tpl` + `RepositoryPort.java.tpl` + `AggregateTest.java.tpl` |
| 新增 ID / 金额 / 地址等值对象 | `ValueObject.java.tpl` |
| 聚合行为产生事件 | `DomainEvent.java.tpl`（标记接口，项目没有才新增）+ `ConcreteDomainEvent.java.tpl` |
| 新增用例 | `ApplicationService.java.tpl` |
| 实现仓储 | `RepositoryImpl.java.tpl` + `PersistencePO.java.tpl` |
| 守护分层 | `ArchUnitLayerTest.java.tpl`（仅在项目已引入 ArchUnit 时使用） |

## 约束

- 所有模板为 Java 8 兼容语法，且不依赖 Lombok；项目使用 Java 17+ 时可把值对象改为 `record`，但须保留构造校验。
- 模板中的 `DomainException` / `ErrorCode` / `DomainEvent` / `${STATUS}` / `${AGGREGATE}Assembler` / `${AGGREGATE}Converter` / `${MAPPER}` 均为示意，替换为项目已有的类；项目没有时先补齐再生成业务代码，不得留空实现，也不要擅自引入新依赖。
- 生成前先确认文件落层与包路径，见 `references/layering.md`。
- 复制模板后删除所有占位符与示意注释，不把 `${...}` 残留到交付代码里。

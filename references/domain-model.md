# 领域层建模规范

领域层是业务规则的唯一归属地。判断标准：把同一段逻辑换一个入口（HTTP、定时任务、消息）复用时是否仍然成立；成立则应放在 domain。

## 构件选择表

| 构件 | 使用条件 | 命名 |
| --- | --- | --- |
| 聚合根 | 有独立生命周期、需要作为事务一致性边界 | `Order`、`Account`（不加后缀） |
| 实体 | 聚合内有身份、状态会变化 | `OrderLine`、`Payment` |
| 值对象 | 无身份、按值判等、描述性概念 | `Money`、`Address`、`OrderId` |
| 领域服务 | 逻辑不自然属于任一实体，或需协调多个同聚合对象 | `PricingService`、`TransferDomainService` |
| 领域事件 | 已发生的事实，用于跨聚合 / 跨上下文最终一致 | `OrderPlacedEvent`（过去式） |
| 仓储接口 | 聚合根的持久化端口 | `OrderRepository` |
| 工厂 | 聚合构造复杂、需要校验多个来源对象 | `OrderFactory` |

## 聚合

- 一个事务只修改一个聚合；跨聚合用领域事件最终一致。
- 聚合之间只持有对方 ID（强类型 `OrderId`），不持有对象引用，不写双向关联。
- 聚合要小：只把必须强一致的不变式圈进边界；大列表、历史记录、统计数据拆到读模型或独立聚合。
- 聚合根负责维护边界内所有不变式；外部无法绕过它修改内部实体。
- 并发控制在 infrastructure 的 PO 上用乐观锁字段实现；domain 不出现 `@Version`。若业务必须感知版本，用领域字段 `long version` 而非框架注解。
- 不要在聚合里注入 Repository 或 Spring Bean；需要外部数据时由 application 查询后作为参数传入。

## 实体与聚合根实现

- 字段 `private final` 优先；可变状态仅状态字段，且只能通过行为方法改变。
- 私有构造 + 静态工厂（`create` / `of` / `reconstitute`）；`reconstitute` 专用于从持久化数据重建，跳过新对象专属校验。
- 行为方法用业务动词：`confirm()`、`addLine()`、`cancel(reason)`，不用 `setStatus()`。
- 禁止公共 setter、禁止 `@Data`、禁止暴露可变集合；集合返回 `Collections.unmodifiableList`（Java 8）或 `List.copyOf`（Java 10+）。
- 校验失败抛领域异常（带错误码），不返回 `null` / `false` / 错误码对象。
- 领域对象不实现序列化接口用于传输，不做 JSON 注解。

```java
public final class Order {
    private final OrderId id;
    private final CustomerId customerId;
    private final List<OrderLine> lines;
    private OrderStatus status;
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    private Order(OrderId id, CustomerId customerId, List<OrderLine> lines, OrderStatus status) {
        this.id = Objects.requireNonNull(id, "id");
        this.customerId = Objects.requireNonNull(customerId, "customerId");
        if (lines == null || lines.isEmpty()) {
            throw new DomainException(ErrorCode.ORDER_EMPTY, "订单至少包含一行");
        }
        this.lines = new ArrayList<>(lines);
        this.status = Objects.requireNonNull(status, "status");
    }

    public static Order create(OrderId id, CustomerId customerId, List<OrderLine> lines) {
        return new Order(id, customerId, lines, OrderStatus.CREATED);
    }

    public static Order reconstitute(OrderId id, CustomerId customerId,
                                     List<OrderLine> lines, OrderStatus status) {
        return new Order(id, customerId, lines, status);
    }

    public void confirm(Instant confirmedAt) {
        if (status != OrderStatus.CREATED) {
            throw new DomainException(ErrorCode.ORDER_STATUS_INVALID, "仅待确认订单可确认");
        }
        this.status = OrderStatus.CONFIRMED;
        this.domainEvents.add(new OrderConfirmedEvent(id, confirmedAt));
    }

    public List<OrderLine> lines() {
        return Collections.unmodifiableList(lines);
    }

    public List<DomainEvent> domainEvents() {
        return Collections.unmodifiableList(domainEvents);
    }

    public void clearDomainEvents() {
        domainEvents.clear();
    }
}
```

`DomainEvent` 为领域事件标记接口；项目没有时新增一个空接口放在 `domain/event`，不得让 domain 依赖 Spring 的 `ApplicationEvent`。

## 值对象

- `final` 类 + `final` 字段，无 setter，构造时自校验；`equals` / `hashCode` 覆盖全部字段。
- 无 ID、无生命周期、无 Repository、无数据库表。
- 提供有业务语义的方法（`Money.plus`、`Money.isGreaterThan`），金额用 `BigDecimal` 并统一 scale 与舍入模式。
- Java 17+ 可用 `record`，但必须在紧凑构造器中做校验；Java 8 用 `final class`。
- 允许 Lombok `@Value`（不可变），但不得用 `@Data` / `@Setter`；`@Builder` 会绕过校验，优先静态工厂。

```java
public final class Money {
    private final BigDecimal amount;
    private final Currency currency;

    private Money(BigDecimal amount, Currency currency) {
        if (amount == null || amount.signum() < 0) {
            throw new DomainException(ErrorCode.MONEY_INVALID, "金额不能为空或负数");
        }
        this.amount = amount.setScale(2, RoundingMode.HALF_UP);
        this.currency = Objects.requireNonNull(currency, "currency");
    }

    public static Money of(BigDecimal amount, Currency currency) {
        return new Money(amount, currency);
    }

    public Money plus(Money other) { /* 校验币种一致后相加 */ }

    @Override
    public boolean equals(Object o) { /* amount + currency */ }
    @Override
    public int hashCode() { return Objects.hash(amount, currency); }
}
```

## 领域服务

- 无状态、无事务注解、不注入 Spring Bean；可依赖 domain 层的端口接口，但优先由 application 传入数据。
- 命名为业务动作或 `XxxDomainService`，不要叫 `XxxManager` / `XxxUtil` / `XxxHelper`。
- 不得把本该属于聚合的逻辑搬进领域服务；领域服务是「无处安放」的最后选择。

## 领域事件

- 过去式命名，携带聚合 ID、发生时间、必要的最小快照；不携带整个聚合对象、不携带 PO。
- 由聚合行为方法内部产生并收集，不在 application 里凭空 new 一个事件来假装领域行为。
- 事务提交后发布：`@TransactionalEventListener(phase = AFTER_COMMIT)` 或 Outbox；禁止在事务内同步调用外部系统。
- 事件消费者必须幂等；跨上下文事件用稳定 schema，避免直接复用内部枚举。

## 仓储接口

- 一个聚合一个仓储，接口在 `domain/repository`，实现在 `infrastructure/persistence/repository`。
- 方法参数与返回值只用领域类型：`Optional<Order> findById(OrderId id)`、`void save(Order order)`。
- 禁止：泛型 `BaseRepository<T>` 泄露给上层、返回 PO、接收分页对象或 Map 参数、按字段局部更新（`updateStatus(...)`）、在接口上标注 Spring / MyBatis 注解。
- 复杂查询走读模型（QueryService + 专用 DTO），不污染写模型仓储。

## 反模式清单

- 贫血模型：实体只有 getter / setter，业务规则全在 `XxxService`。
- 上帝聚合：一个聚合包含几十个实体、跨多个业务上下文。
- 跨聚合对象引用、双向关联、在聚合内调用另一个 Repository。
- 事务脚本：application 里一串 `if` 判断 + 逐字段 set + save。
- 把 VO / Request / DTO 传进领域方法，或在领域方法里做 JSON / 日期格式化。
- 用静态工具类承载业务规则、用 `Optional` 作为字段或入参类型。
- 用 `IllegalArgumentException` 之外的通用运行时异常表达所有业务失败，导致上层无法区分错误码。

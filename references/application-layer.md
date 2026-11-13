# 应用层规范

应用层是用例的编排者，不是业务逻辑的容器。它回答「这次操作要按什么顺序做、事务划到哪里」，不回答「业务规则是什么」。

## 职责清单

- 接收 Command / Query，做用例级前置校验（权限、幂等、并发控制）。
- 加载聚合 → 调用聚合行为 → 保存 → 发布领域事件。
- 划定事务边界；协调外部系统调用（通过 domain 端口接口）。
- 把领域对象转换为 DTO / VO 返回给 interfaces。

判据：一段 `if` 判断的是「对象的状态与业务不变式」→ 属于 domain；判断的是「流程能否继续、调用哪个端口」→ 属于 application。

## 结构

- 按用例切分：一个应用服务对应一组紧密相关用例，或一个用例一个类（`PlaceOrderUseCase`）。项目已有风格优先。
- 输入用 `XxxCommand` / `XxxQuery`，输出用 `XxxDTO`；禁止把 HTTP Request、PO、ORM 对象作为应用服务参数。
- 构造器注入依赖（端口接口、事件发布抽象），禁止 `@Autowired` 字段注入。
- 应用服务之间可以互相调用吗？默认禁止，避免用例链隐藏事务边界；确需复用时抽取共享的 domain 端口，并在报告中说明。

## 事务

- `@Transactional` 只出现在 application 的用例方法上；查询方法标 `readOnly = true`（若项目使用）。
- domain / interfaces / infrastructure 不出现 `@Transactional`（infrastructure 的实现类一般继承调用方事务，无需重复标注）。
- 一个事务只改一个聚合；跨聚合用领域事件最终一致。
- 事务内不得包含：HTTP / RPC 调用、消息发送、文件上传、大批量循环、远程查询后再写库等长耗时动作。先在本地事务内完成状态变更，提交后再做外部副作用。
- 禁止为「省事」把整个 Controller 链路包进事务；禁止捕获异常后返回默认值导致事务不回滚。

## 领域事件发布

两种可接受实现，按项目既有机制二选一：

1. **事务提交后监听**：application 保存聚合后，用 `ApplicationEventPublisher` 发布聚合收集到的事件；infrastructure 或 application 的监听器用 `@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)` 处理。
2. **Outbox**：application 在同一事务内把事件写入 Outbox 表（通过 domain 端口），infrastructure 异步投递，保证至少一次送达。

- 发布前从聚合读取 `domainEvents()`，发布后调用 `clearDomainEvents()`；不得在 domain 中直接发布。
- 事件处理器必须幂等，失败可重试；跨服务场景不要在 `AFTER_COMMIT` 里做无补偿的同步远程调用。
- 禁止「事务还没提交就发消息，消费者回查不到数据」。

## 幂等与并发

- 写用例接收幂等键（业务单号 / 请求 ID），用唯一索引或去重表保证重复请求不产生双份数据。
- 并发修改同一聚合：乐观锁（infrastructure PO 上的版本字段）+ 有限重试；重试必须在应用层显式实现，不得靠框架隐式行为。
- 不要在 application 里用 `synchronized` 解决分布式并发。

## 示例

```java
@Service
public class ConfirmOrderUseCase {

    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher eventPublisher;

    public ConfirmOrderUseCase(OrderRepository orderRepository,
                               ApplicationEventPublisher eventPublisher) {
        this.orderRepository = Objects.requireNonNull(orderRepository, "orderRepository");
        this.eventPublisher = Objects.requireNonNull(eventPublisher, "eventPublisher");
    }

    @Transactional
    public OrderDTO handle(ConfirmOrderCommand command) {
        Order order = orderRepository.findById(command.getOrderId())
            .orElseThrow(() -> new DomainException(ErrorCode.ORDER_NOT_FOUND, "订单不存在"));

        order.confirm(Instant.now());          // 业务规则在聚合内
        orderRepository.save(order);           // 端口，实现在 infrastructure

        for (DomainEvent event : order.domainEvents()) {
            eventPublisher.publishEvent(event); // 配合 AFTER_COMMIT 监听器或 Outbox
        }
        order.clearDomainEvents();
        return OrderAssembler.toDTO(order);
    }
}
```

若项目把事件发布收敛在 infrastructure，则注入 domain 定义的 `DomainEventPublisher` 端口，不要直接依赖消息客户端。

## 禁止

- 在 application 中书写业务规则链、状态机判断、金额计算。
- 直接 `new` PO、直接注入 Mapper / JpaRepository / RedisTemplate 等 infrastructure 具体类。
- 在应用服务里做 JSON 序列化、HTTP 状态码处理、参数格式校验（Bean Validation 属 interfaces）。
- 捕获异常后吞掉、返回 `null`、返回空 DTO 伪装成功。
- 把聚合根直接返回给 interfaces 层。
- 为单个字段更新写 `updateXxx(...)` 用例，绕过聚合行为。

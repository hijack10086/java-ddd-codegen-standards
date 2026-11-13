# 基础设施层规范

基础设施层实现 domain 声明的端口，把技术细节挡在领域之外。它对上只暴露领域类型，不暴露 PO、Mapper、第三方客户端类型。

## 仓储实现

- 命名 `XxxRepositoryImpl`，实现 domain 的 `XxxRepository`，用 `@Repository` 或项目既有的 Bean 注册方式。
- 构造器注入 Mapper / JpaRepository / Converter；注入类型可以是 infrastructure 具体类，因为本层允许依赖技术实现。
- 每个方法内部完成：PO → Domain 重建（用 `reconstitute` / Converter）、Domain → PO 后写入。转换不得泄漏给上层。
- `save` 要处理聚合内子实体的增删改（按项目 ORM 方式），不得只更新聚合根主表而遗留脏子表数据。
- 乐观锁、逻辑删除、租户字段、审计字段都在本层处理，domain 不感知。
- 事务由 application 的用例方法提供；实现类一般不重复标 `@Transactional`。

```java
@Repository
public class OrderRepositoryImpl implements OrderRepository {

    private final OrderMapper mapper;
    private final OrderConverter converter;

    public OrderRepositoryImpl(OrderMapper mapper, OrderConverter converter) {
        this.mapper = Objects.requireNonNull(mapper, "mapper");
        this.converter = Objects.requireNonNull(converter, "converter");
    }

    @Override
    public Optional<Order> findById(OrderId id) {
        OrderPO po = mapper.selectById(id.value());
        return Optional.ofNullable(po).map(converter::toDomain);
    }

    @Override
    public void save(Order order) {
        converter.toPO(order);   // 返回含子表数据的结构，由 mapper 落库
        mapper.upsert(/* ... */);
    }
}
```

## 持久化对象 PO

- 只含持久化字段、ORM 注解与必要的 getter / setter（可用 Lombok `@Data`，本层不要求充血）。
- 命名 `XxxPO` / `XxxDO`（按项目）；不含业务方法、不实现领域接口、不引用值对象类型作为字段类型时尽量拆成基本类型或 String。
- 数据库字段与领域字段的差异（枚举码、金额分为单位、时间精度）在 Converter 中显式转换，不让差异渗进 domain。
- 禁止把 PO 作为仓储接口返回类型、作为应用服务参数、或直接序列化到 HTTP 响应。

## 对象转换 Converter / Assembler

- 纯映射：无业务规则、无远程调用、不吞异常；字段名一一对应，转换差异集中在这里并写注释说明 why。
- 值对象拆装：`OrderId.of(po.getId())`、`Money.of(po.getAmount(), po.getCurrency())`。
- 枚举：用显式 `switch` 或映射表，禁止 `valueOf(po.getStatus())` 之类在枚举重命名时静默崩溃的写法。
- 集合转换返回新集合，不复用可变引用；空集合返回空列表而非 `null`。

## ORM 取舍

- 默认策略：**PO 与 Domain 分离**，即本文与模板所示。
- 若项目已采用 JPA 直接映射富领域对象（domain 类上带 `@Entity`），这是既定的架构取舍：沿用项目模式新增代码，并在报告中标为「与内置规范冲突，已按项目约定实现」；不得顺手重写既有类。
- 即便采用 JPA 富模型，domain 仍不得引入 Spring 依赖、`@Autowired`、Service 调用或 HTTP 相关注解。

## 外部系统适配器（防腐层 ACL）

- domain 定义 `XxxGateway` 端口接口（领域语义、领域类型）；infrastructure 提供 `XxxClient` / `XxxAdapter` 实现。
- 第三方 SDK 的请求 / 响应对象只存在于 infrastructure，进入上层前转换为领域类型或专用 DTO。
- 超时、重试、熔断、限流参数配置化；对第三方异常做包装为项目统一异常，保留可追溯的错误码与 cause。
- 重试只针对幂等操作；禁止在事务内做带重试的远程调用。

## 消息、缓存与配置

- 消息发布 / 消费实现放在 infrastructure；消费者调用 application 的用例入口时要走一层薄适配（把消息体转 Command）。
- 消费者必须幂等，处理失败有明确重试与死信策略。
- 缓存键、序列化方式、TTL 集中配置；缓存不得成为业务正确性的唯一来源。
- Spring 配置类、`@Bean` 定义、Bean 与端口实现的绑定都放 `infrastructure/config`。

## 禁止

- infrastructure 反向 import interfaces / application 层的类（确有事件监听等需求时，通过 domain 端口或事件解耦）。
- 在 Mapper XML / SQL 中写业务规则（状态流转判断、金额计算、权限过滤应可读但不可替代领域规则）。
- 把 PO 或第三方 DTO 传给 application / domain。
- 在仓储实现里开启新事务绕过用例的事务边界。
- 跨聚合联表查询写模型（读模型 / 报表场景例外，须在报告中说明）。
- 未经声明引入新的 ORM、连接池、HTTP 客户端依赖。

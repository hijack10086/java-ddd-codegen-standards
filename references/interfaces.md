# 接入层规范

接入层只做协议适配，保持「一行用例调用」的薄度。同一用例若有 HTTP 与 MQ 两个入口，两者应复用同一个 application 用例，而不是各自实现一套逻辑。

## Controller

- 方法体保持：参数校验 → 组装 Command → 调用用例 → 组装 Response，通常不超过 10 行。
- 使用构造器注入应用服务；禁止注入 Repository / Mapper / Converter。
- 禁止 `@Transactional`、禁止业务判断、禁止循环里逐条调用用例（应提供批量用例）。
- 路径与 HTTP 语义按项目既有风格（REST / RPC 风格统一），不擅自引入新约定。

```java
@RestController
@RequestMapping("/orders")
public class OrderController {

    private final ConfirmOrderUseCase confirmOrderUseCase;

    public OrderController(ConfirmOrderUseCase confirmOrderUseCase) {
        this.confirmOrderUseCase = Objects.requireNonNull(confirmOrderUseCase, "confirmOrderUseCase");
    }

    @PostMapping("/{orderId}/confirm")
    public OrderResponse confirm(@PathVariable String orderId,
                                 @Valid @RequestBody ConfirmOrderRequest request) {
        ConfirmOrderCommand command = OrderRequestAssembler.toCommand(orderId, request);
        return OrderResponseAssembler.from(confirmOrderUseCase.handle(command));
    }
}
```

## 请求与响应对象

- 独立定义 `XxxRequest` / `XxxResponse`（或 `XxxVO`），不复用 Command / DTO / 领域对象 / PO。
- 字段用包装类型以便区分「未传」与「零值」；时间字段明确格式与时区；金额用 `BigDecimal` 或按项目约定用字符串传输并注明精度。
- 序列化注解（`@JsonProperty`、日期格式）只在这一层出现。
- 分页用项目既有的 `PageQuery` / `PageResult`；禁止把 ORM 分页对象直接返回。
- 响应不返回内部枚举原始名、数据库主键之外的内部标识、堆栈信息。

## 参数校验分层

| 校验类型 | 位置 | 例子 |
| --- | --- | --- |
| 格式 / 必填 / 范围 | interfaces（Bean Validation） | 字段非空、长度、邮箱格式、分页大小 |
| 协议级权限 / 幂等键 | interfaces 或 application（按项目） | 登录态、请求 ID |
| 业务前置与用例权限 | application | 操作人是否有权操作该订单 |
| 业务不变式 | domain | 状态是否允许确认、金额是否合法 |

禁止只在 Controller 做校验就认为业务安全；禁止把 `@NotNull` 之类的协议注解写进 domain。

## 异常映射

- 用 `@RestControllerAdvice` 统一处理，按项目既有统一返回体输出。
- 领域异常 / 业务异常 → 4xx（或项目约定的业务错误码 + HTTP 200）；未知技术异常 → 5xx 通用文案。
- 错误码与文案取自 `ErrorCode`，不硬编码散落字符串；日志记录完整堆栈，响应只返回可展示信息。
- 禁止把异常吞掉后返回「成功」、禁止在响应里暴露 SQL、堆栈、内部类名。

## MQ 消费者 / RPC 入口

- 消费者类是薄的适配：反序列化 → 组装 Command → 调用用例；不在监听器里写业务规则。
- 显式声明幂等处理与失败重试策略；消息体版本兼容在本层处理。
- 同一消息重复投递不得产生重复副作用，由 application 的幂等键 + infrastructure 去重共同保证。

## 禁止

- Controller 直接访问 domain 的 Repository 接口或 infrastructure 任何类。
- 把领域对象、聚合根、值对象、PO 直接作为请求 / 响应体。
- 在接入层做对象持久化、发事务内消息、写复杂循环与状态机。
- 为每个接口复制粘贴一套几乎相同的校验与组装逻辑；抽成 assembler 或公共校验组。
- 使用 `Map<String, Object>` 作为请求或响应类型。

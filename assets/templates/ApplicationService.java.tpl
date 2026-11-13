package ${PACKAGE}.application.service;

import ${PACKAGE}.application.assembler.${AGGREGATE}Assembler;
import ${PACKAGE}.application.command.${COMMAND};
import ${PACKAGE}.application.dto.${DTO};
import ${PACKAGE}.domain.event.DomainEvent;
import ${PACKAGE}.domain.exception.DomainException;
import ${PACKAGE}.domain.exception.ErrorCode;
import ${PACKAGE}.domain.model.${AGGREGATE};
import ${PACKAGE}.domain.model.${ID};
import ${PACKAGE}.domain.repository.${AGGREGATE}Repository;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Objects;

/**
 * ${USE_CASE}: orchestrates one use case and owns the transaction boundary.
 * Business rules stay inside the aggregate; this class only sequences steps.
 */
@Service
public class ${USE_CASE} {

    private final ${AGGREGATE}Repository ${AGGREGATE_LOWER}Repository;
    private final ApplicationEventPublisher eventPublisher;

    public ${USE_CASE}(${AGGREGATE}Repository ${AGGREGATE_LOWER}Repository,
                       ApplicationEventPublisher eventPublisher) {
        this.${AGGREGATE_LOWER}Repository = Objects.requireNonNull(${AGGREGATE_LOWER}Repository, "${AGGREGATE_LOWER}Repository");
        this.eventPublisher = Objects.requireNonNull(eventPublisher, "eventPublisher");
    }

    @Transactional
    public ${DTO} handle(${COMMAND} command) {
        ${ID} id = ${ID}.of(command.getAggregateId());
        ${AGGREGATE} aggregate = ${AGGREGATE_LOWER}Repository.findById(id)
            .orElseThrow(() -> new DomainException(ErrorCode.${AGGREGATE}_NOT_FOUND, "${AGGREGATE} not found"));

        aggregate.confirm(Instant.now());       // business rule inside the aggregate
        ${AGGREGATE_LOWER}Repository.save(aggregate);

        // Publish after commit via @TransactionalEventListener(AFTER_COMMIT) or an Outbox.
        for (DomainEvent event : aggregate.domainEvents()) {
            eventPublisher.publishEvent(event);
        }
        aggregate.clearDomainEvents();

        return ${AGGREGATE}Assembler.toDTO(aggregate);
    }
}

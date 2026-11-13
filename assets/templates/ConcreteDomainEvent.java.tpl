package ${PACKAGE}.domain.event;

import ${PACKAGE}.domain.model.${ID};

import java.time.Instant;
import java.util.Objects;

/**
 * ${EVENT}: a fact that already happened, named in the past tense.
 * Carry ids and a minimal snapshot only; never the whole aggregate or a PO.
 */
public final class ${EVENT} implements DomainEvent {

    private final ${ID} aggregateId;
    private final Instant occurredAt;

    public ${EVENT}(${ID} aggregateId, Instant occurredAt) {
        this.aggregateId = Objects.requireNonNull(aggregateId, "aggregateId");
        this.occurredAt = Objects.requireNonNull(occurredAt, "occurredAt");
    }

    public ${ID} aggregateId() {
        return aggregateId;
    }

    @Override
    public Instant occurredAt() {
        return occurredAt;
    }
}

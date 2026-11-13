package ${PACKAGE}.domain.model;

import ${PACKAGE}.domain.event.${EVENT};
import ${PACKAGE}.domain.event.DomainEvent;
import ${PACKAGE}.domain.exception.DomainException;
import ${PACKAGE}.domain.exception.ErrorCode;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

/**
 * ${AGGREGATE} aggregate root.
 * Replace the sample invariant and behaviour with the real business rules.
 */
public final class ${AGGREGATE} {

    private final ${ID} id;
    private final List<String> itemIds;
    private ${STATUS} status;
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    private ${AGGREGATE}(${ID} id, List<String> itemIds, ${STATUS} status) {
        this.id = Objects.requireNonNull(id, "id");
        if (itemIds == null || itemIds.isEmpty()) {
            throw new DomainException(ErrorCode.${AGGREGATE}_EMPTY, "${AGGREGATE} requires at least one item");
        }
        this.itemIds = new ArrayList<>(itemIds);
        this.status = Objects.requireNonNull(status, "status");
    }

    /** Create a brand-new aggregate. All invariants are validated here. */
    public static ${AGGREGATE} create(${ID} id, List<String> itemIds) {
        return new ${AGGREGATE}(id, itemIds, ${STATUS}.CREATED);
    }

    /** Rebuild the aggregate from persistence data without creation-only side effects. */
    public static ${AGGREGATE} reconstitute(${ID} id, List<String> itemIds, ${STATUS} status) {
        return new ${AGGREGATE}(id, itemIds, status);
    }

    /** Business behaviour: state transition plus domain event, never a public setter. */
    public void confirm(Instant occurredAt) {
        if (this.status != ${STATUS}.CREATED) {
            throw new DomainException(ErrorCode.${AGGREGATE}_STATUS_INVALID,
                "Only a created ${AGGREGATE} can be confirmed");
        }
        this.status = ${STATUS}.CONFIRMED;
        this.domainEvents.add(new ${EVENT}(this.id, occurredAt));
    }

    public ${ID} id() {
        return id;
    }

    public ${STATUS} status() {
        return status;
    }

    public List<String> itemIds() {
        return Collections.unmodifiableList(itemIds);
    }

    public List<DomainEvent> domainEvents() {
        return Collections.unmodifiableList(domainEvents);
    }

    public void clearDomainEvents() {
        domainEvents.clear();
    }
}

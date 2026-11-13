package ${PACKAGE}.domain.model;

import ${PACKAGE}.domain.exception.DomainException;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.Arrays;
import java.util.Collections;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/** Pure unit test: no Spring context, no database, no mocks. */
class ${AGGREGATE}Test {

    @Test
    void confirm_onCreatedAggregate_changesStatusAndEmitsEvent() {
        // given
        ${AGGREGATE} aggregate = ${AGGREGATE}.create(
            ${ID}.of("A-1001"), Arrays.asList("item-1", "item-2"));

        // when
        aggregate.confirm(Instant.parse("2026-01-01T00:00:00Z"));

        // then
        assertEquals(${STATUS}.CONFIRMED, aggregate.status());
        assertEquals(1, aggregate.domainEvents().size());
    }

    @Test
    void confirm_twice_throwsDomainException() {
        ${AGGREGATE} aggregate = ${AGGREGATE}.create(
            ${ID}.of("A-1002"), Collections.singletonList("item-1"));
        aggregate.confirm(Instant.now());

        assertThrows(DomainException.class, () -> aggregate.confirm(Instant.now()));
    }

    @Test
    void create_withoutItems_throwsDomainException() {
        assertThrows(DomainException.class,
            () -> ${AGGREGATE}.create(${ID}.of("A-1003"), Collections.<String>emptyList()));
    }

    @Test
    void itemIds_returnsUnmodifiableView() {
        ${AGGREGATE} aggregate = ${AGGREGATE}.create(
            ${ID}.of("A-1004"), Collections.singletonList("item-1"));

        assertThrows(UnsupportedOperationException.class,
            () -> aggregate.itemIds().add("item-2"));
    }
}

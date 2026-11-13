package ${PACKAGE}.domain.event;

import java.time.Instant;

/**
 * Marker interface for domain events.
 * Keep it free of Spring / Jackson / broker types; the domain layer stays framework-agnostic.
 * Create this file only when the project has no equivalent abstraction.
 */
public interface DomainEvent {

    Instant occurredAt();
}

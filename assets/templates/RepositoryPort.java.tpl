package ${PACKAGE}.domain.repository;

import ${PACKAGE}.domain.model.${AGGREGATE};
import ${PACKAGE}.domain.model.${ID};

import java.util.Optional;

/**
 * Persistence port for the ${AGGREGATE} aggregate.
 * Interface lives in domain; implementation belongs to infrastructure.
 * Never expose PO / ORM types, paging objects, or field-level update methods.
 */
public interface ${AGGREGATE}Repository {

    Optional<${AGGREGATE}> findById(${ID} id);

    void save(${AGGREGATE} aggregate);
}

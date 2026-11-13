package ${PACKAGE}.infrastructure.persistence.repository;

import ${PACKAGE}.domain.model.${AGGREGATE};
import ${PACKAGE}.domain.model.${ID};
import ${PACKAGE}.domain.repository.${AGGREGATE}Repository;
import ${PACKAGE}.infrastructure.persistence.converter.${AGGREGATE}Converter;
import ${PACKAGE}.infrastructure.persistence.mapper.${MAPPER};
import ${PACKAGE}.infrastructure.persistence.po.${AGGREGATE}PO;

import org.springframework.stereotype.Repository;

import java.util.Objects;
import java.util.Optional;

/**
 * Adapter for the ${AGGREGATE}Repository port.
 * Domain <-> PO conversion happens here and nowhere else.
 * Transaction is provided by the calling application use case.
 */
@Repository
public class ${AGGREGATE}RepositoryImpl implements ${AGGREGATE}Repository {

    private final ${MAPPER} mapper;
    private final ${AGGREGATE}Converter converter;

    public ${AGGREGATE}RepositoryImpl(${MAPPER} mapper, ${AGGREGATE}Converter converter) {
        this.mapper = Objects.requireNonNull(mapper, "mapper");
        this.converter = Objects.requireNonNull(converter, "converter");
    }

    @Override
    public Optional<${AGGREGATE}> findById(${ID} id) {
        ${AGGREGATE}PO po = mapper.selectById(id.value());
        return Optional.ofNullable(po).map(converter::toDomain);
    }

    @Override
    public void save(${AGGREGATE} aggregate) {
        // Also persist child entities and apply optimistic locking / audit fields here.
        mapper.upsert(converter.toPO(aggregate));
    }
}

package ${PACKAGE}.domain.model;

import ${PACKAGE}.domain.exception.DomainException;
import ${PACKAGE}.domain.exception.ErrorCode;

import java.util.Objects;

/**
 * ${VALUE_OBJECT} value object: immutable, no identity, validates itself.
 * For Java 17+ a record with a compact constructor is an equivalent option.
 */
public final class ${VALUE_OBJECT} {

    private final String value;

    private ${VALUE_OBJECT}(String value) {
        String candidate = Objects.requireNonNull(value, "value").trim();
        if (candidate.isEmpty()) {
            throw new DomainException(ErrorCode.${VALUE_OBJECT}_INVALID, "${VALUE_OBJECT} must not be blank");
        }
        this.value = candidate;
    }

    public static ${VALUE_OBJECT} of(String value) {
        return new ${VALUE_OBJECT}(value);
    }

    public String value() {
        return value;
    }

    /** Add domain-specific operations here instead of exposing raw fields. */

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof ${VALUE_OBJECT})) {
            return false;
        }
        ${VALUE_OBJECT} that = (${VALUE_OBJECT}) other;
        return value.equals(that.value);
    }

    @Override
    public int hashCode() {
        return Objects.hash(value);
    }

    @Override
    public String toString() {
        return "${VALUE_OBJECT}(" + value + ")";
    }
}

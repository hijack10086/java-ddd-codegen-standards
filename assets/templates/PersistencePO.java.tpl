package ${PACKAGE}.infrastructure.persistence.po;

import java.time.LocalDateTime;

/**
 * ${AGGREGATE} persistence object. Add project-specific ORM annotations
 * (@TableName, @Entity, @Table ...) here, never in the domain model.
 * No business methods and no domain types as fields.
 */
public class ${AGGREGATE}PO {

    private String id;
    private String status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private Long version;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public Long getVersion() {
        return version;
    }

    public void setVersion(Long version) {
        this.version = version;
    }
}

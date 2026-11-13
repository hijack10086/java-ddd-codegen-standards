package ${PACKAGE};

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;

/**
 * Executable dependency matrix. Use only when the project already declares ArchUnit
 * (JUnit 4 flavour: replace @BeforeAll/@Test and drop the Jupiter imports).
 * Adjust package patterns when the project uses different layer names.
 */
class LayeringArchitectureTest {

    private static JavaClasses classes;

    @BeforeAll
    static void importClasses() {
        classes = new ClassFileImporter().importPackages("${PACKAGE}");
    }

    @Test
    void domain_shouldNotDependOnFrameworksOrUpperLayers() {
        ArchRule rule = classes().that().resideInAPackage("..domain..")
            .should().notDependOnClassesThat().resideInAnyPackage(
                "org.springframework..", "javax.persistence..", "jakarta.persistence..",
                "org.mybatis..", "com.baomidou..", "com.fasterxml.jackson..",
                "javax.servlet..", "jakarta.servlet..",
                "..interfaces..", "..application..", "..infrastructure..");
        rule.check(classes);
    }

    @Test
    void application_shouldNotDependOnInterfacesOrInfrastructure() {
        ArchRule rule = classes().that().resideInAPackage("..application..")
            .should().notDependOnClassesThat().resideInAnyPackage(
                "..interfaces..", "..infrastructure..", "javax.persistence..", "jakarta.persistence..");
        rule.check(classes);
    }

    @Test
    void interfaces_shouldNotDependOnInfrastructureOrRepositoryPorts() {
        ArchRule rule = classes().that().resideInAPackage("..interfaces..")
            .should().notDependOnClassesThat().resideInAnyPackage(
                "..infrastructure..", "..domain.repository..", "..domain.gateway..");
        rule.check(classes);
    }

    @Test
    void infrastructure_shouldNotDependOnUpperLayers() {
        ArchRule rule = classes().that().resideInAPackage("..infrastructure..")
            .should().notDependOnClassesThat().resideInAnyPackage("..interfaces..", "..application..");
        rule.check(classes);
    }

    @Test
    void repositoryImplementations_shouldResideInInfrastructure() {
        ArchRule rule = classes().that().haveSimpleNameEndingWith("RepositoryImpl")
            .should().resideInAPackage("..infrastructure..");
        rule.check(classes);
    }
}

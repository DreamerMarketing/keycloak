package cn.hztcloud.keycloak.bcrypt;

import org.junit.jupiter.api.Test;
import org.keycloak.models.credential.PasswordCredentialModel;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HztLegacyBcryptPasswordHashProviderTest {
    private final HztLegacyBcryptPasswordHashProvider provider = new HztLegacyBcryptPasswordHashProvider();

    @Test
    void verifiesBcrypt2aAnd2bWithoutLoggingOrTransformingTheHash() {
        String hash2a = "$2a$12$D4G5f18o7aMMfwasBL7xee8F.t88sEL6Hb/g6g7l1E0gOZa13HXxm";
        String hash2b = "$2b$12$D4G5f18o7aMMfwasBL7xee8F.t88sEL6Hb/g6g7l1E0gOZa13HXxm";

        assertTrue(provider.verify("migration-test-password", credential(hash2a)));
        assertTrue(provider.verify("migration-test-password", credential(hash2b)));
        assertFalse(provider.verify("wrong-password", credential(hash2b)));
    }

    @Test
    void rejectsMalformedCredentialsAndExtractsTheEmbeddedCost() {
        assertFalse(LegacyBcryptHash.isValid("not-a-bcrypt-hash"));
        assertTrue(LegacyBcryptHash.isValid("$2b$12$D4G5f18o7aMMfwasBL7xee8F.t88sEL6Hb/g6g7l1E0gOZa13HXxm"));
        assertEquals(12, LegacyBcryptHash.cost("$2b$12$D4G5f18o7aMMfwasBL7xee8F.t88sEL6Hb/g6g7l1E0gOZa13HXxm"));
    }

    @Test
    void createsAKeycloakCredentialUsingTheLegacyAlgorithmId() {
        PasswordCredentialModel credential = provider.encodedCredential("migration-test-password", 12);

        assertEquals(HztLegacyBcryptPasswordHashProvider.ID, credential.getPasswordCredentialData().getAlgorithm());
        assertEquals(12, credential.getPasswordCredentialData().getHashIterations());
        assertTrue(provider.verify("migration-test-password", credential));
    }

    private static PasswordCredentialModel credential(String hash) {
        return PasswordCredentialModel.createFromValues(HztLegacyBcryptPasswordHashProvider.ID, null, 12, hash);
    }
}

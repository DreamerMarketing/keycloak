package cn.hztcloud.keycloak.bcrypt;

import at.favre.lib.crypto.bcrypt.BCrypt;
import org.keycloak.credential.hash.PasswordHashProvider;
import org.keycloak.models.PasswordPolicy;
import org.keycloak.models.credential.PasswordCredentialModel;

public final class HztLegacyBcryptPasswordHashProvider implements PasswordHashProvider {
    public static final String ID = "bcrypt-legacy";

    @Override
    public boolean policyCheck(PasswordPolicy policy, PasswordCredentialModel credential) {
        return policy != null
                && ID.equals(policy.getHashAlgorithm())
                && credential.getPasswordCredentialData().getHashIterations() >= policy.getHashIterations();
    }

    @Override
    public PasswordCredentialModel encodedCredential(String rawPassword, int iterations) {
        int cost = iterations >= 4 && iterations <= 31 ? iterations : 12;
        String encoded = BCrypt.withDefaults().hashToString(cost, rawPassword.toCharArray());
        return PasswordCredentialModel.createFromValues(ID, null, cost, encoded);
    }

    @Override
    public boolean verify(String rawPassword, PasswordCredentialModel credential) {
        if (rawPassword == null || credential == null || credential.getPasswordSecretData() == null) {
            return false;
        }
        String encoded = credential.getPasswordSecretData().getValue();
        if (!LegacyBcryptHash.isValid(encoded)) {
            return false;
        }
        return BCrypt.verifyer().verify(rawPassword.toCharArray(), encoded).verified;
    }

    @Override
    public String credentialHashingStrength(PasswordCredentialModel credential) {
        return String.valueOf(credential.getPasswordCredentialData().getHashIterations());
    }

    @Override
    public void close() {
    }
}

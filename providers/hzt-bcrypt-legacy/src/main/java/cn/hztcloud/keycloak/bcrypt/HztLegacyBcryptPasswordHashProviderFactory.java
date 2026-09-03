package cn.hztcloud.keycloak.bcrypt;

import org.keycloak.Config;
import org.keycloak.credential.hash.PasswordHashProvider;
import org.keycloak.credential.hash.PasswordHashProviderFactory;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;

public final class HztLegacyBcryptPasswordHashProviderFactory implements PasswordHashProviderFactory {
    @Override
    public PasswordHashProvider create(KeycloakSession session) {
        return new HztLegacyBcryptPasswordHashProvider();
    }

    @Override
    public String getId() {
        return HztLegacyBcryptPasswordHashProvider.ID;
    }

    @Override
    public void init(Config.Scope config) {
    }

    @Override
    public void postInit(KeycloakSessionFactory factory) {
    }

    @Override
    public void close() {
    }
}

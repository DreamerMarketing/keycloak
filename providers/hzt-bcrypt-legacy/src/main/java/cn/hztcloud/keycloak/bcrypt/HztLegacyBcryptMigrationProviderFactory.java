package cn.hztcloud.keycloak.bcrypt;

import org.keycloak.Config;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.services.resource.RealmResourceProvider;
import org.keycloak.services.resource.RealmResourceProviderFactory;

public final class HztLegacyBcryptMigrationProviderFactory implements RealmResourceProviderFactory {
    public static final String ID = "hzt-legacy-bcrypt";

    @Override
    public RealmResourceProvider create(KeycloakSession session) {
        return new HztLegacyBcryptMigrationProvider(session);
    }

    @Override
    public String getId() {
        return ID;
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

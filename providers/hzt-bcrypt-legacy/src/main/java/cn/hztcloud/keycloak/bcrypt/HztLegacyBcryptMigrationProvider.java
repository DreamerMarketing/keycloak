package cn.hztcloud.keycloak.bcrypt;

import org.keycloak.models.KeycloakSession;
import org.keycloak.services.resource.RealmResourceProvider;

public final class HztLegacyBcryptMigrationProvider implements RealmResourceProvider {
    private final KeycloakSession session;

    public HztLegacyBcryptMigrationProvider(KeycloakSession session) {
        this.session = session;
    }

    @Override
    public Object getResource() {
        return new HztLegacyBcryptMigrationResource(session);
    }

    @Override
    public void close() {
    }
}

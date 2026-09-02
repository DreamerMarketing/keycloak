package cn.hztcloud.keycloak.bcrypt;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.keycloak.credential.CredentialModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;
import org.keycloak.models.credential.PasswordCredentialModel;
import org.keycloak.common.util.Time;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;

public final class HztLegacyBcryptMigrationResource {
    private static final int MAX_USERS = 200;
    private static final String TOKEN_ENV = "HZT_LEGACY_BCRYPT_IMPORT_TOKEN";

    private final KeycloakSession session;

    public HztLegacyBcryptMigrationResource(KeycloakSession session) {
        this.session = session;
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response importCredentials(@HeaderParam("X-HZT-Migration-Token") String suppliedToken,
                                      ImportRequest request) {
        requireMigrationToken(suppliedToken);
        if (request == null || request.users == null || request.users.isEmpty() || request.users.size() > MAX_USERS) {
            throw new BadRequestException("users must contain between 1 and " + MAX_USERS + " entries");
        }

        RealmModel realm = session.getContext().getRealm();
        HashSet<String> usernames = new HashSet<>();
        Map<String, UserModel> users = new HashMap<>();
        for (ImportUser item : request.users) {
            if (item == null || item.username == null || item.username.isBlank() || !LegacyBcryptHash.isValid(item.bcryptHash)) {
                throw new BadRequestException("invalid legacy bcrypt entry");
            }
            if (!usernames.add(item.username)) {
                throw new BadRequestException("duplicate username");
            }
            UserModel user = session.users().getUserByUsername(realm, item.username);
            if (user == null) {
                throw new BadRequestException("mapped Keycloak user is missing");
            }
            List<CredentialModel> existing = user.credentialManager()
                    .getStoredCredentialsByTypeStream(PasswordCredentialModel.TYPE)
                    .toList();
            if (existing.size() > 1) {
                throw new BadRequestException("user has multiple password credentials");
            }
            users.put(item.username, user);
        }

        int created = 0;
        int replaced = 0;
        for (ImportUser item : request.users) {
            UserModel user = users.get(item.username);
            List<CredentialModel> existing = user.credentialManager()
                    .getStoredCredentialsByTypeStream(PasswordCredentialModel.TYPE)
                    .toList();
            PasswordCredentialModel credential = PasswordCredentialModel.createFromValues(
                    HztLegacyBcryptPasswordHashProvider.ID,
                    null,
                    LegacyBcryptHash.cost(item.bcryptHash),
                    item.bcryptHash
            );
            credential.setCreatedDate(Time.currentTimeMillis());
            if (existing.isEmpty()) {
                user.credentialManager().createStoredCredential(credential);
                created++;
            } else {
                credential.setId(existing.getFirst().getId());
                user.credentialManager().updateStoredCredential(credential);
                replaced++;
            }
            user.removeRequiredAction(UserModel.RequiredAction.UPDATE_PASSWORD);
        }

        return Response.ok(Map.of(
                "ok", true,
                "imported", request.users.size(),
                "created", created,
                "replaced", replaced,
                "algorithm", HztLegacyBcryptPasswordHashProvider.ID
        )).build();
    }

    private static void requireMigrationToken(String suppliedToken) {
        String expected = System.getenv(TOKEN_ENV);
        if (expected == null || expected.length() < 32) {
            throw new ForbiddenException("legacy bcrypt import is disabled");
        }
        byte[] expectedBytes = expected.getBytes(StandardCharsets.UTF_8);
        byte[] suppliedBytes = suppliedToken == null
                ? new byte[0]
                : suppliedToken.getBytes(StandardCharsets.UTF_8);
        if (!MessageDigest.isEqual(expectedBytes, suppliedBytes)) {
            throw new ForbiddenException("invalid migration token");
        }
    }

    public static final class ImportRequest {
        public List<ImportUser> users;
    }

    public static final class ImportUser {
        public String username;
        public String bcryptHash;
    }
}

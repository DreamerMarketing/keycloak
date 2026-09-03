package cn.hztcloud.keycloak.bcrypt;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class LegacyBcryptHash {
    private static final Pattern FORMAT = Pattern.compile("^\\$2[aby]\\$(0[4-9]|[12][0-9]|3[01])\\$[./A-Za-z0-9]{53}$");

    private LegacyBcryptHash() {
    }

    static boolean isValid(String value) {
        return value != null && FORMAT.matcher(value).matches();
    }

    static int cost(String value) {
        Matcher matcher = FORMAT.matcher(value == null ? "" : value);
        if (!matcher.matches()) {
            throw new IllegalArgumentException("Invalid bcrypt credential");
        }
        return Integer.parseInt(matcher.group(1));
    }
}

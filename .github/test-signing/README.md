# Hiraukan test signing

`hiraukan-test-key.jks.b64` is a **test-only** signing key for the Android package
`com.noirero.hiraukan.test`.

It is intentionally committed so GitHub Actions test APKs keep the same signing
certificate across runs and can update one another without uninstalling.

Do **not** use this key for `com.noirero.hiraukan` production releases. Production
must use a private permanent keystore supplied through repository secrets.

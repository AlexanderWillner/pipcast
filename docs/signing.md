# Pipcast signing

Pipcast builds use a dedicated code-signing identity named `Pipcast Self-Signed`.
Create it once on the development Mac using Keychain Access → Certificate Assistant →
Create a Certificate: name `Pipcast Self-Signed`, identity type Self Signed Root,
certificate type Code Signing. Keep the certificate and its private key securely backed up.
The repository configures the identity name; it does not contain or create a certificate.

The same certificate must sign the initially installed app and subsequent updates.
The updater verifies the nested code signature and compares the candidate's leaf certificate
with the running app's certificate. The bundle identifier and version must also match.
Tinycast's developer team is not trusted. Ad-hoc or unsigned builds cannot satisfy this policy.

Verify that the identity is available before building:

```sh
security find-identity -v -p codesigning
```

Debug and Release builds share the signing identity but have separate bundle identifiers.
Release builds retain hardened runtime; Debug builds retain the upstream Debug settings.

The existing release workflow has not yet been adapted for Pipcast. Before using it,
configure it to use this identity and export only this certificate and its private key
as a password-protected PKCS#12 file for the release runner. Never commit that file,
its password, or a private key to the repository.

Losing or replacing the certificate prevents existing installations from accepting new
updates automatically. A certificate change requires a planned migration or manual reinstall.
Self-signing does not provide Apple notarization or remove Gatekeeper's first-install checks.

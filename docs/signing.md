# Pipcast signing

Public Release builds use **Developer ID Application**, with hardened runtime and a secure
timestamp. Debug builds retain the local `Pipcast Self-Signed` identity and never self-update.

Create or export your Developer ID Application certificate using your Apple Developer
account and Keychain Access on the development Mac. A certificate without its corresponding
private key cannot sign an app. Export only this identity as a password-protected `.p12`.
The release credentials are listed in [release.md](release.md). No private key belongs in git.

The release workflow injects `DEVELOPMENT_TEAM` from `APPLE_TEAM_ID`; the app embeds it as
`PipcastUpdateTeamID`. Update signatures must chain to Apple's Developer ID authority and
name that team. Missing or malformed team IDs fail closed. Bundle ID, version, and nested
signature validation remain mandatory. Certificate renewals under the same team are accepted;
a transfer to a different team requires an explicit migration. Self-signed releases are not accepted.

The workflow notarizes and staples both the app and DMG. This is outside Mac App Store
distribution; no App Store listing is required. First installation still receives the normal
macOS downloaded-app confirmation. No Gatekeeper bypass or quarantine stripping is needed.

Verify an installed development identity with `security find-identity -v -p codesigning`.
For local Release builds, provide your `DEVELOPMENT_TEAM` and Developer ID identity. For
public packaging use the manual Release workflow so notarization and stapling are included.

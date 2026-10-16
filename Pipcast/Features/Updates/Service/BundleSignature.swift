import Foundation
import Security

/// Release updates must belong to the configured Apple Developer team.
enum BundleSignature {
    static func requirement(teamID: String?) -> String? {
        guard let teamID, teamID.count == 10,
            teamID.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil else {
            return nil
        }
        return """
            anchor apple generic \
            and certificate leaf[subject.OU] = "\(teamID)" \
            and certificate 1[field.1.2.840.113635.100.6.2.6] exists \
            and certificate leaf[field.1.2.840.113635.100.6.1.13] exists
            """
    }

    static func isTrusted(_ bundleURL: URL) -> Bool {
        let teamID = Bundle.main.object(forInfoDictionaryKey: "PipcastUpdateTeamID") as? String
        guard let text = requirement(teamID: teamID) else { return false }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
            let requirement
        else { return false }
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &code) == errSecSuccess,
            let code
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }
}

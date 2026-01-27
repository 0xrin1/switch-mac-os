import Foundation

@MainActor
public final class SwitchAppModel: ObservableObject {
    @Published public private(set) var configError: String? = nil
    @Published public private(set) var xmpp: XMPPService = XMPPService()
    @Published public private(set) var directory: SwitchDirectoryService? = nil

    public init() {
        do {
            let config = try AppConfig.load()
            xmpp.connect(using: config)

            if let dirJid = config.switchDirectoryJid {
                directory = SwitchDirectoryService(
                    xmpp: xmpp,
                    directoryJid: dirJid,
                    pubSubJid: config.inferredPubSubJidIfMissing()
                )
                directory?.refreshAll()
            }
        } catch {
            configError = String(describing: error)
        }
    }
}

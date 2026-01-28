import Foundation

public struct SwitchAttachment: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let kind: String?
    public let mime: String?
    public let localPath: String?
    public let publicUrl: String?
    public let filename: String?
    public let sizeBytes: Int?
    public let sha256: String?

    public init(
        id: String,
        kind: String? = nil,
        mime: String? = nil,
        localPath: String? = nil,
        publicUrl: String? = nil,
        filename: String? = nil,
        sizeBytes: Int? = nil,
        sha256: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.mime = mime
        self.localPath = localPath
        self.publicUrl = publicUrl
        self.filename = filename
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case mime
        case localPath = "local_path"
        case publicUrl = "public_url"
        case filename
        case sizeBytes = "size_bytes"
        case sha256
    }
}

public struct SwitchAttachmentsPayload: Codable, Hashable, Sendable {
    public let attachments: [SwitchAttachment]

    public init(attachments: [SwitchAttachment]) {
        self.attachments = attachments
    }
}

public enum SwitchAttachmentCodec {
    public static func decodeAttachments(from json: String) -> [SwitchAttachment]? {
        guard let data = json.data(using: .utf8) else { return nil }
        let dec = JSONDecoder()
        if let arr = try? dec.decode([SwitchAttachment].self, from: data) {
            return arr
        }
        if let env = try? dec.decode(SwitchAttachmentsPayload.self, from: data) {
            return env.attachments
        }
        return nil
    }

    public static func encodePayloadJson(attachments: [SwitchAttachment]) -> String? {
        let env = SwitchAttachmentsPayload(attachments: attachments)
        let enc = JSONEncoder()
        guard let data = try? enc.encode(env) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

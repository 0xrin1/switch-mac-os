import Foundation

public struct SubagentWorkEnvelope: Codable, Sendable {
    public let taskId: String
    public let parentJid: String
    public let body: String

    public init(taskId: String, parentJid: String, body: String) {
        self.taskId = taskId
        self.parentJid = parentJid
        self.body = body
    }
}

public enum SubagentWorkCodec {
    public static func encode(_ envelope: SubagentWorkEnvelope) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(envelope) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(_ raw: String) -> SubagentWorkEnvelope? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SubagentWorkEnvelope.self, from: data)
    }
}

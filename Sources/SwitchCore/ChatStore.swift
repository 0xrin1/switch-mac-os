import Foundation
import Martin

public struct ChatMessage: Identifiable, Hashable, Sendable {
    public enum Direction: String, Sendable {
        case incoming
        case outgoing
    }

    public let id: String
    public let threadJid: String
    public let direction: Direction
    public let body: String
    public let timestamp: Date

    public init(id: String, threadJid: String, direction: Direction, body: String, timestamp: Date) {
        self.id = id
        self.threadJid = threadJid
        self.direction = direction
        self.body = body
        self.timestamp = timestamp
    }
}

@MainActor
public final class ChatStore: ObservableObject {
    @Published public private(set) var threads: [String: [ChatMessage]] = [:]

    public init() {}

    public func messages(for threadJid: String) -> [ChatMessage] {
        threads[threadJid] ?? []
    }

    public func appendIncoming(threadJid: String, body: String, id: String?, timestamp: Date) {
        appendIfMissing(
            ChatMessage(
                id: id ?? UUID().uuidString,
                threadJid: threadJid,
                direction: .incoming,
                body: body,
                timestamp: timestamp
            )
        )
    }

    public func appendOutgoing(threadJid: String, body: String, id: String?, timestamp: Date) {
        appendIfMissing(
            ChatMessage(
                id: id ?? UUID().uuidString,
                threadJid: threadJid,
                direction: .outgoing,
                body: body,
                timestamp: timestamp
            )
        )
    }

    private func appendIfMissing(_ message: ChatMessage) {
        var arr = threads[message.threadJid] ?? []
        if arr.contains(where: { $0.id == message.id }) {
            return
        }
        arr.append(message)
        arr.sort { $0.timestamp < $1.timestamp }
        threads[message.threadJid] = arr
    }
}

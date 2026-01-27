import Combine
import Foundation
import Martin

@MainActor
public final class SwitchDirectoryService: ObservableObject {
    @Published public private(set) var dispatchers: [DirectoryItem] = []
    @Published public private(set) var groups: [DirectoryItem] = []
    @Published public private(set) var individuals: [DirectoryItem] = []
    @Published public private(set) var subagents: [DirectoryItem] = []

    @Published public var navigationSelection: NavigationSelection? = nil
    @Published public private(set) var chatTarget: ChatTarget? = nil

    private let xmpp: XMPPService
    private let directoryBareJid: BareJID
    private let pubSubBareJid: BareJID?
    private let nodes: SwitchDirectoryNodes
    private var cancellables: Set<AnyCancellable> = []
    private var subscribedNodes: Set<String> = []
    private var lastSelectedIndividualJid: String? = nil

    public init(
        xmpp: XMPPService,
        directoryJid: String,
        pubSubJid: String?,
        nodes: SwitchDirectoryNodes = SwitchDirectoryNodes()
    ) {
        self.xmpp = xmpp
        self.directoryBareJid = BareJID(directoryJid)
        self.pubSubBareJid = pubSubJid.flatMap { BareJID($0) }
        self.nodes = nodes
        bindSelectionPipeline()
        bindPubSubRefresh()
    }

    public func refreshAll() {
        refreshDispatchers()
        refreshChildListsForCurrentSelection()
    }

    public func selectDispatcher(_ item: DirectoryItem) {
        navigationSelection = .dispatcher(item.jid)
        chatTarget = .dispatcher(item.jid)
        lastSelectedIndividualJid = nil
    }

    public func selectGroup(_ item: DirectoryItem) {
        navigationSelection = .group(item.jid)
    }

    public func selectIndividual(_ item: DirectoryItem) {
        navigationSelection = .individual(item.jid)
        chatTarget = .individual(item.jid)
        lastSelectedIndividualJid = item.jid
    }

    public func selectSubagent(_ item: DirectoryItem) {
        navigationSelection = .subagent(item.jid)
        chatTarget = .subagent(item.jid)
    }

    public func sendChat(body: String) {
        guard let target = chatTarget else { return }
        let jid: String
        switch target {
        case .dispatcher(let j), .individual(let j), .subagent(let j):
            jid = j
        }

        switch target {
        case .subagent:
            let taskId = UUID().uuidString
            let parent = lastSelectedIndividualJid ?? xmpp.client.userBareJid.stringValue
            xmpp.sendSubagentWork(to: jid, taskId: taskId, parentJid: parent, body: body)
        case .dispatcher, .individual:
            xmpp.sendMessage(to: jid, body: body)
        }
    }

    public func messagesForActiveChat() -> [ChatMessage] {
        guard let target = chatTarget else { return [] }
        let jid: String
        switch target {
        case .dispatcher(let j), .individual(let j), .subagent(let j):
            jid = j
        }
        return xmpp.chatStore.messages(for: jid)
    }

    private func refreshDispatchers() {
        let disco = xmpp.disco()
        let node = nodes.dispatchers
        disco.getItems(for: JID(directoryBareJid), node: node) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let items):
                    self.dispatchers = items.items.map { DirectoryItem(jid: $0.jid.bareJid.stringValue, name: $0.name) }
                    self.ensureSubscribed(to: node)
                case .failure:
                    self.dispatchers = []
                }
            }
        }
    }

    private func refreshChildListsForCurrentSelection() {
        switch navigationSelection {
        case .dispatcher(let dispatcherJid):
            refreshGroups(dispatcherJid: dispatcherJid)
            individuals = []
            subagents = []
        case .group(let groupJid):
            refreshIndividuals(groupJid: groupJid)
            subagents = []
        case .individual(let individualJid):
            refreshSubagents(individualJid: individualJid)
        case .subagent:
            break
        case .none:
            groups = []
            individuals = []
            subagents = []
        }
    }

    private func refreshGroups(dispatcherJid: String) {
        let disco = xmpp.disco()
        let node = nodes.groups(dispatcherJid)
        disco.getItems(for: JID(directoryBareJid), node: node) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let items):
                    self.groups = items.items.map { DirectoryItem(jid: $0.jid.bareJid.stringValue, name: $0.name) }
                    self.ensureSubscribed(to: node)
                case .failure:
                    self.groups = []
                }
            }
        }
    }

    private func refreshIndividuals(groupJid: String) {
        let disco = xmpp.disco()
        let node = nodes.individuals(groupJid)
        disco.getItems(for: JID(directoryBareJid), node: node) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let items):
                    self.individuals = items.items.map { DirectoryItem(jid: $0.jid.bareJid.stringValue, name: $0.name) }
                    self.ensureSubscribed(to: node)
                case .failure:
                    self.individuals = []
                }
            }
        }
    }

    private func refreshSubagents(individualJid: String) {
        let disco = xmpp.disco()
        let node = nodes.subagents(individualJid)
        disco.getItems(for: JID(directoryBareJid), node: node) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let items):
                    self.subagents = items.items.map { DirectoryItem(jid: $0.jid.bareJid.stringValue, name: $0.name) }
                    self.ensureSubscribed(to: node)
                case .failure:
                    self.subagents = []
                }
            }
        }
    }

    private func ensureSubscribed(to node: String) {
        guard !subscribedNodes.contains(node) else { return }

        let subscriber = xmpp.client.boundJid ?? JID(xmpp.client.userBareJid)
        let service = pubSubBareJid ?? directoryBareJid
        xmpp.pubsub().subscribe(at: service, to: node, subscriber: subscriber, completionHandler: nil)
        subscribedNodes.insert(node)
    }

    private func bindSelectionPipeline() {
        $navigationSelection
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.refreshChildListsForCurrentSelection()
            }
            .store(in: &cancellables)
    }

    private func bindPubSubRefresh() {
        xmpp.pubSubItemsEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                // Skeleton behavior: on any node update, re-run relevant disco queries.
                // This keeps the client correct even if the pubsub payload format evolves.
                if self.subscribedNodes.contains(notification.node) {
                    self.refreshAll()
                }
            }
            .store(in: &cancellables)
    }
}

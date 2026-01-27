# XMPP Client Specification

## Overview

A custom iOS XMPP client built with Swift using the **Tigase Martin** library. Features a four-column sidebar layout for organizing contacts hierarchically with an always-visible chat panel.

## Architecture

### Four-Column Sidebar Layout

| Column | Content | Behavior |
|--------|---------|----------|
| **1 (Left)** | Dispatchers | Selecting filters Column 2 + opens dispatcher chat |
| **2** | Groups (MUC Rooms) | Selecting filters Column 3 + opens group MUC chat |
| **3** | Individual Sessions | Selecting filters Column 4 + opens 1:1 chat |
| **4 (Right)** | Subagents | Selecting opens subagent chat |

### Selection Behavior

- **Single selection** across all columns at any time
- Selection in a parent column filters the child column(s)
- Clicking a dispatcher → shows only that dispatcher's groups in Column 2
- Clicking a group → shows only that group's individuals in Column 3
- Clicking an individual → shows that individual's subagents in Column 4
- Chat panel always shows the currently selected contact's conversation

### Chat Panel

- **Always visible** on the right side of the sidebar
- Shows **welcome/empty state** when nothing is selected (subtle design)
- Displays **1:1 chat** when an individual or subagent is selected
- Displays **MUC room** when a group is selected
- Displays **1:1 chat** when a dispatcher is selected

## Technical Stack

- **Language**: Swift
- **XMPP Library**: [Tigase Martin](https://github.com/tigase/Martin) (v3.2.1+)
  - Swift Package Manager integration
  - Modular XEP support
- **Real-time Updates**: XMPP event backbone via ejabberd
- **Platform**: iOS

## XMPP Features Required

### Core (Tigase Martin Built-in)
- XEP-0045: Multi-User Chat (MUC) - for groups
- XEP-0198: Stream Management - for reconnection
- XEP-0280: Message Carbons - for multi-device sync
- XEP-0313: Message Archive Management (MAM) - for history
- XEP-0357: Push Notifications - for iOS background

### Contact Types (All Standard XMPP JIDs)

1. **Dispatchers** - Standard XMPP contacts
2. **Groups** - MUC rooms (XEP-0045)
3. **Individuals** - Standard XMPP contacts
4. **Subagents** - Standard XMPP contacts (spawned by other agents)

## Data Flow

```
Dispatcher selected
    ↓
Filter groups to dispatcher's groups
    ↓
Group selected
    ↓
Filter individuals to group's members
    ↓
Individual selected
    ↓
Show individual's subagents + open chat
```

## UI States

### Welcome/Empty State
- Subtle, minimal design
- Displayed when no selection active
- No chat content shown

### Active Chat State
- Chat header shows contact/room name
- Message history loaded via MAM
- Real-time message delivery
- Typing indicators (optional)

## Future Considerations

- Subagents primarily exist to do work for their parent session/contact
- Backend assumes support for agent spawning
- All contact types use standard XMPP protocol

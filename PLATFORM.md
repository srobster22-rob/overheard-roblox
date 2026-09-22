# PLATFORM — which side of Roblox each engine API may be used on

The headless suite mocks Roblox, so it cannot see an API used on the side it
does not run on. It missed exactly that for 138 rounds: the chat hook was a
client-only callback set in the server script, so the live game never heard a
word (COACH.md C1, fixed in R139).

Every side-restricted engine API this game uses, or must never use on the
wrong side, is a row here. `tests/wiring.luau` reads the table: a `client` API
used anywhere in `src/server`, a `server` API used anywhere in `src/client`,
or either one in `src/shared` (which runs on both) fails the ship gate. A new
side-restricted API gets a row before it is used.

| API | use on | why (source) | used in |
|---|---|---|---|
| `OnIncomingMessage` | client | TextChatService and TextChannel: "should be defined on the client only" (Creator Hub, TextChatService) | nowhere since R139 |
| `MessageReceived` | client | TextChatService: "This event is only fired on the client" (Creator Hub, text chat overview) | nowhere |
| `SendingMessage` | client | TextChatService: fires on the sending client (Creator Hub, text chat overview) | nowhere |
| `LocalPlayer` | client | Players.LocalPlayer is nil on the server (memory, <= Jun 2026; Creator Hub, Players) | src/client |
| `FireServer` | client | RemoteEvent: a client calls the server (memory, <= Jun 2026; Creator Hub, RemoteEvent) | src/client |
| `OnClientEvent` | client | RemoteEvent: fires on the client (memory, <= Jun 2026; Creator Hub, RemoteEvent) | src/client |
| `ShouldDeliverCallback` | server | TextChannel: "should be defined on the server only" (Creator Hub, text chat overview) | nowhere |
| `Chatted` | server | Player.Chatted fires on the server for text chat; on the client it does not fire for the local player (DevForum 3652658, 3526019) | ChatFeed.luau |
| `FilterStringAsync` | server | TextService: filters text one user wrote before others see it; the Text filtering guide does it on the server, where the text arrives (practice, not verified as enforced) | init.server.luau |
| `GetNonChatStringForBroadcastAsync` | server | TextFilterResult: text every user may see, from FilterStringAsync's result (Creator Hub, Text filtering) | init.server.luau |
| `OnServerEvent` | server | RemoteEvent: fires on the server (memory, <= Jun 2026; Creator Hub, RemoteEvent) | init.server.luau |
| `FireClient` | server | RemoteEvent: the server calls one client (memory, <= Jun 2026; Creator Hub, RemoteEvent) | init.server.luau |
| `FireAllClients` | server | RemoteEvent: the server calls every client (memory, <= Jun 2026; Creator Hub, RemoteEvent) | init.server.luau |

Sources: [TextChatService](https://create.roblox.com/docs/reference/engine/classes/TextChatService) ·
[Text chat overview](https://create.roblox.com/docs/chat/in-experience-text-chat) ·
[Text filtering](https://create.roblox.com/docs/ui/text-filtering) ·
[TextFilterResult](https://create.roblox.com/docs/reference/engine/classes/TextFilterResult) ·
[Player.Chatted on the client](https://devforum.roblox.com/t/playerchatted-not-firing-on-the-client-for-the-local-player-with-textchatservice/3652658) ·
[Chatted on the server](https://devforum.roblox.com/t/alternative-for-playerchatted-with-textchatservice/3526019) ·
[RemoteEvent](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent) ·
[Players.LocalPlayer](https://create.roblox.com/docs/reference/engine/classes/Players#LocalPlayer)

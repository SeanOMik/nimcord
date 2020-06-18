import tables, hashes, json, message, user, guild, clientobjects

type
    EventType* = enum
        evtReady = "READY"
        evtMessageCreate = "MESSAGE_CREATE"
        evtGuildCreate = "GUILD_CREATE"

    BaseEvent* = object of RootObj
        client*: DiscordClient
        name*: string
    ReadyEvent* = object of BaseEvent
        readyPayload*: JsonNode
        clientUser*: User
    MessageCreateEvent* = object of BaseEvent
        message*: Message
    GuildCreateEvent* = object of BaseEvent
        guild*: Guild

# Table storing all the event listeners
let eventListeners = newTable[string, seq[proc(event: BaseEvent)]]()

proc registerEventListener*(event: EventType, listener: proc(event: BaseEvent)) =
    if (eventListeners.hasKey($event)):
        eventListeners[$event].add(cast[proc(event: BaseEvent)](listener))

        echo "Added other event listener: ", $event
    else:
        let tmp = @[listener]
        eventListeners.add($event, tmp)

        echo "Added new event listener: ", $event

proc dispatchEvent*[T: BaseEvent](event: T) = 
    if (eventListeners.hasKey(event.name)):
        let listeners = eventListeners[event.name]
        echo "Dispatching event: ", event.name
        for index, eventListener in listeners.pairs:
            eventListener(event)
    else:
        echo "No event listeners for event: ", event.name
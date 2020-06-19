import tables, hashes, json, message, user, guild, clientobjects

type
    EventType* = enum
        ## The event type.
        evtReady = "READY"
        evtMessageCreate = "MESSAGE_CREATE"
        evtGuildCreate = "GUILD_CREATE"

    BaseEvent* = object of RootObj
        ## Base event that all events inherit from.
        ## It stores a reference to the DiscordClient and name of the event.
        client*: DiscordClient
        name*: string
    ReadyEvent* = object of BaseEvent
        ## The ready event is triggered everytime the bot starts up.
        ## Stores the readyPayload (JSON Payload) that gets received and the bot's user.
        readyPayload*: JsonNode
        clientUser*: User
    MessageCreateEvent* = object of BaseEvent
        ## The Message Create event is triggered when someone sends a message.
        message*: Message
    GuildCreateEvent* = object of BaseEvent
        ## The Guild Create event is triggered when the bot starts, or when
        ## it gets added to a new guild.
        guild*: Guild

# Table storing all the event listeners
let eventListeners = newTable[string, seq[proc(event: BaseEvent)]]()

proc registerEventListener*(event: EventType, listener: proc(event: BaseEvent)) =
    ## Register an event listener.
    ## 
    ## Examples:
    ## 
    ## .. code-block:: nim
    ##   registerEventListener(EventType.evtReady, proc(bEvt: BaseEvent) =
    ##      let event = ReadyEvent(bEvt)
    ##      bot.clientUser = event.clientUser
    ##   
    ##      echo "Ready! (v", nimcordMajor, ".", nimcordMinor, ".", nimcordMicro, ")"
    ##      echo "Logged in as: ", bot.clientUser.username, "#", bot.clientUser.discriminator
    ##      echo "ID: ", bot.clientUser.id
    ##      echo "--------------------"
    ##   )
    if (eventListeners.hasKey($event)):
        eventListeners[$event].add(cast[proc(event: BaseEvent)](listener))

        echo "Added other event listener: ", $event
    else:
        let tmp = @[listener]
        eventListeners.add($event, tmp)

        echo "Added new event listener: ", $event

proc dispatchEvent*[T: BaseEvent](event: T) = 
    ## Dispatches an event so something can listen to it.
    if (eventListeners.hasKey(event.name)):
        let listeners = eventListeners[event.name]
        echo "Dispatching event: ", event.name
        for index, eventListener in listeners.pairs:
            eventListener(event)
    else:
        echo "No event listeners for event: ", event.name
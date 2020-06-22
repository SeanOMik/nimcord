import tables, hashes, json, message, emoji, user, member, role, guild, channel, clientobjects

type
    EventType* = enum
        ## The event type.
        evtReady = "READY"
        evtResumed = "RESUMED"
        evtReconnect = "RECONNECT"
        evtInvalidSession = "INVALID_SESSION"
        evtChannelCreate = "CHANNEL_CREATE"
        evtChannelUpdate = "CHANNEL_UPDATE"
        evtChannelDelete = "CHANNEL_DELETE"
        evtChannelPinsUpdate = "CHANNEL_PINS_UPDATE"
        evtGuildCreate = "GUILD_CREATE"
        evtGuildUpdate = "GUILD_UPDATE"
        evtGuildDelete = "GUILD_DELETE"
        evtGuildBanAdd = "GUILD_BAN_ADD"
        evtGuildBanRemove = "GUILD_BAN_REMOVE"
        evtGuildEmojisUpdate = "GUILD_EMOJIS_UPDATE"
        evtGuildIntegrationsUpdate = "GUILD_INTEGRATIONS_UPDATE"
        evtGuildMemberAdd = "GUILD_MEMBER_ADD"
        evtGuildMemberRemove = "GUILD_MEMBER_REMOVE"
        evtGuildMemberUpdate = "GUILD_MEMBER_UPDATE"
        evtGuildMembersChunk = "GUILD_MEMBERS_CHUNK"
        evtGuildRoleCreate = "GUILD_ROLE_CREATE"
        evtGuildRoleUpdate = "GUILD_ROLE_UPDATE"
        evtGuildRoleDelete = "GUILD_ROLE_DELETE"
        evtMessageUpdate = "MESSAGE_UPDATE"
        evtMessageDelete = "MESSAGE_DELETE"
        evtMessageCreate = "MESSAGE_CREATE"
        evtMessageDeleteBulk = "MESSAGE_DELETE_BULK"
        evtMessageReactionAdd = "MESSAGE_REACTION_ADD"
        evtMessageReactionRemove = "MESSAGE_REACTION_REMOVE"
        evtMessageReactionRemoveAll = "MESSAGE_REACTION_REMOVE_ALL"
        evtPresenceUpdate = "PRESENCE_UPDATE"
        evtTypingStart = "TYPING_START"
        evtUserUpdate = "USER_UPDATE"
        evtVoiceStateUpdate = "VOICE_STATE_UPDATE"
        evtVoiceServerUpdate = "VOICE_SERVER_UPDATE"
        evtWebhooksUpdate = "WEBHOOKS_UPDATE"

    BaseEvent* = object of RootObj
        ## Base event that all events inherit from.
        ## It stores a reference to the DiscordClient and name of the event.
        client*: DiscordClient
        name*: string

    # Socket Events

    ReadyEvent* = object of BaseEvent
        ## The ready event is triggered everytime the bot starts up.
        ## Stores the readyPayload (JSON Payload) that gets received and the bot's user.
        readyPayload*: JsonNode

    # Channel Events

    ChannelCreateEvent* = object of BaseEvent
        ## The Channel Create event is triggered when a new channel is created.
        channel*: Channel

    ChannelUpdateEvent* = object of BaseEvent
        ## The Channel Update event is triggered when a channel is updated.
        channel*: Channel

    ChannelDeleteEvent* = object of BaseEvent
        ## The Channel Delete event is triggered when a channel is deleted.
        channel*: Channel

    ChannelPinsUpdateEvent* = object of BaseEvent
        ## The Channel Pins Update event is triggered when a channel pin is updated.
        channel*: Channel

    # Guild Events

    GuildCreateEvent* = object of BaseEvent
        ## The Guild Create event is triggered when the bot starts, or when
        ## it gets added to a new guild.
        guild*: Guild

    GuildUpdateEvent* = object of BaseEvent
        ## The Guild Update event is triggered when a guild is updated.
        guild*: Guild

    GuildDeleteEvent* = object of BaseEvent
        ## The Guild Delete event is triggered when a guild is deleted.
        guild*: Guild

    GuildBanAddEvent* = object of BaseEvent
        ## The Guild Ban Add Event is triggered when a member is banned from the guild.
        guild*: Guild
        guild_member*: GuildMember
    
    GuildBanRemoveEvent* = object of BaseEvent
        ## The Guild Ban Remove Event is triggered when a member is unbanned from a guild.
        guild*: Guild
        guild_member*: GuildMember

    GuildEmojisUpdateEvent* = object of BaseEvent
        ## The Guild Emojis Update event is triggered when a guild emote is updated.
        guild*: Guild
        emoji*: Emoji

    #GuildIntegrationsUpdateEvent* = object of BaseEvent

    GuildMemberAddEvent* = object of BaseEvent
        ## The Guild Member Add event is triggered when a user joins a guild.
        guild*: Guild
        guild_member*: GuildMember

    GuildMemberRemoveEvent* = object of BaseEvent
        ## The Guild Member Remove event is triggered when a user leaves a guild.
        guild*: Guild
        guild_member*: GuildMember

    GuildMemberUpdateEvent* = object of BaseEvent
        ## The Guild Member Update event is triggered when a member is updated.
        guild*: Guild
        guild_member*: GuildMember

    #GuildMembersChunkEvent* = object of BaseEvent

    GuildRoleCreateEvent* = object of BaseEvent
        ## The Guild Role Create event is triggered when a role is created.
        guild*: Guild
        role*: Role

    GuildRoleUpdateEvent* = object of BaseEvent
        ## The Guild Role Update event is triggered when a role is updated.
        guild*: Guild
        role*: Role

    GuildRoleDeleteEvent* = object of BaseEvent
        ## The Guild Role Delete event is triggered when a role is deleted.
        guild*: Guild
        role*: Role

    # Message events

    MessageCreateEvent* = object of BaseEvent
        ## The Message Create event is triggered when someone sends a message.
        message*: Message

    MessageUpdateEvent* = object of BaseEvent
        ## The Message Update event is triggered when a message is updated.
        message*: Message

    MessageDeleteEvent* = object of BaseEvent
        ## The Message Create event is triggered when a message is deleted.
        message*: Message


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
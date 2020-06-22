import eventhandler, json, tables, message, emoji, user, member, role
import guild, channel, nimcordutils, httpClient, strformat, cache
import sequtils, asyncdispatch, clientobjects, discordobject, presence

proc readyEvent(discordClient: DiscordClient, json: JsonNode) =
    var readyEvent = ReadyEvent(client: discordClient, readyPayload: json, name: $EventType.evtReady)
    
    # Get client user
    var client = newHttpClient()
    # Add headers
    client.headers = newHttpHeaders({"Authorization": fmt("Bot {discordClient.token}"), 
        "User-Agent": "NimCord (https://github.com/SeanOMik/nimcord, v0.0.0)",
        "X-RateLimit-Precision": "millisecond"})
    echo "Sending GET request, URL: body: {}"

    waitForRateLimits(0, RateLimitBucketType.global)
    var userJson = handleResponse(client.request(endpoint("/users/@me"), HttpGet, ""), 0, RateLimitBucketType.global)

    discordClient.clientUser = newUser(userJson)
    discordClient.sessionID = json["session_id"].getStr()
    
    dispatchEvent(readyEvent)

proc channelCreateEvent(discordClient: DiscordClient, json: JsonNode) = 
    let chnl = newChannel(json)
    let channelCreateEvent = ChannelCreateEvent(client: discordClient, channel: chnl, name: $EventType.evtChannelCreate)

    # Add the channel to its guild's `channels` field
    if (chnl.guildID != 0):
        discordClient.cache.cacheGuildChannel(chnl.guildID, chnl)
    discordClient.cache.channels[chnl.id] = chnl

    dispatchEvent(channelCreateEvent)

proc channelUpdateEvent(discordClient: DiscordClient, json: JsonNode) = 
    let chnl = newChannel(json)
    let channelUpdateEvent = ChannelUpdateEvent(client: discordClient, channel: chnl, name: $EventType.evtChannelUpdate)

    discordClient.cache.channels[chnl.id] = chnl

    if (chnl.guildID != 0):
        let g = discordClient.cache.getGuild(chnl.guildID)
        
        var index = -1
        for i, channel in g.channels:
            if (channel.id == chnl.id):
                index = i

        if (index != -1):
            g.channels[index] = chnl
        else:
            g.channels.add(chnl)
                

    dispatchEvent(channelUpdateEvent)


proc channelDeleteEvent(discordClient: DiscordClient, json: JsonNode) = 
    let chnl = newChannel(json)
    let channelDeleteEvent = ChannelDeleteEvent(client: discordClient, channel: chnl, name: $EventType.evtChannelDelete)

    var removedChnl: Channel
    discard discordClient.cache.channels.pop(chnl.id, removedChnl)

    dispatchEvent(channelDeleteEvent)

proc channelPinsUpdate(discordClient: DiscordClient, json: JsonNode) =
    let channelID = getIDFromJson(json["channel_id"].getStr())

    var channel: Channel
    if (discordClient.cache.channels.hasKey(channelID)):
        channel = discordClient.cache.channels[channelID]
        channel.lastPinTimestamp = json["last_pin_timestamp"].getStr()

    let channelPinsUpdateEvent = ChannelPinsUpdateEvent(client: discordClient, channel: channel, name: $EventType.evtChannelPinsUpdate)
    dispatchEvent(channelPinsUpdateEvent)

proc guildCreateEvent(discordClient: DiscordClient, json: JsonNode) =
    let g = newGuild(json)
    let guildCreateEvnt = GuildCreateEvent(client: discordClient, guild: g, name: $EventType.evtGuildCreate)

    # Add guild and its channels and members in cache.
    discordClient.cache.guilds[g.id] = g
    for channel in g.channels:
        discordClient.cache.channels[channel.id] = channel
    for member in g.members:
        discordClient.cache.members[member.id] = member

    dispatchEvent(guildCreateEvnt)

proc guildUpdateEvent(discordClient: DiscordClient, json: JsonNode) =
    let g = newGuild(json)
    let guildUpdateEvent = GuildUpdateEvent(client: discordClient, guild: g, name: $EventType.evtGuildUpdate)

    # Update guild in cache.
    discordClient.cache.guilds[g.id] = g

    dispatchEvent(guildUpdateEvent)

proc guildDeleteEvent(discordClient: DiscordClient, json: JsonNode) =
    let g = newGuild(json)
    let guildDeleteEvent = GuildDeleteEvent(client: discordClient, guild: g, name: $EventType.evtGuildDelete)

    # Remove guild from cache
    var removedGuild: Guild
    discard discordClient.cache.guilds.pop(g.id, removedGuild)

    dispatchEvent(guildDeleteEvent)

proc guildBanAddEvent(discordClient: DiscordClient, json: JsonNode) =
    let g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let user = newUser(json["user"])

    let guildBanAddEvent = GuildBanAddEvent(client: discordClient, guild: g, bannedUser: user, name: $EventType.evtGuildBanAdd)
    dispatchEvent(guildBanAddEvent)

proc guildBanRemoveEvent(discordClient: DiscordClient, json: JsonNode) =
    let g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let user = newUser(json["user"])

    let guildBanRemoveEvent = GuildBanRemoveEvent(client: discordClient, guild: g, unbannedUser: user, name: $EventType.evtGuildBanRemove)
    dispatchEvent(guildBanRemoveEvent)

proc guildEmojisUpdateEvent(discordClient: DiscordClient, json: JsonNode) =
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    # Empty g.emojis and fill it with the newly updated emojis
    g.emojis = @[]
    for emoji in json["emojis"]:
        g.emojis.add(newEmoji(emoji, g.id))

    let guildEmojisUpdateEvent = GuildEmojisUpdateEvent(client: discordClient, guild: g, emojis: g.emojis, name: $EventType.evtGuildEmojisUpdate)
    dispatchEvent(guildEmojisUpdateEvent)

    #[ var updatedEmojis: Table[snowflake, Emoji] = initTable[snowflake, Emoji]()
    for emoji in json["emojis"]:
        var currentEmoji: Emoji = newEmoji(emoji, g.id)
        updatedEmojis[currentEmoji.id] = currentEmoji

    for emoji in g.emojis:
        if updatedEmojis.hasKey(emoji.id):
            emoji = updatedEmojis[emoji.id] ]#
    
            #g.emojis.apply

proc guildIntegrationsUpdate(discordClient: DiscordClient, json: JsonNode) =
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    let guildIntegrationsUpdateEvent = GuildIntegrationsUpdateEvent(client: discordClient, guild: g, name: $EventType.evtGuildIntegrationsUpdate)
    dispatchEvent(guildIntegrationsUpdateEvent)

proc guildMemberAdd(discordClient: DiscordClient, json: JsonNode) =
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    var newMember = newGuildMember(json, g.id)

    let guildMemberAddEvent = GuildMemberAddEvent(client: discordClient, guild: g, member: newMember, name: $EventType.evtGuildMemberAdd)
    dispatchEvent(guildMemberAddEvent)

proc guildMemberRemove(discordClient: DiscordClient, json: JsonNode) =
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    var removedUser = newUser(json["user"])

    let guildMemberRemoveEvent = GuildMemberRemoveEvent(client: discordClient, guild: g, user: removedUser, name: $EventType.evtGuildMemberRemove)
    dispatchEvent(guildMemberRemoveEvent)

proc guildMemberUpdate(discordClient: DiscordClient, json: JsonNode) =
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    var updatedMember = g.getGuildMember(getIDFromJson(json["user"]["id"].getStr()))
    updatedMember.user = newUser(json["user"])

    updatedMember.roles = @[]
    for roleID in json["roles"]:
        updatedMember.roles.add(getIDFromJson(roleID.getStr()))

    if json.contains("nick"):
        updatedMember.nick = json["nick"].getStr()

    if json.contains("premium_since"):
        updatedMember.premiumSince = json["premium_since"].getStr()

    let guildMemberUpdateEvent = GuildMemberUpdateEvent(client: discordClient, guild: g, member: updatedMember, name: $EventType.evtGuildMemberUpdate)
    dispatchEvent(guildMemberUpdateEvent)

proc guildMembersChunk(discordClient: DiscordClient, json: JsonNode) =
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    var event = GuildMembersChunkEvent(client: discordClient, guild: g, name: $EventType.evtGuildMembersChunk)

    #var members: seq[GuildMember]
    for member in json["members"]:
        event.members.add(newGuildMember(member, g.id))
        
    event.chunkIndex = json["chunk_index"].getInt()
    event.chunkCount = json["chunk_count"].getInt()

    if (json.contains("not_found")):
        for id in json["not_found"]:
            event.notFound.add(getIDFromJson(id.getStr()))

    if (json.contains("presences")):
        for presence in json["presences"]:
            event.presences.add(newPresence(presence))

    if (json.contains("nonce")):
        event.nonce = json["nonce"].getStr()

    dispatchEvent(event)
    
proc guildRoleCreate(discordClient: DiscordClient, json: JsonNode) =
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let role = newRole(json["role"], g.id)

    g.roles.add(role)

    var event = GuildRoleUpdateEvent(client: discordClient, guild: g, role: role, name: $EventType.evtGuildRoleUpdate)
    dispatchEvent(event)

proc guildRoleUpdate(discordClient: DiscordClient, json: JsonNode) =
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let role = newRole(json["role"], g.id)

    var index = -1
    for i, r in g.roles:
        if r.id == role.id:
            index = i

    g.roles[index] = role

    var event = GuildRoleUpdateEvent(client: discordClient, guild: g, role: role, name: $EventType.evtGuildRoleUpdate)
    dispatchEvent(event)

proc guildRoleDelete(discordClient: DiscordClient, json: JsonNode) =
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let roleID = getIDFromJson(json["role_id"].getStr())

    var role: Role
    var index = -1
    for i, r in g.roles:
        if r.id == roleID:
            index = i
            role = r

    if index != -1:
        g.roles.delete(index)

    var event = GuildRoleDeleteEvent(client: discordClient, guild: g, role: role, name: $EventType.evtGuildRoleDelete)
    dispatchEvent(event)

proc inviteCreate(discordClient: DiscordClient, json: JsonNode) =
    var invite = newInvite(json)

    invite.channel = discordClient.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))

    if (json.contains("guild_id")):
        invite.guildID =getIDFromJson(json["guild_id"].getStr())

    var event = InviteCreateEvent(client: discordClient, invite: invite, name: $EventType.evtInviteCreate)
    dispatchEvent(event)

proc inviteDelete(discordClient: DiscordClient, json: JsonNode) =
    var event = InviteDeleteEvent(client: discordClient, name: $EventType.evtInviteDelete)

    event.channel = discordClient.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))
    event.code = json["code"].getStr()

    if (json.contains("guild_id")):
        event.guild = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    dispatchEvent(event)

proc messageCreateEvent(discordClient: DiscordClient, json: JsonNode) =
    let msg = newMessage(json)

    discordClient.cache.messages[msg.id] = msg

    let messageCreateEvnt = MessageCreateEvent(client: discordClient, message: msg, name: $EventType.evtMessageCreate)
    dispatchEvent(messageCreateEvnt)

proc messageUpdateEvent(discordClient: DiscordClient, json: JsonNode) =
    let msg = newMessage(json)

    discordClient.cache.messages[msg.id] = msg

    let event = MessageCreateEvent(client: discordClient, message: msg, name: $EventType.evtMessageUpdate)
    dispatchEvent(event)

proc messageDeleteEvent(discordClient: DiscordClient, json: JsonNode) =
    let msgID = getIDFromJson(json["id"].getStr())

    var msg: Message
    if discordClient.cache.messages.hasKey(msgID):
        discard discordClient.cache.messages.pop(msgID, msg)
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    let event = MessageDeleteEvent(client: discordClient, message: msg, name: $EventType.evtMessageDelete)
    dispatchEvent(event)

proc messageDeleteBulkEvent(discordClient: DiscordClient, json: JsonNode) =
    var event = MessageDeleteBulkEvent(client: discordClient, name: $EventType.evtMessageDeleteBulk)

    event.channel = discordClient.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))
    if (json.contains("guild_id")):
        event.guild = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    for msgIDJson in json["ids"]:
        let msgID = getIDFromJson(msgIDJson.getStr())

        var msg: Message
        if discordClient.cache.messages.hasKey(msgID):
            discard discordClient.cache.messages.pop(msgID, msg)
        else:
            let channelID = getIDFromJson(json["channel_id"].getStr())
            msg = Message(id: msgID, channelID: channelID)

            event.channel = discordClient.cache.getChannel(msg.channelID)
            if (json.contains("guild_id")):
                msg.guildID = getIDFromJson(json["guild_id"].getStr())
        
        event.messages.add(msg)

    dispatchEvent(event)

proc messageReactionAdd(discordClient: DiscordClient, json: JsonNode) =
    var event = MessageReactionAddEvent(client: discordClient, name: $EventType.evtMessageReactionAdd)

    let msgID = getIDFromJson(json["message_id"].getStr())
    var msg: Message
    if discordClient.cache.messages.hasKey(msgID):
        msg = discordClient.cache.messages[msgID]
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    event.user = discordClient.cache.getUser(getIDFromJson(json["user_id"].getStr()))

    if (json.contains("member")):
        event.member = newGuildMember(json["member"], msg.guildID)

    event.emoji = newEmoji(json["emoji"], msg.guildID)

    dispatchEvent(event)

proc messageReactionRemove(discordClient: DiscordClient, json: JsonNode) =
    var event = MessageReactionRemoveEvent(client: discordClient, name: $EventType.evtMessageReactionRemove)

    let msgID = getIDFromJson(json["message_id"].getStr())
    var msg: Message
    if discordClient.cache.messages.hasKey(msgID):
        msg = discordClient.cache.messages[msgID]
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    event.user = discordClient.cache.getUser(getIDFromJson(json["user_id"].getStr()))

    event.emoji = newEmoji(json["emoji"], msg.guildID)

    dispatchEvent(event)

proc messageReactionRemoveAll(discordClient: DiscordClient, json: JsonNode) =
    var event = MessageReactionRemoveAllEvent(client: discordClient, name: $EventType.evtMessageReactionRemoveAll)

    let msgID = getIDFromJson(json["message_id"].getStr())
    var msg: Message
    if discordClient.cache.messages.hasKey(msgID):
        msg = discordClient.cache.messages[msgID]
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    dispatchEvent(event)

proc messageReactionRemoveEmoji(discordClient: DiscordClient, json: JsonNode) =
    var event = MessageReactionRemoveEmojiEvent(client: discordClient, name: $EventType.evtMessageReactionRemoveEmoji)

    let msgID = getIDFromJson(json["message_id"].getStr())
    var msg: Message
    if discordClient.cache.messages.hasKey(msgID):
        msg = discordClient.cache.messages[msgID]
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    event.emoji = newEmoji(json["emoji"], msg.guildID)

    dispatchEvent(event)

proc presenceUpdate(discordClient: DiscordClient, json: JsonNode) =
    # This proc doesn't actually dispatch any events,
    # it just updates member.presence
    var g = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    var member = g.getGuildMember(getIDFromJson(json["user"]["id"].getStr()))

    # Make sure some member fields are upto date.
    member.roles = @[]
    for role in json["roles"]:
        member.roles.add(getIDFromJson(role.getStr()))

    if (json.contains("premium_since")):
        member.premiumSince = json["premium_since"].getStr()
    if (json.contains("nick")):
        member.nick = json["nick"].getStr()

    member.presence = newPresence(json)

proc typingStart(discordClient: DiscordClient, json: JsonNode) =
    var event = TypingStartEvent(client: discordClient, name: $EventType.evtTypingStart)

    event.channel = discordClient.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))

    if (json.contains("guild_id")):
        event.channel.guildID = getIDFromJson(json["guild_id"].getStr())

    event.user = discordClient.cache.getUser(getIDFromJson(json["user_id"].getStr()))

    if (json.contains("member")):
        event.member = newGuildMember(json["member"], event.channel.guildID)

    dispatchEvent(event)

proc userUpdate(discordClient: DiscordClient, json: JsonNode) =
    var event = UserUpdateEvent(client: discordClient, name: $EventType.evtUserUpdate)

    event.user = newUser(json)

    dispatchEvent(event)

proc voiceStateUpdate(discordClient: DiscordClient, json: JsonNode) =
    var event = VoiceStateUpdateEvent(client: discordClient, name: $EventType.evtVoiceStateUpdate)

    dispatchEvent(event)

proc voiceServerUpdate(discordClient: DiscordClient, json: JsonNode) =
    var event = VoiceServerUpdateEvent(client: discordClient, name: $EventType.evtVoiceServerUpdate)

    event.token = json["token"].getStr()
    event.guild = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    event.endpoint = json["endpoint"].getStr()

    dispatchEvent(event)

proc webhooksUpdate(discordClient: DiscordClient, json: JsonNode) =
    var event = WebhooksUpdateEvent(client: discordClient, name: $EventType.evtWebhooksUpdate)

    event.guild = discordClient.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    event.channel = discordClient.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))

    dispatchEvent(event)

let internalEventTable: Table[string, proc(discordClient: DiscordClient, json: JsonNode) {.nimcall.}] = {
        "READY": readyEvent,
        "CHANNEL_CREATE": channelCreateEvent,
        "CHANNEL_UPDATE": channelUpdateEvent,
        "CHANNEL_DELETE": channelDeleteEvent,
        "CHANNEL_PINS_UPDATE": channelPinsUpdate,
        "GUILD_CREATE": guildCreateEvent,
        "GUILD_UPDATE": guildUpdateEvent,
        "GUILD_DELETE": guildDeleteEvent,
        "GUILD_BAN_ADD": guildBanAddEvent,
        "GUILD_BAN_REMOVE": guildBanRemoveEvent,
        "GUILD_EMOJIS_UPDATE": guildEmojisUpdateEvent,
        "GUILD_INTEGRATIONS_UPDATE": guildIntegrationsUpdate,
        "GUILD_MEMBER_ADD": guildMemberAdd,
        "GUILD_MEMBER_REMOVE": guildMemberRemove,
        "GUILD_MEMBER_UPDATE": guildMemberUpdate,
        "GUILD_MEMBER_CHUNK": guildMembersChunk,
        "GUILD_ROLE_CREATE": guildRoleCreate,
        "GUILD_ROLE_UPDATE": guildRoleUpdate,
        "GUILD_ROLE_DELETE": guildRoleDelete,
        "INVITE_CREATE": inviteCreate,
        "INVITE_DELETE": inviteDelete,
        "MESSAGE_CREATE": messageCreateEvent,
        "MESSAGE_DELETE": messageDeleteEvent,
        "MESSAGE_DELETE_BULK": messageDeleteBulkEvent,
        "MESSAGE_REACTION_ADD": messageReactionAdd,
        "MESSAGE_REACTION_REMOVE": messageReactionRemove,
        "MESSAGE_REACTION_REMOVE_ALL": messageReactionRemoveAll,
        "MESSAGE_REACTION_REMOVE_EMOJI": messageReactionRemoveEmoji,
        "PRESENCE_UPDATE": presenceUpdate,
        "TYPING_START": typingStart,
        "USER_UPDATE": userUpdate,
        "VOICE_STATE_UPDATE": voiceStateUpdate,
        "VOICE_SERVER_UPDATE": voiceServerUpdate,
        "WEBHOOKS_UPDATE": webhooksUpdate
    }.toTable

proc handleDiscordEvent*(discordClient: DiscordClient, json: JsonNode, eventName: string) {.async.} =
    ## Handles, and dispatches, a gateway event. Only used internally.
    if (internalEventTable.hasKey(eventName)):
        let eventProc: proc(discordClient: DiscordClient, json: JsonNode) = internalEventTable[eventName]
        eventProc(discordClient, json)
    else:
        echo "Failed to find event: ", eventName
        
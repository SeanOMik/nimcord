import eventhandler, json, tables, message, emoji, user, member, role
import guild, channel, nimcordutils, httpClient, strformat, cache
import sequtils, asyncdispatch, clientobjects, discordobject, presence

proc readyEvent(shard: Shard, json: JsonNode) =
    var readyEvent = ReadyEvent(shard: shard, readyPayload: json, name: $EventType.evtReady)
    
    # Get client user
    var client = newHttpClient()
    # Add headers
    client.headers = newHttpHeaders({"Authorization": fmt("Bot {shard.client.token}"), 
        "User-Agent": "NimCord (https://github.com/SeanOMik/nimcord, v0.0.0)",
        "X-RateLimit-Precision": "millisecond"})
    echo "Sending GET request, URL: body: {}"

    waitForRateLimits(0, RateLimitBucketType.global)
    var userJson = handleResponse(client.request(endpoint("/users/@me"), HttpGet, ""), 0, RateLimitBucketType.global)

    shard.client.clientUser = newUser(userJson)
    shard.sessionID = json["session_id"].getStr()
    
    dispatchEvent(readyEvent)

proc channelCreateEvent(shard: Shard, json: JsonNode) = 
    let chnl = newChannel(json)
    let channelCreateEvent = ChannelCreateEvent(shard: shard, channel: chnl, name: $EventType.evtChannelCreate)

    # Add the channel to its guild's `channels` field
    if (chnl.guildID != 0):
        shard.client.cache.cacheGuildChannel(chnl.guildID, chnl)
    shard.client.cache.channels[chnl.id] = chnl

    dispatchEvent(channelCreateEvent)

proc channelUpdateEvent(shard: Shard, json: JsonNode) = 
    let chnl = newChannel(json)
    let channelUpdateEvent = ChannelUpdateEvent(shard: shard, channel: chnl, name: $EventType.evtChannelUpdate)

    shard.client.cache.channels[chnl.id] = chnl

    if (chnl.guildID != 0):
        let g = shard.client.cache.getGuild(chnl.guildID)
        
        var index = -1
        for i, channel in g.channels:
            if (channel.id == chnl.id):
                index = i

        if (index != -1):
            g.channels[index] = chnl
        else:
            g.channels.add(chnl)
                

    dispatchEvent(channelUpdateEvent)


proc channelDeleteEvent(shard: Shard, json: JsonNode) = 
    let chnl = newChannel(json)
    let channelDeleteEvent = ChannelDeleteEvent(shard: shard, channel: chnl, name: $EventType.evtChannelDelete)

    var removedChnl: Channel
    discard shard.client.cache.channels.pop(chnl.id, removedChnl)

    dispatchEvent(channelDeleteEvent)

proc channelPinsUpdate(shard: Shard, json: JsonNode) =
    let channelID = getIDFromJson(json["channel_id"].getStr())

    var channel: Channel
    if (shard.client.cache.channels.hasKey(channelID)):
        channel = shard.client.cache.channels[channelID]
        channel.lastPinTimestamp = json["last_pin_timestamp"].getStr()

    let channelPinsUpdateEvent = ChannelPinsUpdateEvent(shard: shard, channel: channel, name: $EventType.evtChannelPinsUpdate)
    dispatchEvent(channelPinsUpdateEvent)

proc guildCreateEvent(shard: Shard, json: JsonNode) =
    let g = newGuild(json)
    let guildCreateEvnt = GuildCreateEvent(shard: shard, guild: g, name: $EventType.evtGuildCreate)

    # Add guild and its channels and members in cache.
    shard.client.cache.guilds[g.id] = g
    for channel in g.channels:
        shard.client.cache.channels[channel.id] = channel
    for member in g.members:
        shard.client.cache.members[member.id] = member

    dispatchEvent(guildCreateEvnt)

proc guildUpdateEvent(shard: Shard, json: JsonNode) =
    let g = newGuild(json)
    let guildUpdateEvent = GuildUpdateEvent(shard: shard, guild: g, name: $EventType.evtGuildUpdate)

    # Update guild in cache.
    shard.client.cache.guilds[g.id] = g

    dispatchEvent(guildUpdateEvent)

proc guildDeleteEvent(shard: Shard, json: JsonNode) =
    let g = newGuild(json)
    let guildDeleteEvent = GuildDeleteEvent(shard: shard, guild: g, name: $EventType.evtGuildDelete)

    # Remove guild from cache
    var removedGuild: Guild
    discard shard.client.cache.guilds.pop(g.id, removedGuild)

    dispatchEvent(guildDeleteEvent)

proc guildBanAddEvent(shard: Shard, json: JsonNode) =
    let g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let user = newUser(json["user"])

    let guildBanAddEvent = GuildBanAddEvent(shard: shard, guild: g, bannedUser: user, name: $EventType.evtGuildBanAdd)
    dispatchEvent(guildBanAddEvent)

proc guildBanRemoveEvent(shard: Shard, json: JsonNode) =
    let g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let user = newUser(json["user"])

    let guildBanRemoveEvent = GuildBanRemoveEvent(shard: shard, guild: g, unbannedUser: user, name: $EventType.evtGuildBanRemove)
    dispatchEvent(guildBanRemoveEvent)

proc guildEmojisUpdateEvent(shard: Shard, json: JsonNode) =
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    # Empty g.emojis and fill it with the newly updated emojis
    g.emojis = @[]
    for emoji in json["emojis"]:
        g.emojis.add(newEmoji(emoji, g.id))

    let guildEmojisUpdateEvent = GuildEmojisUpdateEvent(shard: shard, guild: g, emojis: g.emojis, name: $EventType.evtGuildEmojisUpdate)
    dispatchEvent(guildEmojisUpdateEvent)

    #[ var updatedEmojis: Table[snowflake, Emoji] = initTable[snowflake, Emoji]()
    for emoji in json["emojis"]:
        var currentEmoji: Emoji = newEmoji(emoji, g.id)
        updatedEmojis[currentEmoji.id] = currentEmoji

    for emoji in g.emojis:
        if updatedEmojis.hasKey(emoji.id):
            emoji = updatedEmojis[emoji.id] ]#
    
            #g.emojis.apply

proc guildIntegrationsUpdate(shard: Shard, json: JsonNode) =
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    let guildIntegrationsUpdateEvent = GuildIntegrationsUpdateEvent(shard: shard, guild: g, name: $EventType.evtGuildIntegrationsUpdate)
    dispatchEvent(guildIntegrationsUpdateEvent)

proc guildMemberAdd(shard: Shard, json: JsonNode) =
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    var newMember = newGuildMember(json, g.id)

    let guildMemberAddEvent = GuildMemberAddEvent(shard: shard, guild: g, member: newMember, name: $EventType.evtGuildMemberAdd)
    dispatchEvent(guildMemberAddEvent)

proc guildMemberRemove(shard: Shard, json: JsonNode) =
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    var removedUser = newUser(json["user"])

    let guildMemberRemoveEvent = GuildMemberRemoveEvent(shard: shard, guild: g, user: removedUser, name: $EventType.evtGuildMemberRemove)
    dispatchEvent(guildMemberRemoveEvent)

proc guildMemberUpdate(shard: Shard, json: JsonNode) =
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    var updatedMember = g.getGuildMember(getIDFromJson(json["user"]["id"].getStr()))
    updatedMember.user = newUser(json["user"])

    updatedMember.roles = @[]
    for roleID in json["roles"]:
        updatedMember.roles.add(getIDFromJson(roleID.getStr()))

    if json.contains("nick"):
        updatedMember.nick = json["nick"].getStr()

    if json.contains("premium_since"):
        updatedMember.premiumSince = json["premium_since"].getStr()

    let guildMemberUpdateEvent = GuildMemberUpdateEvent(shard: shard, guild: g, member: updatedMember, name: $EventType.evtGuildMemberUpdate)
    dispatchEvent(guildMemberUpdateEvent)

proc guildMembersChunk(shard: Shard, json: JsonNode) =
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    var event = GuildMembersChunkEvent(shard: shard, guild: g, name: $EventType.evtGuildMembersChunk)

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
    
proc guildRoleCreate(shard: Shard, json: JsonNode) =
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let role = newRole(json["role"], g.id)

    g.roles.add(role)

    var event = GuildRoleUpdateEvent(shard: shard, guild: g, role: role, name: $EventType.evtGuildRoleUpdate)
    dispatchEvent(event)

proc guildRoleUpdate(shard: Shard, json: JsonNode) =
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let role = newRole(json["role"], g.id)

    var index = -1
    for i, r in g.roles:
        if r.id == role.id:
            index = i

    g.roles[index] = role

    var event = GuildRoleUpdateEvent(shard: shard, guild: g, role: role, name: $EventType.evtGuildRoleUpdate)
    dispatchEvent(event)

proc guildRoleDelete(shard: Shard, json: JsonNode) =
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    let roleID = getIDFromJson(json["role_id"].getStr())

    var role: Role
    var index = -1
    for i, r in g.roles:
        if r.id == roleID:
            index = i
            role = r

    if index != -1:
        g.roles.delete(index)

    var event = GuildRoleDeleteEvent(shard: shard, guild: g, role: role, name: $EventType.evtGuildRoleDelete)
    dispatchEvent(event)

proc inviteCreate(shard: Shard, json: JsonNode) =
    var invite = newInvite(json)

    invite.channel = shard.client.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))

    if (json.contains("guild_id")):
        invite.guildID =getIDFromJson(json["guild_id"].getStr())

    var event = InviteCreateEvent(shard: shard, invite: invite, name: $EventType.evtInviteCreate)
    dispatchEvent(event)

proc inviteDelete(shard: Shard, json: JsonNode) =
    var event = InviteDeleteEvent(shard: shard, name: $EventType.evtInviteDelete)

    event.channel = shard.client.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))
    event.code = json["code"].getStr()

    if (json.contains("guild_id")):
        event.guild = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    dispatchEvent(event)

proc messageCreateEvent(shard: Shard, json: JsonNode) =
    let msg = newMessage(json)

    shard.client.cache.messages[msg.id] = msg

    let messageCreateEvnt = MessageCreateEvent(shard: shard, message: msg, name: $EventType.evtMessageCreate)
    dispatchEvent(messageCreateEvnt)

proc messageUpdateEvent(shard: Shard, json: JsonNode) =
    let msg = newMessage(json)

    shard.client.cache.messages[msg.id] = msg

    let event = MessageCreateEvent(shard: shard, message: msg, name: $EventType.evtMessageUpdate)
    dispatchEvent(event)

proc messageDeleteEvent(shard: Shard, json: JsonNode) =
    let msgID = getIDFromJson(json["id"].getStr())

    var msg: Message
    if shard.client.cache.messages.hasKey(msgID):
        discard shard.client.cache.messages.pop(msgID, msg)
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    let event = MessageDeleteEvent(shard: shard, message: msg, name: $EventType.evtMessageDelete)
    dispatchEvent(event)

proc messageDeleteBulkEvent(shard: Shard, json: JsonNode) =
    var event = MessageDeleteBulkEvent(shard: shard, name: $EventType.evtMessageDeleteBulk)

    event.channel = shard.client.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))
    if (json.contains("guild_id")):
        event.guild = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))

    for msgIDJson in json["ids"]:
        let msgID = getIDFromJson(msgIDJson.getStr())

        var msg: Message
        if shard.client.cache.messages.hasKey(msgID):
            discard shard.client.cache.messages.pop(msgID, msg)
        else:
            let channelID = getIDFromJson(json["channel_id"].getStr())
            msg = Message(id: msgID, channelID: channelID)

            event.channel = shard.client.cache.getChannel(msg.channelID)
            if (json.contains("guild_id")):
                msg.guildID = getIDFromJson(json["guild_id"].getStr())
        
        event.messages.add(msg)

    dispatchEvent(event)

proc messageReactionAdd(shard: Shard, json: JsonNode) =
    var event = MessageReactionAddEvent(shard: shard, name: $EventType.evtMessageReactionAdd)

    let msgID = getIDFromJson(json["message_id"].getStr())
    var msg: Message
    if shard.client.cache.messages.hasKey(msgID):
        msg = shard.client.cache.messages[msgID]
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    event.user = shard.client.cache.getUser(getIDFromJson(json["user_id"].getStr()))

    if (json.contains("member")):
        event.member = newGuildMember(json["member"], msg.guildID)

    event.emoji = newEmoji(json["emoji"], msg.guildID)

    dispatchEvent(event)

proc messageReactionRemove(shard: Shard, json: JsonNode) =
    var event = MessageReactionRemoveEvent(shard: shard, name: $EventType.evtMessageReactionRemove)

    let msgID = getIDFromJson(json["message_id"].getStr())
    var msg: Message
    if shard.client.cache.messages.hasKey(msgID):
        msg = shard.client.cache.messages[msgID]
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    event.user = shard.client.cache.getUser(getIDFromJson(json["user_id"].getStr()))

    event.emoji = newEmoji(json["emoji"], msg.guildID)

    dispatchEvent(event)

proc messageReactionRemoveAll(shard: Shard, json: JsonNode) =
    var event = MessageReactionRemoveAllEvent(shard: shard, name: $EventType.evtMessageReactionRemoveAll)

    let msgID = getIDFromJson(json["message_id"].getStr())
    var msg: Message
    if shard.client.cache.messages.hasKey(msgID):
        msg = shard.client.cache.messages[msgID]
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    dispatchEvent(event)

proc messageReactionRemoveEmoji(shard: Shard, json: JsonNode) =
    var event = MessageReactionRemoveEmojiEvent(shard: shard, name: $EventType.evtMessageReactionRemoveEmoji)

    let msgID = getIDFromJson(json["message_id"].getStr())
    var msg: Message
    if shard.client.cache.messages.hasKey(msgID):
        msg = shard.client.cache.messages[msgID]
    else:
        msg = Message(id: msgID)

    msg.channelID = getIDFromJson(json["channel_id"].getStr())
    if (json.contains("guild_id")):
        msg.guildID = getIDFromJson(json["guild_id"].getStr())

    event.emoji = newEmoji(json["emoji"], msg.guildID)

    dispatchEvent(event)

proc presenceUpdate(shard: Shard, json: JsonNode) =
    # This proc doesn't actually dispatch any events,
    # it just updates member.presence
    var g = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
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

proc typingStart(shard: Shard, json: JsonNode) =
    var event = TypingStartEvent(shard: shard, name: $EventType.evtTypingStart)

    event.channel = shard.client.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))

    if (json.contains("guild_id")):
        event.channel.guildID = getIDFromJson(json["guild_id"].getStr())

    event.user = shard.client.cache.getUser(getIDFromJson(json["user_id"].getStr()))

    if (json.contains("member")):
        event.member = newGuildMember(json["member"], event.channel.guildID)

    dispatchEvent(event)

proc userUpdate(shard: Shard, json: JsonNode) =
    var event = UserUpdateEvent(shard: shard, name: $EventType.evtUserUpdate)

    event.user = newUser(json)

    dispatchEvent(event)

proc voiceStateUpdate(shard: Shard, json: JsonNode) =
    var event = VoiceStateUpdateEvent(shard: shard, name: $EventType.evtVoiceStateUpdate)

    dispatchEvent(event)

proc voiceServerUpdate(shard: Shard, json: JsonNode) =
    var event = VoiceServerUpdateEvent(shard: shard, name: $EventType.evtVoiceServerUpdate)

    event.token = json["token"].getStr()
    event.guild = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    event.endpoint = json["endpoint"].getStr()

    dispatchEvent(event)

proc webhooksUpdate(shard: Shard, json: JsonNode) =
    var event = WebhooksUpdateEvent(shard: shard, name: $EventType.evtWebhooksUpdate)

    event.guild = shard.client.cache.getGuild(getIDFromJson(json["guild_id"].getStr()))
    event.channel = shard.client.cache.getChannel(getIDFromJson(json["channel_id"].getStr()))

    dispatchEvent(event)

let internalEventTable: Table[string, proc(shard: Shard, json: JsonNode) {.nimcall.}] = {
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

proc handleDiscordEvent*(shard: Shard, json: JsonNode, eventName: string) {.async.} =
    ## Handles, and dispatches, a gateway event. Only used internally.
    if (internalEventTable.hasKey(eventName)):
        let eventProc: proc(shard: Shard, json: JsonNode) = internalEventTable[eventName]
        eventProc(shard, json)
    else:
        echo "Failed to find event: ", eventName
        
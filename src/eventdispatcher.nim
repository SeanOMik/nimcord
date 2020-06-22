import eventhandler, json, tables, message, emoji, user, member, role
import guild, channel, nimcordutils, httpClient, strformat, cache
import sequtils, asyncdispatch, clientobjects, discordobject

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
    discordClient.cache.channels.add(chnl.id, chnl)

    dispatchEvent(channelCreateEvent)

proc channelUpdateEvent(discordClient: DiscordClient, json: JsonNode) = 
    let chnl = newChannel(json)
    let channelUpdateEvent = ChannelUpdateEvent(client: discordClient, channel: chnl, name: $EventType.evtChannelUpdate)

    if (discordClient.cache.channels.hasKey(chnl.id)):
        discordClient.cache.channels[chnl.id] = chnl
    else:
        discordClient.cache.channels.add(chnl.id, chnl)

    dispatchEvent(channelUpdateEvent)


proc channelDeleteEvent(discordClient: DiscordClient, json: JsonNode) = 
    let chnl = newChannel(json)
    let channelDeleteEvent = ChannelDeleteEvent(client: discordClient, channel: chnl, name: $EventType.evtChannelDelete)

    var removedChnl: Channel
    discard discordClient.cache.channels.pop(chnl.id, removedChnl)

    dispatchEvent(channelDeleteEvent)

proc messageCreateEvent(discordClient: DiscordClient, json: JsonNode) =
    let msg = newMessage(json)

    discordClient.cache.messages.add(msg.id, msg)

    let messageCreateEvnt = MessageCreateEvent(client: discordClient, message: msg, name: $EventType.evtMessageCreate)
    dispatchEvent(messageCreateEvnt)

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
    discordClient.cache.guilds.add(g.id, g)
    for channel in g.channels:
        discordClient.cache.channels.add(channel.id, channel)
    for member in g.members:
        discordClient.cache.members.add(member.id, member)

    dispatchEvent(guildCreateEvnt)

let internalEventTable: Table[string, proc(discordClient: DiscordClient, json: JsonNode) {.nimcall.}] = {
        "READY": readyEvent,
        "MESSAGE_CREATE": messageCreateEvent,
        "GUILD_CREATE": guildCreateEvent,
        "CHANNEL_CREATE": channelCreateEvent,
        "CHANNEL_UPDATE": channelUpdateEvent,
        "CHANNEL_DELETE": channelDeleteEvent
    }.toTable

proc handleDiscordEvent*(discordClient: DiscordClient, json: JsonNode, eventName: string) {.async.} =
    ## Handles, and dispatches, a gateway event. Only used internally.
    if (internalEventTable.hasKey(eventName)):
        let eventProc: proc(discordClient: DiscordClient, json: JsonNode) = internalEventTable[eventName]
        eventProc(discordClient, json)
    else:
        echo "Failed to find event: ", eventName
        
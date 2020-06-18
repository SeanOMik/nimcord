import eventhandler, json, tables, message, user, nimcordutils, httpClient, strformat, cache, guild, sequtils, asyncdispatch, clientobjects

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
    var json = handleResponse(client.request(endpoint("/users/@me"), HttpGet, ""), 0, RateLimitBucketType.global)

    let clientUser: User = newUser(json)
    readyEvent.clientUser = clientUser
    
    dispatchEvent(readyEvent)

proc messageCreateEvent(discordClient: DiscordClient, json: JsonNode) =
    let msg = newMessage(json)
    let messageCreateEvnt = MessageCreateEvent(client: discordClient, message: msg, name: $EventType.evtMessageCreate)
    dispatchEvent(messageCreateEvnt)

proc guildCreateEvent(discordClient: DiscordClient, json: JsonNode) =
    let g = newGuild(json)
    let guildCreateEvnt = GuildCreateEvent(client: discordClient, guild: g, name: $EventType.evtGuildCreate)

    discordClient.cache.guilds.insert(g)
    discordClient.cache.channels = concat(discordClient.cache.channels, g.channels)
    discordClient.cache.members = concat(discordClient.cache.members, g.members)
    dispatchEvent(guildCreateEvnt)

let internalEventTable: Table[string, proc(discordClient: DiscordClient, json: JsonNode) {.nimcall.}] = {
        "READY": readyEvent,
        "MESSAGE_CREATE": messageCreateEvent,
        "GUILD_CREATE": guildCreateEvent
    }.toTable

proc handleDiscordEvent*(discordClient: DiscordClient, json: JsonNode, eventName: string) {.async.} =
    if (internalEventTable.hasKey(eventName)):
        let eventProc: proc(discordClient: DiscordClient, json: JsonNode) = internalEventTable[eventName]
        eventProc(discordClient, json)
    else:
        echo "Failed to find event: ", eventName
        
import websocket, asyncdispatch, json, httpClient, eventdispatcher, strformat
import eventhandler, streams, nimcordutils, discordobject, user, cache, clientobjects
import strutils, channel, options, message, emoji, guild, embed, os, presence

type
    DiscordOpCode = enum
        opDispatch = 0,
        opHeartbeat = 1,
        opIdentify = 2,
        opPresenceUpdate = 3,
        opVoiceStateUpdate = 4,
        opResume = 6,
        opReconnect = 7,
        opRequestGuildMembers = 8,
        opInvalidSession = 9,
        opHello = 10,
        opHeartbeatAck = 11

proc sendGatewayRequest*(client: DiscordClient, request: JsonNode, msg: string = "") {.async.} =
    ## Send a gateway request.
    ## Don't use this unless you know what you're doing!
    if (msg.len == 0):
        echo "Sending gateway payload: ", request
    else:
        echo msg

    await client.ws.sendText($request)

proc handleHeartbeat(client: DiscordClient) {.async.} =
    while true:
        var heartbeatPayload: JsonNode
        if (client.lastSequence == 0):
            heartbeatPayload = %* { "d": nil, "op": ord(DiscordOpCode.opHeartbeat) }
        else:
            heartbeatPayload = %* { "d": client.lastSequence, "op": ord(DiscordOpCode.opHeartbeat) }

        await client.sendGatewayRequest(heartbeatPayload, fmt("Sending heartbeat payload: {$heartbeatPayload}"))
        client.heartbeatAcked = true

        echo "Waiting ", client.heartbeatInterval, " ms until next heartbeat..."
        await sleepAsync(client.heartbeatInterval)

proc getIdentifyPacket(client: DiscordClient): JsonNode =
    return %* { "op": ord(DiscordOpCode.opIdentify), "d": { "token": client.token, "properties": { "$os": system.hostOS, "$browser": "NimCord", "$device": "NimCord" } } }

proc startConnection*(client: DiscordClient) {.async.}

proc closeConnection*(client: DiscordClient, code: int = 1000) {.async.} =
    echo "Disconnecting with code: ", code
    await client.ws.close(code)

proc reconnectClient(client: DiscordClient) {.async.} =
    echo "Reconnecting..."
    client.reconnecting = true
    await client.ws.close(1000)

    client.ws = await newAsyncWebsocketClient(client.endpoint[6..client.endpoint.high], Port 443,
            path = "/v=6&encoding=json", true)

    client.reconnecting = false
    client.heartbeatAcked = true
    #waitFor client.startConnection()

# Handle discord disconnect. If it detects that we can reconnect, it will.
proc handleDiscordDisconnect(client: DiscordClient, error: string) {.async.} =
    let disconnectData = extractCloseData(error)

    echo "Discord gateway disconnected! Error code: ", disconnectData.code, ", msg: ", disconnectData.reason

    client.heartbeatAcked = false
    
    # Get the disconnect code
    let c = disconnectData.code

    # 4003, 4004, 4005, 4007, 4010, 4011, 4012, 4013 are not reconnectable.
    if ( (c >= 4003 and c <= 4005) or c == 4007 or (c >= 4010 and c <= 4013) ):
        echo "The Discord gateway sent a disconnect code that we cannot reconnect to."
    else:
        if (not client.reconnecting):
            waitFor client.reconnectClient()
        else:
            echo "Gateway is cannot reconnect due to already reconnecting..."
            

#TODO: Reconnecting may be done, just needs testing.
proc handleWebsocketPacket(client: DiscordClient) {.async.} = 
    while true:
        var packet: tuple[opcode: Opcode, data: string]

        packet = await client.ws.readData();
        echo "Received gateway payload: ", packet.data

        if packet.opcode == Opcode.Close:
            await client.handleDiscordDisconnect(packet.data)

        var json: JsonNode

        # If we fail to parse the json just stop this loop
        try:
            json = parseJson(packet.data);
        except:
            echo "Failed to parse websocket payload: ", packet.data
            continue

        if (json.contains("s")):
            client.lastSequence = json["s"].getInt()

        case json["op"].getInt()
            of ord(DiscordOpCode.opHello):
                if client.reconnecting:
                    echo "Reconnected!"
                    client.reconnecting = false

                    let resume = %* {
                        "op": ord(opResume),
                        "d": {
                            "token": client.token,
                            "session_id": client.sessionID,
                            "seq": client.lastSequence
                        }
                    }

                    await client.sendGatewayRequest(resume)
                else:
                    client.heartbeatInterval = json["d"]["heartbeat_interval"].getInt()
                    await client.sendGatewayRequest(client.getIdentifyPacket())

                    asyncCheck client.handleHeartbeat()
                    client.heartbeatAcked = true
            of ord(DiscordOpCode.opHeartbeatAck):
                client.heartbeatAcked = true
            of ord(DiscordOpCode.opDispatch):
                asyncCheck handleDiscordEvent(client, json["d"], json["t"].getStr())
            of ord(DiscordOpCode.opReconnect):
                asyncCheck client.reconnectClient()
            of ord(DiscordOpCode.opInvalidSession):
                # If the json field `d` is true then the session may be resumable.
                if json["d"].getBool():
                    let resume = %* {
                        "op": ord(opResume),
                        "session_id": client.sessionID,
                        "seq": client.lastSequence
                    }

                    await client.sendGatewayRequest(resume)
                else:
                    asyncCheck client.reconnectClient()
            else:
                discard

proc startConnection*(client: DiscordClient) {.async.} =
    ## Start a bot connection.
    ## 
    ## Examples:
    ## 
    ## .. code-block:: nim 
    ##   var tokenStream = newFileStream("token.txt", fmRead)
    ##   var tkn: string
    ##   if (not isNil(tokenStream)):
    ##      discard tokenStream.readLine(tkn)
    ##      echo "Read token from the file: ", tkn
    ## 
    ##   tokenStream.close()
    ## 
    ##   var bot = newDiscordClient(tkn)
    echo "Connecting..."

    let urlResult = sendRequest(endpoint("/gateway/bot"), HttpMethod.HttpGet, defaultHeaders())
    if (urlResult.contains("url")):
        let url = urlResult["url"].getStr()
        client.endpoint = url

        client.ws = await newAsyncWebsocketClient(url[6..url.high], Port 443,
            path = "/v=6&encoding=json", true)

        asyncCheck client.handleWebsocketPacket()
        # Now just wait. Dont poll for new events while we're reconnecting
        while true:
            if not client.reconnecting:
                poll()
    else:
        raise newException(IOError, "Failed to get gateway url, token may of been incorrect!")

proc updateClientPresence*(client: DiscordClient, presence: Presence) {.async.} =
    let jsonPayload = %* {
        "op": ord(opPresenceUpdate),
        "d": presence.presenceToJson()
    }

    await client.sendGatewayRequest(jsonPayload)

proc newDiscordClient(tkn: string): DiscordClient =
    ## Create a DiscordClient using a token.
    ## 
    ## Sets globalDiscordClient to the newly created client.
    globalToken = tkn

    var cac: Cache
    new(cac)

    result = DiscordClient(token: tkn, cache: cac, reconnecting: false)

var tokenStream = newFileStream("token.txt", fmRead)
var tkn: string
if (not isNil(tokenStream)):
    discard tokenStream.readLine(tkn)
    echo "Read token from the file: ", tkn

    tokenStream.close()

var bot = newDiscordClient(tkn)

registerEventListener(EventType.evtReady, proc(bEvt: BaseEvent) =
    let event = ReadyEvent(bEvt)

    echo "Ready! (v", 0, ".", 0, ".", 1, ")"
    echo "Logged in as: ", bot.clientUser.username, "#", bot.clientUser.discriminator
    echo "ID: ", bot.clientUser.id
    echo "--------------------"

    let presence = newPresence("with Nimcord", activityTypeGame, clientStatusIdle, false)
    asyncCheck event.client.updateClientPresence(presence)
)

registerEventListener(EventType.evtMessageCreate, proc(bEvt: BaseEvent) =
    let event = MessageCreateEvent(bEvt)

    if (event.message.content == "?ping"):
        var channel: Channel = event.message.getMessageChannel(event.client.cache)
        if (channel != nil):
            discard channel.sendMessage("PONG")
    elif (event.message.content.startsWith("?modifyChannelTopic")):
        let modifyTopic = event.message.content.substr(20)

        var channel: Channel = event.message.getMessageChannel(event.client.cache)
        if (channel != nil):
            discard channel.sendMessage("Modifing Channel!")
            discard channel.modifyChannel(ChannelFields(topic: some(modifyTopic)))
    elif (event.message.content.startsWith("?deleteChannel")):
        let channelID = getIDFromJson(event.message.content.substr(15))
        var channel: Channel = event.client.cache.getChannel(channelID)
        
        if (channel != nil):
            discard channel.sendMessage("Deleting Channel!")
            discard channel.deleteChannel()
            discard channel.sendMessage("Deleted Channel!")
    elif (event.message.content.startsWith("?getMessages")):
        var channel: Channel = event.message.getMessageChannel(event.client.cache)
        if (channel != nil):
            discard channel.getMessages(MessagesGetRequest(limit: some(15), before: some(event.message.id)))
    elif (event.message.content.startsWith("?bulkDeleteMessages")):
        var channel: Channel = event.message.getMessageChannel(event.client.cache)
        if (channel != nil):
            var amount: int = 25
            if (event.message.content.len > 19):
                amount = parseIntEasy(event.message.content.substr(20))
            let messages = channel.getMessages(MessagesGetRequest(limit: some(amount), before: some(event.message.id)))
            discard channel.bulkDeleteMessages(messages)
    elif (event.message.content.startsWith("?reactToMessage")):
        var channel: Channel = event.message.getMessageChannel(event.client.cache)
        if (channel != nil):
            let emojis = @[newEmoji("⏮️"), newEmoji("⬅️"), newEmoji("⏹️"), newEmoji("➡️"), newEmoji("⏭️")]
            for emoji in emojis:
                discard event.message.addReaction(emoji)
    elif (event.message.content.startsWith("?testEmbed")):
        var channel: Channel = event.message.getMessageChannel(event.client.cache)
        if (channel != nil):
            var embed = Embed()
            embed.setTitle("This embed is being sent from Nimcord!")
            embed.setDescription("Nimcord was developed in about a week of actual work so there will likely be issues.")
            embed.addField("Title", "value")
            embed.addField("Inline-0", "This is an inline field 0", true)
            embed.addField("Inline-1", "This is an inline field 1", true)
            embed.setColor(0xffb900)
            discard channel.sendMessage("", false, embed)
    elif (event.message.content.startsWith("?sendFile")):
        var channel: Channel = event.message.getMessageChannel(event.client.cache)
        if (channel != nil):
            let filePath = event.message.content.substr(10)

            let splitFile = splitFile(filePath)
            let fileName = splitFile.name & splitFile.ext

            let file = DiscordFile(filePath: filePath, fileName: fileName)
            discard channel.sendMessage("", false, nil, @[file])
    elif (event.message.content.startsWith("?sendImage")):
        var channel: Channel = event.message.getMessageChannel(event.client.cache)
        if (channel != nil):
            let filePath = event.message.content.substr(11)

            let splitFile = splitFile(filePath)
            let fileName = splitFile.name & splitFile.ext

            let file = DiscordFile(filePath: filePath, fileName: fileName)

            var embed = Embed()
            embed.setTitle("Image attachment test.")
            embed.setImage("attachment://" & fileName)
            discard channel.sendMessage("", false, embed, @[file])
    elif (event.message.content.startsWith("?reconnect")):
        var channel: Channel = event.message.getMessageChannel(event.client.cache)
        if (channel != nil):
            discard channel.sendMessage("Reconnecting...")
            #asyncCheck event.client.reconnectClient()
            asyncCheck event.client.ws.sendText("aaaa")
)

waitFor bot.startConnection()
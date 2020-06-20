import websocket, asyncdispatch, json, httpClient, eventdispatcher, strformat
import eventhandler, streams, nimcordutils, discordobject, user, cache, clientobjects
import strutils, channel, options, message, emoji, guild, embed, os

const 
    nimcordMajor = 0
    nimcordMinor = 0
    nimcordMicro = 0

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

    discard client.ws.sendText($request)

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

proc handleWebsocketPacket(client: DiscordClient) {.async.} = 
    while true:
        var packet: tuple[opcode: Opcode, data: string]

        packet = await client.ws.readData();
        echo "Received gateway payload: ", packet.data

        var json: JsonNode = parseJson(packet.data);

        if (json.contains("s")):
            client.lastSequence = json["s"].getInt()

        case json["op"].getInt()
            of ord(DiscordOpCode.opHello):
                client.heartbeatInterval = json["d"]["heartbeat_interval"].getInt()
                discard client.sendGatewayRequest(client.getIdentifyPacket())

                asyncCheck client.handleHeartbeat()
                client.heartbeatAcked = true
            of ord(DiscordOpCode.opHeartbeatAck):
                client.heartbeatAcked = true
            of ord(DiscordOpCode.opDispatch):
                asyncCheck(handleDiscordEvent(client, json["d"], json["t"].getStr()))
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
    let urlResult = sendRequest(endpoint("/gateway/bot"), HttpMethod.HttpGet, defaultHeaders())
    if (urlResult.contains("url")):
        let url = urlResult["url"].getStr()

        client.ws = await newAsyncWebsocketClient(url[6..url.high], Port 443,
            path = "/v=6&encoding=json", true)
        echo "Connected!"

        asyncCheck client.handleWebsocketPacket()
        runForever()
    else:
        raise newException(IOError, "Failed to get gateway url, token may of been incorrect!")

proc newDiscordClient(tkn: string): DiscordClient =
    ## Create a DiscordClient using a token.
    ## 
    ## Sets globalDiscordClient to the newly created client.
    globalToken = tkn

    var cac: Cache
    new(cac)

    result = DiscordClient(token: tkn, cache: cac)
    globalDiscordClient = result

var tokenStream = newFileStream("token.txt", fmRead)
var tkn: string
if (not isNil(tokenStream)):
    discard tokenStream.readLine(tkn)
    echo "Read token from the file: ", tkn

    tokenStream.close()

var bot = newDiscordClient(tkn)

registerEventListener(EventType.evtReady, proc(bEvt: BaseEvent) =
    let event = ReadyEvent(bEvt)
    bot.clientUser = event.clientUser

    echo "Ready! (v", nimcordMajor, ".", nimcordMinor, ".", nimcordMicro, ")"
    echo "Logged in as: ", bot.clientUser.username, "#", bot.clientUser.discriminator
    echo "ID: ", bot.clientUser.id
    echo "--------------------"
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
)

waitFor bot.startConnection()
import websocket, asyncnet, asyncdispatch, json, httpClient, eventdispatcher, strformat
import eventhandler, streams, nimcordutils, discordobject, user, cache, clientobjects
import strutils, channel, options

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

proc defaultHeaders*(client: DiscordClient, added: HttpHeaders = newHttpHeaders()): HttpHeaders = 
    added.add("Authorization", fmt("Bot {client.token}"))
    added.add("User-Agent", "NimCord (https://github.com/SeanOMik/nimcord, v0.0.0)")
    added.add("X-RateLimit-Precision", "millisecond")
    return added;

proc sendGatewayRequest*(client: DiscordClient, request: JsonNode, msg: string = "") {.async.} =
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
                discard handleDiscordEvent(client, json["d"], json["t"].getStr())
            else:
                discard

proc startConnection*(client: DiscordClient) {.async.} =
    let urlResult = sendRequest(endpoint("/gateway/bot"), HttpMethod.HttpGet, client.defaultHeaders())
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
    globalToken = tkn

    var cac: Cache
    new(cac)

    result = DiscordClient(token: tkn, cache: cac)

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
            discard channel.modifyChannel(ChannelModify(topic: some(modifyTopic)))
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
        else:
            echo "Failed to get channel!"
)

waitFor bot.startConnection()
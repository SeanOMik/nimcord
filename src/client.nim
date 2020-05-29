import websocket, asyncnet, asyncdispatch, json, httpClient, strformat

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



    DiscordClient* = ref object ## Discord Client
        token*: string
        #user*: User
        #cache: Cache
        ws: AsyncWebSocket
        httpClient: AsyncHttpClient
        heartbeatInterval: int
        heartbeatAcked: bool
        lastSequence: int

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
            else:
                discard
            
proc endpoint*(url: string): string =
    return fmt("https://discord.com/api/v6{url}")

proc startConnection*(client: DiscordClient) {.async.} =
    client.httpClient = newAsyncHttpClient()
    client.httpClient.headers = newHttpHeaders({"Authorization": fmt("Bot {client.token}")})

    let urlResult = parseJson(await client.httpClient.getContent(endpoint("/gateway/bot")))
    echo "Got result: ", $urlResult

    if (urlResult.contains("url")):
        let url = urlResult["url"].getStr()

        client.ws = await newAsyncWebsocketClient(url[6..url.high], Port 443 ,
            path = "/v=6&encoding=json", true)
        echo "Connected!"

        asyncCheck client.handleWebsocketPacket()
        runForever()
    else:
        var e: ref IOError
        new(e)
        e.msg = "Failed to get gateway url, token may of been incorrect!"
        raise e

var bot = DiscordClient(token: 
    "NjQ4NjcwNDA4NDg4MjU1NTAw.XtCGDw.ZNaRT6kNIMyO1wlcZbbaUGSsm7g")
waitFor bot.startConnection()
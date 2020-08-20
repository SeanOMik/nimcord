import websocket, asyncdispatch, json, httpClient, eventdispatcher, strformat
import nimcordutils, cache, clientobjects
import strutils, options, presence

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

# Forward declarations
proc closeConnection*(shard: Shard, code: int = 1000) {.async.}
proc getIdentifyPacket(shard: Shard): JsonNode
proc handleGatewayDisconnect(shard: Shard, error: string) {.async.}
proc handleHeartbeat(shard: Shard) {.async.}
proc handleWebsocketPacket(shard: Shard) {.async.} 
proc newDiscordClient*(tkn: string, commandPrefix: string): DiscordClient
proc newShard(shardID: int, client: DiscordClient): Shard
proc reconnectShard(shard: Shard) {.async.}
proc sendGatewayRequest*(shard: Shard, request: JsonNode, msg: string = "") {.async.}
proc startConnection*(client: DiscordClient, shardAmount: int = 1) {.async.}
proc updateClientPresence*(shard: Shard, presence: Presence) {.async.}

proc sendGatewayRequest*(shard: Shard, request: JsonNode, msg: string = "") {.async.} =
    ## Send a gateway request.
    ## Don't use this unless you know what you're doing!
    if msg.len == 0:
        echo "Sending gateway payload: ", request
    else:
        echo msg

    await shard.ws.sendText($request)

proc handleHeartbeat(shard: Shard) {.async.} =
    while true:
        var heartbeatPayload: JsonNode
        if shard.lastSequence == 0:
            heartbeatPayload = %* { "d": nil, "op": ord(DiscordOpCode.opHeartbeat) }
        else:
            heartbeatPayload = %* { "d": shard.lastSequence, "op": ord(DiscordOpCode.opHeartbeat) }

        await shard.sendGatewayRequest(heartbeatPayload, fmt("Sending heartbeat payload: {$heartbeatPayload}"))
        shard.heartbeatAcked = true

        echo "Waiting ", shard.heartbeatInterval, " ms until next heartbeat..."
        await sleepAsync(shard.heartbeatInterval)

proc getIdentifyPacket(shard: Shard): JsonNode =
    result = %* {
        "op": ord(DiscordOpCode.opIdentify),
        "d": {
            "token": shard.client.token,
                "properties": {
                "$os": system.hostOS,
                "$browser": "NimCord",
                "$device": "NimCord"
            }
        }
    }

    if shard.client.shardCount != -1:
        result.add("shard", %*[shard.id, shard.client.shardCount])

proc closeConnection*(shard: Shard, code: int = 1000) {.async.} =
    echo "Disconnecting with code: ", code
    await shard.ws.close(code)

proc reconnectShard(shard: Shard) {.async.} =
    echo "Reconnecting..."
    shard.reconnecting = true
    await shard.ws.close(1000)

    shard.ws = await newAsyncWebsocketClient(shard.client.endpoint[6..shard.client.endpoint.high], Port 443,
            path = "/v=6&encoding=json", true)

    shard.reconnecting = false
    shard.heartbeatAcked = true
    # waitFor client.startConnection()

# Handle discord disconnect. If it detects that we can reconnect, it will.
proc handleGatewayDisconnect(shard: Shard, error: string) {.async.} =
    let disconnectData = extractCloseData(error)

    echo "Discord gateway disconnected! Error code: ", disconnectData.code, ", msg: ", disconnectData.reason

    shard.heartbeatAcked = false
    
    # Get the disconnect code
    let c = disconnectData.code

    # 4003, 4004, 4005, 4007, 4010, 4011, 4012, 4013 are not reconnectable.
    if  (c >= 4003 and c <= 4005) or c == 4007 or (c >= 4010 and c <= 4013):
        echo "The Discord gateway sent a disconnect code that we cannot reconnect to."
    else:
        if not shard.reconnecting:
            waitFor shard.reconnectShard()
        else:
            echo "Gateway is cannot reconnect due to already reconnecting..."
            
#TODO: Reconnecting may be done, just needs testing.
proc handleWebsocketPacket(shard: Shard) {.async.} = 
    while true:
        var packet: tuple[opcode: Opcode, data: string]

        packet = await shard.ws.readData()
        echo "[SHARD ", $shard.id, "] Received gateway payload: ", packet.data

        if packet.opcode == Opcode.Close:
            await shard.handleGatewayDisconnect(packet.data)

        var json: JsonNode

        # If we fail to parse the json just stop this loop
        try:
            json = parseJson(packet.data)
        except:
            echo "Failed to parse websocket payload: ", packet.data
            continue

        if json.contains("s"):
            shard.lastSequence = json["s"].getInt()

        case json["op"].getInt()
            of ord(DiscordOpCode.opHello):
                if shard.reconnecting:
                    echo "Reconnected!"
                    shard.reconnecting = false

                    let resume = %* {
                        "op": ord(opResume),
                        "d": {
                            "token": shard.client.token,
                            "session_id": shard.sessionID,
                            "seq": shard.lastSequence
                        }
                    }

                    await shard.sendGatewayRequest(resume)
                else:
                    shard.heartbeatInterval = json["d"]["heartbeat_interval"].getInt()
                    await shard.sendGatewayRequest(shard.getIdentifyPacket())

                    asyncCheck shard.handleHeartbeat()
                    shard.heartbeatAcked = true
            of ord(DiscordOpCode.opHeartbeatAck):
                shard.heartbeatAcked = true
            of ord(DiscordOpCode.opDispatch):
                asyncCheck handleDiscordEvent(shard, json["d"], json["t"].getStr())
            of ord(DiscordOpCode.opReconnect):
                asyncCheck shard.reconnectShard()
            of ord(DiscordOpCode.opInvalidSession):
                # If the json field `d` is true then the session may be resumable.
                if json["d"].getBool():
                    let resume = %* {
                        "op": ord(opResume),
                        "session_id": shard.sessionID,
                        "seq": shard.lastSequence
                    }

                    await shard.sendGatewayRequest(resume)
                else:
                    asyncCheck shard.reconnectShard()
            else:
                discard

proc newShard(shardID: int, client: DiscordClient): Shard =
    return Shard(id: shardID, client: client)

proc startConnection*(client: DiscordClient, shardAmount: int = 1) {.async.} =
    ## Start a bot connection.
    ## 
    ## Examples:
    ## 
    ## .. code-block:: nim 
    ##   var tokenStream = newFileStream("token.txt", fmRead)
    ##   var tkn: string
    ##   if not isNil(tokenStream):
    ##      discard tokenStream.readLine(tkn)
    ##      echo "Read token from the file: ", tkn
    ## 
    ##   tokenStream.close()
    ## 
    ##   var bot = newDiscordClient(tkn)
    echo "Connecting..."

    # let urlResult = sendRequest(endpoint("/gateway/bot"), HttpMethod.HttpGet, defaultHeaders())
    let urlResult = sendRequest(endpoint("/gateway"), HttpMethod.HttpGet, defaultHeaders())
    if urlResult.contains("url"):
        let url = urlResult["url"].getStr()
        client.endpoint = url

        var shardCount = shardAmount
        if urlResult.hasKey("shards") and shardCount < urlResult["shards"].getInt():
            shardCount = urlResult["shards"].getInt()
        client.shardCount = shardCount

        if shardCount > 1:
            for index in 0..shardCount - 2:
                var shard = newShard(index, client)
                client.shards.add(shard)

                shard.ws = await newAsyncWebsocketClient(url[6..url.high], Port 443,
                    path = "/v=6&encoding=json", true)

                asyncCheck shard.handleWebsocketPacket()

                # Theres a 5 second delay on identify payloads.
                await sleepAsync(5500)
                
        var shard = newShard(shardCount - 1, client)
        client.shards.add(shard)

        shard.ws = await newAsyncWebsocketClient(url[6..url.high], Port 443,
            path = "/v=6&encoding=json", true)

        asyncCheck shard.handleWebsocketPacket()

        # Now just wait. Dont poll while we're reconnecting
        while true:
            if not shard.reconnecting:
                poll()
    else:
        raise newException(IOError, "Failed to get gateway url, token may of been incorrect!")

proc updateClientPresence*(shard: Shard, presence: Presence) {.async.} =
    ## Start a bot's presence.
    ## 
    ## Examples:
    ## 
    ## .. code-block:: nim 
    ##   let presence = newPresence("with Nimcord", activityTypeGame, clientStatusIdle, false)
    ##   asyncCheck event.shard.updateClientPresence(presence) ## Will read "Playing with Nimcord"
    let jsonPayload = %* {
        "op": ord(opPresenceUpdate),
        "d": presence.presenceToJson()
    }

    await shard.sendGatewayRequest(jsonPayload)

# DiscordClient stored instances:
let clientInstances = newTable[uint8, DiscordClient]()
var nextInstanceId = 0

proc getClientInstance*(instanceID: uint8): DiscordClient =
    ## Get a client instance with instance id. Mainly used internally.
    return clientInstances[instanceID]

proc newDiscordClient*(tkn: string, commandPrefix: string): DiscordClient =
    ## Create a DiscordClient using a token.
    ## 
    ## Sets globalDiscordClient to the newly created client.
    globalToken = tkn

    var cac: Cache
    new(cac)

    result = DiscordClient(token: tkn, cache: cac, commandPrefix: commandPrefix, instanceID: nextInstanceId)
    clientInstances.add(nextInstanceId, result)
    nextInstanceId++
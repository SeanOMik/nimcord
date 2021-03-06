import ws, asyncdispatch, json, httpClient, eventdispatcher, strformat
import nimcordutils, cache, clientobjects, strutils, options, presence, log
import tables

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
proc newDiscordClient*(tkn: string, commandPrefix: string, log: Log = newLog(ord(LoggerFlags.loggerFlagWarnSeverity) or ord(LoggerFlags.loggerFlagInfoSeverity) or ord(LoggerFlags.loggerFlagErrorSeverity))): DiscordClient
proc newShard(shardID: int, client: DiscordClient): Shard
proc reconnectShard*(shard: Shard) {.async.}
proc sendGatewayRequest*(shard: Shard, request: JsonNode, msg: string = "") {.async.}
proc startConnection*(client: DiscordClient, shardAmount: int = 1) {.async.}
proc updateClientPresence*(shard: Shard, presence: Presence) {.async.}

proc sendGatewayRequest*(shard: Shard, request: JsonNode, msg: string = "") {.async.} =
    ## Send a gateway request.
    ## Don't use this unless you know what you're doing!
    if msg.len == 0:
        shard.client.log.debug("[SHARD " & $shard.id & "] Sending gateway payload: " & $request)
    else:
        shard.client.log.debug("[SHARD " & $shard.id & "] " & msg)

    await shard.ws.send($request)

proc handleHeartbeat(shard: Shard) {.async.} =
    while true:
        var heartbeatPayload: JsonNode
        if shard.lastSequence == 0:
            heartbeatPayload = %* { "d": nil, "op": ord(DiscordOpCode.opHeartbeat) }
        else:
            heartbeatPayload = %* { "d": shard.lastSequence, "op": ord(DiscordOpCode.opHeartbeat) }

        await shard.sendGatewayRequest(heartbeatPayload, fmt("Sending heartbeat payload: {$heartbeatPayload}"))
        shard.heartbeatAcked = true

        shard.client.log.debug("[SHARD " & $shard.id & "] Waiting " & $shard.heartbeatInterval & " ms until next heartbeat...")
        await sleepAsync(shard.heartbeatInterval)

        if (not shard.heartbeatAcked and not shard.reconnecting):
            shard.client.log.debug("[SHARD " & $shard.id & "] Heartbeat not acked! Reconnecting...")
            asyncCheck shard.reconnectShard()

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
    shard.client.log.warn("[SHARD " & $shard.id & "] Disconnecting with code: " & $code)
    shard.ws.close()

proc reconnectShard*(shard: Shard) {.async.} =
    shard.client.log.info("[SHARD " & $shard.id & "] Reconnecting...")
    shard.reconnecting = true

    #waitFor shard.ws.close(1000)
    
    try:
        shard.ws = waitFor newWebSocket(shard.client.endpoint & "/v=6&encoding=json")
        #shard.ws = waitFor newAsyncWebsocketClient(shard.client.endpoint[6..shard.client.endpoint.high], Port 443,
        #    path = "/v=6&encoding=json", true)
    except OSError:
        shard.client.log.error("[SHARD " & $shard.id & "] Failed to reconnect to websocket with OSError trying again!")
        asyncCheck shard.reconnectShard()
    except IOError:
        shard.client.log.error("[SHARD " & $shard.id & "] Failed to reconnect to websocket with IOError trying again!")
        asyncCheck shard.reconnectShard()

    shard.reconnecting = false
    shard.heartbeatAcked = true

# Handle discord disconnect. If it detects that we can reconnect, it will.
proc handleGatewayDisconnect(shard: Shard, error: string) {.async.} =
    shard.client.log.warn("[SHARD " & $shard.id & "] Discord gateway disconnected!")
    #[[let disconnectData = extractCloseData(error)

    shard.client.log.warn("[SHARD " & $shard.id & "] Discord gateway disconnected! Error code: " & $disconnectData.code & ", msg: " & disconnectData.reason)

    shard.heartbeatAcked = false
    
    # Get the disconnect code
    let c = disconnectData.code

    # 4003, 4004, 4005, 4007, 4010, 4011, 4012, 4013 are not reconnectable.
    if  (c >= 4003 and c <= 4005) or c == 4007 or (c >= 4010 and c <= 4013):
        shard.client.log.error("[SHARD " & $shard.id & "] The Discord gateway sent a disconnect code that we cannot reconnect to.")
    else:
        if not shard.reconnecting:
            shard.reconnectShard()
        else:
            shard.client.log.debug("[SHARD " & $shard.id & "] Gateway cannot reconnect due to already reconnecting...")]]#
            
#TODO: Reconnecting may be done, just needs testing.
proc handleWebsocketPacket(shard: Shard) {.async.} = 
    var hasStartedHeartbeatThread = false;
    while true:

        # Skip if the websocket isn't open
        if shard.ws.readyState == Open:
            var packet = await shard.ws.receiveStrPacket()
            shard.client.log.debug("[SHARD " & $shard.id & "] Received gateway payload: " & $packet)

            #if packet == Opcode.Close:
            #    await shard.handleGatewayDisconnect(packet)

            var json: JsonNode

            # If we fail to parse the json just stop this loop
            try:
                json = parseJson(packet)
            except:
                shard.client.log.error("[SHARD " & $shard.id & "] Failed to parse websocket payload: " & $packet)
                continue

            if json.contains("s"):
                shard.lastSequence = json["s"].getInt()

            case json["op"].getInt()
                of ord(DiscordOpCode.opHello):
                    if shard.reconnecting:
                        shard.client.log.info("[SHARD " & $shard.id & "] Reconnected!")
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

                        # Don't start a new heartbeat thread if one is already started
                        echo "About to start a heartbeat thread! shard.heartbeatAcked is ", shard.heartbeatAcked
                        if not hasStartedHeartbeatThread:
                            echo "Starting new heartbeat thread! shard.heartbeatAcked is ", shard.heartbeatAcked
                            asyncCheck shard.handleHeartbeat()
                            hasStartedHeartbeatThread = true
                        else:
                            echo "Not gonna start a new heartbeat thread since. shard.heartbeatAcked is ", shard.heartbeatAcked
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
    client.log.info("[CLIENT] Connecting...")

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

                shard.ws = await newWebSocket(shard.client.endpoint & "/v=6&encoding=json")

                asyncCheck shard.handleWebsocketPacket()

                # Theres a 5 second delay on identify payloads.
                await sleepAsync(5500)
                
        var shard = newShard(shardCount - 1, client)
        client.shards.add(shard)

        shard.ws = await newWebSocket(shard.client.endpoint & "/v=6&encoding=json")

        await shard.handleWebsocketPacket()

        # Just wait. Don't poll while we're reconnecting
        #[ while true:
            if not shard.reconnecting:
                try:
                    poll()
                except WebSocketError:
                    echo "WebSocketError" ]#
    else:
        raise newException(IOError, "Failed to get gateway url, token may of been incorrect!")

proc updateClientPresence*(shard: Shard, presence: Presence) {.async.} =
    let jsonPayload = %* {
        "op": ord(opPresenceUpdate),
        "d": presence.presenceToJson()
    }

    await shard.sendGatewayRequest(jsonPayload)

proc newDiscordClient*(tkn: string, commandPrefix: string, log: Log = newLog(ord(LoggerFlags.loggerFlagWarnSeverity) or ord(LoggerFlags.loggerFlagInfoSeverity) or ord(LoggerFlags.loggerFlagErrorSeverity))): DiscordClient =
    ## Create a DiscordClient using a token.
    ## 
    ## Sets globalToken to the newly created client's token.
    globalToken = tkn
    globalLog = log

    var cac: Cache
    new(cac)

    result = DiscordClient(token: tkn, cache: cac, commandPrefix: commandPrefix, log: log)
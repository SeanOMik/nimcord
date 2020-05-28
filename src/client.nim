import websocket, asyncnet, asyncdispatch, json, httpClient, strformat

type
    DiscordClient* = ref object ## Discord Client
        token*: string
        #user*: User
        #cache: Cache
        ws: AsyncWebSocket
        httpClient: AsyncHttpClient

#[ proc heartbeat() {.async.} =
    while true:
        await sleepAsync(35000)
        echo "heartbeat now" ]#

proc read(client: DiscordClient) {.async.} = 
    while true:
        var packet: tuple[opcode: Opcode, data: string]

        packet = await client.ws.readData();
        echo "(opcode: ", packet.opcode, ", data: ", packet.data, ")"

        var json: JsonNode = parseJson(packet.data);

        case json["op"].num
            of 10:
                echo "Received 'HELLO' from the gateway."
                # Start heartbeat here!
            else:
                discard
            
proc Endpoint(url: string): string =
    return fmt("https://discord.com/api/v6{url}")

proc startConnection(client: DiscordClient) {.async.} =
    client.httpClient = newAsyncHttpClient()
    client.httpClient.headers = newHttpHeaders({"Authorization": fmt("Bot {client.token}")})

    let result = parseJson(await client.httpClient.getContent(Endpoint("/gateway/bot")))
    echo "Got result: ", $result

    if (result.contains("url")):
        let url = result["url"].getStr()

        client.ws = await newAsyncWebsocketClient(url[6..url.high], Port 443 ,
            path = "/v=6&encoding=json", true)
        echo "Connected!"

        asyncCheck client.read()
        #asyncCheck heartbeat()
        runForever()
    else:
        var e: ref IOError
        new(e)
        e.msg = "Failed to get gateway url, token may of been incorrect!"
        raise e

var bot = DiscordClient(token: 
    "TOKEN")
waitFor bot.startConnection()
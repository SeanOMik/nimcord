import websocket, cache, user

type 
    DiscordClient* = ref object 
        ## Discord Client
        token*: string
        clientUser*: User
        cache*: Cache
        shards*: seq[Shard]
        shardCount*: int
        endpoint*: string
        commandPrefix*: string

    Shard* = ref object
        id*: int
        client*: DiscordClient
        ws*: AsyncWebSocket
        heartbeatInterval*: int
        heartbeatAcked*: bool
        lastSequence*: int
        reconnecting*: bool
        sessionID*: string
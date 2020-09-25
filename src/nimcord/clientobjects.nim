import ws, cache, user, log

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
        log*: Log

    Shard* = ref object
        id*: int
        client*: DiscordClient
        ws*: WebSocket
        heartbeatInterval*: int
        heartbeatAcked*: bool
        lastSequence*: int
        reconnecting*: bool
        sessionID*: string
        isHandlingHeartbeat*: bool
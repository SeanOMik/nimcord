import websocket, cache, user

type DiscordClient* = ref object ## Discord Client
        token*: string
        clientUser*: User
        cache*: Cache
        ws*: AsyncWebSocket
        heartbeatInterval*: int
        heartbeatAcked*: bool
        lastSequence*: int
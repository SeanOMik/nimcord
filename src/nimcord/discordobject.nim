type 
    Snowflake* = uint64
    DiscordObject* = object of RootObj
        id*: Snowflake

proc `==`*(obj1: DiscordObject, obj2: DiscordObject): bool =
    return obj1.id == obj2.id

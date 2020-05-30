type 
    snowflake = uint64
    DiscordObject* = object of RootObj
        id*: snowflake

proc `==`(obj1: DiscordObject, obj2: DiscordObject): bool =
    return obj1.id == obj2.id
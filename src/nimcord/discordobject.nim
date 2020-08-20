type 
    Snowflake* = uint64
    DiscordObject* = object of RootObj
        id*: Snowflake ## ID of this discord object.
        clientInstanceID*: uint8 ## Client instance id for this object. Mainly used internally.

proc `==`*(obj1: DiscordObject, obj2: DiscordObject): bool =
    return obj1.id == obj2.id

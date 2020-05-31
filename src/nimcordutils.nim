include parseutils, json, httpClient
from discordobject import snowflake

proc getIDFromJson*(str: string): uint64 =
    var num: uint64
    discard parseOct(str, num)
    return num


type RateLimitBucketType = enum
    CHANNEL,
    GUILD,
    WEBHOOK,
    GLOBAL
import parseutils, json, httpClient, strformat, tables, times, asyncdispatch
from discordobject import snowflake

proc getIDFromJson*(str: string): uint64 =
    var num: uint64
    discard parseOct(str, num)
    return num

proc endpoint*(url: string): string =
    return fmt("https://discord.com/api/v6{url}")

type 
    RateLimitBucketType* = enum
        channel,
        guild,
        webhook,
        global
    RateLimit = ref object {.requiresInit.}
        limit: int
        remainingLimit: int
        ratelimitReset: float

proc newRateLimit(lmt: int = 500, remLmnt: int = 500, ratelmtReset: float = 0): RateLimit =
    return RateLimit(limit: lmt, remainingLimit: remLmnt, ratelimitReset: ratelmtReset)

# Rate limit buckets
let channelRatelimitBucket = newTable[snowflake, RateLimit]()
let guildRatelimitBucket = newTable[snowflake, RateLimit]()
let webhookRatelimitBucket = newTable[snowflake, RateLimit]()
var globalRateLimit: RateLimit = newRateLimit()

proc handleRateLimits*(headers: HttpHeaders, objectID: snowflake, bucketType: RateLimitBucketType) =
    var obj: RateLimit
    if (headers.hasKey("x-ratelimit-global")):
        obj = globalRateLimit
    elif (headers.hasKey("x-ratelimit-limit")):
        case bucketType:
            of RateLimitBucketType.channel:
                obj = channelRatelimitBucket[objectID]
                discard
            of RateLimitBucketType.guild:
                obj = guildRatelimitBucket[objectID]
                discard
            of RateLimitBucketType.webhook:
                obj = webhookRatelimitBucket[objectID]
                discard
            of RateLimitBucketType.global:
                obj = globalRateLimit
                discard
    else:
        return

    discard parseInt(headers["x-ratelimit-limit"], obj.limit)
    discard parseInt(headers["x-ratelimit-remaining"], obj.remainingLimit)
    discard parseFloat(headers["x-ratelimit-reset"], obj.ratelimitReset)


proc handleResponse*(response: Response, objectID: snowflake, bucketType: RateLimitBucketType): JsonNode =
    echo fmt("Received requested payload: {response.body}")

    handleRateLimits(response.headers, objectID, bucketType)

    return parseJson(response.body())

proc waitForRateLimits*(objectID: snowflake, bucketType: RateLimitBucketType) =
    var rlmt: RateLimit
    if (globalRateLimit.remainingLimit == 0):
        rlmt = globalRateLimit
    else:
        case bucketType:
            of RateLimitBucketType.channel:
                rlmt = channelRatelimitBucket[objectID]
                discard
            of RateLimitBucketType.guild:
                rlmt = guildRatelimitBucket[objectID]
                discard
            of RateLimitBucketType.webhook:
                rlmt = webhookRatelimitBucket[objectID]
                discard
            of RateLimitBucketType.global:
                rlmt = globalRateLimit
                discard
    
    if (rlmt.remainingLimit == 0):
        let millisecondTime: float = rlmt.ratelimitReset * 1000 - epochTime() * 1000

        if (millisecondTime > 0):
            echo fmt("Rate limit wait time: {millisecondTime} miliseconds")
            discard sleepAsync(millisecondTime)
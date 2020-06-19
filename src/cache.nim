import sequtils, message, member, channel, guild, discordobject, nimcordutils, httpcore

type Cache* = ref object
    members*: seq[GuildMember]
    messages*: seq[Message]
    channels*: seq[Channel]
    guilds*: seq[Guild]

proc getChannel*(cache: Cache, id: snowflake): Channel =
    for index, channel in cache.channels:
        if (channel.id == id):
            return channel
    
    return newChannel(sendRequest(endpoint("/channels/" & $id), HttpGet, defaultHeaders(), 
        id, RateLimitBucketType.channel))

proc getMessageChannel*(msg: Message, cache: Cache): Channel =
    ## Get a message's channel object.
    ## 
    ## If for some reason the channel is not in cache, it gets requested via the 
    ## Discord REST API.
    return cache.getChannel(msg.channelID)

proc getGuild*(cache: Cache, id: snowflake): Guild =
    for index, guild in cache.guilds:
        if (guild.id == id):
            return guild
    
    return newGuild(sendRequest(endpoint("/guild/" & $id), HttpGet, defaultHeaders(), 
        id, RateLimitBucketType.guild))

proc getChannelGuild*(channel: Channel, cache: Cache): Guild =
    return cache.getGuild(channel.guildID)
import sequtils, message, member, channel, guild, discordobject, nimcordutils, httpcore

type Cache* = ref object
    members*: seq[GuildMember]
    messages*: seq[Message]
    channels*: seq[Channel]
    guilds*: seq[Guild]

proc getMessageChannel*(msg: Message, cache: Cache): Channel =
    for index, channel in cache.channels:
        if (channel.id == msg.channelID):
            return channel

    return nil

proc getChannelGuild*(channel: Channel, cache: Cache): Guild =
    for index, guild in cache.guilds:
        if (guild.id == channel.guildID):
            return guild

    return nil

proc getChannel*(cache: Cache, id: snowflake): Channel =
    for index, channel in cache.channels:
        if (channel.id == id):
            return channel
    
    return newChannel(sendRequest(endpoint("/channels/" & $id), HttpGet, 
        defaultHeaders(), id, RateLimitBucketType.channel))
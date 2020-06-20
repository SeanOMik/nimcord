import message, member, channel, guild, discordobject, nimcordutils, httpcore, user

type Cache* = ref object
    members*: seq[GuildMember]
    messages*: seq[Message]
    channels*: seq[Channel]
    guilds*: seq[Guild]

proc getChannel*(cache: var Cache, id: snowflake): Channel =
    ## Get a channel object from the id.
    ## 
    ## If for some reason the channel is not in cache, it gets requested via the 
    ## Discord REST API.
    for channel in cache.channels:
        if (channel.id == id):
            return channel
    
    result = newChannel(sendRequest(endpoint("/channels/" & $id), HttpGet, defaultHeaders(), 
        id, RateLimitBucketType.channel))
    cache.channels.add(result)

proc getMessageChannel*(msg: Message, cache: var Cache): Channel =
    ## Get a message's channel object.
    ## 
    ## If for some reason the channel is not in cache, it gets requested via the 
    ## Discord REST API.
    return cache.getChannel(msg.channelID)

proc getGuild*(cache: var Cache, id: snowflake): Guild =
    ## Get a guild object from it's id.
    ## 
    ## If for some reason the guild is not in cache, it gets requested via the 
    ## Discord REST API.
    for guild in cache.guilds:
        if (guild.id == id):
            return guild
    
    result = newGuild(sendRequest(endpoint("/guilds/" & $id), HttpGet, defaultHeaders(), 
        id, RateLimitBucketType.guild))
    cache.guilds.add(result)

proc getChannelGuild*(channel: Channel, cache: var Cache): Guild =
    ## Get a channels's guild object.
    ## 
    ## If for some reason the guild is not in cache, it gets requested via the 
    ## Discord REST API.
    return cache.getGuild(channel.guildID)

proc getUser*(cache: Cache, id: snowflake): User =
    ## Get a user object from it's id.
    ## 
    ## If for some reason the user is not in cache, it gets requested via the 
    ## Discord REST API.
    for member in cache.members:
        if (member.user.id == id):
            return member.user

    return newUser(sendRequest(endpoint("/users/" & $id), HttpGet, defaultHeaders()))
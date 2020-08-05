import message, member, channel, guild, discordobject, nimcordutils, httpcore, user, tables

type Cache* = ref object
    members*: Table[Snowflake, GuildMember]
    messages*: Table[Snowflake, Message]
    channels*: Table[Snowflake, Channel]
    guilds*: Table[Snowflake, Guild]

proc getChannel*(cache: var Cache, id: Snowflake): Channel =
    ## Get a channel object from the id.
    ## 
    ## If for some reason the channel is not in cache, it gets requested via the 
    ## Discord REST API.
    if cache.channels.hasKey(id):
        return cache.channels[id]
    
    result = newChannel(sendRequest(endpoint("/channels/" & $id), HttpGet, defaultHeaders(), 
        id, RateLimitBucketType.channel))
    cache.channels.add(id, result)

proc getMessageChannel*(msg: Message, cache: var Cache): Channel =
    ## Get a message's channel object.
    ## 
    ## If for some reason the channel is not in cache, it gets requested via the 
    ## Discord REST API.
    return cache.getChannel(msg.channelID)

proc getGuild*(cache: var Cache, id: Snowflake): Guild =
    ## Get a guild object from it's id.
    ## 
    ## If for some reason the guild is not in cache, it gets requested via the 
    ## Discord REST API.
    if cache.guilds.hasKey(id):
        return cache.guilds[id]
    
    result = newGuild(sendRequest(endpoint("/guilds/" & $id), HttpGet, defaultHeaders(), 
        id, RateLimitBucketType.guild))
    cache.guilds.add(result.id, result)

proc getChannelGuild*(channel: Channel, cache: var Cache): Guild =
    ## Get a channels's guild object.
    ## 
    ## If for some reason the guild is not in cache, it gets requested via the 
    ## Discord REST API.
    return cache.getGuild(channel.guildID)

proc getUser*(cache: Cache, id: Snowflake): User =
    ## Get a user object from it's id.
    ## 
    ## If for some reason the user is not in cache, it gets requested via the 
    ## Discord REST API.
    if cache.members.hasKey(id):
        return cache.members[id].user

    return newUser(sendRequest(endpoint("/users/" & $id), HttpGet, defaultHeaders()))

proc cacheGuildChannel*(cache: var Cache, guildID: Snowflake, channel: Channel) = 
    ## Adds a channel in cache.guilds[guildID].channels.
    ## Only used for internal library, dont touch!
    var guild = cache.getGuild(guildID)
    guild.channels.add(channel)

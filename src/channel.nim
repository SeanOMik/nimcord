import json, discordobject, user, options, nimcordutils, message, httpcore, asyncdispatch, asyncfutures, strutils

type 
    ChannelType* = enum
        chanTypeNIL = -1,
        chanTypeGuildText = 0,
        chanTypeDM = 1,
        chanTypeGuildVoice = 2,
        chanTypeGroupDM = 3,
        chanTypeGuildCategory = 4,
        chanTypeGuildNews = 5,
        chanTypeGuildStore = 6

    Channel* = ref object of DiscordObject
        `type`*: ChannelType ## The type of channel.
        guildID*: snowflake ## The id of the guild.
        position*: int ## Sorting position of the channel.
        #permissionOverwrites*: seq[Permissions] ## Explicit permission overwrites for members and roles.
        name*: string ## The name of the channel (2-100 characters).
        topic*: string ## The channel topic (0-1024 characters).
        nsfw*: bool ## Whether the channel is nsfw.
        lastMessageID*: snowflake ## The id of the last message sent in this channel (may not point to an existing or valid message).
        bitrate*: int ## The bitrate (in bits) of the voice channel.
        userLimit*: int ## The user limit of the voice channel.
        rateLimitPerUser*: int ## Amount of seconds a user has to wait before sending another message (0-21600); bots, as well as users with the permission manage_messages or manage_channel, are unaffected.
        recipients*: seq[User] ## The recipients of the DM
        icon*: string ## Icon hash
        ownerID: snowflake ## ID of the DM creator
        applicationID: snowflake ## Application id of the group DM creator if it is bot-created
        parentID: snowflake ## ID of the parent category for a channel
        lastPinTimestamp: string ## When the last pinned message was pinned
    
    ChannelModify* {.requiresInit.} = ref object
        ## Use this type to modify a channel by setting each fields.
        name*: Option[string]
        `type`*: Option[ChannelType]
        position*: Option[int]
        topic*: Option[string]
        nsfw*: Option[bool]
        rateLimitPerUser*: Option[int]
        bitrate*: Option[int]
        userLimit*: Option[int]
        #permissionOverwrites*: seq[Permissions] ## Explicit permission overwrites for members and roles.
        parentID*: Option[snowflake]

#[ proc newChannelModify*(name: Option[string], `type`: Option[ChannelType], position: Option[int], 
    topic: Option[string], nsfw: Option[bool], rateLimitPerUser: Option[int], bitrate: Option[int], 
    userLimit: Option[int], parentID: Option[snowflake]): ChannelModify =
    
    return ChannelModify(name: name.get, `type`:`type`, position: position, nsfw: nsfw, 
        rateLimitPerUser: rateLimitPerUser, bitrate: bitrate, userLimit: userLimit, parentID: parentID) ]#

proc newChannel*(channel: JsonNode): Channel {.inline.} =
    var chan = Channel(
        id: getIDFromJson(channel["id"].getStr()),
        `type`: ChannelType(channel["type"].getInt()),
    )

    if (channel.contains("guild_id")):
        chan.guildID = getIDFromJson(channel["guild_id"].getStr())
    if (channel.contains("position")):
        chan.position = channel["position"].getInt()
    if (channel.contains("permission_overwrites")):
        echo "permission_overwrites"
    if (channel.contains("name")):
        chan.name = channel["name"].getStr()
    if (channel.contains("topic")):
        chan.topic = channel["topic"].getStr()
    if (channel.contains("nsfw")):
        chan.nsfw = channel["nsfw"].getBool()
    if (channel.contains("last_message_id")):
        chan.lastMessageID = getIDFromJson(channel["last_message_id"].getStr())
    if (channel.contains("bitrate")):
        chan.bitrate = channel["bitrate"].getInt()
    if (channel.contains("user_limit")):
        chan.userLimit = channel["user_limit"].getInt()
    if (channel.contains("rate_limit_per_user")):
        chan.rateLimitPerUser = channel["rate_limit_per_user"].getInt()
    if (channel.contains("recipients")):
        for recipient in channel["recipients"]:
            chan.recipients.insert(newUser(recipient))
    if (channel.contains("icon")):
        chan.icon = channel["icon"].getStr()
    if (channel.contains("owner_id")):
        chan.ownerID = getIDFromJson(channel["owner_id"].getStr())
    if (channel.contains("application_id")):
        chan.applicationID = getIDFromJson(channel["application_id"].getStr())
    if (channel.contains("parent_id")):
        chan.parentID = getIDFromJson(channel["parent_id"].getStr())
    if (channel.contains("last_pin_timestamp")):
        chan.lastPinTimestamp = channel["last_pin_timestamp"].getStr()

    return chan

proc sendMessage*(channel: Channel, content: string, tts: bool = false): Message =
    let messagePayload = %*{"content": content, "tts": tts}

    return newMessage(sendRequest(endpoint("/channels/" & $channel.id & "/messages"), HttpPost, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), channel.id, 
        RateLimitBucketType.channel, messagePayload))

proc modifyChannel*(channel: Channel, modify: ChannelModify): Future[Channel] {.async.} =
    var modifyPayload = %*{}

    if (modify.name.isSome):
        modifyPayload.add("name", %modify.name.get())

    if (modify.`type`.isSome):
        modifyPayload.add("type", %modify.`type`.get())

    if (modify.position.isSome):
        modifyPayload.add("position", %modify.position.get())

    if (modify.topic.isSome):
        modifyPayload.add("topic", %modify.topic.get())

    if (modify.nsfw.isSome):
        modifyPayload.add("nsfw", %modify.nsfw.get())

    if (modify.rateLimitPerUser.isSome):
        modifyPayload.add("rate_limit_per_user", %modify.rateLimitPerUser.get())

    if (modify.bitrate.isSome):
        modifyPayload.add("bitrate", %modify.bitrate.get())

    if (modify.userLimit.isSome):
        modifyPayload.add("user_limit", %modify.userLimit.get())

    #[ if (modify.name.isSome):
        modifyPayload.add("permission_overwrites", %modify.parentID.get()0 ]#

    if (modify.parentID.isSome):
        modifyPayload.add("parent_id", %modify.parentID.get())

    return newChannel(sendRequest(endpoint("/channels/" & $channel.id), HttpPatch, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        channel.id, RateLimitBucketType.channel, modifyPayload))

proc deleteChannel*(channel: Channel) {.async.} =
    discard sendRequest(endpoint("/channels/" & $channel.id), HttpDelete, 
        defaultHeaders(), channel.id, RateLimitBucketType.channel)
import json, discordobject, user, options, nimcordutils, message, httpcore, asyncdispatch, asyncfutures, strutils

type 
    ChannelType* = enum
        ## This enum shows the type of the channel.
        chanTypeGuildText = 0,
        chanTypeDM = 1,
        chanTypeGuildVoice = 2,
        chanTypeGroupDM = 3,
        chanTypeGuildCategory = 4,
        chanTypeGuildNews = 5,
        chanTypeGuildStore = 6

    Channel* = ref object of DiscordObject
        ## Discord channel object.
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
    
    ChannelModify* = ref object
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

proc newChannel*(channel: JsonNode): Channel {.inline.} =
    ## Parses the channel from json.
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
    ## Send a message through the channel. 
    let messagePayload = %*{"content": content, "tts": tts}

    return newMessage(sendRequest(endpoint("/channels/" & $channel.id & "/messages"), HttpPost, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), channel.id, 
        RateLimitBucketType.channel, messagePayload))

proc modifyChannel*(channel: Channel, modify: ChannelModify): Future[Channel] {.async.} =
    ## Modifies the channel.
    ## 
    ## Examples:
    ## .. code-block:: nim
    ##    var chan = getChannel(703084913510973472)
    ##    chan = chan.modifyChannel(ChannelModify(topic: some("This is the channel topic")))

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
    ## Delete the channel.
    discard sendRequest(endpoint("/channels/" & $channel.id), HttpDelete, 
        defaultHeaders(), channel.id, RateLimitBucketType.channel)

type MessagesGetRequest* = object
    ## Use this type to get a channel's messages by setting some of the fields.
    ## You can only set one of `around`, `before`, or `after`.
    around*: Option[snowflake]
    before*: Option[snowflake]
    after*: Option[snowflake]
    limit*: Option[int]

proc getMessages*(channel: Channel, request: MessagesGetRequest): seq[Message] =
    ## Gets messages in the channel.
    ## 
    ## Examples:
    ## .. code-block:: nim
    ##   var chan = getChannel(703084913510973472)
    ##   channel.getMessages(MessagesGetRequest(limit: some(15), before: some(723030179760570428)))

    var url: string = endpoint("/channels/" & $channel.id & "/messages?")

    if (request.around.isSome):
        url = url & "around=" & $request.around.get()

    # Raise some exceptions to make sure the user doesn't
    # try to set more than one of these fields
    if (request.before.isSome):
        if (request.around.isSome):
            raise newException(Defect, "You cannot get around and before a message! Choose one...")
        url = url & "before=" & $request.before.get()

    if (request.after.isSome):
        if (request.around.isSome or request.before.isSome):
            raise newException(Defect, "You cannot get around/before and after a message! Choose one...")
        url = url & "after=" & $request.after.get()

    if (request.limit.isSome):
        # Add the `&` for the url if something else is set.
        if (request.around.isSome or request.before.isSome or request.after.isSome):
            url = url & "&"
        
        url = url & "limit=" & $request.limit.get()

    let response = sendRequest(url, HttpGet, defaultHeaders(newHttpHeaders()),
        channel.id, RateLimitBucketType.channel)

    for message in response:
        result.add(newMessage(message))
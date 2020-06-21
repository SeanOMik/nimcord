import json, discordobject, user, options, nimcordutils, message, httpcore, asyncdispatch, asyncfutures, permission, embed, httpclient, streams, strformat

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
        permissionOverwrites*: seq[Permissions] ## Explicit permission overwrites for members and roles.
        name*: string ## The name of the channel (2-100 characters).
        topic*: string ## The channel topic (0-1024 characters).
        nsfw*: bool ## Whether the channel is nsfw.
        lastMessageID*: snowflake ## The id of the last message sent in this channel (may not point to an existing or valid message).
        bitrate*: int ## The bitrate (in bits) of the voice channel.
        userLimit*: int ## The user limit of the voice channel.
        rateLimitPerUser*: int ## Amount of seconds a user has to wait before sending another message (0-21600); bots, as well as users with the permission manage_messages or manage_channel, are unaffected.
        recipients*: seq[User] ## The recipients of the DM
        icon*: string ## Icon hash
        ownerID*: snowflake ## ID of the DM creator
        applicationID*: snowflake ## Application id of the group DM creator if it is bot-created
        parentID*: snowflake ## ID of the parent category for a channel
        lastPinTimestamp*: string ## When the last pinned message was pinned
    
    ChannelFields* = ref object
        ## Use this type to modify or create a channel by setting each fields.
        name*: Option[string]
        `type`*: Option[ChannelType]
        topic*: Option[string]
        bitrate*: Option[int]
        userLimit*: Option[int]
        rateLimitPerUser*: Option[int]
        position*: Option[int]
        permissionOverwrites*: Option[seq[Permissions]] ## Explicit permission overwrites for members and roles.
        parentID*: Option[snowflake]
        nsfw*: Option[bool]

    Invite* = object
        ## Represents a code that when used, adds a user to a guild or group DM channel.
        code*: string ## The invite code (unique ID)
        guildID*: snowflake ## The guild this invite is for
        channel*: Channel ## The channel this invite is for
        inviter*: User ## The user who created the invite
        targetUser*: User ## The target user for this invite
        #targetUserType* # Not sure if this is needed because it can only be `1`
        approximatePresenceCount*: int ## Approximate count of online members (only present when target_user is set)
        approximateMemberCount*: int ## Approximate count of total members
        uses*: int ## Number of times this invite has been used
        maxUsers*: int ## Max number of times this invite can be used
        maxAge*: int ## Duration (in seconds) after which the invite expires
        temporary*: bool ## Whether this invite only grants temporary membership
        createdAt: string ## When this invite was created

    DiscordFile* = ref object
        ## This type is used for sending files. 
        ## It stores the file name, and the file path.
        ## Nimcord will read the file contents itself.
        fileName*: string
        filePath*: string

proc newChannel*(channel: JsonNode): Channel {.inline.} =
    ## Parses the channel from json.
    var chan = Channel(
        id: getIDFromJson(channel["id"].getStr()),
        `type`: ChannelType(channel["type"].getInt())
    )

    if (channel.contains("guild_id")):
        chan.guildID = getIDFromJson(channel["guild_id"].getStr())
    if (channel.contains("position")):
        chan.position = channel["position"].getInt()
    if (channel.contains("permission_overwrites")):
        for perm in channel["permission_overwrites"]:
            chan.permissionOverwrites.add(newPermissions(perm))
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

proc newInvite*(json: JsonNode): Invite {.inline.} =
    ## Parses an invite from json.
    var invite = Invite(
        code: json["code"].getStr(),
        channel: newChannel(json["channel"])
    )
    if (json.contains("guild")):
        invite.guildID = getIDFromJson(json["guild"]["id"].getStr())
    if (json.contains("target_user")):
        invite.targetUser = newUser(json["target_user"])
    if (json.contains("approximate_presence_count")):
        invite.approximatePresenceCount = json["approximate_presence_count"].getInt()
    if (json.contains("approximate_member_count")):
        invite.approximateMemberCount = json["approximate_member_count"].getInt()
    if (json.contains("uses")):
        invite.uses = json["uses"].getInt()
    if (json.contains("max_uses")):
        invite.maxUsers = json["max_uses"].getInt()
    if (json.contains("max_age")):
        invite.maxAge = json["max_age"].getInt()
    if (json.contains("temporary")):
        invite.temporary = json["temporary"].getBool()
    if (json.contains("created_at")):
        invite.createdAt = json["created_at"].getStr()

    return invite

proc sendMessage*(channel: Channel, content: string, tts: bool = false, embed: Embed = nil, files: seq[DiscordFile] = @[]): Message =
    ## Send a message through the channel. 
    var messagePayload = %*{"content": content, "tts": tts}

    if (not embed.isNil()):
        messagePayload.add("embed", embed.embedJson)

    if (files.len != 0):
        var client = newHttpClient()
        let endpoint = endpoint("/channels/" & $channel.id & "/messages")
        var multipart = newMultipartData()
        # Add headers
        client.headers = defaultHeaders(newHttpHeaders({"Content-Type": "multipart/form-data"}))

        for index, file in files:
            var imageStream = newFileStream(file.filePath, fmRead)
            if (not isNil(imageStream)):
                let data = imageStream.readALL()
                multipart.add("file" & $index, data, file.fileName, "application/octet-stream", false)
                
                imageStream.close()
            else:
                raise newException(IOError, "Failed to open file for sending: " & file.filePath)
        multipart.add("payload_json", $messagePayload, "", "application/json", false)

        echo "Sending POST request, URL: ", endpoint, ", headers: ", client.headers, " payload_json: ", messagePayload

        waitForRateLimits(channel.id, RateLimitBucketType.channel)
        let response: Response = client.post(endpoint, "", multipart)
        return newMessage(handleResponse(response, channel.id, RateLimitBucketType.channel))

    return newMessage(sendRequest(endpoint("/channels/" & $channel.id & "/messages"), HttpPost, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), channel.id, 
        RateLimitBucketType.channel, messagePayload))

proc modifyChannel*(channel: Channel, modify: ChannelFields): Future[Channel] {.async.} =
    ## Modifies the channel.
    ## 
    ## Examples:
    ##
    ## .. code-block:: nim
    ##   var chan = getChannel(703084913510973472)
    ##   chan = chan.modifyChannel(ChannelFields(topic: some("This is the channel topic")))

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

    if (modify.permissionOverwrites.isSome):
        var permOverwrites = parseJson("[]")
        for perm in modify.permissionOverwrites.get():
            permOverwrites.add(perm.permissionsToJson())
        modifyPayload.add("permission_overwrites", permOverwrites)

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
    ## Gets messages from the channel.
    ## 
    ## Examples:
    ##
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

proc getMessage*(channel: Channel, messageID: snowflake): Message =
    ## Requests a message from the channel via the Discord REST API.
    return newMessage(sendRequest(endpoint("/channels/" & $channel.id & "/messages/" & $messageID), HttpGet, 
        defaultHeaders(), channel.id, RateLimitBucketType.channel))


proc bulkDeleteMessages*(channel: Channel, messageIDs: seq[snowflake]) {.async.} =
    ## Bulk delete channel messages. This endpoint can only delete 2-100 messages.
    ## This proc takes a seq[snowflakes] represtenting the message's IDs.
    ## The messages can not be older than 2 weeks!
    ## 
    ## See also:
    ## * `bulkDeleteMessages(channel: Channel, messages: seq[Message])`_
    # Remove the `@` from the string conversion
    let stringPayload: string = ($messageIDs).substr(1)
    let jsonPayload = %*{"messages": parseJson(stringPayload)}

    discard sendRequest(endpoint("/channels/" & $channel.id & "/messages/bulk-delete"), HttpPost, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), channel.id, 
        RateLimitBucketType.channel, jsonPayload)
    

proc bulkDeleteMessages*(channel: Channel, messages: seq[Message]) {.async.} =
    ## Delete multiple messages in a single request. This endpoint can only delete 2-100 messages.
    ## This proc takes a seq[Message] represtenting the message's you want to delete.
    ## The messages can not be older than 2 weeks!
    ## 
    ## See also:
    ## * `bulkDeleteMessages(channel: Channel, messageIDs: seq[snowflake])`_
    var messageIDs: seq[snowflake]
    for msg in messages:
        messageIDs.add(msg.id)

    waitFor channel.bulkDeleteMessages(messageIDs)

proc editChannelPermissions*(channel: Channel, perms: Permissions) {.async.} =
    ## Edit the channel permission overwrites for a user or role in a channel. 
    ## Only usable for guild channels. Requires the `MANAGE_ROLES` permission.
    discard sendRequest(endpoint("/channels/" & $channel.id & "/permissions/" & $perms.roleUserID), 
        HttpPost, defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), channel.id, 
        RateLimitBucketType.channel, perms.permissionsToJson())

proc getChannelInvites*(channel: Channel): seq[Invite] =
    ## Returns a list of invite objects (with invite metadata) for the channel. 
    ## Only usable for guild channels. Requires the MANAGE_CHANNELS permission.
    let json = sendRequest(endpoint("/channels/" & $channel.id & "/invites"), HttpGet, 
        defaultHeaders(), channel.id, RateLimitBucketType.channel)

    for invite in json:
        result.add(newInvite(invite))

type CreateInviteFields* = object
    maxAge: Option[int] ## Duration of invite in seconds before expiry, or 0 for never
    maxUses: Option[int] ## Max number of uses or 0 for unlimited
    temporary: Option[bool] ## Whether this invite only grants temporary membership
    unique: Option[bool] ## If true, don't try to reuse a similar invite (useful for creating many unique one time use invites)
    targetUser: Option[snowflake] ## The target user id for this invite
    targetUserType: Option[int] ## The type of target user for this invite

proc createChannelInvite*(channel: Channel, fields: CreateInviteFields): Invite =
    ## Create a new invite object for the channel. Only usable for guild channels. 
    ## Requires the CREATE_INSTANT_INVITE permission.
    ## 
    ## Examples:
    ##
    ## .. code-block:: nim
    ##   var chan = getChannel(703084913510973472)
    ##   # Create an invite that lasts 1 day, and can only be used 10 times
    ##   channel.createChannelInvite(CreateInviteFields(maxAge: 3600, maxUses: 10))
    var createPayload = %*{}

    if (fields.maxAge.isSome):
        createPayload.add("max_age", %fields.maxAge.get())
    if (fields.maxUses.isSome):
        createPayload.add("max_uses", %fields.maxUses.get())
    if (fields.temporary.isSome):
        createPayload.add("temporary", %fields.temporary.get())
    if (fields.unique.isSome):
        createPayload.add("unique", %fields.unique.get())
    if (fields.targetUser.isSome):
        createPayload.add("target_user", %fields.targetUser.get())
    # Not sure if its needed because it can only be `1`
    #[ if (fields.targetUserType.isSome):
        createPayload.add("target_user_type", %fields.targetUserType.get()) ]#

    return newInvite(sendRequest(endpoint("/channels/" & $channel.id & "/invites"), HttpPost, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), channel.id, 
        RateLimitBucketType.channel, createPayload))

#TODO: https://discord.com/developers/docs/resources/channel#delete-channel-permission
proc deleteChannelPermission*(channel: Channel, overwrite: Permissions) {.async.} =
    ## Delete a channel permission overwrite for a user or role in a channel. 
    ## Only usable for guild channels. Requires the `MANAGE_ROLES` permission.
    discard sendRequest(endpoint(fmt("/channels/{channel.id}/permissions/{overwrite.roleUserID}")), 
        HttpDelete, defaultHeaders(), channel.id, RateLimitBucketType.channel)

proc triggerTypingIndicator*(channel: Channel) {.async.} =
    ## Post a typing indicator for the specified channel.
    discard sendRequest(endpoint("/channels/" & $channel.id & "/typing"), HttpPost, 
        defaultHeaders(), channel.id, RateLimitBucketType.channel)

proc getPinnedMessages*(channel: Channel): seq[Message] =
    ## Returns all pinned messages in the channel
    let json = sendRequest(endpoint("/channels/" & $channel.id & "/pins"), HttpGet, 
        defaultHeaders(), channel.id, RateLimitBucketType.channel)
    
    for message in json:
        result.add(newMessage(message))

proc groupDMAddRecipient*(channel: Channel, user: User, accessToken: string, nick: string) {.async.} =
    ## Adds a recipient to a Group DM using their access token.
    let jsonBody = %* {"access_token": accessToken, "nick": nick}
    discard sendRequest(endpoint("/channels/" & $channel.id & "/recipients/" & $user.id), 
        HttpPut, defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        channel.id, RateLimitBucketType.channel, jsonBody)
    
proc groupDMRemoveRecipient*(channel: Channel, user: User) {.async.} =
    ## Removes a recipient from a Group DM.
    discard sendRequest(endpoint("/channels/" & $channel.id & "/recipients/" & $user.id), 
        HttpPut, defaultHeaders(), channel.id, RateLimitBucketType.channel)
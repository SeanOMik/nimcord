import json, discordobject, nimcordutils, user, member, httpcore, asyncdispatch, emoji, options, embed, role, emoji

type 
    MessageType* = enum
        default = 0,
        recipientAdd = 1,
        recipientRemove = 2,
        call = 3,
        channelNameChange = 4,
        channelIconChange = 5,
        channelPinnedMessage = 6,
        guildMemberJoin = 7,
        userPremiumGuildSubscription = 8,
        userPremiumGuildSubscriptionTier1 = 9,
        userPremiumGuildSubscriptionTier2 = 10,
        userPremiumGuildSubscriptionTier3 = 11,
        channelFollowAdd = 12,
        guildDiscoveryDisqualified = 14,
        guildDiscoveryRequalified = 15

    MessageActivityType* = enum
        join = 1,
        spectate = 2,
        listen = 3,
        joinRequest = 5

    MessageActivity* = ref object
        `type`*: MessageActivityType
        partyID*: string

    MessageApplication* = ref object of DiscordObject
        coverImage*: string
        description*: string
        icon*: string
        name*: string

    MessageReference* = ref object
        messageID*: snowflake
        channelID*: snowflake
        guildID*: snowflake

    MessageFlags* = enum
        msgFlagCrossposted = 0,
        msgFlagIsCrossPost = 1,
        msgFlagSuppressEmbeds = 2,
        msgFlagSourceMsgDeleted = 3,
        msgFlagUrgent = 4

    Reaction* = ref object
        count*: uint
        me*: bool ## Whether the current user has reacted using this emoji.
        emoji*: Emoji

    ChannelMention* = ref object
        ## Represents a channel mention inside of a message.
        channelID*: snowflake
        guildID*: snowflake
        channelType*: int
        name*: string

    MessageAttachment* = ref object of DiscordObject
        ## Represents a message attachment
        filename*: string
        size*: uint
        url*: string
        proxyURL*: string
        height*: int
        width*: int

    Message* = ref object of DiscordObject
        channelID*: snowflake
        guildID*: snowflake
        author*: User
        member*: GuildMember
        content*: string
        timestamp*: string
        editedTimestamp*: string
        tts*: bool
        mentionEveryone*: bool
        mentions*: seq[User]
        mentionRoles*: seq[snowflake]
        mentionChannels*: seq[ChannelMention]
        attachments*: seq[MessageAttachment]
        embeds*: seq[Embed]
        reactions*: seq[Reaction]
        pinned*: bool
        webhookID*: snowflake
        `type`*: MessageType
        activity*: MessageActivity
        application*: MessageApplication
        messageReference*: MessageReference
        flags*: int

proc newMessage*(messageJson: JsonNode): Message =
    var msg = Message(
        id: getIDFromJson(messageJson["id"].getStr()),
        channelID: getIDFromJson(messageJson["channel_id"].getStr()),
        guildID: getIDFromJson(messageJson{"guild_id"}.getStr()),
        content: messageJson["content"].getStr(),
        timestamp: messageJson["timestamp"].getStr(),
        editedTimestamp: messageJson{"edited_timestamp"}.getStr(),
        tts: messageJson["tts"].getBool(),
        mentionEveryone: messageJson["mention_everyone"].getBool(),
        pinned: messageJson["pinned"].getBool(),
        webhookID: getIDFromJson(messageJson{"webhook_id"}.getStr()),
        `type`: MessageType(messageJson["type"].getInt()),
        flags: messageJson{"flags"}.getInt()
    )

    if (messageJson.contains("author")):
        msg.author = newUser(messageJson["author"])
    if (messageJson.contains("member")):
        msg.member = newGuildMember(messageJson["member"], msg.guildID)

    if (messageJson.contains("mentions")):
        for userJson in messageJson["mentions"]:
            msg.mentions.add(newUser(userJson))
        
    for role in messageJson["mention_roles"]:
        msg.mentionRoles.add(getIDFromJson(role.getStr()))

    if (messageJson.contains("mention_channels")):
        for channel in messageJson["mention_channels"]:
            msg.mentionChannels.add(ChannelMention(
                channelID: getIDFromJson(channel["id"].getStr()),
                guildID: getIDFromJson(channel["guild_id"].getStr()),
                channelType: channel["type"].getInt(),
                name: channel["tyoe"].getStr()
            ))

    for attachment in messageJson["attachments"]:
        msg.attachments.add(MessageAttachment(
            id: getIDFromJson(attachment["id"].getStr()),
            filename: attachment["filename"].getStr(),
            size: uint(attachment["size"].getInt()),
            url: attachment["url"].getStr(),
            proxyURL: attachment["proxy_url"].getStr(),
            height: attachment{"height"}.getInt(),
            width: attachment{"width"}.getInt()
        ))

    for embed in messageJson["embeds"]:
        msg.embeds.add(Embed(embedJson: embed))

    if (messageJson.contains("reactions")):
        for reaction in messageJson["reactions"]:
            msg.reactions.add(Reaction(
                count: uint(reaction["count"].getInt()),
                me: reaction["me"].getBool(),
                emoji: newEmoji(reaction["emoji"], msg.guildID)
            ))

    if (messageJson.contains("activity")):
        msg.activity = MessageActivity(`type`: MessageActivityType(messageJson["activity"]["type"].getInt()), 
            partyID: messageJson["activity"]["party_id"].getStr())
    if (messageJson.contains("application")):
        msg.application = MessageApplication(
            id: getIDFromJson(messageJson["application"]["id"].getStr()),
            coverImage: messageJson["application"]{"cover_image"}.getStr(),
            description: messageJson["application"]["description"].getStr(),
            icon: messageJson["application"]{"icon"}.getStr(),
            name: messageJson["application"]["name"].getStr()
        )
    if (messageJson.contains("message_reference")):
        msg.messageReference = MessageReference(
            messageID: getIDFromJson(messageJson["message_reference"]{"message_id"}.getStr()),
            channelID: getIDFromJson(messageJson["message_reference"]["channel_id"].getStr()),
            guildID: getIDFromJson(messageJson["message_reference"]{"guild_id"}.getStr()),
        )

    return msg

proc addReaction*(message: Message, emoji: Emoji) {.async.} =
    ## Create a reaction for the message. This endpoint requires the 
    ## `READ_MESSAGE_HISTORY` permission to be present on the current
    ## user. Additionally, if nobody else has reacted to the message 
    ## using this emoji, this endpoint requires the 'ADD_REACTIONS' 
    ## permission to be present on the current user.
    ## 
    ## See also:
    ## * `removeReaction<#removeReaction,Message,Emoji>`_
    discard sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id & 
        "/reactions/" & emoji.toUrlEncoding() & "/@me"), HttpPut, defaultHeaders(),
        message.channelID, RateLimitBucketType.channel)

proc removeReaction*(message: Message, emoji: Emoji) {.async.} =
    ## Delete a reaction the bot user has made for the message.
    ## 
    ## See also:
    ## * `addReaction<#addReaction,Message,Emoji>`_
    ## * `removeUserReaction<#removeUserReaction,Message,Emoji,User>`_
    ## * `removeAllReactions<#removeAllReactions,Message>`_
    ## * `removeAllReactions<#removeAllReactions,Message,Emoji>`_
    discard sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id & 
        "/reactions/" & emoji.toUrlEncoding() & "/@me"), HttpDelete, defaultHeaders(),
        message.channelID, RateLimitBucketType.channel)

proc removeUserReaction*(message: Message, emoji: Emoji, user: User) {.async.} =
    ## Deletes another user's reaction. This endpoint requires the 
    ## `MANAGE_MESSAGES` permission to be present on the current user
    ## 
    ## See also:
    ## * `addReaction<#addReaction,Message,Emoji>`_
    ## * `removeReaction<#removeReaction,Message,Emoji>`_
    ## * `removeAllReactions<#removeAllReactions,Message>`_
    ## * `removeAllReactions<#removeAllReactions,Message,Emoji>`_
    discard sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id & 
        "/reactions/" & emoji.toUrlEncoding() & "/" & $user.id), HttpDelete, defaultHeaders(),
        message.channelID, RateLimitBucketType.channel)

type ReactantsGetRequest* = object
    ## Use this type to get a messages's reactants by setting 
    ## some of the fields.
    ## You can only set one of `before` and `after`.
    before*: Option[snowflake]
    after*: Option[snowflake]
    limit*: Option[int]

proc getReactants*(message: Message, emoji: Emoji, request: ReactantsGetRequest): seq[User] =
    ## Get a list of users that reacted with this emoji.
    
    var url: string = endpoint("/channels/" & $message.channelID & "/messages/" & $message.id & 
        "/reactions/" & emoji.toUrlEncoding())

    # Raise some exceptions to make sure the user doesn't
    # try to set more than one of these fields
    if (request.before.isSome):
        url = url & "before=" & $request.before.get()

    if (request.after.isSome):
        if (request.before.isSome):
            raise newException(Defect, "You cannot get before and after a message! Choose one...")
        url = url & "after=" & $request.after.get()

    if (request.limit.isSome):
        # Add the `&` for the url if something else is set.
        if (request.before.isSome or request.after.isSome):
            url = url & "&"
        
        url = url & "limit=" & $request.limit.get()

    let json = sendRequest(url, HttpGet, defaultHeaders(), message.channelID, 
        RateLimitBucketType.channel)
    
    for user in json:
        result.add(newUser(user))

proc removeAllReactions*(message: Message) {.async.} =
    ## Deletes all reactions on a message. This endpoint requires the 
    ## `MANAGE_MESSAGES` permission to be present on the current user.
    ## 
    ## See also:
    ## * `addReaction<#addReaction,Message,Emoji>`_
    ## * `removeReaction<#removeReaction,Message,Emoji>`_
    ## * `removeUserReaction<#removeUserReaction,Message,Emoji,User>`_
    ## * `removeAllReactions<#removeAllReactions,Message,Emoji>`_
    discard sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id & 
        "/reactions/"), HttpDelete, defaultHeaders(), message.channelID, RateLimitBucketType.channel)

proc removeAllReactions*(message: Message, emoji: Emoji) {.async.} =
    ## Deletes all the reactions for a given emoji on a message. This 
    ## endpoint requires the `MANAGE_MESSAGES` permission to be present
    ## on the current user.
    ## 
    ## See also:
    ## * `addReaction<#addReaction,Message,Emoji>`_
    ## * `removeReaction<#removeReaction,Message,Emoji>`_
    ## * `removeUserReaction<#removeUserReaction,Message,Emoji,User>`_
    ## * `removeAllReactions<#removeAllReactions,Message>`_
    discard sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id & 
        "/reactions/" & emoji.toUrlEncoding()), HttpDelete, defaultHeaders(), message.channelID, 
        RateLimitBucketType.channel)

#TODO: Embeds and maybe flags?
proc editMessage*(message: Message, content: string): Future[Message] {.async.} =
    ## Edit a previously sent message.
    let jsonBody = %*{"content": content}
    return newMessage(sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id),
        HttpPatch, defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        message.channelID, RateLimitBucketType.channel, jsonBody))

proc deleteMessage*(message: Message) {.async.} =
    ## Delete a message. If operating on a guild channel and trying to delete
    ## a message that was not sent by the current user, this endpoint requires
    ## the `MANAGE_MESSAGES` permission.
    ## 
    ## See also:
    ## * `deleteMessage<#deleteMessage,Message>`_
    discard sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id), 
        HttpDelete, defaultHeaders(), message.channelID, RateLimitBucketType.channel)
import json, discordobject, nimcordutils, user, member, httpcore, asyncdispatch, emoji

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

    MessageActivity* = object
        `type`*: MessageActivityType
        partyID*: string

    MessageApplication* = object of DiscordObject
        coverImage: string
        description: string
        icon: string
        name: string

    MessageReference* = object
        messageID: snowflake
        channelID: snowflake
        guildID: snowflake

    MessageFlags* = enum
        msgFlagCrossposted = 0,
        msgFlagIsCrossPost = 1,
        msgFlagSuppressEmbeds = 2,
        msgFlagSourceMsgDeleted = 3,
        msgFlagUrgent = 4

    Message* = object of DiscordObject
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
        #mentionRoles*: seq[Role]
        #mentionChannels*: seq[ChannelMention]
        #attachments*: seq[Attachment]
        #embeds*: seq[Embed]
        #reactions*: seq[Reaction]
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
        #mentionRoles
        #mentionChannels?
        #attachments
        #embeds
        #reactions?
        pinned: messageJson["pinned"].getBool(),
        webhookID: getIDFromJson(messageJson{"webhook_id"}.getStr()),
        `type`: MessageType(messageJson["type"].getInt()),
        flags: messageJson{"flags"}.getInt()
    )

    if (messageJson.contains("author")):
        msg.author = newUser(messageJson["author"])
    if (messageJson.contains("member")):
        msg.member = newGuildMember(messageJson["member"])

    if (messageJson.contains("mentions")):
        let mentionsJson = messageJson["mentions"].getElems()

        for userJson in mentionsJson.items:
            msg.mentions.add(newUser(userJson))

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
    discard sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id & 
        "/reactions/" & emoji.toUrlEncoding() & "/@me"), HttpPut, defaultHeaders(),
        message.channelID, RateLimitBucketType.channel)

#TODO: Embeds and maybe flags?
proc editMessage*(message: Message, content: string): Future[Message] {.async.} =
    let jsonBody = %*{"content": content}
    return newMessage(sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id),
        HttpPatch, defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        message.channelID, RateLimitBucketType.channel, jsonBody))

proc deleteMessage*(message: Message) =
    ## Delete a message. If operating on a guild channel and trying to delete
    ## a message that was not sent by the current user, this endpoint requires
    ## the `MANAGE_MESSAGES` permission.
    discard sendRequest(endpoint("/channels/" & $message.channelID & "/messages/" & $message.id), 
        HttpDelete, defaultHeaders(), message.channelID, RateLimitBucketType.channel)
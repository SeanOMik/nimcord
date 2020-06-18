import json, discordobject, nimcordutils, user, member

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
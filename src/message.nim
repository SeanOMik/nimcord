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

proc newMessage*(json: json.JsonNode): Message =
    var msg = Message(
        id: getIDFromJson(json["id"].getStr()),
        channelID: snowflake(json["channel_id"].getBiggestInt()),
        guildID: snowflake(json{"guild_id"}.getBiggestInt()),
        content: json["content"].getStr(),
        timestamp: json["timestamp"].getStr(),
        editedTimestamp: json{"edited_timestamp"}.getStr(),
        tts: json["tts"].getBool(),
        mentionEveryone: json["mention_everyone"].getBool(),
        #mentionRoles
        #mentionChannels
        #attachments
        #embeds
        #reactions
        pinned: json["pinned"].getBool(),
        webhookID: snowflake(json{"webhook_id"}.getBiggestInt()),
        `type`: MessageType(json["type"].getInt()),
        flags: json{"flags"}.getInt()
    )

    if (json.contains("author")):
        msg.author = newUser(json["author"])
    if (json.contains("member")):
        msg.member = newGuildMember(json["member"])

    if (json.contains("mentions")):
        var userArray: seq[JsonNode]
        json.getElems(json["mentions"], userArray)

        for index, userJson in userArray.pairs:
            msg.mentions.add(newUser(userJson))

    if (json.contains("activity")):
        msg.activity = MessageActivity(`type`: MessageActivityType(json["activity"]["type"].getInt()), 
            partyID: json["activity"]["party_id"].getStr())
    if (json.contains("application")):
        msg.application = MessageApplication(
            id: getIDFromJson(json["application"]["id"].getStr()),
            coverImage: json["application"]{"cover_image"}.getStr(),
            description: json["application"]["description"].getStr(),
            icon: json["application"]{"icon"}.getStr(),
            name: json["application"]["name"].getStr()
        )
    if (json.contains("message_reference")):
        msg.messageReference = MessageReference(
            messageID: getIDFromJson(json["message_reference"]{"message_id"}.getStr()),
            channelID: getIDFromJson(json["message_reference"]["channel_id"].getStr()),
            guildID: getIDFromJson(json["message_reference"]{"guild_id"}.getStr()),
        )

    return msg
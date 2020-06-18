import json, discordobject, channel, member, options, nimcordutils

type 
    ChannelType* = enum
        chanTypeGuildText = 0,
        chanTypeDM = 1,
        chanTypeGuildVoice = 2,
        chanTypeGroupDM = 3,
        chanTypeGuildCategory = 4,
        chanTypeGuildNews = 5,
        chanTypeGuildStore = 6

    VerificationLevel* = enum
        verifLevelNone = 0,
        verifLevelLow = 1,
        verifLevelMedium = 2,
        verifLevelHigh = 3,
        verifLevelVeryHigh = 4

    MFALevel* = enum
        mfaLevelNone = 0,
        mfaLevelElevated = 1

    PremiumTier* = enum
        premTierNone = 0,
        prermTierOne = 1,
        premTierTwo = 2,
        premTierThree = 3

    MessageNotificationsLevel* = enum
        msgNotifLevelAll = 0,
        msgNotifLevelMentions = 1

    ExplicitContentFilterLevel * = enum
        expFilterLvlDisabled = 0,
        expFilterLvlMembersWithoutRoles = 1,
        expFilterLvlAllMembers = 2

    Guild* = ref object of DiscordObject
        name*: string
        icon*: string
        splash*: string
        discoverySplash*: string
        owner*: bool
        ownerID: snowflake
        #TODO: Convert this to a Permissions type
        permissions*: int
        region*: string
        afkChannelID*: snowflake
        afkTimeout*: int
        verificationLevel*: VerificationLevel
        defaultMessageNotifications*: MessageNotificationsLevel
        explicitContentFilter*: ExplicitContentFilterLevel
        #roles*: seq[Role]
        #emojis*: seq[Emoji]
        features*: seq[string]
        mfaLevel*: MFALevel
        applicationID*: snowflake
        widgetEnabled*: bool
        widgetChannelID*: snowflake
        systemChannelID*: snowflake
        systemChannelFlags*: int
        rulesChannelID*: snowflake
        joinedAt*: string
        large*: bool
        unavailable*: bool
        memberCount*: int
        #voiceStates*: seq[VoiceState]
        members*: seq[GuildMember]
        channels*: seq[Channel]
        #presences*: seq[Presence]
        maxPresences*: int
        maxMembers*: int
        vanityUrlCode*: string
        description*: string
        banner*: string
        premiumTier*: PremiumTier
        premiumSubscriptionCount*: int
        preferredLocale*: string
        publicUpdatesChannelID*: snowflake
        maxVideoChannelUsers*: int
        approximateMemberCount*: int
        approximatePresenceCount*: int

proc newGuild*(json: JsonNode): Guild {.inline.} =
    # Parsing all null or guaranteed fields
    var g = Guild(
        id: getIDFromJson(json["id"].getStr()),
        name: json["name"].getStr(),
        icon: json["icon"].getStr(),
        splash: json["splash"].getStr(),
        discoverySplash: json["discovery_splash"].getStr(),
        ownerID: getIDFromJson(json["owner_id"].getStr()),
        region: json["region"].getStr(),
        afkChannelID: getIDFromJson(json["afk_channel_id"].getStr()),
        afkTimeout: json["afk_timeout"].getInt(),
        verificationLevel: VerificationLevel(json["verification_level"].getInt()),
        defaultMessageNotifications: MessageNotificationsLevel(json["default_message_notifications"].getInt()),
        explicitContentFilter: ExplicitContentFilterLevel(json["explicit_content_filter"].getInt()),
        #roles
        #emojis
        #features
        mfaLevel: MFALevel(json["mfa_level"].getInt()),
        applicationID: getIDFromJson(json["application_id"].getStr()),
        systemChannelID: getIDFromJson(json["system_channel_id"].getStr()),
        systemChannelFlags: json["system_channel_flags"].getInt(),
        rulesChannelID: getIDFromJson(json["rules_channel_id"].getStr()),
        vanityUrlCode: json["vanity_url_code"].getStr(),
        description: json["description"].getStr(),
        banner: json["banner"].getStr(),
        premiumTier: PremiumTier(json["premium_tier"].getInt()),
        preferredLocale: json["preferred_locale"].getStr(),
        publicUpdatesChannelID: getIDFromJson(json["public_updates_channel_id"].getStr())
    )

    # Parse all non guaranteed fields
    if (json.contains("owner")):
        g.owner = json["owner"].getBool()
    if (json.contains("owner_id")):
        g.ownerID = getIDFromJson(json["owner_id"].getStr())
    #TODO: permissions
    if (json.contains("widget_enabled")):
        g.widgetEnabled = json["widget_enabled"].getBool()
    if (json.contains("widget_channel_id")):
        g.widgetChannelID = getIDFromJson(json["widget_channel_id"].getStr())
    if (json.contains("large")):
        g.large = json["large"].getBool()
    if (json.contains("unavailable")):
        g.unavailable = json["unavailable"].getBool()
    if (json.contains("member_count")):
        g.memberCount = json["member_count"].getInt()
    #TODO: voice_states
    if (json.contains("members")):
        for member in json["members"]:
            g.members.insert(newGuildMember(member))
    if (json.contains("channels")):
        for channel in json["channels"]:
            g.channels.insert(newChannel(channel))
    #TODO: presences
    if (json.contains("max_presences")):
        g.maxPresences = json["max_presences"].getInt()
    if (json.contains("max_members")):
        g.maxMembers = json["max_members"].getInt()
    if (json.contains("premium_subscription_count")):
        g.premiumSubscriptionCount = json["premium_subscription_count"].getInt()
    if (json.contains("max_video_channel_users")):
        g.maxVideoChannelUsers = json["max_video_channel_users"].getInt()
    if (json.contains("approximate_member_count")):
        g.approximateMemberCount = json["approximate_member_count"].getInt()
    if (json.contains("approximate_presence_count")):
        g.approximatePresenceCount = json["approximate_presence_count"].getInt()

    return g
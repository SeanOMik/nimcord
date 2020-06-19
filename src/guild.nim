import json, discordobject, channel, member, options, nimcordutils, emoji, role, permission, httpcore

type 
    VerificationLevel* = enum
        ## Verification level required for the guild.
        verifLevelNone = 0,
        verifLevelLow = 1,
        verifLevelMedium = 2,
        verifLevelHigh = 3,
        verifLevelVeryHigh = 4

    MFALevel* = enum
        ## The required MFA level for the guild.
        mfaLevelNone = 0,
        mfaLevelElevated = 1

    PremiumTier* = enum
        ## Guild boost level
        premTierNone = 0,
        prermTierOne = 1,
        premTierTwo = 2,
        premTierThree = 3

    MessageNotificationsLevel* = enum
        ## Default message notifications level
        msgNotifLevelAll = 0,
        msgNotifLevelMentions = 1

    ExplicitContentFilterLevel * = enum
        ## Guild explicit content filter level
        expFilterLvlDisabled = 0,
        expFilterLvlMembersWithoutRoles = 1,
        expFilterLvlAllMembers = 2

    Guild* = ref object of DiscordObject
        ## Discord Guild object
        name*: string
        icon*: string
        splash*: string
        discoverySplash*: string
        owner*: bool
        ownerID: snowflake
        permissions*: Permissions
        region*: string
        afkChannelID*: snowflake
        afkTimeout*: int
        verificationLevel*: VerificationLevel
        defaultMessageNotifications*: MessageNotificationsLevel
        explicitContentFilter*: ExplicitContentFilterLevel
        roles*: seq[Role]
        emojis*: seq[Emoji]
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
    ## Parses a Guild type from json.
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
    if (json.contains("permissions")):
        g.permissions = newPermissions(json["permissions"])
    for role in json["roles"]:
        g.roles.add(newRole(role))
    for emoji in json["emojis"]:
        g.emojis.add(newEmoji(emoji))
    #TODO features
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

proc createGuild*(name: string, region: Option[string], icon: Option[string], verificationLevel: Option[VerificationLevel],
    defaultMessageNotifications: Option[MessageNotificationsLevel], explicitContentFilter: Option[ExplicitContentFilterLevel],
    roles: Option[seq[Role]], channels: Option[seq[Channel]], afkChannelID: Option[snowflake], afkTimeout: Option[int],
    systemChannelID: Option[snowflake]): Guild =
    ## Create a new guild.
    ## 
    ## Some restraints/notes for this endpoint:
    ## * When using the roles parameter, the first member of the array is used 
    ##   to change properties of the guild's @everyone role. If you are trying to 
    ##   bootstrap a guild with additional roles, keep this in mind.
    ## * When using the roles parameter, the required id field within each role object
    ##   is an integer placeholder, and will be replaced by the API upon consumption.
    ##   Its purpose is to allow you to overwrite a role's permissions in a channel when 
    ##   also passing in channels with the channels array.
    ## * When using the channels parameter, the position field is ignored, and none of the 
    ##   default channels are created.
    ## * When using the channels parameter, the id field within each channel object may be 
    ##   set to an integer placeholder, and will be replaced by the API upon consumption. 
    ##   Its purpose is to allow you to create GUILD_CATEGORY channels by setting the parent_id 
    ##   field on any children to the category's id field. Category channels must be listed 
    ##   before any children.

    var json = %* {"name": name}

    if (region.isSome):
        json.add("region", %region.get())
    if (icon.isSome):
        json.add("icon", %icon.get())
    if (verificationLevel.isSome):
        json.add("verification_level", %ord(verificationLevel.get()))
    if (defaultMessageNotifications.isSome):
        json.add("default_message_notifications", %ord(defaultMessageNotifications.get()))
    if (explicitContentFilter.isSome):
        json.add("explicit_content_filter", %ord(explicitContentFilter.get()))
    if (roles.isSome):
        #json.add("verification_level", %ord(verificationLevel.get()))
        var rolesJson = parseJson("[]")
        for role in roles.get():
            let roleJson = %*{
                "name": role.name,
                "color": role.color,
                "hoist": role.hoist,
                "position": role.position,
                "permissions": role.permissions.allowPerms,
                "managed": role.managed,
                "mentionable": role.mentionable
            }
            rolesJson.add(roleJson)

        json.add("channels", rolesJson)
    if (channels.isSome):
        var channelsJson = parseJson("[]")
        for channel in channels.get():
            var channelJson = %*{
                "type": channel.`type`,
                "position": channel.position,
                "name": channel.name,
                "topic": channel.topic,
                "nsfw": channel.nsfw,
                "user_limit": channel.userLimit,
                "rate_limit_per_user": channel.rateLimitPerUser,
                "parent_id": channel.parentID
            }

            if (channel.permissionOverwrites.len != 0):
                channelsJson.add("permission_overwrites", parseJson("[]"))
                for permOverwrite in channel.permissionOverwrites:
                    channelsJson["permission_overwrites"].add(permOverwrite.permissionsToJson())

            channelsJson.add(channelJson)

        json.add("channels", channelsJson)
    if (afkChannelID.isSome):
        json.add("afk_channel_id", %ord(afkChannelID.get()))
    if (afkTimeout.isSome):
        json.add("afk_timeout", %ord(afkTimeout.get()))
    if (systemChannelID.isSome):
        json.add("system_channel_id", %ord(systemChannelID.get()))

    return newGuild(sendRequest(endpoint("/guilds"), HttpPost, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        0, RateLimitBucketType.global, json))
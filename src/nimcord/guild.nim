import json, discordobject, channel, member, options, nimcordutils, emoji 
import role, permission, httpcore, strformat, image, asyncdispatch, user
import permission, presence, tables

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

    GuildFeature* = enum
        ## Guild's features. This enum is used as constants for the user.
        ## For guild feature explainations go [here](https://discord.com/developers/docs/resources/guild#guild-object-guild-features)
        featureInviteSplash = "INVITE_SPLASH",
        featureVipRegions = "VIP_REGIONS",
        featureVanityUrl = "VANITY_URL",
        featureVerifiedPartnered = "PARTNERED",
        featurePublic = "PUBLIC",
        featureCommerce = "COMMERCE",
        featureNews = "NEWS",
        featureDiscoverable = "DISCOVERABLE",
        featureFeaturable = "FEATURABLE",
        featureAnimatedIcon = "ANIMATED_ICON",
        featureBanner = "BANNER",
        featurePublicDisabled = "PUBLIC_DISABLED",
        featureWelcomeScreenEnabled = "WELCOME_SCREEN_ENABLED"

    VoiceState* = ref object
        ## Used to represent a user's voice connection status
        guildID*: Snowflake
        channelID*: Snowflake
        userID*: Snowflake
        member*: GuildMember
        sessionID*: string
        deaf*: bool
        mute*: bool
        selfDeaf*: bool
        selfMute*: bool
        selfStream*: bool
        suppress*: bool

    Guild* = ref object of DiscordObject
        ## Discord Guild object
        name*: string ## The name of the current guild
        icon*: string ## The hash of the current guild's icon
        splash*: string ## The hash of the current guild's splash
        discoverySplash*: string 
        owner*: bool ## Whether or not the current user is the owner of the current guild
        ownerID: Snowflake ## The snowflake id of the current guild's owner
        permissions*: Permissions 
        region*: string ## The region of the current guild
        afkChannelID*: Snowflake ## The afk voice channel of the current guild
        afkTimeout*: int ## The afk timeout of the current guild
        verificationLevel*: VerificationLevel ## The verification level of the current guild
        defaultMessageNotifications*: MessageNotificationsLevel ## The message notification level of the current guild
        explicitContentFilter*: ExplicitContentFilterLevel ## The explicit content filter level of the current guild
        roles*: seq[Role] ## The role list of the current guild
        emojis*: seq[Emoji] ## The emoji list of the current guild
        features*: seq[string] 
        mfaLevel*: MFALevel ## Whether or not ADMIN permission requires multi-factor authentication
        applicationID*: Snowflake 
        widgetEnabled*: bool
        widgetChannelID*: Snowflake
        systemChannelID*: Snowflake ## The system channel id of the current guild
        systemChannelFlags*: int
        rulesChannelID*: Snowflake
        joinedAt*: string
        large*: bool
        unavailable*: bool ## Whether or not the current guild is unavailable 
        memberCount*: int ## The approximate membercount of the current guild (sent by discord)
        voiceStates*: seq[VoiceState] 
        members*: seq[GuildMember] ## The member list of the current guild 
        channels*: seq[Channel] ## The channel list of the current guild
        #presences*: seq[Presence] 
        maxPresences*: int ## The maximum amount of presences in the current guild
        maxMembers*: int ## The maximum amount of members in the current guild?
        vanityUrlCode*: string ## The vanity invite for the current guild (ex: https://discord.gg/discord-api)
        description*: string
        banner*: string ## The hash code of the current guild
        premiumTier*: PremiumTier
        premiumSubscriptionCount*: int
        preferredLocale*: string
        publicUpdatesChannelID*: Snowflake
        maxVideoChannelUsers*: int
        approximateMemberCount*: int
        approximatePresenceCount*: int

    GuildPreview* = ref object of DiscordObject
        ## Represents a guild review.
        name*: string
        icon*: string
        splash*: string
        discoverySplash*: string
        emojis*: seq[Emoji]
        features*: seq[string]
        approximateMemberCount*: int
        approximatePresenceCount*: int
        description*: string

    GuildBan* = ref object
        ## A guild ban.
        reason*: string ## The reason the user was banned
        user*: User ## The user object that was banned

    VoiceRegion* = ref object
        ## Voice region.
        id*: string
        name*: string
        vip*: bool
        optimal*: bool
        deprecated*: bool
        custom*: bool

    IntegrationExpireBehavior* = enum
        intExpireBehRemoveRole = 0,
        intExpireBehKick = 1

    IntegrationAccount* = ref object
        id*: string
        name*: string

    Integration* = ref object of DiscordObject
        name*: string
        `type`*: string ## Integration type (twitch, youtube, etc)
        enabled*: bool
        syncing*: bool
        roleID*: Snowflake
        enableEmoticons*: bool
        expireBehavior*: IntegrationExpireBehavior
        expireGracePeriod*: int
        user*: User
        account*: IntegrationAccount
        syncedAt*: string

    GuildWidget* = ref object
        enabled*: bool
        channelID*: Snowflake

    GuildWidgetStyle* = enum
        guildWidgetStyleShield = "shield",
        guildWidgetStyleBanner1 = "banner1",
        guildWidgetStyleBanner2 = "banner2",
        guildWidgetStyleBanner3 = "banner3",
        guildWidgetStyleBanner4 = "banner4"


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
    if json.contains("owner"):
        g.owner = json["owner"].getBool()
    if json.contains("permissions"):
        g.permissions = newPermissions(json["permissions"])
    for role in json["roles"]:
        g.roles.add(newRole(role, g.id))
    for emoji in json["emojis"]:
        g.emojis.add(newEmoji(emoji, g.id))
    for feature in json["features"]:
        g.features.add(feature.getStr())
    if json.contains("widget_enabled"):
        g.widgetEnabled = json["widget_enabled"].getBool()
    if json.contains("widget_channel_id"):
        g.widgetChannelID = getIDFromJson(json["widget_channel_id"].getStr())
    if json.contains("large"):
        g.large = json["large"].getBool()
    if json.contains("unavailable"):
        g.unavailable = json["unavailable"].getBool()
    if json.contains("member_count"):
        g.memberCount = json["member_count"].getInt()
    if json.contains("voice_states"):
        for voicestate in json["voice_states"]:
            var state = VoiceState(
                guildID: g.id,
                channelID: getIDFromJson(voicestate["channel_id"].getStr()),
                userID: getIDFromJson(voicestate["user_id"].getStr()),
                sessionID: voicestate["session_id"].getStr(),
                deaf: voicestate["deaf"].getBool(),
                mute: voicestate["mute"].getBool(),
                selfDeaf: voicestate["self_deaf"].getBool(),
                selfMute: voicestate["self_mute"].getBool(),
                selfStream: voicestate{"self_stream"}.getBool(),
                suppress: voicestate["suppress"].getBool()
            )

            if voicestate.contains("member"):
                state.member = newGuildMember(voicestate["member"], g.id)

            g.voiceStates.add(state)
    if json.contains("members"):
        for member in json["members"]:
            g.members.insert(newGuildMember(member, g.id))
    if json.contains("channels"):
        for channel in json["channels"]:
            g.channels.insert(newChannel(channel))
    if json.contains("presences"):
        # Parse all presences
        var tmpPresences = initTable[Snowflake, Presence]()
        for presence in json["presences"]:
            tmpPresences.add(getIDFromJson(presence["user"]["id"].getStr()), newPresence(presence))

        # Check if the `tmpPresences` variable has a presence for the member,
        # if it does, then update the member to include its presence.
        for member in g.members:
            if tmpPresences.hasKey(member.user.id):
                member.presence = tmpPresences[member.user.id]

    if json.contains("max_presences"):
        g.maxPresences = json["max_presences"].getInt()
    if json.contains("max_members"):
        g.maxMembers = json["max_members"].getInt()
    if json.contains("premium_subscription_count"):
        g.premiumSubscriptionCount = json["premium_subscription_count"].getInt()
    if json.contains("max_video_channel_users"):
        g.maxVideoChannelUsers = json["max_video_channel_users"].getInt()
    if json.contains("approximate_member_count"):
        g.approximateMemberCount = json["approximate_member_count"].getInt()
    if json.contains("approximate_presence_count"):
        g.approximatePresenceCount = json["approximate_presence_count"].getInt()

    return g

proc createGuild*(name: string, region: Option[string], icon: Option[string], verificationLevel: Option[VerificationLevel],
    defaultMessageNotifications: Option[MessageNotificationsLevel], explicitContentFilter: Option[ExplicitContentFilterLevel],
    roles: Option[seq[Role]], channels: Option[seq[Channel]], afkChannelID: Option[Snowflake], afkTimeout: Option[int],
    systemChannelID: Option[Snowflake]): Guild =
    ## Create a new guild.
    ## 
    ## Some restraints/notes for this endpoint:
    ## * This endpoint is only available with bots that are in less than 10 guilds.
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

    if region.isSome:
        json.add("region", %region.get())
    if icon.isSome:
        json.add("icon", %icon.get())
    if verificationLevel.isSome:
        json.add("verification_level", %ord(verificationLevel.get()))
    if defaultMessageNotifications.isSome:
        json.add("default_message_notifications", %ord(defaultMessageNotifications.get()))
    if explicitContentFilter.isSome:
        json.add("explicit_content_filter", %ord(explicitContentFilter.get()))
    if roles.isSome:
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
    if channels.isSome:
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

            if channel.permissionOverwrites.len != 0:
                channelsJson.add("permission_overwrites", parseJson("[]"))
                for permOverwrite in channel.permissionOverwrites:
                    channelsJson["permission_overwrites"].add(permOverwrite.permissionsToJson())

            channelsJson.add(channelJson)

        json.add("channels", channelsJson)
    if afkChannelID.isSome:
        json.add("afk_channel_id", %ord(afkChannelID.get()))
    if afkTimeout.isSome:
        json.add("afk_timeout", %ord(afkTimeout.get()))
    if systemChannelID.isSome:
        json.add("system_channel_id", %ord(systemChannelID.get()))

    return newGuild(sendRequest(endpoint("/guilds"), HttpPost, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        0, RateLimitBucketType.global, json))

proc getGuildPreview*(guild: Guild): GuildPreview =
    ## Returns the guild preview object for the given id, even if the user is not in the guild.
    ## Only available for public guilds!
    let json = sendRequest(endpoint(fmt("/guilds/{guild.id}/preview")), HttpPost, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        guild.id, RateLimitBucketType.guild)

    result = GuildPreview(
        id: getIDFromJson(json["id"].getStr()),
        name: json["name"].getStr(),
        icon: json["icon"].getStr(),
        splash: json["splash"].getStr(),
        discoverySplash: json["discovery_splash"].getStr(),
        approximateMemberCount: json["approximate_member_count"].getInt(),
        approximatePresenceCount: json["approximate_presence_count"].getInt(),
        description: json["description"].getStr()
    )

    for emoji in json["emojis"]:
        result.emojis.add(newEmoji(emoji, guild.id))

    for feature in json["features"]:
        result.features.add(feature.getStr())

type GuildModify* = ref object
    ## Use this type to modify a guild by setting each fields.
    name*: Option[string]
    region*: Option[string]
    verificationLevel*: Option[VerificationLevel]
    defaultMessageNotifications*: Option[MessageNotificationsLevel]
    explicitContentFilter*: Option[ExplicitContentFilterLevel]
    afkChannelID*: Option[Snowflake]
    afkTimeout*: Option[int]
    icon*: Option[Image]
    ownerID*: Option[Snowflake]
    splash*: Option[Image]
    banner*: Option[Image]
    systemChannelID*: Option[Snowflake]
    rulesChannelID*: Option[Snowflake]
    publicUpdatesChannelID*: Option[Snowflake]
    preferredLocale*: Option[string]

proc modifyGuild*(guild: Guild, modify: GuildModify): Future[Guild] {.async.} =
    ## Modifies the Guild.
    ## 
    ## Examples:
    ##
    ## .. code-block:: nim
    ##   var guild = getGuild(703084913510973472)
    ##   guild = guild.modifyGuild(GuildModify(name: some("Epic Gamer Guild")))
    
    var modifyPayload = %*{}

    if modify.name.isSome:
        modifyPayload.add("name", %modify.name.get())
    
    if modify.region.isSome:
        modifyPayload.add("region", %modify.region.get())
    
    if modify.verificationLevel.isSome:
        modifyPayload.add("verification_level", %modify.verificationLevel.get())

    if modify.defaultMessageNotifications.isSome:
        modifyPayload.add("default_message_notifications", %modify.defaultMessageNotifications.get())

    if modify.explicitContentFilter.isSome:
        modifyPayload.add("explicit_content_filter", %modify.explicitContentFilter.get())

    if modify.afkChannelID.isSome:
        modifyPayload.add("afk_channel_id", %modify.afkChannelID.get())

    if modify.afkTimeout.isSome:
        modifyPayload.add("afk_timeout", %modify.afkTimeout.get())

    if modify.icon.isSome:
        modifyPayload.add("icon", %modify.icon.get().imageToDataURI())

    if modify.ownerID.isSome:
        modifyPayload.add("owner_id", %modify.ownerID.get())

    if modify.splash.isSome:
        modifyPayload.add("splash", %modify.splash.get().imageToDataURI())

    if modify.banner.isSome:
        modifyPayload.add("banner", %modify.banner.get().imageToDataURI())

    if modify.systemChannelID.isSome:
        modifyPayload.add("system_channel_id", %modify.systemChannelID.get())

    if modify.rulesChannelID.isSome:
        modifyPayload.add("rules_channel_id", %modify.rulesChannelID.get())

    if modify.publicUpdatesChannelID.isSome:
        modifyPayload.add("public_updates_channel_id", %modify.publicUpdatesChannelID.get())
    
    if modify.preferredLocale.isSome:
        modifyPayload.add("preferred_locale", %modify.preferredLocale.get())

    return newGuild(sendRequest(endpoint("/guilds/" & $guild.id), HttpPatch, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        guild.id, RateLimitBucketType.guild, modifyPayload))

proc deleteGuild*(guild: Guild) {.async.} =
    ## Delete the guild. The bot must be the owner of the guild!
    discard sendRequest(endpoint("/guilds/" & $guild.id), HttpDelete, 
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

proc requestGuildChannels*(guild: var Guild): seq[Channel] =
    ## Request all guild channels via Discord's REST API
    ## Only use this if for some reason, guild.channels is inaccurate!
    ## 
    ## Also updates the guild's channels when called.
    let json = sendRequest(endpoint("/guilds/" & $guild.id & "/channels"), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

    for channel in json:
        result.add(newChannel(channel))
    guild.channels = result

proc createGuildChannel*(guild: var Guild, create: ChannelFields): Future[Channel] {.async.} =
    ## Creates a new guild channel.
    ## The name field must be set, if you dont a `Defect` exception will be raised.
    ## The created channel will be added to the guild's `channels` field.
    ## 
    ## Examples:
    ##
    ## .. code-block:: nim
    ##   let guild = getGuild(703084913510973472)
    ##   let channel = waitFor guild.createGuildChannel(ChannelFields(name: some("Epic Gamer Channel")))

    var createPayload = %*{}

    # Make sure that the name is supplied since its required for this endpoint.
    if create.name.isSome:
        createPayload.add("name", %create.name.get())
    else:
        raise newException(Defect, "You must have a channel name when creating it!")

    if create.`type`.isSome:
        createPayload.add("type", %create.`type`.get())

    if create.position.isSome:
        createPayload.add("position", %create.position.get())

    if create.topic.isSome:
        createPayload.add("topic", %create.topic.get())

    if create.nsfw.isSome:
        createPayload.add("nsfw", %create.nsfw.get())

    if create.rateLimitPerUser.isSome:
        createPayload.add("rate_limit_per_user", %create.rateLimitPerUser.get())

    if create.bitrate.isSome:
        createPayload.add("bitrate", %create.bitrate.get())

    if create.userLimit.isSome:
        createPayload.add("user_limit", %create.userLimit.get())

    if create.permissionOverwrites.isSome:
        var permOverwrites = parseJson("[]")
        for perm in create.permissionOverwrites.get():
            permOverwrites.add(perm.permissionsToJson())
        createPayload.add("permission_overwrites", permOverwrites)

    result = newChannel(sendRequest(endpoint("/guilds/" & $guild.id & "/channels"), HttpPost, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        guild.id, RateLimitBucketType.guild, createPayload))

proc modifyGuildChannelPositions*(guild: var Guild, channels: seq[Channel]) {.async.} =
    ## Modify the positions of a set of channel objects for the guild.
    ## The order is determined by the channel's `position` field
     
    var jsonBody: JsonNode
    for channel in channels:
        jsonBody.add(%*{"id": channel.id, "position": channel.position})

    discard sendRequest(endpoint("/guilds/" & $guild.id & "/channels"), HttpPatch, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        guild.id, RateLimitBucketType.guild, jsonBody)

proc getGuildMember*(guild: var Guild, memberID: Snowflake): GuildMember =
    ## Get a guild member.
    ## This first checks `guild.members`, but if it doesn't exist there,
    ## it will be requested from Discord's REST API.
    ## 
    ## If we end up requesting one, it will add it to `guild.members`
    
    for member in guild.members:
        if member.id == memberID:
            return member

    result = newGuildMember(sendRequest(endpoint(fmt("/guilds/{guild.id}/members/{memberID}")), 
        HttpGet, defaultHeaders(), guild.id, RateLimitBucketType.guild), guild.id)
    guild.members.add(result)

# Would this endpoint be worth adding? https://discord.com/developers/docs/resources/guild#list-guild-members
# And what about this one? https://discord.com/developers/docs/resources/guild#list-guild-members

proc modifyCurrentUserNick*(guild: Guild, nick: string) {.async.} =
    ## Modifies the nickname of the current user in a guild.
    discard sendRequest(endpoint(fmt("/guilds/{guild.id}/members/@me/nick")), HttpPatch,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        guild.id, RateLimitBucketType.guild, %*{"nick": nick})

proc kickGuildMember*(guild: Guild, member: GuildMember) {.async.} =
    ## Remove a member from a guild. Requires `KICK_MEMBERS` permission.
    discard sendRequest(endpoint(fmt("/guilds/{guild.id}/members/{member.id}")), HttpDelete,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

proc getGuildBans*(guild: Guild): seq[GuildBan] =
    ## Get a list of guild bans. Requires the `BAN_MEMBERS` permission.
    let json = sendRequest(endpoint(fmt("/guilds/{guild.id}/bans")), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

    for ban in json:
        result.add(GuildBan(
            reason: json{"reason"}.getStr(),
            user: newUser(json["user"])
        ))

proc getGuildBan*(guild: Guild, userID: Snowflake): GuildBan =
    ## Returns a ban object for the given user or nil if the ban cannot be found. 
    ## Requires the BAN_MEMBERS permission.
    let response = sendRequest(endpoint(fmt("/guilds/{guild.id}/bans{userID}")), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

    if not response.isNil():
        return GuildBan(
            reason: response{"reason"}.getStr(),
            user: newUser(response["user"])
        )
    else:
        return nil

proc banGuildMember*(guild: Guild, userID: Snowflake, reason: Option[string] = none(string), deleteMessageDays: Option[int] = none(int)) {.async.} =
    ## Create a guild ban, and optionally delete previous messages sent by the
    ## banned user. Requires the BAN_MEMBERS permission.
    
    var jsonBody: JsonNode

    if reason.isSome:
        jsonBody.add("reason", %reason.get())
    if deleteMessageDays.isSome:
        jsonBody.add("deleteMessageDays", %deleteMessageDays.get())

    discard sendRequest(endpoint(fmt("/guilds/{guild.id}/bans/{userID}")), HttpPut,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        guild.id, RateLimitBucketType.guild, jsonBody)

proc unbanGuildMember*(guild: Guild, userID: Snowflake) {.async.} =
    ## Remove the ban for a user. Requires the BAN_MEMBERS permissions. 
    discard sendRequest(endpoint(fmt("/guilds/{guild.id}/bans/{userID}")), HttpDelete,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

proc requestGuildRoles*(guild: Guild): seq[Role] =
    ## Request all guild roles via Discord's REST API
    ## Only use this if for some reason, guild.roles is inaccurate!
    ## 
    ## Also updates the guild's roles when called.
    
    let jsonBody = sendRequest(endpoint(fmt("/guilds/{guild.id}/roles")), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)
    
    for role in jsonBody:
        result.add(newRole(role, guild.id))
    guild.roles = result

proc createGuildRole*(guild: Guild, name: Option[string] = none(string), permissions: Option[Permissions] = none(Permissions),
    color: Option[int] = none(int), hoist: Option[bool] = none(bool), mentionable: Option[bool] = none(bool)): Future[Role] {.async.} =
    ## Create a new role for the guild. Requires the `MANAGE_ROLES` permission.
    ## 
    ## Example:
    ## 
    ## .. code-block:: nim
    ##   discard guild.createGuildRole(name = some("Gamer Role"), color = some(0xff0000))
    
    var jsonBody: JsonNode

    if name.isSome:
        jsonBody.add("name", %name)

    if permissions.isSome:
        jsonBody.add("permissions", %permissions.get().allowPerms)

    if color.isSome:
        jsonBody.add("color", %color)

    if hoist.isSome:
        jsonBody.add("hoist", %hoist)

    if mentionable.isSome:
        jsonBody.add("mentionable", %mentionable)

    return newRole(sendRequest(endpoint(fmt("/guilds/{guild.id}/roles")), HttpPost,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        guild.id, RateLimitBucketType.guild, jsonBody), guild.id)

proc modifyGuildRolePositions*(guild: var Guild, roles: seq[Role]) {.async.} =
    ## Modify the positions of a set of role objects for the guild.
    ## The order is determined by the role's `position` field
     
    var jsonBody: JsonNode
    for role in roles:
        jsonBody.add(%*{"id": role.id, "position": role.position})

    discard sendRequest(endpoint("/guilds/" & $guild.id & "/roles"), HttpPatch, 
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})), 
        guild.id, RateLimitBucketType.guild, jsonBody)

proc getGuildPruneCount*(guild: Guild, days: int = 7, includedRoles: seq[Snowflake]): int =
    ## Returns the number of members that would be removed in a prune operation. 
    ## Requires the `KICK_MEMBERS` permission.
    ## 
    ## By default, prune will not remove users with roles. You can optionally include 
    ## specific roles in your prune by providing the `includedRoles` parameter. Any 
    ## inactive user that has a subset of the provided role(s) will be counted in 
    ## the prune and users with additional roles will not.
    var url = endpoint(fmt("/guilds/{guild.id}/prune"))

    if days != 7:
        url &= "?days=" & $days

    if includedRoles.len != 0:
        # If the days field was also set, then we need to ad "&" to the url.
        if days != 7:
            url &= "&"
        url &= "include_roles=" & ($includedRoles).substr(1)

    let jsonBody = sendRequest(url, HttpGet, defaultHeaders(), guild.id, RateLimitBucketType.guild)
    return jsonBody["pruned"].getInt()

proc beginGuildPrune*(guild: Guild, days: int = 7, computePruneCount: bool = false, includedRoles: seq[Snowflake]): Future[Option[int]] {.async.} =
    ## Returns the number of members that would be removed in a prune operation. 
    ## Requires the `KICK_MEMBERS` permission.
    ## 
    ## If you specify `computePruneCount` the proc will return the amount of users
    ## that were pruned. Not recommended on large guilds!
    ## 
    ## By default, prune will not remove users with roles. You can optionally include 
    ## specific roles in your prune by providing the `includedRoles` parameter. Any 
    ## inactive user that has a subset of the provided role(s) will be counted in 
    ## the prune and users with additional roles will not.
    var url = endpoint(fmt("/guilds/{guild.id}/prune"))

    if days != 7:
        url &= "?days=" & $days

    if includedRoles.len != 0:
        # If the days field was also set, then we need to add "&" to the url.
        if days != 7:
            url &= "&"
        url &= "include_roles=" & ($includedRoles).substr(1)
    
    if computePruneCount:
        # If the days or includedRoles field was also set, then we need to add "&" to the url.
        if days != 7 or includedRoles.len != 0:
            url &= "&"
        url &= "compute_prune_count=" & $computePruneCount

    let jsonBody = sendRequest(url, HttpGet, defaultHeaders(), guild.id, RateLimitBucketType.guild)

    if computePruneCount:
        return some(jsonBody["pruned"].getInt())

proc getGuildVoiceRegions*(guild: Guild): seq[VoiceRegion] =
    ## Returns a list of voice region objects for the guild.
    let jsonBody = sendRequest(endpoint(fmt("/guilds/{guild.id}/regions")), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

    for voiceRegion in jsonBody:
        result.add(VoiceRegion(
            id: jsonBody["id"].getStr(),
            name: jsonBody["name"].getStr(),
            vip: jsonBody["vip"].getBool(),
            optimal: jsonBody["optimal"].getBool(),
            deprecated: jsonBody["deprecated"].getBool(),
            custom: jsonBody["custom"].getBool()
        ))

proc getGuildInvites*(guild: Guild): seq[Invite] =
    ## Returns a list of invite objects (with invite metadata) for the guild. 
    ## Requires the `MANAGE_GUILD` permission.
    let jsonBody = sendRequest(endpoint(fmt("/guilds/{guild.id}/invites")), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

    for invite in jsonBody:
        result.add(newInvite(invite))

proc getGuildIntegrations*(guild: Guild): seq[Integration] =
    ## Returns a list of integration objects for the guild. Requires the `MANAGE_GUILD` permission.
    let jsonBody = sendRequest(endpoint(fmt("/guilds/{guild.id}/integrations")), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

    for integration in jsonBody:
        result.add(Integration(
            id: getIDFromJson(jsonBody["id"].getStr()),
            name: jsonBody["name"].getStr(),
            `type`: jsonBody["type"].getStr(),
            enabled: jsonBody["enabled"].getBool(),
            syncing: jsonBody["syncing"].getBool(),
            roleID: getIDFromJson(jsonBody["role_id"].getStr()),
            enableEmoticons: jsonBody["enable_emoticons"].getBool(),
            expireBehavior: IntegrationExpireBehavior(jsonBody["expire_behavior"].getInt()),
            expireGracePeriod: jsonBody{"expire_grace_period"}.getInt(),
            user: newUser(jsonBody["user"]),
            account: IntegrationAccount(
                id: jsonBody["account"]["id"].getStr(),
                name: jsonBody["account"]["name"].getStr(),
            ),
            syncedAt: jsonBody["synced_at"].getStr()
        ))

proc createGuildIntegration*(guild: Guild, `type`: string, id: string) {.async.} =
    ## Attach an integration object from the current user to the guild. Requires the `MANAGE_GUILD` permission.
    let jsonBody = %* {
        "type": `type`,
        "id": id
    }

    discard sendRequest(endpoint("/guilds/" & $guild.id & "/integrations"), HttpPost,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        guild.id, RateLimitBucketType.guild, jsonBody)

proc modifyGuildIntegration*(guild: Guild, integration: var Integration, 
    expireBehavior: Option[IntegrationExpireBehavior] = none(IntegrationExpireBehavior), 
    expireGracePeriod: Option[int] = none(int), enableEmoticons: Option[bool] = none(bool)) {.async.} =
    ## Modify the behavior and settings of an integration object for the guild. Requires the `MANAGE_GUILD` permission.
    ## 
    ## The changes are reflected to the given `integration`.
    ## 
    ## Example:
    ## 
    ## .. code-block:: nim
    ##   discard integration.modifyGuildIntegration(enable_emoticons = true)
    var modifyPayload = %*{}

    if expireBehavior.isSome:
        modifyPayload.add("expire_behavior", %expireBehavior.get())
        integration.expireBehavior = (expireBehavior.get())

    if expireGracePeriod.isSome:
        modifyPayload.add("expire_grace_period", %expireGracePeriod.get())
        integration.expireGracePeriod = expireGracePeriod.get()

    if enableEmoticons.isSome:
        modifyPayload.add("enable_emoticons", %enableEmoticons.get())
        integration.enableEmoticons = enableEmoticons.get()

    discard sendRequest(endpoint(fmt("/guilds/{guild.id}/integration/{integration.id}")), HttpPatch,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        guild.id, RateLimitBucketType.guild, modifyPayload)

proc deleteGuildIntegration*(guild: Guild, integration: Integration) {.async.} =
    ## Delete the attached integration object for the guild. Requires the `MANAGE_GUILD` permission.
    discard sendRequest(endpoint(fmt("/guilds/{guild.id}/integrations/{integration.id}")), HttpDelete,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

proc syncGuildIntegration*(guild: Guild, integration: Integration) {.async.} =
    ## Sync an integration. Requires the `MANAGE_GUILD` permission.
    discard sendRequest(endpoint(fmt("/guilds/{guild.id}/integrations/{integration.id}")), HttpPost,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

proc getGuildWidget*(guild: Guild): GuildWidget =
    ## Returns the guild widget object. Requires the `MANAGE_GUILD` permission.

    let jsonBody = sendRequest(endpoint(fmt("/guilds/{guild.id}/widget")), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

    return GuildWidget(enabled: jsonBody["enabled"].getBool(), 
        channelID: getIDFromJson(jsonBody{"channel_id"}.getStr()))

proc modifyGuildWidget*(guild: Guild, widget: var GuildWidget, enabled: bool, channelID: Snowflake) {.async.} =
    ## Modify a guild widget object for the guild. Requires the `MANAGE_GUILD` permission.
    widget.enabled = enabled
    widget.channelID = channelID

    let jsonBody = %* {
        "enabled": enabled,
        "channelID": channelID
    }

    discard sendRequest(endpoint(fmt("/guilds/{guild.id}/widget")), HttpPost,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        guild.id, RateLimitBucketType.guild, jsonBody)

proc getGuildVanityURL*(guild: Guild): Invite =
    ## Returns a partial invite object for guilds with that feature enabled. Requires the `MANAGE_GUILD` permission.
    return newInvite(sendRequest(endpoint(fmt("/guilds/{guild.id}/vanity-url")), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild))

proc getGuildWidgetImage*(guild: Guild, style: GuildWidgetStyle): string =
    ## Returns a url to this guild's widget image.
    ## 
    ## Style types:
    ## * Shield: Shield style widget with Discord icon and guild members 
    ##   online count. [Example](https://discord.com/api/guilds/81384788765712384/widget.png?style=shield)
    ## * Banner 1: Large image with guild icon, name and online count. 
    ##   "POWERED BY DISCORD" as the footer of the widget. [Example](https://discord.com/api/guilds/81384788765712384/widget.png?style=banner1)
    ## * Banner 2: Smaller widget style with guild icon, name and online
    ##   count. Split on the right with Discord logo. [Example](https://discord.com/api/guilds/81384788765712384/widget.png?style=banner2)
    ## * Banner 3: Large image with guild icon, name and online count. 
    ##   In the footer, Discord logo on the left and "Chat Now" on the right [Example](https://discord.com/api/guilds/81384788765712384/widget.png?style=banner3)
    ## * Banner 4: Large Discord logo at the top of the widget. Guild 
    ##   icon, name and online count in the middle portion of the widget 
    ##   and a "JOIN MY SERVER" button at the bottom. [Example](https://discord.com/api/guilds/81384788765712384/widget.png?style=banner4)
    result = fmt("guilds/{guild.id}/widget.png")

    case style
        of GuildWidgetStyle.guildWidgetStyleShield:
            result &= "?style=shield"
        of GuildWidgetStyle.guildWidgetStyleBanner1:
            result &= "?style=banner1"
        of GuildWidgetStyle.guildWidgetStyleBanner2:
            result &= "?style=banner2"
        of GuildWidgetStyle.guildWidgetStyleBanner3:
            result &= "?style=banner3"
        of GuildWidgetStyle.guildWidgetStyleBanner4:
            result &= "?style=banner4"

proc requestEmojis*(guild: Guild): seq[Emoji] =
    ## Request all guild emojis via Discord's REST API
    ## Only use this if, for some reason, guild.emojis is inaccurate!
    ## 
    ## Also updates the guild's emojis when called.
    let json = sendRequest(endpoint("/guilds/" & $guild.id & "/emojis"), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild)

    for emoji in json:
        result.add(newEmoji(emoji, guild.id))
    guild.emojis = result

proc getEmoji*(guild: Guild, emojiID: Snowflake): Emoji =
    ## Returns a guild's emoji with `emojiID`.
    ## If the emoji isn't found in `guild.emojis` then it will request on
    ## from the Discord REST API.
    for emoji in guild.emojis:
        if emoji.id == emojiID:
            return emoji
    
    return newEmoji(sendRequest(endpoint("/guilds/{guild.id}/emojis/{emojiID}"), HttpGet,
        defaultHeaders(), guild.id, RateLimitBucketType.guild), guild.id)

proc createEmoji*(guild: Guild, name: string, image: Image, roles: seq[Snowflake]): Future[Emoji] {.async.} =
    ## Create a new emoji for the guild. Requires the `MANAGE_EMOJIS` permission.
    var jsonBody = %* {
        "name": name,
        "image": image.imageToDataURI()
    }

    jsonBody.add(parseJson(($roles).substr(1)))

    return newEmoji(sendRequest(endpoint(fmt("/guilds/{guild.id}/emojis")), HttpPost,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        guild.id, RateLimitBucketType.guild, jsonBody), guild.id)

proc getGuildMemberRoles*(guild: Guild, member: GuildMember): seq[Role] =
    ## Get the role objects for a member's roles.
    for role in guild.roles:
        if member.roles.contains(role.id):
            result.add(role)

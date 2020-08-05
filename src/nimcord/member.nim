import discordobject, user, json, options, asyncdispatch, nimcordutils, httpcore, strformat, strutils, presence

type GuildMember* = ref object of DiscordObject
    ## This type is a guild member.
    user*: User ## The user this guild member represents.
    nick*: string ## This users guild nickname.
    roles*: seq[Snowflake] ## Array of roles.
    joinedAt*: string ## When the user joined the guild.
    premiumSince*: string ## When the user started boosting the guild.
    deaf*: bool ## Whether the user is deafened in voice channels.
    mute*: bool ## Whether the user is muted in voice channels.
    guildID*: Snowflake ## The guild this member is in.
    presence*: Presence ## The member's presence.

proc newGuildMember*(json: JsonNode, guild: Snowflake): GuildMember {.inline.} =
    ## Construct a GuildMember using json.
    result = GuildMember(
        nick: json{"nick"}.getStr(),
        #roles: seq[Role]
        joinedAt: json["joined_at"].getStr(),
        premiumSince: json{"premium_since"}.getStr(),
        deaf: json["deaf"].getBool(),
        mute: json["mute"].getBool(),
        guildID: guild
    )

    if json.contains("user"):
        result.user = newUser(json["user"])

    # Add roles
    for role in json["roles"]:
        result.roles.add(getIDFromJson(role.getStr()))
    
type GuildMemberModify* = ref object
    nick: Option[string]
    roles: Option[seq[Snowflake]]
    mute: Option[bool]
    deaf: Option[bool]
    channelID: Option[Snowflake]

proc modifyGuildMember*(member: GuildMember, memberID: Snowflake, modify: GuildMemberModify) {.async.} =
    ## Modify attributes of a guild member. If the `channel_id` is set to null, 
    ## this will force the target user to be disconnected from voice.
    ## 
    ## The member's new attributes will be reflected to `guild.members`.
    var modifyPayload = %*{}

    if modify.nick.isSome:
        modifyPayload.add("nick", %modify.nick.get())

    if modify.roles.isSome:
        # Convert the roles array to a string representation and remove the `@`
        # that is at the front of a conversion like this.
        var rolesStr = ($modify.roles.get()).substr(1)
        modifyPayload.add(parseJson(rolesStr))

    if modify.mute.isSome:
        modifyPayload.add("mute", %modify.mute.get())

    if modify.deaf.isSome:
        modifyPayload.add("deaf", %modify.deaf.get())

    if modify.channelID.isSome:
        modifyPayload.add("channel_id", %modify.channelID.get())

    discard sendRequest(endpoint(fmt("/guilds/{member.guildID}/members/{member.id}")), HttpPatch,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        member.guildID, RateLimitBucketType.guild, modifyPayload)

proc addGuildMemberRole*(member: GuildMember, roleID: Snowflake) {.async.} =
    ## Adds a role to a guild member. Requires the `MANAGE_ROLES` permission.
    discard sendRequest(endpoint(fmt("/guilds/{member.guildID}/members/{member.id}/roles/{roleID}")),
        HttpPut, defaultHeaders(), member.guildID, RateLimitBucketType.guild)

proc removeGuildMemberRole*(member: GuildMember, roleID: Snowflake) {.async.} =
    ## Remove's a role to a guild member. Requires the `MANAGE_ROLES` permission.
    discard sendRequest(endpoint(fmt("/guilds/{member.guildID}/members/{member.id}/roles/{roleID}")),
        HttpDelete, defaultHeaders(), member.guildID, RateLimitBucketType.guild)

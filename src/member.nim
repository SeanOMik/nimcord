import discordobject, user, json

type GuildMember* = object of DiscordObject
    ## This type is a guild member.
    user*: User ## The user this guild member represents.
    nick*: string ## This users guild nickname.
    #roles*: seq[Role] ## Array of roles.
    joinedAt*: string ## When the user joined the guild.
    premiumSince*: string ## When the user started boosting the guild.
    deaf*: bool ## Whether the user is deafened in voice channels.
    mute*: bool ## Whether the user is muted in voice channels.


proc newGuildMember*(memberJson: JsonNode): GuildMember {.inline.} =
    var member = GuildMember(
        nick: memberJson{"nick"}.getStr(),
        #roles: seq[Role]
        joinedAt: memberJson["joined_at"].getStr(),
        premiumSince: memberJson{"premium_since"}.getStr(),
        deaf: memberJson["deaf"].getBool(),
        mute: memberJson["mute"].getBool()
    )

    if (memberJson.contains("user")):
        member.user = newUser(memberJson["user"])

    return member
    
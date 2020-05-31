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


proc newGuildMember*(json: JsonNode): GuildMember =
    var member = GuildMember(
        nick: json["nick"].getStr(),
        #roles: seq[Role]
        joinedAt: json["joined_at"].getStr(),
        premiumSince: json["premium_since"].getStr(),
        deaf: json["deaf"].getBool(),
        mute: json["mute"].getBool()
    )
    
    if (json.contains("user")):
        member.user = newUser(json["user"])

    return member
    
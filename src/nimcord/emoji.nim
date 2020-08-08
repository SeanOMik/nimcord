import json, discordobject, nimcordutils, user, httpcore, strutils, uri, strformat, asyncdispatch

type 
    Emoji* = ref object of DiscordObject
        name*: string
        roles*: seq[Snowflake]
        user*: User
        requireColons*: bool
        managed*: bool
        animated*: bool
        available*: bool
        guildID*: Snowflake

proc newEmoji*(json: JsonNode, guild: Snowflake): Emoji =
    ## Construct an emoji with json.
    ## This shouldn't really be used by the user, only internal use.
    result = Emoji(
        name: json["name"].getStr(),
        guildID: guild
    )

    if json.contains("id"):
        result.id = getIDFromJson(json["id"].getStr())
    if json.contains("roles"):
        for role in json["roles"]:
            result.roles.add(getIDFromJson(role.getStr()))
    if json.contains("user"):
        result.user = newUser(json["user"])
    if json.contains("require_colons"):
        result.requireColons = json["require_colons"].getBool()
    if json.contains("managed"):
        result.managed = json["managed"].getBool()
    if json.contains("animated"):
        result.requireColons = json["animated"].getBool()
    if json.contains("available"):
        result.requireColons = json["available"].getBool()

proc newEmoji*(name: string, id: Snowflake): Emoji =
    ## Construct an emoji using its name, and id.
    return Emoji(name: name, id: id)

proc newEmoji*(unicode: string): Emoji =
    ## Construct an emoji from its unicode reprsentation.
    return Emoji(name: unicode)

proc `$`*(emoji: Emoji): string =
    ## Converts the emoji to a string to use in text.
    
    # Check if the emoji has a name but not id.
    # If its true, this means that the emoji is just a unicode
    # representation of the emoji.
    if emoji.id == 0 and not emoji.name.isEmptyOrWhitespace():
        return emoji.name
    else:
        result = $emoji.id & ":" & emoji.name

        # If the emoji must be wrapped in colons, wrap it!
        if emoji.requireColons:
            result = ":" & result & ":"

proc `==`*(a: Emoji, b: Emoji): bool =
    ## Check if two Emojis are equal.
    # Check if emojis have name but no id
    if a.id == 0 and b.id == 0 and a.name.isEmptyOrWhitespace() and b.name.isEmptyOrWhitespace():
        return a.name == b.name
    # Check if emoji has IDs, but no name
    elif a.id != 0 and b.id != 0 and a.name.isEmptyOrWhitespace() and b.name.isEmptyOrWhitespace():
        return a.id == b.id
    # Check if emoji has IDs, and a name
    elif a.id != 0 and b.id != 0 and not a.name.isEmptyOrWhitespace() and not b.name.isEmptyOrWhitespace():
        return $a == $b
    return false

proc toUrlEncoding*(emoji: Emoji): string =
    ## Converts the `Emoji` to be used in a url.
    ## Not needed for users, only for internal
    ## library use.
    return encodeUrl($emoji, true)

proc modifyEmoji*(emoji: var Emoji, name: string, roles: seq[Snowflake]): Future[Emoji] {.async.} =
    ## Modify the given emoji. Requires the `MANAGE_EMOJIS` permission.
    ## Changes will be reflected in given `emoji`.
    var jsonBody = %* {
        "name": name,
        "roles": parseJson(($roles).substr(1))
    }

    emoji.name = name
    emoji.roles = roles

    return newEmoji(sendRequest(endpoint(fmt("/guilds/{emoji.guildID}/emojis/{emoji.id}")), HttpPatch,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        emoji.guildID, RateLimitBucketType.guild, jsonBody), emoji.guildID)

proc deleteEmoji*(emoji: Emoji) {.async.} =
    ## Delete the given emoji. Requires the `MANAGE_EMOJIS` permission.
    discard sendRequest(endpoint(fmt("/guilds/{emoji.guildID}/emojis/{emoji.id}")), HttpDelete,
        defaultHeaders(), emoji.guildID, RateLimitBucketType.guild)

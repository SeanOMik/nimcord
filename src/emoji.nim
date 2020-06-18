import json, discordobject, nimcordutils, user, httpcore, asyncdispatch, strutils, uri

type 
    Emoji* = ref object of DiscordObject
        name*: string
        roles*: seq[snowflake]
        user*: User
        requireColons: bool
        managed: bool
        animated: bool
        available: bool

proc newEmoji*(json: JsonNode): Emoji =
    result = Emoji(
        id: getIDFromJson(json["id"].getStr()),
        name: json["name"].getStr()
    )

    if (json.contains("roles")):
        for role in json["roles"]:
            result.roles.add(getIDFromJson(role.getStr()))
    if (json.contains("user")):
        result.user = newUser(json["user"])
    if (json.contains("require_colons")):
        result.requireColons = json["require_colons"].getBool()
    if (json.contains("managed")):
        result.managed = json["managed"].getBool()
    if (json.contains("animated")):
        result.requireColons = json["animated"].getBool()
    if (json.contains("available")):
        result.requireColons = json["available"].getBool()

proc newEmoji*(name: string, id: snowflake): Emoji =
    return Emoji(name: name, id: id)

proc newEmoji*(unicode: string): Emoji =
    return Emoji(name: unicode)

proc `$`*(emoji: Emoji): string =
    ## Converts the emoji to a string to use in text.
    
    # Check if the emoji has a name but not id.
    # If its true, this means that the emoji is just a unicode
    # representation of the emoji.
    if (emoji.id == 0 and not emoji.name.isEmptyOrWhitespace()):
        return emoji.name
    else:
        result = $emoji.id & ":" & emoji.name

        # If the emoji must be wrapped in colons, wrap it!
        if emoji.requireColons:
            result = ":" & result & ":"

proc toUrlEncoding*(emoji: Emoji): string =
    ## Converts the emoji to be used in a url.
    ## Not needed for users, only for internal 
    ## library use.
    return encodeUrl($emoji, true)
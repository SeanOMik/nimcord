import json, discordobject, nimcordutils

type 
    NitroSubscription* = enum
        none = 0,
        nitroClassic = 1,
        nitro = 2

    User* = ref object of DiscordObject
        ## This type is a discord user.
        username*: string ## The user's username, not unique across the platform.
        discriminator*: cushort ## The user's 4-digit discord-tag.
        avatar*: string ## The user's avatar hash.
        bot*: bool ## Whether the user belongs to an OAuth2 application.
        system*: bool ## Whether the user is an Official Discord System user (part of the urgent message system).
        flags*: int ## The flags on a user's account.
        premiumType*: NitroSubscription ## The type of Nitro subscription on a user's account.
        publicFlags*: int ## The public flags on a user's account.

    ClientUser* = ref object of User
        mfaEnabled*: bool ## Whether the user has two factor authentication enabled on their account.
        locale*: string ## The user's chosen language option.
        verified*: bool ## Whether or not the current user has a verified email.
        email*: string ## The current user's email

proc newUser*(user: JsonNode): User {.inline.} =
    return User(
        id: getIDFromJson(user["id"].getStr()),
        username: user["username"].getStr(),
        discriminator: cushort(parseIntEasy(user["discriminator"].getStr())),
        avatar: user["avatar"].getStr(),
        bot: user{"bot"}.getBool(),
        system: user{"system"}.getBool(),
        flags: user{"flags"}.getInt(),
        premiumType: NitroSubscription(user{"premium_type"}.getInt()),
        publicFlags: user{"public_flags"}.getInt()
    )

proc newClientUser*(clientUser: JsonNode): ClientUser {.inline.} =
    return ClientUser(
        id: getIDFromJson(clientUser["id"].getStr()),
        username: clientUser["username"].getStr(),
        discriminator: cushort(parseIntEasy(clientUser["discriminator"].getStr())),
        avatar: clientUser["avatar"].getStr(),
        bot: clientUser{"bot"}.getBool(),
        system: clientUser{"system"}.getBool(),
        mfaEnabled: clientUser{"mfa_enabled"}.getBool(),
        locale: clientUser{"locale"}.getStr(),
        verified: clientUser{"verified"}.getBool(),
        email: clientUser{"email"}.getStr(),
        flags: clientUser{"flags"}.getInt(),
        premiumType: NitroSubscription(clientUser{"premium_type"}.getInt()),
        publicFlags: clientUser{"public_flags"}.getInt()
    )
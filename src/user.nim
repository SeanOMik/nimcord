import json, discordobject, nimcordutils

type 
    NitroSubscription* = enum
        none = 0,
        nitroClassic = 1,
        nitro = 2

    User* = object of DiscordObject
        ## This type is a discord user.
        username*: string ## The user's username, not unique across the platform.
        discriminator*: cushort ## The user's 4-digit discord-tag.
        avatar*: string ## The user's avatar hash.
        bot*: bool ## Whether the user belongs to an OAuth2 application.
        system*: bool ## Whether the user is an Official Discord System user (part of the urgent message system).
        mfaEnabled*: bool ## Whether the user has two factor enabled on their account	.
        locale*: string ## The user's chosen language option .
        verified*: bool ## Whether the email on this account has been verified.
        email*: string ## The user's email.
        flags*: int ## The flags on a user's account.
        premiumType*: NitroSubscription ## The type of Nitro subscription on a user's account.
        publicFlags*: int ## The public flags on a user's account.

proc newUser*(json: json.JsonNode): User =
    return User(
        id: getIDFromJson(json["id"].getStr()),
        username: json["username"].getStr(),
        discriminator: cushort(json["discriminator"].getInt()),
        avatar: json["avatar"].getStr(),
        bot: json{"bot"}.getBool(),
        system: json{"system"}.getBool(),
        mfaEnabled: json{"mfa_enabled"}.getBool(),
        locale: json{"locale"}.getStr(),
        verified: json["verified"].getBool(),
        email: json["email"].getStr(),
        flags: json["flags"].getInt(),
        premiumType: NitroSubscription(json["premium_type"].getInt()),
        publicFlags: json["public_flags"].getInt()
    )
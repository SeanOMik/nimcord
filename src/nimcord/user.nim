import json, discordobject, nimcordutils, strutils

type 
    NitroSubscription* = enum
        none = 0,
        nitroClassic = 1,
        nitro = 2

    User* = ref object of DiscordObject
        ## This type is any discord user.
        username*: string ## The user's username, not unique across the platform.
        discriminator*: cushort ## The user's 4-digit discord-tag.
        bot*: bool ## Whether the user belongs to an OAuth2 application.
        system*: bool ## Whether the user is an Official Discord System user (part of the urgent message system).
        publicFlags*: int ## The public [flags](https://discord.com/developers/docs/resources/user#user-object-user-flags) on a user's account. (User Badges)
        avatarRaw: array[2, uint64] ## The split hash for the 128bit hexadeximal avatar.
        isAvatarGif: bool ## Wether the avatar is a gif.


    ClientUser* = ref object of User
        ## This type is the clients discord user.
        mfaEnabled*: bool ## Whether the user has two factor authentication enabled on their account.
        locale*: string ## The user's chosen language option.
        verified*: bool ## Whether or not the current user has a verified email.
        email*: string ## The current user's email
        premiumType*: NitroSubscription ## The type of Nitro subscription on a user's account.
        flags*: int ## The [flags](https://discord.com/developers/docs/resources/user#user-object-user-flags) on a user's account.

proc newUser*(user: JsonNode): User {.inline.} =
    result = User(
        id: getIDFromJson(user["id"].getStr()),
        username: user["username"].getStr(),
        discriminator: cushort(parseIntEasy(user["discriminator"].getStr())),
        bot: user{"bot"}.getBool(),
        system: user{"system"}.getBool(),
        publicFlags: user{"public_flags"}.getInt()
    )

    if user.contains("avatar"):
        let avatarStr = user["avatar"].getStr()

        # If the avatar is animated we need to remove the prefixed "a_"
        if avatarStr.startsWith("a_"):
            result.isAvatarGif = true
            result.avatarRaw = splitAvatarHash(avatarStr.substr(2))
        else:
            result.isAvatarGif = false
            result.avatarRaw = splitAvatarHash(avatarStr)


proc newClientUser*(clientUser: JsonNode): ClientUser {.inline.} =
    result = ClientUser(
        id: getIDFromJson(clientUser["id"].getStr()),
        username: clientUser["username"].getStr(),
        discriminator: cushort(parseIntEasy(clientUser["discriminator"].getStr())),
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

    if clientUser.contains("avatar"):
        let avatarStr = clientUser["avatar"].getStr()

        # If the avatar is animated we need to remove the prefixed "a_"
        if avatarStr.startsWith("a_"):
            result.isAvatarGif = true
            result.avatarRaw = splitAvatarHash(avatarStr.substr(2))
        else:
            result.isAvatarGif = false
            result.avatarRaw = splitAvatarHash(avatarStr)

proc getUserAvatarURL*(user: User, imageType: ImageType = ImageType.imgTypeAuto): string = 
    # If the user doesn't have an avatar, then return a default avatar url.
    if user.avatarRaw.len == 0:
        return "https://cdn.discordapp.com/embed/avatars/" & $(user.discriminator mod 5) & ".png"

    result = "https://cdn.discordapp.com/avatars/" & $user.id & "/" & $combineAvatarHash(user.avatarRaw)

    # If we're finding the image type automaticly, then we need to
    # check if the avatar is a gif.
    var tmp = imageType
    if (imageType == ImageType.imgTypeAuto):
        if user.isAvatarGif:
            tmp = ImageType.imgTypeGif
        else:
            tmp = ImageType.imgTypePng

    case tmp:
        of ImageType.imgTypeGif:
            result &= ".gif"
            discard
        of ImageType.imgTypeJpeg:
            result &= ".jpeg"
            discard
        of ImageType.imgTypePng:
            result &= ".png"
            discard
        of ImageType.imgTypeWebp:
            result &= ".webp"
            discard
        of ImageType.imgTypeAuto:
            result &= ".png" # Just incase
            discard
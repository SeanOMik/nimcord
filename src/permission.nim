import json, discordobject, nimcordutils

type 
    PermissionType* = enum
        permTypeRole,
        permTypeMember
    
    Permission* = enum
        permCreateInstantInvite = 0x00000001,
        permKickMembers = 0x00000002,
        permBanMembers = 0x00000004,
        permAdministrator = 0x00000008,
        permManageChannels = 0x00000010,
        permManageGuilds = 0x00000020,
        permAddReactions = 0x00000040,
        permViewAuditLog = 0x00000080,
        permPrioritySpeaker = 0x00000100,
        permStream = 0x00000200,
        permReadMessages = 0x00000400,
        permSendMessages = 0x00000800,
        permSendTTSMessages = 0x00001000,
        permManageMessages = 0x00002000,
        permEmbedLinks = 0x00004000,
        permAttachFiles = 0x00008000,
        permReadMessageHistory = 0x00010000,
        permMentionEveryoneHereAllRoles = 0x00020000,
        permUseExternalEmojis = 0x00040000,
        permConnect = 0x00100000,
        permSpeak = 0x00200000,
        permMuteMembers = 0x00400000,
        permDeafenMembers = 0x00800000,
        permMoveMembers = 0x01000000,
        permUseVAD = 0x02000000,
        permChangeNickname = 0x04000000,
        permManageNicknames = 0x08000000,
        permManageRoles = 0x10000000,
        permManageWebhooks = 0x20000000,
        permManageEmojis = 0x40000000

    Permissions* = ref object
        ## This type referes to a user's permissions given by the role or per user.
        roleUserID*: snowflake
        allowPerms*: uint
        denyPerms*: uint
        permissionType*: PermissionType

proc newPermissions*(json: JsonNode): Permissions =
    ## Parses a `Permissions` from json.
    result = Permissions(
        roleUserID: getIDFromJson(json["id"].getStr()),
        allowPerms: uint(json["allow"].getInt()),
        denyPerms: uint(json["deny"].getInt())
    )

    if (json["type"].getStr() == "role"):
        result.permissionType = PermissionType.permTypeRole
    else:
        result.permissionType = PermissionType.permTypeMember

proc hasPermission*(perms: Permissions, perm: Permission): bool =
    ## Check if Permissions has a specific permission.
    ## This also checks if it is not a part of the denyPerms.
    return (perms.allowPerms and uint(perm)) == uint(perm) and (perms.denyPerms and uint(perm)) != uint(perm)

proc addAllowPermission*(perms: Permissions, perm: Permission): Permissions =
    ## Add a `Permission` to the `Permissions` allow values.
    ## If it finds the permission in denyPerms, it will remove it from that also.
    
    # Check if the permission is in deny, and remove it.
    if ((perms.denyPerms and uint(perm)) == uint(perm)):
        perms.denyPerms = perms.denyPerms and (not uint(perm))

    perms.allowPerms = perms.allowPerms or uint(perm)

proc addDenyPermission*(perms: Permissions, perm: Permission): Permissions =
    ## Add a `Permission` to the `Permissions` deny values.
    ## If it finds the permission in allowPerms, it will remove it from that also.
    
    # Check if the permission is in allowed, and remove it.
    if ((perms.allowPerms and uint(perm)) == uint(perm)):
        perms.allowPerms = perms.allowPerms and (not uint(perm))

    perms.denyPerms = perms.denyPerms or uint(perm)
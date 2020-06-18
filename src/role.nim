import json, nimcordutils, discordobject, permission

type Role* = ref object of DiscordObject
    name*: string
    color*: uint
    hoist*: bool
    position*: uint
    permissions*: Permissions
    managed*: bool
    mentionable*: bool

proc newRole*(json: JsonNode): Role =
    result = Role(
        id: getIDFromJson(json["id"].getStr()),
        name: json["name"].getStr(),
        color: uint(json["color"].getInt()),
        hoist: json["hoist"].getBool(),
        position: uint(json["position"].getInt()),
        permissions: newPermissions(json["permissions"]),
        managed: json["managed"].getBool(),
        mentionable: json["mentionable"].getBool()
    )
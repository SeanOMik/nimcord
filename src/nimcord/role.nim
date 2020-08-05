import json, nimcordutils, discordobject, permission, options, httpcore, asyncdispatch, strformat

type Role* = ref object of DiscordObject
    name*: string
    color*: uint
    hoist*: bool
    position*: uint
    permissions*: Permissions
    managed*: bool
    mentionable*: bool
    guildID*: Snowflake

proc newRole*(json: JsonNode, guild: Snowflake): Role =
    ## Parses role from json.
    result = Role(
        id: getIDFromJson(json["id"].getStr()),
        name: json["name"].getStr(),
        color: uint(json["color"].getInt()),
        hoist: json["hoist"].getBool(),
        position: uint(json["position"].getInt()),
        managed: json["managed"].getBool(),
        mentionable: json["mentionable"].getBool(),
        guildID: guild
    )

    result.permissions = newPermissions(result.id, PermissionType.permTypeRole, 
            uint(json["permissions"].getInt()))

proc modifyGuildRole*(role: var Role, name: Option[string] = none(string), permissions: Option[Permissions] = none(Permissions),
    color: Option[int] = none(int), hoist: Option[bool] = none(bool), mentionable: Option[bool] = none(bool)): Future[Role] {.async.} =
    ## Modify a guild role. Requires the `MANAGE_ROLES` permission.
    ## The changes will reflect on the `role` object you supplied.
    ## 
    ## Example:
    ## 
    ## .. code-block:: nim
    ##   discard role.modifyGuildRole(name = some("Gamer Role"), color = some(0xff0000))

    var jsonBody: JsonNode

    if name.isSome:
        jsonBody.add("name", %name)

    if permissions.isSome:
        jsonBody.add("permissions", %permissions.get().allowPerms)

    if color.isSome:
        jsonBody.add("color", %color)

    if hoist.isSome:
        jsonBody.add("hoist", %hoist)

    if mentionable.isSome:
        jsonBody.add("mentionable", %mentionable)

    result = newRole(sendRequest(endpoint(fmt("/guilds/{role.guildID}/roles/{role.id}")), HttpPatch,
        defaultHeaders(newHttpHeaders({"Content-Type": "application/json"})),
        role.guildID, RateLimitBucketType.guild, jsonBody), role.guildID)
    role = result

proc deleteGuildRole*(role: Role) {.async.} =
    ## Delete a guild role. Requires the `MANAGE_ROLES` permission.
    discard sendRequest(endpoint(fmt("/guilds/{role.guildID}/roles/{role.id}")), HttpDelete,
        defaultHeaders(), role.guildID, RateLimitBucketType.guild)

import json, discordobject, emoji, nimcordutils, tables, times

type 
    ClientStatus* = enum
        clientStatusOnline = "online",
        clientStatusOffline = "offline",
        clientStatusInvisible = "invisible",
        clientStatusIdle = "idle",
        clientStatusDnd = "dnd" ## Do not disturb.

    ActivityType* = enum
        activityTypeGame = 0,
        activityTypeStreaming = 1,
        activityTypeListening = 2,
        activityTypeCustom = 4

    ActivityFlag* = enum
        activityFlagInstance = 0,
        activityFlagJoin = 1,
        activityFlagSpectate = 2,
        activityFlagJoinRequest = 3,
        activityFlagSync = 4,
        activityFlagPlay = 5

    ActivityTimestamp* = ref object
        startTime*: uint
        endTime*: uint

    ActivityParty* = ref object
        id*: string
        currentSize*: uint
        maxSize*: uint

    ActivityAssets* = ref object
        largeImg: string
        largeText*: string
        smallImg*: string
        smallText*: string

    ActivitySecrets* = ref object
        join*: string
        spectate*: string
        match*: string

    Activity* = ref object
        name*: string
        `type`*: ActivityType
        url*: string
        createdAt*: uint
        timestamps*: seq[ActivityTimestamp]
        applicationID*: snowflake
        details*: string
        state*: string
        emoji*: Emoji
        party*: ActivityParty
        assets*: ActivityAssets
        secrets*: ActivitySecrets
        instance*: bool
        flags*: uint

    Presence* = ref object
        status*: string
        game*: Activity
        activities*: seq[Activity]
        afk*: bool

proc newActivity*(json: JsonNode, guildID: snowflake): Activity = 
    ## Parse a new activity from json.
    var act = Activity(
        name: json["name"].getStr(),
        `type`: ActivityType(json["type"].getInt()),
        url: json{"url"}.getStr(),
        createdAt: uint(json{"created_at"}.getInt()),
        applicationID: getIDFromJson(json{"application_id"}.getStr()),
        details: json{"details"}.getStr(),
        state: json{"state"}.getStr(),
        instance: json{"instance"}.getBool(),
        flags: uint(json{"flags"}.getInt()),
    )

    if (json.contains("timestamps")):
        for timestamp in json["timestamps"]:
            var time: ActivityTimestamp
            if (timestamp.contains("start")):
                time.startTime = uint(timestamp["start"].getInt())
            if (timestamp.contains("end")):
                time.endTime = uint(timestamp["end"].getInt())

            act.timestamps.add(time)
                
    if (json.contains("emoji")):
        act.emoji = newEmoji(json["emoji"], guildID)

    if (json.contains("party")):
        var party: ActivityParty
        if (json["party"].contains("id")):
            party.id = json["party"]["id"].getStr()
        if (json["party"].contains("size")):
            party.currentSize = uint(json["party"]["size"].elems[0].getInt())
            party.maxSize = uint(json["party"]["size"].elems[1].getInt())

    if (json.contains("assets")):
        var assets: ActivityAssets
        if (json["assets"].contains("large_image")):
            assets.largeImg = json["assets"]["large_image"].getStr()
        if (json["assets"].contains("large_text")):
            assets.largeText = json["assets"]["large_text"].getStr()
        if (json["assets"].contains("small_image")):
            assets.smallImg = json["assets"]["small_image"].getStr()
        if (json["assets"].contains("small_text")):
            assets.smallText = json["assets"]["small_text"].getStr()

    if (json.contains("secrets")):
        var secrets: ActivitySecrets
        if (json["secrets"].contains("join")):
            secrets.join = json["secrets"]["join"].getStr()
        if (json["secrets"].contains("spectate")):
            secrets.spectate = json["secrets"]["spectate"].getStr()
        if (json["secrets"].contains("match")):
            secrets.match = json["secrets"]["match"].getStr()

proc newPresence*(json: JsonNode): Presence =
    ## Parses Presence type from json.
    result = Presence(
        status: json["status"].getStr()
    )

    if (json.contains("game") and json["game"].getFields().len > 0):
        result.game = newActivity(json["game"], getIDFromJson(json{"guild_id"}.getStr()))

    if json.contains("activities"):
        for activity in json["activities"]:
            result.activities.add(newActivity(json["game"], getIDFromJson(json{"guild_id"}.getStr())))

proc newPresence*(text: string, `type`: ActivityType, status: ClientStatus, afk: bool = false): Presence =
    ## Used to create a presence that you can use to update the presence of your bot's user.
    return Presence(
        status: $status,
        afk: afk,
        game: Activity(
            name: text,
            `type`: `type`
        )
    )
    
proc presenceToJson*(presence: Presence): JsonNode =
    ## Convert a presence to json for sending via gateway.
    ## If your a user, no reason to use this!
    result = %* {
        "status": presence.status,
        "afk": presence.afk,
        "since": getTime().toUnix(),
        "game": {
            "name": presence.game.name,
            "type": ord(presence.game.`type`)
        }
    }
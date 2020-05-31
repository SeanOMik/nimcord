import eventhandler, json, tables, hashes, message

proc readyEvent(json: JsonNode) =
    let readyEvent = ReadyEvent(readyPayload: json, name: $EventType.evtReady)
    dispatchEvent(readyEvent)

proc messageCreateEvent(json: JsonNode) =
    let msg = newMessage(json)
    let messageCreateEvnt = MessageCreateEvent(message: msg)
    dispatchEvent(messageCreateEvnt)

let internalEventTable: Table[string, proc(json: JsonNode) {.nimcall.}] = {
        "READY": readyEvent,
        "MESSAGE_CREATE": messageCreateEvent
    }.toTable

proc handleDiscordEvent*(json: JsonNode, eventName: string) =
    if (internalEventTable.hasKey(eventName)):
        let eventProc:proc(json: JsonNode) = internalEventTable[eventName]
        eventProc(json)
    else:
        echo "Failed to find event: ", eventName
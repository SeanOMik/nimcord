import eventhandler, json, tables, hashes

proc readyEvent(json: JsonNode) =
    let readyEvent = ReadyEvent(readyPayload: json, name: $EventType.evtReady)
    dispatchEvent(readyEvent)

let internalEventTable: Table[string, proc(json: JsonNode) {.nimcall.}] = {
        "READY": readyEvent
    }.toTable

proc handleDiscordEvent*(json: JsonNode, eventName: string) =
    if (internalEventTable.hasKey(eventName)):
        let eventProc:proc(json: JsonNode) = internalEventTable[eventName]
        eventProc(json)
    else:
        echo "Failed to find event: ", eventName
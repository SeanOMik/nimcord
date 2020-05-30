import tables, hashes, json

type
    EventType* = enum
        evtReady = "READY"

    BaseEvent* = object of RootObj
        name*: string
    ReadyEvent* = object of BaseEvent
        readyPayload*: JsonNode

# Table storing all the event listeners
let eventListeners = newTable[string, seq[proc(event: BaseEvent)]]()

proc registerEventListener*(event: EventType, listener: proc(event: BaseEvent)) =
    if (eventListeners.hasKey($event)):
        var listeners = eventListeners[$event]
        listeners.add(cast[proc(event: BaseEvent)](listener))

        echo "Added other event listener: ", $event
    else:
        let tmp = @[listener]
        eventListeners.add($event, tmp)

        echo "Added new event listener: ", $event

proc dispatchEvent*[T: BaseEvent](event: T) = 
    #let base: BaseEvent = BaseEvent(event)

    if (eventListeners.hasKey(event.name)):
        let listeners = eventListeners[event.name]
        for index, eventListener in listeners.pairs:
            echo "Dispatching event: ", event.name
            eventListener(event)
    else:
        echo "No event listeners for event: ", event.name
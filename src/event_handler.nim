import tables, hashes, sequtils

type
    BaseEvent* = object
        name*: string

proc hash[T: object](o: T): Hash =
    for k, v in o.fieldPairs: 
        result = result !& v.hash
    result = !$result

# Table storing all the event listeners
let eventListeners = newTable[BaseEvent, seq[proc()]]()

proc registerEventListener*(event: BaseEvent, listener: proc()) =
    if (eventListeners.hasKey(event)):
        var listeners = eventListeners[event]
        listeners.add(listener)
    else:
        let tmp = @[listener]
        eventListeners.add(event, tmp)

proc dispatchEvent(event: BaseEvent) = 
    if (eventListeners.hasKey(event)):
        let listeners = eventListeners[event]
        for index, eventListener in listeners.pairs:
            eventListener()
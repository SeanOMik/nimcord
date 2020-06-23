import ../src/nimcord, asyncdispatch, streams, os, strutils, options, websocket

var tokenStream = newFileStream("token.txt", fmRead)
var tkn: string
if (not isNil(tokenStream)):
    discard tokenStream.readLine(tkn)
    echo "Read token from the file: ", tkn

    tokenStream.close()

var bot = newDiscordClient(tkn)

registerEventListener(EventType.evtReady, proc(bEvt: BaseEvent) =
    let event = ReadyEvent(bEvt)

    echo "Ready! (v", 0, ".", 0, ".", 1, ")"
    echo "Logged in as: ", bot.clientUser.username, "#", bot.clientUser.discriminator
    echo "ID: ", bot.clientUser.id
    echo "--------------------"

    let presence = newPresence("with Nimcord", activityTypeGame, clientStatusIdle, false)
    asyncCheck event.shard.updateClientPresence(presence)
)

registerEventListener(EventType.evtMessageCreate, proc(bEvt: BaseEvent) =
    let event = MessageCreateEvent(bEvt)

    if (event.message.content == "?ping"):
        var channel: Channel = event.message.getMessageChannel(event.shard.client.cache)
        if (channel != nil):
            discard channel.sendMessage("PONG")
    elif (event.message.content.startsWith("?modifyChannelTopic")):
        let modifyTopic = event.message.content.substr(20)

        var channel: Channel = event.message.getMessageChannel(event.shard.client.cache)
        if (channel != nil):
            discard channel.sendMessage("Modifing Channel!")
            discard channel.modifyChannel(ChannelFields(topic: some(modifyTopic)))
    elif (event.message.content.startsWith("?deleteChannel")):
        let channelID = getIDFromJson(event.message.content.substr(15))
        var channel: Channel = event.shard.client.cache.getChannel(channelID)
        
        if (channel != nil):
            discard channel.sendMessage("Deleting Channel!")
            discard channel.deleteChannel()
            discard channel.sendMessage("Deleted Channel!")
    elif (event.message.content.startsWith("?getMessages")):
        var channel: Channel = event.message.getMessageChannel(event.shard.client.cache)
        if (channel != nil):
            discard channel.getMessages(MessagesGetRequest(limit: some(15), before: some(event.message.id)))
    elif (event.message.content.startsWith("?bulkDeleteMessages")):
        var channel: Channel = event.message.getMessageChannel(event.shard.client.cache)
        if (channel != nil):
            var amount: int = 25
            if (event.message.content.len > 19):
                amount = parseIntEasy(event.message.content.substr(20))
            let messages = channel.getMessages(MessagesGetRequest(limit: some(amount), before: some(event.message.id)))
            discard channel.bulkDeleteMessages(messages)
    elif (event.message.content.startsWith("?reactToMessage")):
        var channel: Channel = event.message.getMessageChannel(event.shard.client.cache)
        if (channel != nil):
            let emojis = @[newEmoji("⏮️"), newEmoji("⬅️"), newEmoji("⏹️"), newEmoji("➡️"), newEmoji("⏭️")]
            for emoji in emojis:
                discard event.message.addReaction(emoji)
    elif (event.message.content.startsWith("?testEmbed")):
        var channel: Channel = event.message.getMessageChannel(event.shard.client.cache)
        if (channel != nil):
            var embed = Embed()
            embed.setTitle("This embed is being sent from Nimcord!")
            embed.setDescription("Nimcord was developed in about a week of actual work so there will likely be issues.")
            embed.addField("Title", "value")
            embed.addField("Inline-0", "This is an inline field 0", true)
            embed.addField("Inline-1", "This is an inline field 1", true)
            embed.setColor(0xffb900)
            discard channel.sendMessage("", false, embed)
    elif (event.message.content.startsWith("?sendFile")):
        var channel: Channel = event.message.getMessageChannel(event.shard.client.cache)
        if (channel != nil):
            let filePath = event.message.content.substr(10)

            let splitFile = splitFile(filePath)
            let fileName = splitFile.name & splitFile.ext

            let file = DiscordFile(filePath: filePath, fileName: fileName)
            discard channel.sendMessage("", false, nil, @[file])
    elif (event.message.content.startsWith("?sendImage")):
        var channel: Channel = event.message.getMessageChannel(event.shard.client.cache)
        if (channel != nil):
            let filePath = event.message.content.substr(11)

            let splitFile = splitFile(filePath)
            let fileName = splitFile.name & splitFile.ext

            let file = DiscordFile(filePath: filePath, fileName: fileName)

            var embed = Embed()
            embed.setTitle("Image attachment test.")
            embed.setImage("attachment://" & fileName)
            discard channel.sendMessage("", false, embed, @[file])
)

waitFor bot.startConnection(2)
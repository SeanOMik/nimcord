import ../src/nimcord, asyncdispatch, streams, os, strutils, options, websocket

var tokenStream = newFileStream("token.txt", fmRead)
var tkn: string
if (not isNil(tokenStream)):
    discard tokenStream.readLine(tkn)

    tokenStream.close()

var bot = newDiscordClient(tkn, "?", newLog(ord(LoggerFlags.loggerFlagDebugSeverity)))

let pingCommand = Command(name: "ping", commandBody: proc(ctx: CommandContext) = 
    discard ctx.channel.sendMessage("PONG")
)

let modifyChannelTopicCommand = Command(name: "modifyChannelTopic", commandBody: proc(ctx: CommandContext) = 
    let modifyTopic = ctx.message.content.substr(20)

    discard ctx.channel.sendMessage("Modifing Channel!")
    discard ctx.channel.modifyChannel(ChannelFields(topic: some(modifyTopic)))
)

let deleteChannelCommand = Command(name: "deleteChannel", commandBody: proc(ctx: CommandContext) =
    let channelID = getIDFromJson(ctx.arguments[0])
    var channel: Channel = ctx.client.cache.getChannel(channelID)
    
    # Check if we could find the channel to delete
    if (channel != nil):
        discard channel.sendMessage("Deleting Channel!")
        discard channel.deleteChannel()
        discard ctx.channel.sendMessage("Deleted Channel!")
)

let bulkDeleteMessagesCommand = Command(name: "bulkDeleteMessages", commandBody: proc(ctx: CommandContext) =
    var amount: int = 25
    if (ctx.message.content.len > 19):
        amount = parseIntEasy(ctx.arguments[0])

    # Get the message to delete, then delete them.
    let messages = ctx.channel.getMessages(MessagesGetRequest(limit: some(amount), before: some(ctx.message.id)))
    discard ctx.channel.bulkDeleteMessages(messages)

    # Delete the message that was used to run this command.
    discard ctx.message.deleteMessage()
)

let reactToMessageCommand = Command(name: "reactToMessage", commandBody: proc(ctx: CommandContext) =
    let emojis = @[newEmoji("⏮️"), newEmoji("⬅️"), newEmoji("⏹️"), newEmoji("➡️"), newEmoji("⏭️")]
    for emoji in emojis:
        discard ctx.message.addReaction(emoji)
)

let testEmbedCommand = Command(name: "testEmbed", commandBody: proc(ctx: CommandContext) =
    var embed = Embed()
    embed.setTitle("This embed is being sent from Nimcord!")
    embed.setDescription("Nimcord was developed in about a week of actual work so there will likely be issues.")
    embed.addField("Title", "value")
    embed.addField("Inline-0", "This is an inline field 0", true)
    embed.addField("Inline-1", "This is an inline field 1", true)
    embed.setColor(0xffb900)
    discard ctx.channel.sendMessage("", false, embed)
)

let sendFileCommand = Command(name: "sendFile", commandBody: proc(ctx: CommandContext) =
    let filePath = ctx.message.content.substr(10)

    let splitFile = splitFile(filePath)
    let fileName = splitFile.name & splitFile.ext

    let file = DiscordFile(filePath: filePath, fileName: fileName)
    discard ctx.channel.sendMessage("", false, nil, @[file])
)

let sendImageCommand = Command(name: "sendImage", commandBody: proc(ctx: CommandContext) =
    let filePath = ctx.message.content.substr(11)

    let splitFile = splitFile(filePath)
    let fileName = splitFile.name & splitFile.ext

    let file = DiscordFile(filePath: filePath, fileName: fileName)

    var embed = Embed()
    embed.setTitle("Image attachment test.")
    embed.setImage("attachment://" & fileName)
    discard ctx.channel.sendMessage("", false, embed, @[file])
)

# You can even register commands like this:
registerCommand(Command(name: "ping2", commandBody: proc(ctx: CommandContext) = 
    discard ctx.channel.sendMessage("PONG 2")
))

# Listen for the ready event.
registerEventListener(EventType.evtReady, proc(bEvt: BaseEvent) =
    # Cast the BaseEvent to the ReadyEvent which is what we're listening to.
    let event = ReadyEvent(bEvt) 

    event.shard.client.log.info("Ready!")
    event.shard.client.log.info("Logged in as: " & bot.clientUser.username & "#" & $bot.clientUser.discriminator)
    event.shard.client.log.info("ID: " & $bot.clientUser.id)
    event.shard.client.log.info("--------------------")

    let presence = newPresence("with Nimcord", ActivityType.activityTypeGame, 
        ClientStatus.clientStatusIdle, false)
    asyncCheck event.shard.updateClientPresence(presence)

    # Register commands. You don't need to register them in EventReady.
    registerCommand(pingCommand)
    registerCommand(modifyChannelTopicCommand)
    registerCommand(deleteChannelCommand)
    registerCommand(bulkDeleteMessagesCommand)
    registerCommand(reactToMessageCommand)
    registerCommand(testEmbedCommand)
    registerCommand(sendFileCommand)
    registerCommand(sendImageCommand)
)

waitFor bot.startConnection()
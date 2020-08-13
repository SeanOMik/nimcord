import tables, message, member, user, channel, strutils, clientobjects, cache

type 
    CommandContext* = ref object of RootObj
        ## Object to make it easier to create commands.
        message*: Message ## The message that ran the command
        channel*: Channel ## The channel that this command was ran in.
        author*: GuildMember ## The GuildMember that ran the command.
        user*: User ## The user who ran the command.
        arguments*: seq[string] ## The command arguments.
        client*: DiscordClient ## The DiscordClient.

    Command* = ref object of RootObj
        ## Command object.
        name*: string ## The name of the command.
        commandBody*: proc(ctx: CommandContext) ## The command body of the command.
        commandRequirements*: proc(ctx: CommandContext): bool ## The requirements of the command,
                                                              ## ran before commandBody to check if 
                                                              ## the command can run.

# Table storing all the commands
let registeredCommands = newTable[string, Command]()

proc registerCommand*(command: Command) =
    ## Register a Command.
    ## 
    ## Examples:
    ## 
    ## .. code-block:: nim
    ##   registerCommand(Command(name: "ping", commandBody: proc(ctx: CommandContext) = 
    ##      discard ctx.channel.sendMessage("PONG")
    ##   ))
    registeredCommands.add(command.name, command)

proc fireCommand*(client: DiscordClient, message: Message) = 
    ## Fire a command. This is already called by Nimcord. Not any need to call this.

    # If the message doesn't start with the prefix, then
    # it probably isn't a commnand.
    if not message.content.startsWith(client.commandPrefix):
        return

    # Get the arguments for the command
    var arguments: seq[string] = message.content.split(" ")
    
    # Extract the command name from arguments
    let commandName = arguments[0].substr(1)
    arguments.del(0)

    ## Dispatches an event so something can listen to it.
    if (registeredCommands.hasKey(commandName)):
        let commandContext = CommandContext(message: message, channel: message.getMessageChannel(client.cache), 
            author: message.member, user: message.author, arguments: arguments, client: client)

        let command = registeredCommands[commandName]
        if command.commandRequirements != nil:
            if command.commandRequirements(commandContext):
                command.commandBody(commandContext)
        else:
            command.commandBody(commandContext)
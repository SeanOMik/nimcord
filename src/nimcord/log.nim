import terminal, streams, times

type 
    LoggerFlags* = enum
        loggerFlagDisable = 0x1,
        loggerFlagInfoSeverity = 0x2,
        loggerFlagWarnSeverity = 0x4,
        loggerFlagErrorSeverity = 0x8,
        loggerFlagAllSeverity = 0x16,
        loggerFlagDebugSeverity = 0x32,
        loggerFlagFileOnly = 0x64

    Log* = ref object
        flags: int
        logFile: FileStream

    LogSeverity* = enum
        logSevInfo = 0,
        logSevWarn = 1,
        logSevError = 2,
        logSevDebug = 3

proc newLog*(flags: int, filePath: string = ""): Log =
    ## Create a new log. Colors in a file is printed as "fgYellow".
    var log = Log(flags: flags)
    if filePath.len > 0:
        log.logFile = newFileStream(filePath, fmWrite)
        if isNil(log.logFile):
            raise newException(IOError, "Failed to open log file: " & filePath)
    
    return log

proc canLog(log: Log, sev: LogSeverity): bool = 
    if (log.flags and int(LoggerFlags.loggerFlagDisable)) == int(LoggerFlags.loggerFlagDisable):
        return false
    elif (log.flags and int(LoggerFlags.loggerFlagAllSeverity)) == int(LoggerFlags.loggerFlagAllSeverity):
        return true
    elif (log.flags and int(LoggerFlags.loggerFlagDebugSeverity)) == int(LoggerFlags.loggerFlagDebugSeverity):
        return true

    case sev
        of LogSeverity.logSevInfo:
            return (log.flags and int(LoggerFlags.loggerFlagInfoSeverity)) == int(LoggerFlags.loggerFlagInfoSeverity)
        of LogSeverity.logSevWarn:
            return (log.flags and int(LoggerFlags.loggerFlagWarnSeverity)) == int(LoggerFlags.loggerFlagWarnSeverity)
        of LogSeverity.logSevError:
            return (log.flags and int(LoggerFlags.loggerFlagErrorSeverity)) == int(LoggerFlags.loggerFlagErrorSeverity)
        else:
            return false

proc severityToString(sev: LogSeverity): string =
    case sev
        of LogSeverity.logSevInfo:
            return "INFO"
        of LogSeverity.logSevWarn:
            return "WARN"
        of LogSeverity.logSevError:
            return "ERROR"
        of LogSeverity.logSevDebug:
            return "DEBUG"

proc autoLog(log: Log, sev: LogSeverity, text: string) =
    if log.canLog(sev):
        let timeFormated = getTime().format("[HH:mm:ss]")
        let sevStr = "[" & severityToString(sev) & "]"

        let logHeader = timeFormated & " " & sevStr & " "

        terminal.styledEcho(logHeader, text)

        if log.logFile != nil:
            log.logFile.writeLine(logHeader, text)

proc debug*(log: Log, text: string) =
    ## Log debug severity. Example output: `[22:34:31] [DEBUG] Test`
    log.autoLog(logSevDebug, text)

proc warn*(log: Log, text: string) =
    ## Log warning severity. Example output: `[22:34:31] [WARN] Test`
    log.autoLog(logSevWarn, text)

proc error*(log: Log, text: string) =
    ## Log error severity. Example output: `[22:34:31] [ERROR] Test`
    log.autoLog(logSevError, text)

proc info*(log: Log, text: string) =
    ## Log info severity. Example output: `[22:34:31] [INFO] Test`
    log.autoLog(logSevInfo, text)

proc closeLog*(log: Log) =
    ## Close log file if it was ever open.
    if log.logFile != nil:
        log.info("Closing log...")
        log.logFile.close()

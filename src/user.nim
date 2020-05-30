import discordobject

type
    User = ref object of DiscordObject
        username*: string # username of the current user object
        avatar_hash*: string # avatar hash of the current object
        discriminator*: uint16 # discriminator of the current user object
        flags: int # flags of the current user object
        method GetDiscriminator(this: User): string = $(this.discriminator)
type
    GuildMember = ref object of User
        guild_id*: snowflake # id of the guild of the current member object 
        nickname*: string # nickname of the current member object
        joined_at*: string # date the current member object joined at
        hierarchy*: int # role hierarchy for the current member object

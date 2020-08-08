import json

type 
    Embed* {.requiresInit.} = ref object
        ## A message embed type
        embedJson*: JsonNode

    EmbedFieldException* = object of CatchableError

proc setTitle*(embed: var Embed, title: string) =
    ## Set the title of the embed.
    ## 
    ## Contstraints:
    ## * `title` must be set and cannot be larger than 256 characters.
    if title.len < 0 or title.len > 256:
        raise newException(EmbedFieldException, "Embed title can only be 0-256 characters")

    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("title", %title)

proc setDescription*(embed: var Embed, description: string) =
    ## Set the description of the embed.
    ## 
    ## Contstraints:
    ## * `description` must be set and cannot be larger than 2048 characters.
    if description.len < 0 or description.len > 2048:
        raise newException(EmbedFieldException, "Embed description can only be 0-2048 characters")

    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("description", %description)

proc setURL*(embed: var Embed, url: string) =
    ## Set the url of the embed.
    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("url", %url)

proc setTimestamp*(embed: var Embed, timestamp: string) =
    ## Set the timestamp of the embed.
    ## The timestamp is in `ISO8601` format.    
    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("timestamp", %timestamp)

proc setColor*(embed: var Embed, color: uint) =
    ## Set the color of the embed.    
    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("color", %color)

proc setFooter*(embed: var Embed, text: string, iconURL: string = "", proxyIconURL: string = "") =
    ## Set the footer of the embed.
    ## The `text` field cannot be longer than 2048 characters.
    ## The `proxyIconURL` field is the proxied url for the footer icon.
    ## 
    ## Contstraints:
    ## * `text` must be set and cannot be larger than 2048 characters.
    if text.len < 0 or text.len > 2048:
        raise newException(EmbedFieldException, "Embed's footer text can only be 0-2048 characters")

    let footer = %* {
        "text": text,
        "icon_url": iconURL,
        "proxy_icon_url": proxyIconURL
    }

    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("footer", footer)

proc setImage*(embed: var Embed, url: string, proxyIconURL: string = "", height: int = -1, width: int = -1) =
    ## Set the image of the embed.
    ## The `proxyIconURL` field is the proxied url for the image.
    var image = %* {
        "url": url,
        "proxy_icon_url": proxyIconURL
    }

    if height != -1:
        image.add("height", %height)
    if width != -1:
        image.add("width", %width)
    
    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("image", image)

proc setThumbnail*(embed: var Embed, url: string, proxyIconURL: string = "", height: int = -1, width: int = -1) =
    ## Set the thumbnail of the embed.
    ## The `proxyIconURL` field is the proxied url for the thumbnail.
    var thumbnail = %* {
        "url": url,
        "proxy_icon_url": proxyIconURL
    }

    if height != -1:
        thumbnail.add("height", %height)
    if width != -1:
        thumbnail.add("width", %width)
    
    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("thumbnail", thumbnail)

proc setVideo*(embed: var Embed, url: string, height: int = -1, width: int = -1) =
    ## Set the video of the embed.
    var video = %* {
        "url": url
    }

    if height != -1:
        video.add("height", %height)
    if width != -1:
        video.add("width", %width)
    
    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("video", video)

proc setProvider*(embed: var Embed, name: string, url: string = "") =
    ## Set the embed's provider.
    let provider = %* {
        "name": name,
        "url": url
    }
    
    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("provider", provider)

proc setAuthor*(embed: var Embed, name: string, url: string = "", iconURL: string = "", proxyIconURL: string = "") =
    ## Set the embed's author.
    ## The `url` field referes to the url of the author.
    ## 
    ## Contstraints:
    ## * `name` cannot be larger than 256 characters
    if name.len < 0 or name.len > 256:
        raise newException(EmbedFieldException, "Embed's author name can only be 0-256 characters")

    let author = %* {
        "name": name,
        "url": url,
        "icon_url": iconURL,
        "proxy_icon_url": proxyIconURL
    }

    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    embed.embedJson.add("author", author)

proc addField*(embed: var Embed, name: string, value: string, inline: bool = false) =
    ## Add an embed field.
    ## 
    ## Contstraints:
    ## * `name` must be set and cannot be larger than 256 characters
    ## * `value` must be set and cannot be larger than 1024 characters
    if name.len == 0 or value.len == 0:
        raise newException(EmbedFieldException, "Embed's field name or values must be set")
    elif name.len > 256:
        raise newException(EmbedFieldException, "Embed's field name can only be 0-256 characters")
    elif value.len > 1024:
        raise newException(EmbedFieldException, "Embed's field value can only be 0-1024 characters")

    let field = %* {
        "name": name,
        "value": value,
        "inline": inline
    }

    if embed.embedJson.isNil():
        embed.embedJson = %*{}

    if embed.embedJson.contains("fields"):
        if embed.embedJson["fields"].len > 25:
            raise newException(EmbedFieldException, "Embeds can only have upto 25 fields")
        embed.embedJson["fields"].add(field)
    else:
        embed.embedJson.add("fields", %*[field])

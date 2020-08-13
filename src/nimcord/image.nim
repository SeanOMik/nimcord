import base64, streams, os, strformat

type Image* = ref object
    filepath*: string ## The filepath of the current image
    extension: string ## The extension of the current image
    base64Encoded: string 

proc newImage*(filepath: string): Image =
    ## Reads from a file that exists at `filepath`. It reads the image data,
    ## and image extension for later use.
    var imageStream = newFileStream(filepath, fmRead)
    if not isNil(imageStream):
        let data = imageStream.readALL()

        # Get the file's extension and remove the `.` from the start of it
        result = Image(
            extension: splitFile(filepath).ext.substr(1),
            base64Encoded: encode(data),
            filepath: filepath
        )

        imageStream.close()
    else:
        raise newException(IOError, "Failed to open file: " & filepath)

proc imageToDataURI*(image: Image): string =
    return fmt("data:image/{image.extension};base64,{image.base64Encoded}")

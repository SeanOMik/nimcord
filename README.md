<h1 align="center">NimCord</h1>

<p align="center">
Memory optimized, simple, and feature rich Discord API wrapper written in Nim.
</p>

# NimCord
A Discord API wrapper written in Nim. Inspired, and created by the author of a memory optimized Discord Library named [DisC++](https://github.com/DisCPP/DisCPP).

## Note:
Library is discontinued. Due to Discord's lack of communication and out-of-touch attitude towards library developers, this library is no longer being maintained. Recommended alternative is [Dimscord](https://github.com/krisppurg/dimscord).

## State
NimCord is currently in a testing state. If you want to use it, you can but you may encounter errors. If you do encounter errors, create a GitHub issue or join the Discord server.

## Dependencies
* [ws](https://github.com/treeform/ws)

## Documenation
You can generate documenation by running `generate_docs.bat/sh` (depending on your system). Documentation is outputted to the `docs` directory.

## What makes NimCord different?
* Low memory usage.
* Even though its memory optimized, it's still easy to use without loosing any features.
* If an member, or channel, is somehow not in cache, it will request the object from the REST api and update the cache to ensure that your bot doesn't crash.
* Other libraries don't have a command handler built in and also doesn't have a event handler that supports multiple listeners.

## How to install:
1. Install [Nim](https://nim-lang.org/)
2. Install NimCord.
   * NimCord is not yet available on the official Nimble package repository. To install it, you need to clone this repo and in the project root, run: `nimble install`

### Note: 
* To compile you must define `ssl` example: `nim compile -d:ssl --run .\examples\basic.nim`

You can view examples in the [examples](examples) directory.

# Todo:
- [x] Finish all REST API calls.
- [x] Handle all gateway events.
- [x] Reconnecting.
- [ ] Configurable Logger.
- [ ] Add library to official Nimble package repository.
- [ ] Memory optimizations.
  - [ ] Member
  - [ ] Channel
  - [ ] Guild
  - [ ] Misc.
- [x] Sharding.
- [ ] Deglobalize (Remove global client instance).
- [ ] Audit log.
- [ ] Voice.

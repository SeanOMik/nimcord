## Welcome to NimCord Documentation!
## 
## NimCord is a Discord API wrapper written in Nim.
## Its created by SeanOMik, who also created [DisC++](https://github.com/DisCPP/DisCPP),
## a Discord API wrapper written in C++.
## 
## Because of my (SeanOMik) work with C++, I made sure to make NimCord
## member optimized but keep it simple to use and feature rich.
## 
## Each modules are split in an object fashion. So `client` handles all gateway stuff,
## `member` defines the GuildMember type and some procs to modify it.
## 
## The module `nimcordutils` defined some helper procs. Currently (as of 0.0.1) these
## procs are only used by Nimcord and likely wont be useful to the user.

import nimcord/[cache, channel, client, clientobjects, discordobject]
import nimcord/[embed, emoji, eventdispatcher, eventhandler, guild]
import nimcord/[image, member, message, nimcordutils, permission]
import nimcord/[presence, role, user, commandsystem]

export cache, channel, client, clientobjects, discordobject
export embed, emoji, eventdispatcher, eventhandler, guild
export image, member, message, nimcordutils, permission
export presence, role, user, commandsystem

const NimCordVersion = "v0.0.1"
---
summary: Allow Moderators to set rooms to moderated
labels:
- Stage-Alpha
...

## Introduction

This module tries to solve the issue, that only the room owners can change a room to "moderated". With this module room owners can optionally allow room admins to set rooms to moderated. This is done by chat command. 

The commands are only available in rooms where the module has been enabled via ad-hoc command by the owner.

The module reserves its name *mod_muc_moderated_chat* as nickname in the room, to send the messages from.

Currently the module sends texts in english and german.
New languages or general code contributions welcome.

## Configuration

Add to the config optionally:

```lua
muc_moderated_chat_inform_admins = false
```

Default: true

When enabled, all room admins and owners currently present in the room get a message when the moderation setting is changed.
They will also get a usage info when the module is enabled for the room.

On servers with huge rooms this can be disabled, because the lookup, who is a Moderator in a room, may be costly. (It was not bemchmarked)


```lua
muc_moderated_chat_module_nickname = "ModInfo"
```

Default: "mod_muc_moderated_chat"

The Name the room sends messages from. This Nickname will not be available for room occupants.

## Usage

### Room configuration

The module adds the following boolean field to the MUC configuration form:

**Allow Admins (Moderators) to set a room to moderated**

Enable this option for each room where Moderators (Administrators) should be able to set a room moderated.


### Chat commands

Once enabled for a room use `!moderate` to set the room to moderated (no voice to new visitors)

Use `!unmoderate` to disable moderated chat.

Only occupants with `admin` or `owner` affiliation can use the commands.

The command message itself is not delivered as a normal groupchat message.


## Installation

For Module installation see below.
Then enable it under a muc like:

```lua
Component "conference.example.org" "muc"
modules_enabled = {
    "muc_moderated_chat";
}
```

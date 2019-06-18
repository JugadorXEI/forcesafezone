# forcesafezone
This plugin can force a safe zone/koth zone in Battle Royale. Maybe (read below).

## Commands:
- **sm_zones** | **sm_zonelist**: Gives you a list of zones on the map (mapadd zones won't appear and thus can't be forced.)
- **sm_forcezone**: Will force the zone to be the one selected by the game logic.
- **sm_activatezone**: Will force the zone's effects to activate. This can't be done if a zone is active.

## Known bugs:
```
Will not work with zones added via mapadd script
Will not work on brush zones that are marked as templates (they are removed on map spawn)
Will break any entity parrented to the original koth zone
```
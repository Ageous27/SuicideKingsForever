Suicide Kings Forever is a WoW Forever loot addon that keeps one Suicide Kings list, reconciles who is in the raid, and runs timed rolls for the officer.

## Features

- One core list, with seeding for raiders who do not have a position yet
- Reconcile on the List window: Present, Bench, Absent, No-call/no-show, and Pug/fill
- Locked rolls of Bid, MS, and OS, or MS and OS, or cannot roll
- Hold, or allow a later bid to raise, without jumping over someone who is holding
- A roll timer, a raider popup, and chat rolls for people who do not have the addon
- Award by master loot when that loot method is on, otherwise by trade
- Disenchant to an assigned disenchanter
- Append-only history, with a Discord export and a merge import that only adds missing events
- List import and export as a tab-separated Discord code block
- Gargul compatibility when both addons are installed
- A background opacity slider for SKF windows on this character

## Usage

Install the `SuicideKingsForever` folder in `Interface\AddOns` and `/reload`. Commands are `/sk`, `/skf`, and `/suicidekings`.

The officer is the master looter when loot is set to master looter. Otherwise the officer is the raid or party leader. Out of a group, you are the officer. Raiders see List and History. The officer also sees Import, Rolls, and Settings.

### List and reconcile

`/sk` opens List. Before the raid is locked, the officer sees reconcile controls on that same window. After lock, or for anyone who is not the officer, it is the read-only list.

Set a status for each person before Lock raid. Status sets the default rolls and whether a later bid can raise them. Rolls and the raise/hold checkbox can still be changed before lock. Changing status resets those defaults. Changing rolls or the checkbox does not change status.

- Present: Bid, MS, OS, and allow raise
- Bench: cannot roll, and allow raise
- Absent: cannot roll, and hold
- No-call/no-show: cannot roll, swap one stored position down, then hold. Last place stays last
- Pug/fill on a core raider: MS and OS, hold, and they keep their stored position

Add with the Pug/fill checkbox for a true fill. They sit at the bottom for this raid and leave the list at End raid. History keeps their events.

Current Pos is the position when this reconcile pass started. New Pos is the live position and turns gold when it differs. Lock raid clears that comparison and writes one history row per person.

A core raider who joins after lock gets an officer-only popup. Yes lets them bid and roll. No leaves them ineligible. Someone who was in the raid at lock and reconnects is not a late join.

### Import and export

Import takes Position, Name, and Class. Tabs or commas both work. A blank position is unseeded. A fully numbered list skips seeding. Merge with blank positions adds new names at the bottom of a list that already has positions. Replace with no positions starts seeding.

Export selects a Discord code block, including the ` ``` ` lines. Ctrl+C copies it. `sample-roster.csv` is a numbered 20-person example.

### Rolls

Open Rolls with `/sk rolls`, the dropdown, or alt-click an item in loot, a bag, or a chat link. Select a Waiting item and press Start. One item is live at a time. Start uses the timer from Settings. Changing the timer does not change an item that is already live.

Raiders with the addon get a popup for the choices their locked rolls allow. During seeding, an unseeded core raider does not see Bid. Anyone can say `bid` in chat, `/roll 100` for MS, or `/roll 99` for OS. A popup choice replaces chat from the same person. One Bid beats every roll. MS beats OS. Chat does not announce list positions.

On a normal list, the best stored position among bidders wins and spends that position. Bid drop, set in Settings, puts the winner in last place or immediately below the lowest other bidder. A sole bidder goes last. People set to hold keep their position. A seeding win inserts the winner at the bottom.

Award, Disenchant, and Cancel are on the live item. Award gives the item with master loot when that method is on and the item is still in a loot slot. Otherwise it goes to Needs Trade and the winner is asked to open trade. Disenchant also goes to Needs Trade and whispers the assigned disenchanter. The list does not move.

### History

History appends loot, reconcile, and late-join events. Export selects every event as a Discord code block. Import / Merge adds events whose id is not already saved and deletes nothing. It does not send those old events to the raid. Clear history is local to this character.

### Gargul

If Gargul is also installed and you are made master looter, SKF asks whether this raid should run in Gargul or SKF. Raiders who have both follow that choice. When the master looter uses SKF, a raider who only has Gargul gets Gargul's roll window. MS and OS from that window show on the officer's Rolls window. Gargul's Pass button only closes its own window, so it does not appear as a pass.

### Settings

Settings is on the officer dropdown, after History. There is no separate slash command.

- Bid drop: last place, or immediately below the lowest other bidder
- Roll timer, default 15 seconds, and countdown, default 5 seconds
- Disenchanter, saved across sessions
- Auto add items when you are master looter, with a quality threshold
- Background opacity for every SKF window on this character. It is not sent to the raid
- Reset all settings restores those values and window positions. It does not clear the list or history
- Clear list asks for confirmation and is refused while the raid is locked

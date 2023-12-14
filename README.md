# Eye of Wisdom

Simple addon for World of Warcraft that scans players around you and saves their inspect data.

## Requirements

Currently supported WoW version: 3.3.5a

## Installation

Copy the `EyeOfWisdom` folder into your `Interface/AddOns` folder.

## Usage

Type '/eow' or '/eyeofwisdom' to see the list of commands.

Addons scans players around you when you do mouseover on them and tries to inspect if you in range.

Scanned data is saved in table in
 `WTF/Account/<account_name>/SavedVariables/EyeOfWisdom.lua` on logout or `/reload`.

You can access data on particular player by typing `/eow get <player_name>`.

## Notes

Addon is still in development and may contain bugs.
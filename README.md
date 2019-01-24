Display Menu
============

A simple macOS menubar extra to apply display presets. A preset consists of
screen resolutions, mirroring configurations, and dock settings.

[Download](https://github.com/Kwpolska/DisplayMenu/releases)

Configuration
-------------

At this stage, the app is very uncomplicated — it can only display a menu, and
has no dedicated configuration GUI.  To get it to work, you need to write a
JSON configuration file file and put it in
`~/Library/Application Support/com.chriswarrick.DisplayMenu/DisplayMenu.json`.
A sample file is included with the distribution.

As part of the configuration, you need to figure out ScreenIDs for your screens
— use the command-line `./PrintScreenIDs` executable or compile the `.swift`
source file yourself.

Roadmap
-------

* only change settings that differ from current setup
* show setting applicability and current preset in the menu
* build a configuration GUI

Credits
-------

Icons: `desktop-mac` and `check` from Material Icons by Google (Apache License v2.0)

Copyright © 2017-2019, Chris Warrick. All rights reserved.
Licensed under the 3-clause BSD license.

-- Open a URL in a NEW Safari window of a fixed pixel width, at full usable
-- height, anchored to one side of the screen.
--
-- usage: osascript safari-window.applescript <url> <width-px> <left|right>
--
-- Width is a fixed px value rather than a fraction so a document reads
-- identically on a laptop and an ultrawide. It is clamped to the usable width
-- so a target wider than the screen just fills it.
--
-- The usable frame is measured directly: screen bounds from Finder, menu bar
-- height and Dock position from System Events. An earlier version derived it by
-- zooming the window and reading its bounds back, but zooming is asynchronous
-- and had not applied by the time we measured, so every window came out sized
-- to a fraction of Safari's default window instead of the screen.

on run argv
    set theURL to item 1 of argv
    set targetW to (item 2 of argv) as integer
    set theSide to item 3 of argv

    -- item extraction must sit outside the tell block, or Finder tries to
    -- resolve "item 3 of" itself and errors with -1728
    tell application "Finder"
        set dtb to bounds of window of desktop
    end tell
    set screenW to item 3 of dtb
    set screenH to item 4 of dtb

    tell application "System Events"
        set mb to item 2 of (get size of menu bar 1 of process "Finder")
        tell dock preferences
            set dockHidden to autohide
            set dockEdge to (screen edge) as text
        end tell
    end tell

    set leftX to 0
    set rightX to screenW
    set topY to mb
    set botY to screenH

    -- an autohidden Dock reserves no space
    if not dockHidden then
        tell application "System Events"
            set dockPos to position of list 1 of process "Dock"
            set dockSz to size of list 1 of process "Dock"
        end tell
        if dockEdge is "bottom" then
            set botY to item 2 of dockPos
        else if dockEdge is "left" then
            set leftX to (item 1 of dockPos) + (item 1 of dockSz)
        else if dockEdge is "right" then
            set rightX to item 1 of dockPos
        end if
    end if

    -- clamp: never wider than the screen actually allows
    set usableW to rightX - leftX
    set wd to targetW
    if wd > usableW then set wd to usableW

    tell application "Safari"
        activate
        make new document with properties {URL:theURL}
        delay 0.2
        -- the document is already open by this point; a placement failure must
        -- not fail the script, or the caller's fallback opens a SECOND window
        try
            set w to window 1
            if theSide is "right" then
                set bounds of w to {rightX - wd, topY, rightX, botY}
            else
                set bounds of w to {leftX, topY, leftX + wd, botY}
            end if
        end try
    end tell
end run

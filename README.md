# reaper-scripts

## Midi Tabulature

This Script aims to emulate guitar tabulature input to write midi takes the way one is used to from GuitarPro in Reaper.

Features:
- Mouseless note input
- Recognizing note under the cursor and changing it
- Palm mute keyswitch, for example Odin II VST offers different articulations
- Compatible with ReaTabHero by using the same string=midi-channel logic
- Tuning presets, can be used for drum
- Scrolling along when playing

### Why does this exist?
I have been using GuitarPro for many years to write my own music. To me the quick input and writing down ideas/riffs became very natural.

But I have never been a fan of their sound engine, which led to me exporting songs to MIDI and importing them into my DAW.

Now I have 3 files (gp-file, midi and DAW project) to keep in synch, because I always fiddle with guitar/drum parts. Which is something I rarely/never do.

So the goal of this file is to eliminate my (perceived) need for GuitarPro in easily and quickly writing down ideas.

### Installation and Usage

Requirements (recommend to use https://reapack.com/): 
- ReaImGui - https://github.com/cfillion/reaimgui

Download script and load it:

    Actions -> Show Actions List -> New Action -> Load ReaScript

### Usage
- Create a Midi take and open the editor
- Run the `MidiTabulature.lua` script

### Keys 

|Key|Function|
|--|--|
|Numbers|Enter note, 1 sec to enter 2 digit numbers|
|Arrows|Move one step or change strings|
|+ / - | double/half note length
|*|(un)dotted note
|/|triplet note
|c| copy notes at cursor and paste after last note
|p| palm mute note

### ToDos / ideas

- ctrl+Right/Left - jump to beginning of next measure or note
- configuration tab
    - keyswitch modifications
- show and edit multiple instruments
    - Loop through all tracks, add trackname as heading
    - Deselect tracks from being shown 
    - Store/Receive metadata about tuning per track
- Copy and paste behind last entered note
- "Insert" add rest, i.e. shift all later notes to the right
- Randomize Velocities
- show if note is palm muted
- add slides
- make ui look nicer


## DrumHumanizer

## GuitarVelocityHumanizer
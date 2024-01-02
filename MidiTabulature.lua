local ctx = reaper.ImGui_CreateContext('Guitar Velocity Humanizer')
local size = reaper.GetAppVersion():match('OSX') and 12 or 14
--local font = reaper.ImGui_CreateFont('sans-serif', size)
--reaper.ImGui_AttachFont(ctx, font)

widgets = {}
window_flags = reaper.ImGui_WindowFlags_TopMost()
local ImGui = {}
for name, func in pairs(reaper) do
  name = name:match('^ImGui_(.+)$')
  if name then ImGui[name] = func end
end
ppqinit=960
ppq = 960
pitch_offset = 0
-- https://boostrobotics.eu/windows-key-codes/
enter=13
rightarrow = 39
uparrow = 38
leftarrow = 37
downarrow= 40
minus = 109
plus = 107
multiply = 106
divide = 111
isdotted=false
istriplet=false
printlog=true
channel = 0
focus_on = 0
palmmute=false
pmnote = 15
lookback_measures = 1
timelastpressed=nil
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()); 
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take);

--https://www.inspiredacoustics.com/en/MIDI_note_numbers_and_center_frequencies


strings = {}
strings[0] = { color = 0xff0000d9,  note = 40, fret='' } -- E -- 6 strings guitar
strings[1] = { color = 0xdaa520d9 , note = 45, fret='' } -- A
strings[2] = { color = 0x008000d9 ,    note = 50, fret='' } -- D
strings[3] = { color = 0x0000ffd9,     note = 55, fret='' } -- G
strings[4] = { color = 0x800080d9 ,   note = 59, fret='' } -- B
strings[5] = { color = 0x4b139ad9,  note = 64, fret='' } -- E


keypad = {}
keypad[reaper.ImGui_Key_Keypad0()]=0
keypad[reaper.ImGui_Key_Keypad1()]=1
keypad[reaper.ImGui_Key_Keypad2()]=2
keypad[reaper.ImGui_Key_Keypad3()]=3
keypad[reaper.ImGui_Key_Keypad4()]=4
keypad[reaper.ImGui_Key_Keypad5()]=5
keypad[reaper.ImGui_Key_Keypad6()]=6
keypad[reaper.ImGui_Key_Keypad7()]=7
keypad[reaper.ImGui_Key_Keypad8()]=8
keypad[reaper.ImGui_Key_Keypad9()]=9
keypad[reaper.ImGui_Key_0()]=0
keypad[reaper.ImGui_Key_1()]=1
keypad[reaper.ImGui_Key_2()]=2
keypad[reaper.ImGui_Key_3()]=3
keypad[reaper.ImGui_Key_4()]=4
keypad[reaper.ImGui_Key_5()]=5
keypad[reaper.ImGui_Key_6()]=6
keypad[reaper.ImGui_Key_7()]=7
keypad[reaper.ImGui_Key_8()]=8
keypad[reaper.ImGui_Key_9()]=9     

-- Get MIDI Note name from a MIDI row.
-- credit: X-Raym_ReaTab Hero.lua. line 511
--[[
number: integer, MIDI row, between 0 and 127
offset: integer, octave offset
flat: bolean, sharp by default, flat if true
idx: bolean, have the number in three digits form as prefix (useful for sorting)
]]--
function GetMIDINoteName(number, offset, flat, idx)

  local output

  if 0 <= number and number <= 127 then

  -- OCTAVE
  local octave = math.floor(number/12)
  if offset then
    octave = octave + math.floor(offset)
  end

  -- KEY
  local key = number % 12

  if key == 0 then key = "C"
  elseif key == 1 then
    if not flat then key = "C#" else key = "Db" end
  elseif key == 2 then key = "D"
  elseif key == 3 then
    if not flat then key = "D#" else key = "Eb" end
  elseif key == 4 then key = "E"
  elseif key == 5 then key = "F"
  elseif key == 6 then
    if not flat then key = "F#" else key = "Gb" end
  elseif key == 7 then key = "G"
  elseif key == 8 then
    if not flat then key = "G#" else key = "Ab" end
  elseif key == 9 then key = "A"
  elseif key == 10 then
    if not flat then key = "A#" else key = "Bb" end
  elseif key == 11 then key = "B"
  else key = nil end

  -- OUTPUT
  output = key .. octave

  if idx then
    local prefix = tostring(number)

    local length = string.len(number)
    if length == 1 then prefix = "00" .. prefix
    elseif length == 2 then prefix = "0" .. prefix end

    output = prefix .. "-" .. output
    end

  end

  return output

end

function dotted_note()
  if isdotted then 
    ppq = ppq/1.5
    isdotted=false 
  else 
    ppq=ppq*1.5 
    isdotted=true  
  end
end

function triplet_note()
  if istriplet then 
    ppq = ppq*3/2
    istriplet=false 
  else 
    ppq=ppq*2/3
    istriplet=true  
  end
end


function HSV(h, s, v, a)
  local r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s, v)
  return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

function draw_grid_measures()
  
  for ppqpos=first_note, (max_ppq+40*ppqinit),ppqinit do


    if ppqpos % (ppqinit) == 0 then

      time = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
      local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(0, time)
      local retval_2, measures_2, cml_2, fullbeats_2, cdenom_2 = reaper.TimeMap2_timeToBeats(0, time + 5) --NOTE: 10 is arbirary, but needed because offset (all_measure_length) is calculated at each new measure (and it can change).
      local beat_number = fullbeats_2 - fullbeats
      local measures_number = measures_2 - measures

      if printlog then
        reaper.ShowConsoleMsg('first_note: ' .. first_note..'\n')
        reaper.ShowConsoleMsg('ppqpos: ' .. ppqpos..'\n'..'\n')
        reaper.ShowConsoleMsg('measures: ' .. measures..'\n'..'\n')
        reaper.ShowConsoleMsg('fullbeats: ' .. fullbeats..'\n'..'\n')
        reaper.ShowConsoleMsg('measures_2: ' .. measures_2..'\n'..'\n')
        reaper.ShowConsoleMsg('fullbeats_2: ' .. fullbeats_2..'\n'..'\n')
        reaper.ShowConsoleMsg('measures_number: ' .. measures_number..'\n'..'\n')
      end

      p1_x = (ppqpos - first_note)/sz_factor + p[1]
      p1_y = p[2]
      p2_x = (ppqpos - first_note)/sz_factor + p[1]
      p2_y = p[2] + 6*sz_y
      col_rgba = 0x00ffffff

      if ppqpos % (ppqinit*4) == 0 then
        ImGui.DrawList_AddLine(draw_list, p1_x, p1_y ,  p2_x,  p2_y, col_rgba, 3.0)
        ImGui.DrawList_AddTextEx(draw_list, font,20,p1_x,p1_y,0xffffffff ,measures+1)
      else
        ImGui.DrawList_AddLine(draw_list, p1_x, p1_y ,  p2_x,  p2_y, col_rgba, 0.3)

      end
    end
  end
  printlog=false
end


function gui()
  -- row_bg_color = 0x333333a6
  -- ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg0(), row_bg_color)

  _, lookback_measures = reaper.ImGui_InputInt(ctx, 'Lookback', lookback_measures, 1)
  play_state = reaper.GetPlayState()
  cursorPos = reaper.MIDI_GetPPQPosFromProjTime(take, GetPlayOrEditCursorPos())

  reaper.ImGui_Text(ctx, ('Note Length: 1/%.1f'):format(ppqinit/ppq*4))
  reaper.ImGui_Text(ctx, ('PPQ: %d'):format(ppq))
  reaper.ImGui_Text(ctx, ('focus_on: %s'):format(focus_on))
  reaper.ImGui_Text(ctx, ('isdotted: %s'):format(tostring(isdotted)))
  reaper.ImGui_Text(ctx, ('istriplet: %s'):format(tostring(istriplet)))
  reaper.ImGui_Text(ctx, ('palmmute: %s'):format(tostring(palmmute)))
  reaper.ImGui_Text(ctx, ('MidiNotename: %s'):format(GetMIDINoteName(40,-1,false,false)))
  reaper.ImGui_Text(ctx, ('cursorPos: %f'):format(cursorPos))

  ImGui.PushItemWidth(ctx, -ImGui.GetFontSize(ctx) * 15)
  draw_list = ImGui.GetWindowDrawList(ctx)




  
  p = {ImGui.GetCursorScreenPos(ctx)}
  sz_factor = 16
  sz_y = 36
  lookback = lookback_measures * ppqinit * 4
  -- cursorPos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPosition())
  
  -- reaper.ShowConsoleMsg('play_state' .. play_state)
  

  -- if printlog then
  --   _cpos = GetPlayOrEditCursorPos()
  --   reaper.ShowConsoleMsg(_cpos ..'\n'.. '\n')
    
  --   local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(0, GetPlayOrEditCursorPos())
  --   local retval_2, measures_2, cml_2, fullbeats_2, cdenom_2 = reaper.TimeMap2_timeToBeats(0, GetPlayOrEditCursorPos() + 5) --NOTE: 10 is arbirary, but needed because offset (all_measure_length) is calculated at each new measure (and it can change).
  --   local beat_number = fullbeats_2 - fullbeats
  --   local measures_number = measures_2 - measures
  --   reaper.ShowConsoleMsg(retval ..'\n'.. measures ..'\n'.. cml ..'\n'.. fullbeats ..'\n'.. cdenom..'\n'..'\n')
  --   reaper.ShowConsoleMsg(retval_2 ..'\n'.. measures_2 ..'\n'.. cml_2 ..'\n'.. fullbeats_2 ..'\n'.. cdenom_2..'\n'..'\n')
  --   reaper.ShowConsoleMsg(beat_number ..'\n'.. measures_number..'\n'..'\n')

  --   printlog=false
  -- end



  first_note = cursorPos - lookback - (cursorPos%ppqinit )


  
 
  
  take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()); 
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take);
  -- Get the current cursor position
  -- cursorPos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPosition())
  max_ppq = first_note
  for j = 0, notes-1 do
    retval, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, j)

    if startppqposOut > max_ppq then max_ppq = startppqposOut end

    if chan <= 5 then 
      strings[chan].fret = pitch - strings[chan].note
      sz_x = ((endppqposOut - startppqposOut) / sz_factor)
      
      x = (startppqposOut - first_note)/sz_factor + p[1]
      y = p[2] + (5-chan)*sz_y
      col = strings[chan].color   
      ImGui.DrawList_AddRect(draw_list, x, y, x + sz_x, y + sz_y, col, 0.0, ImGui.DrawFlags_None(),3.0)
      ImGui.DrawList_AddTextEx(draw_list, font,20,x+sz_x/4,y+sz_y/4,0xffffffff ,strings[chan].fret)
    end
  end

  draw_grid_measures()
  
  p1_x = (cursorPos - first_note)/sz_factor + p[1]
  p1_y = p[2]
  p2_x = (cursorPos - first_note)/sz_factor + p[1]
  p2_y = p[2] + 6*sz_y
  col_rgba = 0xffffffff
  ImGui.DrawList_AddLine(draw_list, p1_x, p1_y ,  p2_x,  p2_y, col_rgba, 1.0)

  -- Draw highlighting for cursor
  if play_state == 0 then
    col = 0xffffc0cb
    x = (cursorPos - first_note)/sz_factor + p[1]
    y = p[2] + (5-focus_on)*sz_y
    sz_x = ((ppq) / sz_factor)

    ImGui.DrawList_AddRect(draw_list, x, y, x + sz_x, y + sz_y, col, 0.0, ImGui.DrawFlags_None(),3.0)
    ImGui.DrawList_AddTextEx(draw_list, font,20,x+sz_x/4,y+sz_y/4,0xffffffff ,fret)
  end
end



function GetPlayOrEditCursorPos()
  local cursor_pos
  if play_state == 1 or play_state == 5 then
    cursor_pos = reaper.GetPlayPosition()
  else
    cursor_pos = reaper.GetCursorPosition()
  end
  return cursor_pos
end


-- Define Content of ReaImgUi
function frame()
  local rv
  -- multiply - dotted note
  if reaper.ImGui_IsKeyPressed(ctx, multiply) then
    dotted_note()
  end

  -- divide - triplet note
  if reaper.ImGui_IsKeyPressed(ctx, divide) then
    triplet_note()
  end
  -- plus minus doubles/halfs the note length
  if reaper.ImGui_IsKeyPressed(ctx, plus) then
    ppq = ppq*2
  end
  if reaper.ImGui_IsKeyPressed(ctx, minus) then
    ppq = ppq/2
  end  
  -- Up down arrows to go through strings/channels
  if reaper.ImGui_IsKeyPressed(ctx, uparrow) then
    channel =math.min(5,channel+1)
    focus_on = channel
  end
  if reaper.ImGui_IsKeyPressed(ctx, downarrow) then
    channel =math.max(0,channel-1)
    focus_on = channel
  end

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) then
    if play_state == 0 then reaper.OnPlayButton() else reaper.OnStopButton() end
  end

  -- Get the current cursor position
  cursorPos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPosition())
  -- Move the cursor
  if reaper.ImGui_IsKeyPressed(ctx, rightarrow) then
    if not(fret == nil) then 
      enter_current_note(fret)
      fret = nil
    end
    projTime = reaper.MIDI_GetProjTimeFromPPQPos(take, cursorPos+ppq)
    reaper.SetEditCurPos(projTime, true, true)
    focus_on=channel
    
  end
  if reaper.ImGui_IsKeyPressed(ctx, leftarrow) then
    projTime = reaper.MIDI_GetProjTimeFromPPQPos(take, cursorPos-ppq)
    reaper.SetEditCurPos(projTime, true, true)
    focus_on=channel
  end

 
  -- Delete note
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Delete()) then
    delete_note()
  end  

  -- Palm Multe note
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_P()) then
    palmmute=true
  end    
  -- for key in   

  now = os.time()
  for k,v in pairs(keypad) do 
    if reaper.ImGui_IsKeyPressed(ctx, k) then
      delete_note()

      

      if timelastpressed == nil then
        fret = v
      else
        if (os.difftime(now, timelastpressed) < 1) then
          fret = tonumber(tostring(fret) .. tostring(v))
        else
          fret = v
        end        
      end

      timelastpressed = now
    end
  end

  if not(timelastpressed == nil) and not(fret == nil) then
    if (os.difftime(now, timelastpressed) > 1) then
      enter_current_note(fret)
      fret = nil
    end
  end
  gui()
end

function delete_note()
  take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()); 
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take);
  -- Get the current cursor position
  cursorPos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPosition())
  for j = 0, notes-1 do
    retval, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, j)

    if (startppqposOut == cursorPos) and (chan == focus_on) then
      reaper.MIDI_DeleteNote(take, j)
    end
  end
end


function enter_current_note(fret)
  reaper.ShowConsoleMsg(strings[focus_on].fret .. "\n")
  reaper.ShowConsoleMsg(tostring(strings[focus_on].fret == '') .. "\n")
  reaper.ShowConsoleMsg(tostring(not(strings[focus_on].fret == '')) .. "\n")

  pitch = strings[focus_on].note + fret + pitch_offset
  reaper.ShowConsoleMsg("pitch: " .. pitch .. "\n")

  -- Set the velocity of the MIDI note (0 to 127)
  velocity = 100

  -- Set the length of the MIDI note in PPQ (one quarter note)
  ppqPos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPosition())
  -- Convert PPQ to project seconds
  projTime = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqPos)

  -- Display the result in the console
  reaper.ShowConsoleMsg("PPQ position: " .. ppqPos .. "\n")
  reaper.ShowConsoleMsg("Project seconds: " .. projTime .. "\n")

  -- Insert the MIDI note
  reaper.ShowConsoleMsg("cursorPos: " .. cursorPos .. "\n")
  reaper.ShowConsoleMsg("cursorPos+length: " .. cursorPos+ppq .. "\n")
  reaper.ShowConsoleMsg("string focus_on: " .. focus_on .. "\n")
  
  reaper.MIDI_InsertNote(take, false, false, cursorPos, cursorPos+ppq, focus_on, pitch, velocity, false )

  if palmmute then
    reaper.MIDI_InsertNote(take, false, false, cursorPos, cursorPos+ppq, 15, pmnote, velocity, false )
  end
  projTime = reaper.MIDI_GetProjTimeFromPPQPos(take, cursorPos+ppq)
  reaper.SetEditCurPos(projTime, true, true)
end

-- initalize ReaImGui
function loop()
  
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_SetNextWindowSize(ctx, 400, 80, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'MidiTabulature', true, window_flags)
  if visible then
    frame()
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)
  
  if open then
    reaper.defer(loop)
  else
    reaper.ImGui_DestroyContext(ctx)
  end
end

reaper.defer(loop)
local ctx = reaper.ImGui_CreateContext('Guitar Velocity Humanizer')
local size = reaper.GetAppVersion():match('OSX') and 12 or 14
local font = reaper.ImGui_CreateFont('sans-serif', size)
reaper.ImGui_AttachFont(ctx, font)

widgets = {}


hard_velo_max = 110
hard_velo_min = 90
soff_velo_max = 13
soff_velo_min = 8
ppq = 960
nudge = 12
downstroke = true

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()); 
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take);


math.randomseed(os.clock()*100000000000)

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  -- table.sort(a, function (a, b) return a>b end)

  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end 


function humanize(hard_velo_max,hard_velo_min,soff_velo_max,soff_velo_min,nudge,downstroke)
  notesordered = {}
  for j = 0, notes-1 do
      retval, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, j)
      if notesordered[startppqposOut] == nil then
          notesordered[startppqposOut] = {}
      end
      notesordered[startppqposOut][pitch] = j
  end
  table.sort(notesordered)

  for key,value in pairs(notesordered) 
  do
      k = 0	
      subarray = notesordered[key]
      table.sort(subarray)
      
      -- initialize random base velocity
      randomval = math.random(hard_velo_min, hard_velo_max);

      
      if downstroke then
          f = nil
      else
          f = function (a, b) return a>b end
      end
      for key,value in pairsByKeys(subarray, f) 
      do
          retval, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, value)
          if sel == true then
              vel = randomval-math.random(soff_velo_min, soff_velo_max)*k;
              NewstartppqposOut = startppqposOut+nudge*4*k
              reaper.MIDI_SetNote(take, value, false, muted, NewstartppqposOut,endppqposOut, chan, pitch, vel, true);
              k=k+1
          end
      end
  end
end

function palm_mute_velos()
  hard_velo_max = 50
  hard_velo_min = 30
  soff_velo_max = 8
  soff_velo_min = 4
end

function normal_velos()
  hard_velo_max = 110
  hard_velo_min = 90
  soff_velo_max = 13
  soff_velo_min = 8
end

-- Define Content of ReaImgUi
function frame()
  local rv

  if reaper.ImGui_Button(ctx, 'Normal Velos') then
    normal_velos()
  end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, 'Palm Mute velos') then
    palm_mute_velos()
  end
  rv, hard_velo_max = reaper.ImGui_InputInt(ctx, 'Hard Max Velocity', hard_velo_max)
  rv, hard_velo_min = reaper.ImGui_InputInt(ctx, 'Hard Min Velocity', hard_velo_min)
  rv, soff_velo_max = reaper.ImGui_InputInt(ctx, 'String Offset Max Velocity', soff_velo_max)
  rv, soff_velo_min = reaper.ImGui_InputInt(ctx, 'String Offset Min Velocity', soff_velo_min)


  if reaper.ImGui_Button(ctx, 'HUMANIZE!!!') then
    humanize(hard_velo_max,hard_velo_min,soff_velo_max,soff_velo_min, nudge, downstroke)
  end

  reaper.ImGui_Text(ctx, 'Advanced Settings')
  rv, ppq = reaper.ImGui_InputInt(ctx, 'Midi Ticks per Quarter', ppq)
  rv, nudge = reaper.ImGui_InputInt(ctx, 'Chord Nudge Length', nudge)
  rv, downstroke = reaper.ImGui_Checkbox(ctx, 'Downstroke?', downstroke)
end

-- initalize ReaImGui
function loop()
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_SetNextWindowSize(ctx, 400, 80, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'Guitar Velocity Humanizer', true)
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
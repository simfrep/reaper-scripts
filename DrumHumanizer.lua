local ctx = reaper.ImGui_CreateContext('Drum Humanizer')
local size = reaper.GetAppVersion():match('OSX') and 12 or 14
local font = reaper.ImGui_CreateFont('sans-serif', size)
reaper.ImGui_AttachFont(ctx, font)

widgets = {}

widgets.multi_component = {
  vector = reaper.new_array({ 1.0,1.0,1.0,1.0 })
}
function dump(o)
  if type(o) == 'table' then
     local s = '{ '
     for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
     end
     return s .. '} '
  else
     return tostring(o)
  end
end



local r = reaper

x0 = 3
y0 = 4
hard_velo_max = 110
hard_velo_min = 90
weak_velo_max = 60
weak_velo_min = 40
ppq = 960
nudge = 12
steps = 4
downstroke = true
      -- Initialize pattern
_vector = {}-- vec4 = { 1.0,1.0,1.0,1.0 }

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


function humanize(pattern,hard_velo_max,hard_velo_min,weak_velo_max,weak_velo_min)
  notesordered = {}
  
  k = 0
  -- Get all notes
  for j = 0, notes-1 do
      retval, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, j)
      -- Filter for selected notes
      if sel == true then
        reaper.ShowConsoleMsg(startppqposOut)
        reaper.ShowConsoleMsg(' ')
        -- reaper.ShowConsoleMsg(sel)
        reaper.ShowConsoleMsg('\n')
        if pattern[(k % #pattern)+1] then
          -- initialize random base velocity
          randomval = math.random(hard_velo_min, hard_velo_max);  
        else
          randomval = math.random(weak_velo_min, weak_velo_max);  
        end
        vel = randomval
        reaper.MIDI_SetNote(take, j, false, muted, startppqposOut,endppqposOut, chan, pitch, vel, true);
        k=k+1
  end
end
  

  for key,value in pairs(notesordered) 
  do    	
      
      -- initialize random base velocity
      randomval = math.random(hard_velo_min, hard_velo_max);          
          
      retval, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, value)
      if sel == true then
          reaper.ShowConsoleMsg(startppqposOut)
          reaper.ShowConsoleMsg(' ')
          reaper.ShowConsoleMsg(value)
          reaper.ShowConsoleMsg('\n')
          -- vel = randomval-math.random(soff_velo_min, soff_velo_max)*k;
          vel = array[(k % #array)+1]
          reaper.MIDI_SetNote(take, value, false, muted, startppqposOut,endppqposOut, chan, pitch, vel, true);
          k=k+1
      end
  end

end

function high_velos()
  hard_velo_max = 110
  hard_velo_min = 90
  weak_velo_max = 60
  weak_velo_min = 40
end

function low_velos()
  hard_velo_max = 70
  hard_velo_min = 50
  weak_velo_max = 40
  weak_velo_min = 20  

end

function generate_pattern(array)
  pattern = {}
  val = true
  for i=1,#array do
      for j=1,array[i] do
          pattern[#pattern+1] = val
      end
      val = not val
  end
end

-- Define Content of ReaImgUi
function frame()

  for i = 1,steps do
    _vector[i]=1
  end
  -- Convert to reaper.array
  vector = reaper.new_array(_vector)
  
  local rv
  reaper.ImGui_Text(ctx, 'Pattern Selection')
  reaper.ImGui_Text(ctx, 'Cycles through selected notes and assigns randomized velocity following alternating hard-soft patterns')
  if r.ImGui_BeginTabBar(ctx, 'MyTabBar', r.ImGui_TabBarFlags_None()) then
    if r.ImGui_BeginTabItem(ctx, '1') then
      reaper.ImGui_Text(ctx, 'One Hard')
      generate_pattern({1})
      r.ImGui_EndTabItem(ctx)
    end
    if r.ImGui_BeginTabItem(ctx, '1-0') then
      reaper.ImGui_Text(ctx, 'One Hard, One Soft (Double Base, Tom rolls)')
      generate_pattern({1,1})
      r.ImGui_EndTabItem(ctx)
    end
    if reaper.ImGui_BeginTabItem(ctx, '1-0-1') then
      reaper.ImGui_Text(ctx, 'Hard, Soft, Hard (Gallop beats)')
      generate_pattern({1,1,1})
      r.ImGui_EndTabItem(ctx)
    end
    if reaper.ImGui_BeginTabItem(ctx, '1-x-1') then
      reaper.ImGui_Text(ctx, 'Hard, x-times Soft, Hard')
      rv, x0 = reaper.ImGui_InputInt(ctx, 'Weak hits', x0)
      generate_pattern({1,x0,1})
      r.ImGui_EndTabItem(ctx)
    end    
    if reaper.ImGui_BeginTabItem(ctx, '1-x') then
      reaper.ImGui_Text(ctx, 'Hard + x-times Soft (Steady cymbals)')
      rv, x0 = reaper.ImGui_InputInt(ctx, 'Weak hits', x0)
      generate_pattern({1,x0})
      r.ImGui_EndTabItem(ctx)
    end
    if reaper.ImGui_BeginTabItem(ctx, '1-x-1-y') then
      reaper.ImGui_Text(ctx, 'Hard + x-times Soft, Hard + y-times Soft')
      rv, x0 = reaper.ImGui_InputInt(ctx, 'Weak hits x', x0)
      rv, y0 = reaper.ImGui_InputInt(ctx, 'Weak hits y', y0)
      generate_pattern({1,x0,1,y0})
      r.ImGui_EndTabItem(ctx)
    end
    if reaper.ImGui_BeginTabItem(ctx, 'Custom') then
      reaper.ImGui_Text(ctx, 'Create custom Hard-Soft pattern.')
      rv, steps = reaper.ImGui_InputInt(ctx, 'Pattern steps', steps)




      r.ImGui_InputDoubleN(ctx, 'Custom pattern', vector,nil,nil,'%.0f')
      generate_pattern(vector)
      r.ImGui_EndTabItem(ctx)
    end

    if reaper.ImGui_Button(ctx, 'HUMANIZE!!!') then
      reaper.ShowConsoleMsg(dump(pattern))
      humanize(pattern,hard_velo_max,hard_velo_min,weak_velo_max,weak_velo_min)
    end
  
  
  
  reaper.ImGui_Text(ctx, '')
  reaper.ImGui_Text(ctx, 'Velocity Selection')
  if reaper.ImGui_Button(ctx, 'High Velos') then
    high_velos()
  end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, 'Low velos') then
    low_velos()
  end

  rv, hard_velo_max = reaper.ImGui_InputInt(ctx, 'Hard Max Velocity', hard_velo_max)
  rv, hard_velo_min = reaper.ImGui_InputInt(ctx, 'Hard Min Velocity', hard_velo_min)
  rv, weak_velo_max = reaper.ImGui_InputInt(ctx, 'Weak Max Velocity', weak_velo_max)
  rv, weak_velo_min = reaper.ImGui_InputInt(ctx, 'Weak Min Velocity', weak_velo_min)


  r.ImGui_EndTabBar(ctx)
end

end

-- initalize ReaImGui
function loop()
  reaper.ImGui_PushFont(ctx, font)
  reaper.ImGui_SetNextWindowSize(ctx, 400, 80, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'Drum Humanizer', true)
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
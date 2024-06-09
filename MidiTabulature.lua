local r = reaper
local ctx = r.ImGui_CreateContext("MidiTabulature")
local size = r.GetAppVersion():match("OSX") and 12 or 14

local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

-- https://gist.github.com/tylerneylon/81333721109155b2d244#file-copy-lua-L29-34
function copy1(obj)
	if type(obj) ~= "table" then
		return obj
	end
	local res = {}
	for k, v in pairs(obj) do
		res[copy1(k)] = copy1(v)
	end
	return res
end
widgets = {}
local ImGui = {}
for name, func in pairs(reaper) do
	name = name:match("^ImGui_(.+)$")
	if name then
		ImGui[name] = func
	end
end
window_flags = ImGui.WindowFlags_TopMost()

tunings = {
	strings = 8,
}
trackTunings = {}
ppqinit = 960
ppq = 960
pitch_offset = 0

isdotted = false
istriplet = false
printlog = true
palmmute = false
tracknames = {}
takes = {}
current_take = nil
current_track = nil

focus_on = 0
max_ppq_end = nil
pmnote = 30

lookback_measures = 1
number_shown_tracks = 3
timelastpressed = nil
pitchmodified = nil
modifiednotedeleted = nil
offset = 25
take = r.MIDIEditor_GetTake(r.MIDIEditor_GetActive())

strings = {}
strings[0] = { color = 0x808000d9, note = 42, fret = "" } -- F# -- 8 strings guitar
strings[1] = { color = 0xC50C4Cd9, note = 47, fret = "" } -- B -- 7 strings guitar
strings[2] = { color = 0xff0000d9, note = 52, fret = "" } -- E -- 6 strings guitar
strings[3] = { color = 0xdaa520d9, note = 57, fret = "" } -- A
strings[4] = { color = 0x008000d9, note = 62, fret = "" } -- D
strings[5] = { color = 0x0000ffd9, note = 67, fret = "" } -- G
strings[6] = { color = 0x800080d9, note = 71, fret = "" } -- B
strings[7] = { color = 0x4b139ad9, note = 76, fret = "" } -- E

keypad = {}
keypad[ImGui.Key_Keypad0()] = 0
keypad[ImGui.Key_Keypad1()] = 1
keypad[ImGui.Key_Keypad2()] = 2
keypad[ImGui.Key_Keypad3()] = 3
keypad[ImGui.Key_Keypad4()] = 4
keypad[ImGui.Key_Keypad5()] = 5
keypad[ImGui.Key_Keypad6()] = 6
keypad[ImGui.Key_Keypad7()] = 7
keypad[ImGui.Key_Keypad8()] = 8
keypad[ImGui.Key_Keypad9()] = 9
keypad[ImGui.Key_0()] = 0
keypad[ImGui.Key_1()] = 1
keypad[ImGui.Key_2()] = 2
keypad[ImGui.Key_3()] = 3
keypad[ImGui.Key_4()] = 4
keypad[ImGui.Key_5()] = 5
keypad[ImGui.Key_6()] = 6
keypad[ImGui.Key_7()] = 7
keypad[ImGui.Key_8()] = 8
keypad[ImGui.Key_9()] = 9

-- Get MIDI Note name from a MIDI row.
-- credit: X-Raym_ReaTab Hero.lua. line 511
--[[
number: integer, MIDI row, between 0 and 127
offset: integer, octave offset
flat: bolean, sharp by default, flat if true
idx: bolean, have the number in three digits form as prefix (useful for sorting)
]]
--
function GetMIDINoteName(number, offset, flat, idx)
	local output

	if 0 <= number and number <= 127 then
		-- OCTAVE
		local octave = math.floor(number / 12)
		if offset then
			octave = octave + math.floor(offset)
		end

		-- KEY
		local key = number % 12

		if key == 0 then
			key = "C"
		elseif key == 1 then
			if not flat then
				key = "C#"
			else
				key = "Db"
			end
		elseif key == 2 then
			key = "D"
		elseif key == 3 then
			if not flat then
				key = "D#"
			else
				key = "Eb"
			end
		elseif key == 4 then
			key = "E"
		elseif key == 5 then
			key = "F"
		elseif key == 6 then
			if not flat then
				key = "F#"
			else
				key = "Gb"
			end
		elseif key == 7 then
			key = "G"
		elseif key == 8 then
			if not flat then
				key = "G#"
			else
				key = "Ab"
			end
		elseif key == 9 then
			key = "A"
		elseif key == 10 then
			if not flat then
				key = "A#"
			else
				key = "Bb"
			end
		elseif key == 11 then
			key = "B"
		else
			key = nil
		end

		-- OUTPUT
		output = key .. octave

		if idx then
			local prefix = tostring(number)

			local length = string.len(number)
			if length == 1 then
				prefix = "00" .. prefix
			elseif length == 2 then
				prefix = "0" .. prefix
			end

			output = prefix .. "-" .. output
		end
	end

	return output
end

function dotted_note()
	if isdotted then
		ppq = ppq / 1.5
		isdotted = false
	else
		ppq = ppq * 1.5
		isdotted = true
	end
end

function palmmute_note()
	if palmmute then
		palmmute = false
	else
		palmmute = true
	end
end
function triplet_note()
	if istriplet then
		ppq = ppq * 3 / 4
		istriplet = false
	else
		ppq = ppq * 4 / 3
		istriplet = true
	end
end

function draw_grid_measures(n)
	if istriplet then
		stepsize = 1280
	else
		stepsize = ppqinit
	end

	next_beat = cursorPos - (cursorPos % stepsize) - stepsize * 4
	for ppqpos = next_beat, (max_ppq + 40 * ppqinit), (stepsize / 4) do
		if ppqpos % stepsize == 0 then
			time = r.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
			local retval, measures, cml, fullbeats, cdenom = r.TimeMap2_timeToBeats(0, time)
			local retval_2, measures_2, cml_2, fullbeats_2, cdenom_2 = r.TimeMap2_timeToBeats(0, time + 5) --NOTE: 10 is arbirary, but needed because offset (all_measure_length) is calculated at each new measure (and it can change).
			local beat_number = fullbeats_2 - fullbeats
			local measures_number = measures_2 - measures

			p1_x = (ppqpos - first_note) / sz_factor + p[1] + offset
			p1_y = p[2] + (n - 1) * (sz_y * tunings.strings + offset)
			p2_x = (ppqpos - first_note) / sz_factor + p[1] + offset
			p2_y = p[2] + tunings.strings * sz_y + (n - 1) * (sz_y * tunings.strings + offset)

			visible = true

			if p2_x < p[1] + offset then
				visible = false
			end
			col_rgba = 0x00ffffff

			if visible then
				if istriplet then
					if ppqpos % (stepsize * 3) == 0 then
						ImGui.DrawList_AddLine(draw_list, p1_x, p1_y, p2_x, p2_y, col_rgba, 2.0)
						ImGui.DrawList_AddTextEx(draw_list, font, 20, p1_x, p1_y, 0xffffffff, measures + 1)
					else
						ImGui.DrawList_AddLine(draw_list, p1_x, p1_y, p2_x, p2_y, col_rgba, 0.3)
					end
				else
					if ppqpos % (stepsize * 4) == 0 then
						ImGui.DrawList_AddLine(draw_list, p1_x, p1_y, p2_x, p2_y, col_rgba, 2.0)
						ImGui.DrawList_AddTextEx(draw_list, font, 20, p1_x, p1_y, 0xffffffff, measures + 1)
					else
						ImGui.DrawList_AddLine(draw_list, p1_x, p1_y, p2_x, p2_y, col_rgba, 0.3)
					end
				end
			end
		end
	end
end

function gui()
	if ImGui.BeginTabBar(ctx, "MyTabBar", ImGui.TabBarFlags_None()) then
		if ImGui.BeginTabItem(ctx, "Tabulature") then
			if ImGui.BeginListBox(ctx, "", -FLT_MIN) then
				for n, v in ipairs(tracknames) do
					local is_selected = current_track == n
					if ImGui.Selectable(ctx, v, is_selected) then
						current_track = n
						current_trackname = v
						current_take = takes[v]
					end

					-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
					if is_selected then
						trackname = v
						take = takes[trackname]
						ImGui.SetItemDefaultFocus(ctx)
						if ImGui.Button(ctx, "Standard") then
							set_std_tuning(n)
						end
						ImGui.SameLine(ctx)
						if ImGui.Button(ctx, "Drop") then
							set_std_tuning(n)
							trackTunings[n][0].note = trackTunings[n][0].note - 2
						end
						ImGui.SameLine(ctx)
						if ImGui.Button(ctx, "Drums") then
							for i = 0, tunings.strings - 1 do
								trackTunings[n][i].note = 0
							end
						end
						ImGui.SameLine(ctx)
						for i = 0, tunings.strings - 1 do
							-- Arrow buttons with Repeater
							ImGui.SameLine(ctx)
							stringname = GetMIDINoteName(trackTunings[n][i].note, -2, false, false)
							r.ImGui_Text(ctx, ("%s(%d)"):format(stringname, trackTunings[n][i].note))
						end
						_, trackTunings[n][0].note, trackTunings[n][1].note, trackTunings[n][2].note, trackTunings[n][3].note =
							r.ImGui_SliderInt4(
								ctx,
								"1",
								trackTunings[n][0].note,
								trackTunings[n][1].note,
								trackTunings[n][2].note,
								trackTunings[n][3].note,
								36,
								100
							)
						_, trackTunings[n][4].note, trackTunings[n][5].note, trackTunings[n][6].note, trackTunings[n][7].note =
							r.ImGui_SliderInt4(
								ctx,
								"2",
								trackTunings[n][4].note,
								trackTunings[n][5].note,
								trackTunings[n][6].note,
								trackTunings[n][7].note,
								36,
								100
							)
					end
				end
				ImGui.EndListBox(ctx)
			end
			play_state = r.GetPlayState()
			cursorPos = r.MIDI_GetPPQPosFromProjTime(take, GetPlayOrEditCursorPos())
			sz_factor = 8
			sz_y = 36
			lookback = lookback_measures * ppqinit * 4
			first_note = cursorPos - lookback
			max_ppq = first_note
			max_ppq_end = first_note
			if ImGui.CollapsingHeader(ctx, "DebugInfo") then
				ImGui.Text(ctx, ("Note Length: 1/%.1f"):format(ppqinit / ppq * 4))
				ImGui.Text(ctx, ("PPQ: %d"):format(ppq))
				ImGui.Text(ctx, ("focus_on: %s"):format(focus_on))
				ImGui.Text(ctx, ("isdotted: %s"):format(tostring(isdotted)))
				ImGui.Text(ctx, ("istriplet: %s"):format(tostring(istriplet)))
				ImGui.Text(ctx, ("palmmute: %s"):format(tostring(palmmute)))
				ImGui.Text(ctx, ("MidiNotename: %s"):format(GetMIDINoteName(40, -2, false, false)))
				ImGui.Text(ctx, ("cursorPos: %f"):format(cursorPos))
				ImGui.Text(ctx, ("first_note: %f"):format(first_note))
				ImGui.Text(ctx, ("max_ppq: %f"):format(max_ppq))
				ImGui.Text(ctx, ("current_track: %s"):format(current_track))
			end

			p = { ImGui.GetCursorScreenPos(ctx) }
			draw_list = ImGui.GetWindowDrawList(ctx)

			for n, v in ipairs(tracknames) do
				if n <= number_shown_tracks then
					-- draw string tunings
					for j = 0, tunings.strings - 1 do
						stringname = GetMIDINoteName(trackTunings[n][j].note, -2, false, false)
						x = p[1]
						y = p[2]
							+ (tunings.strings - 1 - j) * sz_y
							+ sz_y / 4
							+ (n - 1) * (sz_y * tunings.strings + offset)
						ImGui.DrawList_AddTextEx(draw_list, font, 20, x, y, 0xffffffff, stringname)
						-- draw separator
						p1_x = p[1] + offset
						p1_y = p[2] + (n - 1) * (sz_y * tunings.strings + offset)

						p2_x = p[1] + offset
						p2_y = p[2] + tunings.strings * sz_y + (n - 1) * (sz_y * tunings.strings + offset)

						col_rgba = 0x00ffffff
						ImGui.DrawList_AddLine(draw_list, p1_x, p1_y, p2_x, p2_y, col_rgba, 2.0)
					end
					trackname = v
					take = takes[trackname]
					--take = r.MIDIEditor_GetTake(r.MIDIEditor_GetActive())
					retval, notes, ccs, sysex = r.MIDI_CountEvts(take)
					ImGui.PushItemWidth(ctx, -ImGui.GetFontSize(ctx) * 15)

					for j = 0, notes - 1 do
						retval, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = r.MIDI_GetNote(take, j)
						if startppqposOut > max_ppq then
							max_ppq = startppqposOut
						end
						if endppqposOut > max_ppq_end then
							max_ppq_end = endppqposOut
						end
						if chan <= tunings.strings - 1 then
							trackTunings[n][chan].fret = pitch - trackTunings[n][chan].note
							sz_x = ((endppqposOut - startppqposOut) / sz_factor)
							x = (startppqposOut - first_note) / sz_factor + p[1] + offset
							y = p[2] + (tunings.strings - 1 - chan) * sz_y + (n - 1) * (sz_y * tunings.strings + offset)

							col = trackTunings[n][chan].color

							if x + sz_x > p[1] + offset then
								_x = math.max(x, p[1] + offset)
								ImGui.DrawList_AddRectFilled(
									draw_list,
									_x,
									y,
									x + sz_x,
									y + sz_y,
									col,
									0.0,
									ImGui.DrawFlags_None()
								)
								ImGui.DrawList_AddRect(
									draw_list,
									_x,
									y,
									x + sz_x,
									y + sz_y,
									0xffffffff,
									0.0,
									ImGui.DrawFlags_None(),
									1.0
								)
							end
							if x + sz_x / 4 > p[1] + offset then
								ImGui.DrawList_AddTextEx(
									draw_list,
									font,
									20,
									x + sz_x / 4,
									y + sz_y / 4,
									0xffffffff,
									trackTunings[n][chan].fret
								)
							end
						end
						draw_grid_measures(n)
					end
				end
			end

			if current_track then
				-- draw whilte line at current cursor
				p1_x = (cursorPos - first_note) / sz_factor + p[1] + offset
				p1_y = p[2] + (current_track - 1) * (sz_y * tunings.strings + offset)
				p2_x = (cursorPos - first_note) / sz_factor + p[1] + offset
				p2_y = p[2] + tunings.strings * sz_y + (current_track - 1) * (sz_y * tunings.strings + offset)
				col_rgba = 0xffffffff
				ImGui.DrawList_AddLine(draw_list, p1_x, p1_y, p2_x, p2_y, col_rgba, 3.0)

				-- Draw highlighting box for cursor
				if play_state == 0 then
					col = 0xffffc0cb
					x = (cursorPos - first_note) / sz_factor + p[1] + offset
					y = p[2]
						+ (tunings.strings - 1 - focus_on) * sz_y
						+ (current_track - 1) * (sz_y * tunings.strings + offset)
					sz_x = (ppq / sz_factor)

					ImGui.DrawList_AddRect(draw_list, x, y, x + sz_x, y + sz_y, col, 0.0, ImGui.DrawFlags_None(), 3.0)
					ImGui.DrawList_AddTextEx(draw_list, font, 20, x + sz_x / 4, y + sz_y / 4, 0xffffffff, fret)
				end
			end
			ImGui.EndTabItem(ctx)
		end
		if ImGui.BeginTabItem(ctx, "Configuration") then
			configurationtab()
			ImGui.EndTabItem(ctx)
		end
		ImGui.EndTabBar(ctx)
	end
end

function set_std_tuning(n)
	if tunings.strings == 8 then
		trackTunings[n][0].note = 42
		trackTunings[n][1].note = 47
		trackTunings[n][2].note = 52
		trackTunings[n][3].note = 57
		trackTunings[n][4].note = 62
		trackTunings[n][5].note = 67
		trackTunings[n][6].note = 71
		trackTunings[n][7].note = 76
	end
end

function configurationtab()
	_, lookback_measures = ImGui.InputInt(ctx, "Lookback", lookback_measures, 1)
	_, number_shown_tracks = ImGui.InputInt(ctx, "Number Shown Tracks", number_shown_tracks, 1)

	ImGui.SeparatorText(ctx, "Tuning")

	_, tunings.strings = ImGui.InputInt(ctx, "Visible Strings", tunings.strings, 1)
	if tunings.strings < 4 then
		tunings.strings = 4
	end
	if tunings.strings > 9 then
		tunings.strings = 9
	end
	if ImGui.Button(ctx, "Standard") then
		set_std_tuning()
	end
	ImGui.SameLine(ctx)
	if ImGui.Button(ctx, "Drop") then
		set_std_tuning()
		strings[0].note = strings[0].note - 2
	end
	ImGui.SameLine(ctx)
	if ImGui.Button(ctx, "Drums") then
		for i = 0, tunings.strings - 1 do
			strings[i].note = 0
		end
	end
	for i = 0, tunings.strings - 1 do
		stringname = GetMIDINoteName(strings[i].note, -2, false, false)
		_, strings[i].note = ImGui.InputInt(ctx, stringname, strings[i].note, 1)
	end
end

function GetPlayOrEditCursorPos()
	local cursor_pos
	if play_state == 1 or play_state == 5 then
		cursor_pos = r.GetPlayPosition()
	else
		cursor_pos = r.GetCursorPosition()
	end
	return cursor_pos
end

function keyboard_events(take)
	-- multiply - dotted note
	if ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadMultiply()) then
		dotted_note()
		modify_note(take)
	end

	-- divide - triplet note
	if ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadDivide()) then
		triplet_note()
		modify_note(take)
	end
	-- plus minus doubles/halfs the note length
	if ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadAdd()) then
		ppq = ppq * 2
		modify_note(take)
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadSubtract()) then
		ppq = ppq / 2
		modify_note(take)
	end
	-- Up down arrows to go through strings/channels
	if ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow()) then
		if not (fret == nil) then
			enter_current_note(take, fret)
			fret = nil
		end
		focus_on = math.min(7, focus_on + 1)
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow()) then
		if not (fret == nil) then
			enter_current_note(take, fret)
			fret = nil
		end
		focus_on = math.max(0, focus_on - 1)
	end

	if ImGui.IsKeyPressed(ctx, ImGui.Key_Space()) then
		if play_state == 0 then
			r.OnPlayButton()
		else
			r.OnStopButton()
		end
	end

	-- Move the cursor
	if ImGui.IsKeyPressed(ctx, ImGui.Key_RightArrow()) then
		-- Get the current cursor position
		cursorPos = r.MIDI_GetPPQPosFromProjTime(take, r.GetCursorPosition())
		if not (fret == nil) then
			enter_current_note(take, fret)
			fret = nil
		end
		projTime = r.MIDI_GetProjTimeFromPPQPos(take, cursorPos + ppq)
		r.SetEditCurPos(projTime, true, true)
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_LeftArrow()) then
		-- Get the current cursor position
		cursorPos = r.MIDI_GetPPQPosFromProjTime(take, r.GetCursorPosition())
		if not (fret == nil) then
			enter_current_note(take, fret)
			fret = nil
		end
		projTime = r.MIDI_GetProjTimeFromPPQPos(take, cursorPos - ppq)
		r.SetEditCurPos(projTime, true, true)
	end

	-- Delete note
	if ImGui.IsKeyPressed(ctx, ImGui.Key_Delete()) then
		delete_note(take)
	end

	-- Palm Multe note
	if ImGui.IsKeyPressed(ctx, ImGui.Key_P()) then
		palmmute_note()
		modify_note(take)
	end

	if ImGui.IsKeyPressed(ctx, ImGui.Key_C()) then
		copy_notes(take)
	end

	-- Enter
	if (ImGui.IsKeyPressed(ctx, ImGui.Key_Enter())) or (ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter())) then
		timelastpressed = nil
		if not (fret == nil) then
			enter_current_note(take, fret)
			fret = nil
		end
	end

	now = os.time()
	for k, v in pairs(keypad) do
		if ImGui.IsKeyPressed(ctx, k) then
			delete_note(take)
			if timelastpressed == nil then
				fret = v
			else
				if os.difftime(now, timelastpressed) < 1 then
					fret = tonumber(tostring(fret) .. tostring(v))
				else
					fret = v
				end
			end
			timelastpressed = now
		end
	end

	if not (timelastpressed == nil) and not (fret == nil) then
		if os.difftime(now, timelastpressed) > 1 then
			enter_current_note(take, fret)
			fret = nil
		end
	end

	if not (pitchmodified == nil) and (modifiednotedeleted == 1) then
		fret = pitchmodified - trackTunings[current_track][focus_on].note - pitch_offset
		enter_current_note(take, fret)
		modifiednotedeleted = nil
		fret = nil
	end
end

function delete_note(take)
	retval, notes, ccs, sysex = r.MIDI_CountEvts(take)
	-- Get the current cursor position
	cursorPos = r.MIDI_GetPPQPosFromProjTime(take, r.GetCursorPosition())
	for j = 0, notes - 1 do
		retval, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = r.MIDI_GetNote(take, j)

		if (startppqposOut == cursorPos) and (chan == focus_on) then
			r.MIDI_DeleteNote(take, j)
		end
	end
end

function modify_note(take)
	retval, notes, ccs, sysex = r.MIDI_CountEvts(take)
	-- Get the current cursor position
	cursorPos = r.MIDI_GetPPQPosFromProjTime(take, r.GetCursorPosition())
	for j = 0, notes - 1 do
		_, _, _, _startppqpos, _, _chan, _pitch, _ = r.MIDI_GetNote(take, j)

		if (_startppqpos == cursorPos) and (_chan == focus_on) then
			-- use this variable to reenter note on the next frame
			modifiednotedeleted = 1
			pitchmodified = _pitch
			r.MIDI_DeleteNote(take, j)
			break
		end
	end
end

function copy_notes(take)
	retval, notes, ccs, sysex = r.MIDI_CountEvts(take)
	-- Get the current cursor position
	cursorPos = r.MIDI_GetPPQPosFromProjTime(take, r.GetCursorPosition())
	for j = 0, notes - 1 do
		_, _, _, _startppqpos, _endppqpos, _chan, _pitch, _velo = r.MIDI_GetNote(take, j)

		if _startppqpos == cursorPos then
			r.MIDI_InsertNote(
				take,
				false,
				false,
				max_ppq_end,
				max_ppq_end + _endppqpos - _startppqpos,
				_chan,
				_pitch,
				_velo,
				false
			)
		end
	end
	projTime = r.MIDI_GetProjTimeFromPPQPos(take, cursorPos + _endppqpos - _startppqpos)
	r.SetEditCurPos(projTime, true, true)
end

function enter_current_note(take, fret)
	pitch = trackTunings[current_track][focus_on].note + fret + pitch_offset
	-- Set the velocity of the MIDI note (0 to 127)
	velocity = 100
	-- Set the length of the MIDI note in PPQ (one quarter note)
	ppqPos = r.MIDI_GetPPQPosFromProjTime(take, r.GetCursorPosition())
	-- Convert PPQ to project seconds
	projTime = r.MIDI_GetProjTimeFromPPQPos(take, ppqPos)
	-- Insert the MIDI note
	r.MIDI_InsertNote(take, false, false, cursorPos, cursorPos + ppq, focus_on, pitch, velocity, false)
	if palmmute then
		r.MIDI_InsertNote(take, false, false, cursorPos, cursorPos + ppq, 15, pmnote, velocity, false)
	end
	-- reset value
	timelastpressed = nil
end

-- Function to check if a take is a MIDI take
function IsMIDITake(take)
	if not take then
		return false
	end

	-- Get the TAKEFX_INST chunk
	local _, chunk = r.GetItemStateChunk(r.GetMediaItemTake_Item(take), "", false)

	-- Check if the TAKEFX_INST chunk contains "MIDI"
	return string.find(chunk, "MIDI") ~= nil
end

-- initalize ReaImGui
function loop()
	ImGui.PushFont(ctx, font)
	ImGui.SetNextWindowSize(ctx, 400, 80, ImGui.Cond_FirstUseEver())
	local visible, open = ImGui.Begin(ctx, "MidiTabulature", true, window_flags)
	if visible then
		if play_state == 0 then
			proj = r.EnumProjects(-1)

			tracknames = {}
			_trackcount = 0
			for trackidx = 0, r.CountTracks(proj) - 1 do
				if _trackcount < number_shown_tracks then
					track = r.GetTrack(proj, trackidx)
					_, trackname = r.GetTrackName(track)
					mediaitem = r.GetTrackMediaItem(track, 0)
					if mediaitem then
						take = r.GetTake(mediaitem, 0)
						if IsMIDITake(take) then
							if not current_track then
								current_track = 1
								current_trackname = trackname
								current_take = take
							end
							table.insert(tracknames, trackname)
							takes[trackname] = take
							_trackcount = _trackcount + 1
						end
					end
				end
			end

			-- initialize trackTunings
			if printlog then
				for trackidx = 0, _trackcount do
					trackTunings[trackidx] = copy1(strings)
				end
			end
			printlog = false
		end

		keyboard_events(current_take)
		gui()
		ImGui.End(ctx)
	end
	ImGui.PopFont(ctx)

	if open then
		r.defer(loop)
	else
		ImGui.DestroyContext(ctx)
	end
end

r.defer(loop)

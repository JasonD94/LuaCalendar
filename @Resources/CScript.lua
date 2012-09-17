-- LuaCalendar v3.6 beta 2 by Smurfier (smurfier20@gmail.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
	Set={ -- Retrieve Measure Settings
		DPref = SELF:GetOption('DayPrefix', 'l'),
		HLWeek = SELF:GetNumberOption('HideLastWeek', 0) > 0,
		LZer = SELF:GetNumberOption('LeadingZeroes', 0) > 0,
		MPref = SELF:GetOption('MeterPrefix', 'mDay'),
		SMon = SELF:GetNumberOption('StartOnMonday', 0) > 0,
		LText = SELF:GetOption('LabelText', '{MName}, {Year}'),
		NFormat = SELF:GetOption('NextFormat', '{day}: {desc}'),
	}
	Old, cMonth = {Day = 0, Month = 0, Year = 0}, {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
	StartDay, Month, Year, InMonth, Error = 0, 0, 0, true, false
	-- Weekday labels text
	local Labels = Delim('DayLabels', 'S|M|T|W|T|F|S')
	if #Labels < 7 then -- Check for Error
		Labels = ErrMsg({'S', 'M', 'T', 'W', 'T', 'F', 'S'}, 'Invalid DayLabels string')
	end
	for a = 1, 7 do
		SKIN:Bang('!SetOption', Set.DPref .. a, 'Text', Labels[Set.SMon and (a % 7 + 1) or a])
	end
	-- Localization
	MLabels = Delim('MonthLabels')
	if SELF:GetNumberOption('UseLocalMonths', 0) > 0 then
		os.setlocale('', 'time')
		for a = 1, 12 do
			MLabels[a] = os.date('%B', os.time{year = 2000, month = a, day = 1})
		end
	end
	-- Holiday File
	hFile = {}
	for _, FileName in ipairs(Delim('EventFile')) do
		local File = io.open(SKIN:MakePathAbsolute(FileName), 'r')
		if not File then -- File could not be opened.
			ErrMsg(0, 'File Read Error', FileName:match('[^/\\]+$'))
		else -- File is open.
			local text = File:read('*all'):gsub('<!%-%-.-%-%->', '') -- Read in file contents and remove comments.
			File:close()
			if not text:lower():match('<eventfile.->.-</eventfile>') then
				ErrMsg(0, 'Invalid Event File', FileName:match('[^/\\]+$'))
			else
				local eFile, eSet = {}, setmetatable({}, { __call = function(input)
					local tbl = {}
					for _, column in ipairs(input) do
						for key, value in pairs(column) do
							tbl[key] = value
						end
					end
					return tbl
				end})
				local default = {month = '', day = '', year = false, descri = '', title = false, color = false, ['repeat'] = false, multip = 1, annive = false,}
				local sw = setmetatable({ -- Define Event File tags
					set = function(x) table.insert(eSet, Keys(x)) end,
					['/set'] = function() table.remove(eSet, #eSet) end,
					eventfile = function(x) eFile = Keys(x) end,
					['/eventfile'] = function() eFile = {} end,
					event = function(x)
						local Tmp, dSet, tbl = Keys(x), eSet(), {}
						for k, v in pairs(default) do tbl[k] = Tmp[k] or dSet[k] or eFile[k] or v end
						table.insert(hFile, tbl)
					end,
				},
				{ __index = function(tbl, tag) ErrMsg(0, 'Invalid Event Tag', tag, 'in', FileName:match('[^/\\]+$')) return function() end end,})

				for tag in text:gmatch('%b<>') do
					sw[tag:lower():match('^<([^%s>]+)')](tag)
				end
			end
		end
	end
end -- Initialize

function Update()
	Time = os.date('*t')
	
	-- If in the current month or if browsing and Month changes to that month, set to Real Time.
	if (InMonth and Month ~= Time.month) or ((not InMonth) and Month == Time.month and Year == Time.year) then
		Move()
	end
	
	if Month ~= Old.Month or Year ~= Old.Year then -- Recalculate and Redraw if Month and/or Year changes.
		Old = {Month=Month, Year=Year, Day=Time.day}
		StartDay = rotate(tonumber(os.date('%w', os.time{year = Year, month = Month, day = 1})))
		cMonth[2] = 28 + ((((Year % 4) == 0 and (Year % 100) ~= 0) or (Year % 400) == 0) and 1 or 0) -- Check for Leap Year.
		Events()
		Draw()
	elseif Time.day ~= Old.Day then -- Redraw if Today changes.
		Old.Day = Time.day
		Draw()
	end
	
	return Error and 'Error!' or 'Success!'
end -- Update

function Events() -- Parse Events table.
	Hol = setmetatable({}, { __call = function(self) -- Returns a list of events
		local Evns = {}
	
		for day = InMonth and Time.day or 1, cMonth[Month] do -- Parse through month days to keep days in order.
			if self[day] then
				local tbl = {day = day, desc = table.concat(self[day]['text'], ',')}
				local event = Set.NFormat:gsub('(%b{})', function(variable)
					return tbl[variable:lower():match('{(.+)}')] or ErrMsg('', 'Invalid NextFormat variable', variable)
				end)
				table.insert(Evns, event)
			end
		end
	
		return table.concat(Evns, '\n')
	end})

	local AddEvn = function(day, desc, color, ann)
		desc = string.format(desc, ann and ' (' .. ann .. ') ' or '')
		if Hol[day] then
			table.insert(Hol[day]['text'], desc)
			table.insert(Hol[day]['color'], color)
		else
			Hol[day] = {text = {desc}, color = setmetatable({color}, { __call = function(tbl)
				local color
	
				for _, value in ipairs(tbl) do
					if color then
						if color ~= value then
							return ''
						end
					else
						color = value
					end
				end
				
				return color
			end,}),}
		end
	end
	
	for _, event in ipairs(hFile) do
		local eMonth = SKIN:ParseFormula(Vars(event.month, event.descri))
		if  eMonth == Month or event['repeat'] then
			local day = SKIN:ParseFormula(Vars(event.day, event.descri)) or ErrMsg(0, 'Invalid Event Day', event.day, 'in', event.descri)
			local desc = event.descri .. '%s' .. (event.title and ' -' .. event.title or '')
			local rswitch = setmetatable({
				week = function()
					if eMonth and event.year and day then
						local stamp = os.time{month = eMonth, day = day, year = event.year,}
						local test = os.time{month = Month, day = day, year = Year,} >= stamp
						local mstart = os.time{month = Month, day = 1, year = Year,}
						local multi = event.multip * 604800
						local first = mstart + ((stamp - mstart) % multi)
						for a = 0, 4 do
							local tstamp = first + a * multi
							local temp = os.date('*t', tstamp)
							if temp.month == Month and test then
								AddEvn(temp.day, desc, event.color, event.annive and ((tstamp - stamp) / multi + 1) or false)
							end
						end
					end
				end,
				year = function()
					local test = (event.year and event.multip > 1) and ((Year - event.year) % event.multip) or 0
					if eMonth == Month and test == 0 then
						AddEvn(day, desc, event.color, event.annive and (Year - event.year / event.multip) or false)
					end
				end,
				month = function()
					local ydiff = Year - event.year - 1
					local mdiff = ydiff == -1 and (Month - eMonth) or ((12 - eMonth) + Month + (ydiff * 12))
					if eMonth and event.year then
						if Year >= event.year then
							local estamp = os.time{year = event.year, month = eMonth, day = 1,}
							local mstart = os.time{year = Year, month = Month, day = 1,}

							if (mdiff % event.multip) == 0 and mstart >= estamp then
								AddEvn(day, desc, event.color, event.annive and (mdiff / event.multip + 1) or false)
							end
						end
					else
						AddEvn(day, desc, event.color, event.annive and (mdiff + 1) or false)
					end
				end,
				},
				{ __index = function() if event.year == Year then AddEvn(day, desc, event.color) end return function() end end })
			
			rswitch[event['repeat']:lower()]()
		end
	end
end -- Events

function Draw() -- Sets all meter properties and calculates days.
	local LastWeek = Set.HLWeek and math.ceil((StartDay + cMonth[Month]) / 7) < 6
	
	for wday = 1, 7 do -- Set Weekday Labels styles.
		local Styles = {'LblTxtSty'}
		if wday == 1 then
			table.insert(Styles, 'LblTxtStart')
		end
		if rotate(Time.wday - 1) == (wday - 1) and InMonth then
			table.insert(Styles, 'LblCurrSty')
		end
		SKIN:Bang('!SetOption', Set.DPref .. wday, 'MeterStyle', table.concat(Styles, '|'))
	end
	
	for meter = 1, 42 do -- Calculate and set day meters.
		local day, event, color, Styles = (meter - StartDay), '', '', {'TextStyle'}
		if meter == 1 then
			table.insert(Styles, 'FirstDay')
		elseif (meter % 7) == 1 then
			table.insert(Styles, 'NewWk')
		end
		-- Holiday ToolTip and Style
		if day > 0 and day <= cMonth[Month] and Hol[day] then
			event = table.concat(Hol[day]['text'], '\n')
			table.insert(Styles, 'HolidayStyle')
			color = Hol[day]['color']()
		end
		
		if (Time.day + StartDay) == meter and InMonth then -- Current Day.
			table.insert(Styles, 'CurrentDay')
		elseif meter > 35 and LastWeek then -- Last week of the month.
			table.insert(Styles, 'LastWeek')
		elseif day < 1 then -- Previous month.
			day = day + cMonth[Month == 1 and 12 or (Month - 1)]
			table.insert(Styles, 'PreviousMonth')
		elseif day > cMonth[Month] then -- Following month.
			day = day - cMonth[Month]
			table.insert(Styles, 'NextMonth')
		elseif (meter % 7) == 0 or (meter % 7) == (Set.SMon and 6 or 1) then -- Weekends.
			table.insert(Styles, 'WeekendStyle')
		end
		
		for k,v in pairs{ -- Define meter properties.
			Text = LZero(day),
			MeterStyle = table.concat(Styles, '|'),
			ToolTipText = event,
			FontColor = color,
		} do SKIN:Bang('!SetOption', Set.MPref .. meter, k, v) end
	end
	-- Define skin variables.
	for k, v in pairs{
		ThisWeek = math.ceil((Time.day + StartDay) / 7),
		Week = rotate(Time.wday - 1),
		Today = LZero(Time.day),
		Month = MLabels[Month] or Month,
		Year = Year,
		MonthLabel = Vars(Set.LText, 'MonthLabel'),
		LastWkHidden = LastWeek and 1 or 0,
		NextEvent = Hol(),
	} do SKIN:Bang('!SetVariable', k, v) end
end -- Draw

function Move(value) -- Move calendar through the months.
	local sw = setmetatable({
		['1'] = function() Month, Year = (Month % 12 + 1), Month == 12 and (Year + 1) or Year end, -- Forward
		['-1'] = function() Month, Year = Month == 1 and 12 or (Month - 1), Month == 1 and (Year - 1) or Year end, -- Back
		['0'] = function() Month, Year = Time.month, Time.year end, -- Home
	},
	{ __index = function() ErrMsg(0, 'Invalid Move parameter', value) return function() end end, })
	sw[tostring(value or 0)]()
	InMonth = Month == Time.month and Year == Time.year
	SKIN:Bang('!SetVariable', 'NotCurrentMonth', InMonth and 0 or 1)
end -- Move

--===== These Functions are used to make life easier =====

function Easter() -- Returns a timestamp representing easter of the current year.
	local a, b, c, h, L, m = (Year % 19), math.floor(Year / 100), (Year % 100), 0, 0, 0
	local d, e, f, i, k = math.floor(b/4), (b % 4), math.floor((b + 8) / 25), math.floor(c / 4), (c % 4)
	h = (19 * a + b - d - math.floor((b - f + 1) / 3) + 15) % 30
	L = (32 + 2 * e + 2 * i - h - k) % 7
	m = math.floor((a + 11 * h + 22 * L) / 451)
	
	return os.time{month = math.floor((h + L - 7 * m + 114) / 31), day = ((h + L - 7 * m + 114) % 31 + 1), year = Year}
end -- Easter

function BuiltInEvents(default) -- Makes allowance for events that require calculation.
	local tbl = default or {}
	
	local SetVar = function(name, timestamp)
		local temp = os.date('*t', timestamp)
		tbl[name:lower() .. 'month'] = temp.month
		tbl[name:lower() .. 'day'] = temp.day
	end
	
	local sEaster = Easter()
	local day = 86400
	SetVar('easter', sEaster)
	SetVar('goodfriday', sEaster - 2 * day)
	SetVar('ashwednesday', sEaster - 46 * day)
	SetVar('mardigras', sEaster - 47 * day)
	
	return tbl
end -- BuiltInEvents

function Vars(line, source) -- Makes allowance for {Variables}
	local D, W = {sun = 0, mon = 1, tue = 2, wed = 3, thu = 4, fri = 5, sat = 6}, {first = 0, second = 1, third = 2, fourth = 3, last = 4}
	local tbl = BuiltInEvents{mname = MLabels[Month] or Month, year = Year, today = LZero(Time.day), month = Month}
	
	return tostring(line):gsub('%b{}', function(variable)
		local strip = variable:lower():match('{(.+)}')
		local v1, v2 = strip:match('(.+)(...)')
		if tbl[strip] then -- Regular variable.
			return tbl[strip]
		elseif W[v1 or ''] and D[v2 or ''] then -- Variable day.
			local L, wD = (36 + D[v2]-StartDay), rotate(D[v2])
			return W[v1] < 4 and (wD + 1 - StartDay + (StartDay > wD and 7 or 0) + 7 * W[v1]) or (L - math.ceil((L - cMonth[Month]) / 7) * 7)
		else -- Error
			return ErrMsg(0, 'Invalid Variable', variable, source and 'in ' .. source or '')
		end
	end)
end -- Vars

function rotate(value) -- Makes allowance for StartOnMonday.
	return Set.SMon and ((value - 1 + 7) % 7) or value
end -- rotate

function LZero(value) -- Used to make allowance for LeadingZeros
	return Set.LZer and string.format('%02d', value) or value
end -- LZero

function Keys(line, default) -- Converts Key="Value" sets to a table
	local tbl = default or {}
	
	local funcs = setmetatable({
		color = function(input)
			input = input:gsub('%s', '')
			if input:len() == 0 then
				return nil
			elseif input:match(',') then
				local hex = {}
	
				for rgb in input:gmatch('%d+') do
					table.insert(hex, string.format('%02X', tonumber(rgb)))
				end
	
				return table.concat(hex)
			else
				return input
			end
		end,
		multip = function(input) return tonumber(input) and tonumber(string.format('%.0f', input)) or nil end,
		annive = function(input) return tonumber(input) and (tonumber(input) > 0) or nil end,
		year = function(input) return tonumber(input) end,
	},
	{ __index = function() return function(val) return tonumber(val) or val end end,})
	
	for key, value in line:gmatch('(%a+)=(%b"")') do
		value = value:gsub('&([^;]+);', {quot='"', lt='<', gt='>', amp='&',}) -- XML escape characters
		local nkey = key:sub(1, 6):lower()
		tbl[nkey] = funcs[nkey](value:match('"(.+)"'))
	end
	
	return tbl
end -- Keys

function ErrMsg(...) -- Used to display errors
	Error = true
	print('LuaCalendar: ' .. table.concat(arg, ' ', 2))
	return arg[1]
end -- ErrMsg

function Delim(option, default) -- Separate String by Delimiter
	local value, tbl = SELF:GetOption(option, default), {}
	for word in value:gmatch('[^|]+') do table.insert(tbl, word) end
	return tbl
end -- Delim
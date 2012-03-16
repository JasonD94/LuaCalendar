-- LuaCalendar v3.2 by Smurfier (smurfier20@gmail.com)
-- This work is licensed under a Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.

function Initialize()
	Set={ -- Retrieve Measure Settings
		DPrefix=SELF:GetOption('DayPrefix','l');
		HLWeek=SELF:GetNumberOption('HideLastWeek',0);
		LZer=SELF:GetNumberOption('LeadingZeroes',0);
		MPref=SELF:GetOption('MeterPrefix','mDay');
		SMon=SELF:GetNumberOption('StartOnMonday',0);
	}
	OldDay,OldMonth,OldYear,StartDay,Month,Year,InMonth=0,0,0,0,0,0,1 -- Initialize Variables.
	cMonth={31;28;31;30;31;30;31;31;30;31;30;31;} -- Length of the months.
--	========== Weekday labels text ==========
	local Labels={} -- Initialize Labels table in local context.
	for a in string.gmatch(SELF:GetOption('DayLabels','S|M|T|W|T|F|S'),'[^%|]+') do -- Separate DayLabels by Delimiter.
		table.insert(Labels,a)
	end
	for a=1,#Labels do -- Set DayLabels text.
		SetOption(Set.DPrefix..a,'Text',Labels[Set.SMon==1 and a%#Labels+1 or a])
	end
--	========== Localization ==========
	MLabels={}
	if SELF:GetNumberOption('UseLocalMonths',0)==1 then
		os.setlocale('','time') -- Set current locale. This affects all skins and scripts.
		for a=1,12 do -- Pull each month name.
			table.insert(MLabels,os.date('%B',os.time({year=2000,month=a,day=1})))
		end
	else
		for a in string.gmatch(SELF:GetOption('MonthLabels',''),'[^%|]+') do -- Pull custom month names.
			table.insert(MLabels,a)
		end
		for a=#MLabels+1,12 do -- Make sure there are 12 months.
			table.insert(MLabels,a)
		end
	end
--	========== Holiday File ==========
	hFile={} -- Initialize Main Holiday table.
	for a=1,5 do hFile[a]={} end -- Turn Holiday Table into a Matrix with 5 columns.
	for file in string.gmatch(SELF:GetOption('HolidayFile',''),'[^%|]+') do -- For each holiday file.
		local In=io.input(SKIN:MakePathAbsolute(file),'r') -- Open file in read only.
		if In then -- If file is open.
			local Title=''
			for line in io.lines() do -- For each file line.
				if string.match(line,'<Title>.+</Title>') then
					Title=' -'..string.match(line,'<Title>(.+)</Title>') -- Set Title.
				elseif string.match(line,'<Event.+>.+</') then
					table.insert(hFile[1],Strip(line,'Month'))
					table.insert(hFile[2],Strip(line,'Day'))
					table.insert(hFile[3],Strip(line,'Year'))
					table.insert(hFile[4],string.match(line,'<Event.+>(.+)</') or '')
					table.insert(hFile[5],Title)
				end
			end
		else -- File could not be opened.
			print('File Read Error: '..file)
		end
		io.close(In) -- Close the current file.
	end	
end -- function Initialize

function Update()
	Time=os.date('*t') -- Retrieve date values.
	if InMonth==1 and Month~=Time.month then  -- If in the current month, set to Real Time.
		Month,Year=Time.month,Time.year
	elseif InMonth==0 and Month==Time.month and Year==Time.year then -- If browsing and Month changes to that month, set to Real Time.
		Home()
	end
	if Month~=OldMonth or Year~=OldYear then -- Recalculate and Redraw if Month and/or Year changes.
		OldMonth,OldYear=Month,Year
		StartDay=rotate(os.date('%w',os.time({year=Year,month=Month,day=1})))
		cMonth[2]=28+((((Year%4)==0 and (Year%100)~=0) or (Year%400)==0) and 1 or 0) --Check for Leap Year.
		if Set.HLWeek==1 then --Set LastWkHidden skin variable.
			SetVariable('LastWkHidden',math.ceil((StartDay+cMonth[Month])/7)<6 and 1 or 0)
		end
		Holidays()
		Draw()
	end
	if Time.day~=OldDay then --Redraw if Today changes.
		OldDay=Time.day
		Draw()
	end
	return 'Success!' --Return a value to Rainmeter.
end -- function Update

function Holidays() --Parse Holidays table.
	Hol={} --Initialize Holiday Table.
	if SELF:GetNumberOption('DisableBuiltInEvents',0)==0 then Easter() end -- Add Easter.
	for i=1,#hFile[1] do --For each holiday in the main table.
		local Dy=0 --Reset Dy to zero just to be sure.
		if tonumber(hFile[1][i])==Month or hFile[1][i]=='*' then --If Holiday exists in current month or *.
			Dy=SKIN:ParseFormula(Replace(VarDay(hFile[2][i]))) -- Calculate Day.
			local An=tonumber(hFile[3][i]) and ' ('..(Year-tonumber(hFile[3][i]))..')' or '' --Calculate Anniversary.
			Hol[Dy]=(Hol[Dy] and Hol[Dy]..'\n' or '')..hFile[4][i]..An..hFile[5][i] --Add to Holiday Table.
		end
	end
end -- function Holidays

function Draw() --Sets all meter properties and calculates days.
	for a=1,7 do --Set Weekday Labels styles.
		local Styles={'LblTxtSty'}
		if a==1 then table.insert(Styles,'LblTxtStart') end
		if rotate(Time.wday-1)==(a-1) and InMonth==1 then --If in current month and year, set Current Weekday style.
			table.insert(Styles,'LblCurrSty')
		end
		SetOption(Set.DPrefix..a,'MeterStyle',table.concat(Styles,'|'))
	end
	for a=1,42 do --Calculate and set day meters.
		local Par,Styles={a-StartDay;''},{'TextStyle'} --Reinitialize variables.
		if a%7==1 then table.insert(Styles,a==1 and 'FirstDay' or 'NewWk') end --First Day and New Week
		if Par[1]>0 and Par[1]<=cMonth[Month] and Hol[Par[1]] then --Holiday ToolTip and Style
			Par[2]=Hol[Par[1]]
			table.insert(Styles,'HolidayStyle')
		end
		if (Time.day+StartDay)==a and InMonth==1 then --If in current month and year, set Current Day Style.
			table.insert(Styles,'CurrentDay')
		elseif a>35 and math.ceil((StartDay+cMonth[Month])/7)<6 and Set.HLWeek==1 then --LastWeek of the month.
			table.insert(Styles,'LastWeek')
		elseif Par[1]<1 then --Days in the previous month.
			Par[1]=Par[1]+cMonth[Month==1 and 12 or Month-1]
			table.insert(Styles,'PreviousMonth')
		elseif Par[1]>cMonth[Month] then --Days in the following month.
			Par[1]=Par[1]-cMonth[Month]
			table.insert(Styles,'NextMonth')
		elseif a%7==0 or a%7==(Set.SMon==0 and 1 or 6) then --Weekends in the current month.
			table.insert(Styles,'WeekendStyle')
		end
		local tbl={ --Use this table to define meter properties.
			Text=LZero(Par[1]);
			MeterStyle=table.concat(Styles,'|');
			ToolTipText=Par[2];
		}
		--Reads tbl and sets meter properties.
		for i,v in pairs(tbl) do SetOption(Set.MPref..a,i,v) end
	end
	local var={ --Use this table to define skin variables.
		ThisWeek=math.ceil((Time.day+StartDay)/7);
		Week=rotate(Time.wday-1);
		Today=LZero(Time.day);
		Month=MLabels[Month];
		Year=Year;
		MonthLabel=Replace(SELF:GetOption('LabelText',MLabels[Month]..', '..Year));
	}
	for i,v in pairs(var) do SetVariable(i,v) end --Reads var and sets skin variables.
end -- function Draw

function Forward() --Advance Calendar by one month.
	Month,Year=Month%12+1,Month==12 and Year+1 or Year
	InMonth=((Month==Time.month and Year==Time.year) and 1 or 0) --Check if in the current month.
	SetVariable('NotCurrentMonth',1-InMonth) --Set Skin Variable NotCurrentMonth
end -- function Forward

function Back() --Regress Calendar by one month.
	Month,Year=Month==1 and 12 or Month-1,Month==1 and Year-1 or Year
	InMonth=((Month==Time.month and Year==Time.year) and 1 or 0) --Check if in the current month.
	SetVariable('NotCurrentMonth',1-InMonth) --Set Skin Variable NotCurrentMonth
end -- function Back

function Home() --Returns Calendar to current month.
	Month,Year,InMonth=Time.month,Time.year,1
	SetVariable('NotCurrentMonth',0)
end -- function Home

--===== These Functions are used to make life easier =====

function Easter() -- Calculates Easter.
	local a,b,c,g,h,L,m=Year%19,math.floor(Year/100),Year%100,0,0,0,0
	local d,e,f,i,k=math.floor(b/4),b%4,math.floor((b+8)/25),math.floor(c/4),c%4
	g=math.floor((b-f+1)/3)
	h=(19*a+b-d-g+15)%30
	L=(32+2*e+2*i-h-k)%7
	m=math.floor((a+11*h+22*L)/451)
	if Month==math.floor((h+L-7*m+114)/31) then Hol[(h+L-7*m+114)%31+1]='Easter' end
end -- function Easter

function VarDay(a) -- Makes allowance for VariableDays
	local D,W={sun=0,mon=1,tue=2,wed=3,thu=4,fri=5,sat=6},{first=0,second=1,third=2,fourth=3,last=4}
	for b in string.gmatch(a,'%b{}') do
		local v1,v2=string.match(string.lower(b),'{(.*)(...)}')
		local L,wD=36+D[v2]-StartDay,rotate(D[v2])
		local num=W[v1]<4 and wD+1-StartDay+(StartDay>wD and 7 or 0)+7*W[v1] or L-math.ceil((L-cMonth[Month])/7)*7
		a=string.gsub(a,b,tonumber(num) or 0)
	end
	return a
end -- function VarDay

function Replace(a) -- Makes !Variable substitutions
	local tbl={
		MName=MLabels[Month];
		Year=Year;
		Today=LZero(Time.day);
		Month=Month;
	}
	for i,v in pairs(tbl) do a=string.gsub(a,'!'..i,v) end
	return a
end -- function Replace

function rotate(a) -- Used to make allowance for StartOnMonday.
	a=tonumber(a)
	return Set.SMon==1 and (a-1+7)%7 or a
end -- function rotate

function SetVariable(a,b) -- Used to easily set Skin Variables
	SKIN:Bang('!SetVariable '..a..' """'..b..'"""')
end -- function SetVariable

function SetOption(a,b,c) -- Used to easily set Meter/Measure Options
	SKIN:Bang('!SetOption "'..a..'" "'..b..'" """'..c..'"""')
end -- function SetOption

function Strip(a,b,c) -- Used to simplify some string matching
	a=string.match(a,b..'=(%b"")')
	return a and string.match(a,'^"(.-)"$') or (c or '')
end -- function Strip

function LZero(a) -- Used to make allowance for LeadingZeroes
	return Set.LZer==1 and string.format('%02d',a) or a
end -- function LZero
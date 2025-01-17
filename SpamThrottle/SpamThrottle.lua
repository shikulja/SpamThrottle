--[[
	SpamThrottle - Remove redundant and annoying chat messages
	Version:	Vanilla 1.16
	Date:		11.02.2017
	Author:	Mopar
	This is a port of SpamThrottle to work with Vanilla WoW, release 1.12.1 and 1.12.2.
	I am also the author of the retail version (no longer maintained).
	Only allows a particular message to be displayed once, rather than repeated.	
	A timeout (call the gapping value) controls how often the exact same message
	may be repeated, and this value is settable by the user. There is also a keyword
	list to filter by keywords, and a player name list to filter by specific players.
	Both lists are unlimited in size.
	
	Also allows (optional) blocking of chat channel join/leave spam,
	and other chat channel control messages.
	Portions of this code were adapted from the following addons:
	- SpamEraser
	- ASSFilter

	Special thanks to Github's sipertruk for multiple-chat frame handling code.
]]

--============================
--= Settings, Defaults, and Local Variables
--============================
local DebugMsg = false;
local ErrorMsg = true;
local DebugMode = false;
local BlockReportMode = false;
local ScoreMsg = false;
local debugWin = 0; 

local MessageList = {}
for i=1, NUM_CHAT_WINDOWS do
	MessageList["ChatFrame"..i] = {}
end
MessageList["WIM_Core"] = {}
local WIM_Present = false;
local MultiMessageCache = {}
local MultiLastMsg = {}
local LastPurgeTime = time()
local LastAuditTime = time()
local FilteredCount = 0;
local UniqueCount = 0;
local PlayerListAuditGap = 10;
local DelayHookInitTime = time();
local DelayHookReHooked;

Default_SpamThrottle_Config = {
		Version = SpamThrottleProp.Version;
		STActive = true;
		STDupFilter = true;
		STColor = false;
		STGoldSeller = true;
		STFuzzy = true;
		STChinese = true;
		STCtrlMsgs = true;
		STYellMsgs = true;
		STSayMsgs = true;
		STWispMsgs = true;
		STWispBack = false;
		STMultiWisp = true;
		STWispMsgsOFF = false;
		STReverse = false;
		STGap = 180;
		STBanPerm = true;
		STBanTimeout = 600;
		STWhiteChannel1 = "";
		STWhiteChannel2 = "";
		STWhiteChannel3 = "";
		MinimapButtonAtt = true;
		STMinimapButton = true;
		ButtonPosX = -17;
		ButtonPosY = -113;
}

Default_SpamThrottle_KeywordFilterList = {
	"Blessed Blade of the Windseeker", "item4game", "moneyforgames",
	"goldinsider", "sinbagame", "sinbagold", "sinbaonline", "susangame",
	"4gamepower", "iloveugold", "okogames", "okogomes", "item4wow", "gold4mmo",
	"wtsitem", "golddeal", "g4wow", 
	"legacy-boost", "mmotank", "naxxgames", "nost100", "wwvokgames"}

Default_SpamThrottle_PlayerFilterList = {};

SpamThrottle_PlayerBanTime = {};

local SpamThrottle_GlobalBanList = {}

SpamThrottle_LastClickedItem = nil;
SpamThrottle_LastClickedTable = nil;
SpamThrottle_LastClickedValue = nil;

SpamThrottle_LastPlayerBanned = " ";
SpamThrottle_LastPlayerFiltered = " ";

SpamThrottle_UTF8Convert = {};

SpamThrottle_UTF8Convert[tonumber("391",16)] = "A";
SpamThrottle_UTF8Convert[tonumber("392",16)] = "B";
SpamThrottle_UTF8Convert[tonumber("395",16)] = "E";
SpamThrottle_UTF8Convert[tonumber("396",16)] = "Z";
SpamThrottle_UTF8Convert[tonumber("397",16)] = "H";
SpamThrottle_UTF8Convert[tonumber("399",16)] = "I";
SpamThrottle_UTF8Convert[tonumber("39A",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("39C",16)] = "M";
SpamThrottle_UTF8Convert[tonumber("39D",16)] = "N";
SpamThrottle_UTF8Convert[tonumber("39F",16)] = "O";
SpamThrottle_UTF8Convert[tonumber("3A1",16)] = "P";
SpamThrottle_UTF8Convert[tonumber("3A4",16)] = "T";
SpamThrottle_UTF8Convert[tonumber("3A5",16)] = "Y";
SpamThrottle_UTF8Convert[tonumber("3A6",16)] = "O";
SpamThrottle_UTF8Convert[tonumber("3A7",16)] = "X";
SpamThrottle_UTF8Convert[tonumber("405",16)] = "S";
SpamThrottle_UTF8Convert[tonumber("406",16)] = "I";
SpamThrottle_UTF8Convert[tonumber("408",16)] = "J";
SpamThrottle_UTF8Convert[tonumber("410",16)] = "A";
SpamThrottle_UTF8Convert[tonumber("412",16)] = "B";
SpamThrottle_UTF8Convert[tonumber("415",16)] = "E";
SpamThrottle_UTF8Convert[tonumber("41A",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("41C",16)] = "M";
SpamThrottle_UTF8Convert[tonumber("41D",16)] = "H";
SpamThrottle_UTF8Convert[tonumber("41E",16)] = "O";
SpamThrottle_UTF8Convert[tonumber("420",16)] = "P";
SpamThrottle_UTF8Convert[tonumber("421",16)] = "C";
SpamThrottle_UTF8Convert[tonumber("422",16)] = "T";
SpamThrottle_UTF8Convert[tonumber("423",16)] = "Y";
SpamThrottle_UTF8Convert[tonumber("425",16)] = "X";
SpamThrottle_UTF8Convert[tonumber("428",16)] = "W";
SpamThrottle_UTF8Convert[tonumber("429",16)] = "W";
SpamThrottle_UTF8Convert[tonumber("435",16)] = "O";
SpamThrottle_UTF8Convert[tonumber("448",16)] = "w";
SpamThrottle_UTF8Convert[tonumber("449",16)] = "w";
SpamThrottle_UTF8Convert[tonumber("460",16)] = "W";
SpamThrottle_UTF8Convert[tonumber("461",16)] = "w";
SpamThrottle_UTF8Convert[tonumber("49A",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("49B",16)] = "k";
SpamThrottle_UTF8Convert[tonumber("49C",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("49D",16)] = "k";
SpamThrottle_UTF8Convert[tonumber("49E",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("49F",16)] = "k";
SpamThrottle_UTF8Convert[tonumber("4A0",16)] = "K";
SpamThrottle_UTF8Convert[tonumber("4A1",16)] = "k";
SpamThrottle_UTF8Convert[tonumber("4AE",16)] = "Y";
SpamThrottle_UTF8Convert[tonumber("4AF",16)] = "Y";
SpamThrottle_UTF8Convert[tonumber("51C",16)] = "W";
SpamThrottle_UTF8Convert[tonumber("51D",16)] = "w";


--============================
--= Static Popup Dialog Definitions
--============================
StaticPopupDialogs["SPAMTHROTTLE_ADD_KEYWORD"] = {
	text = "%s";
    button1 = "Okay";
    button2 = "Cancel";
    hasEditBox = 1,
    whileDead = 1,
    hideOnEscape = 1,
    timeout = 0,
	enterClicksFirstButton = 1,
    OnShow = function()
		getglobal(this:GetName().."EditBox"):SetText("");
    end,
    OnAccept = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		SpamThrottle_AddKeyword(variable);
    end,
	EditBoxOnEnterPressed = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		SpamThrottle_AddKeyword(variable);
		this:GetParent():Hide();
	end,
    OnAlt = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
    end
 }

StaticPopupDialogs["SPAMTHROTTLE_ADD_PLAYERBAN"] = {
	text = "%s";
    button1 = "Okay";
    button2 = "Cancel";
    hasEditBox = 1,
    whileDead = 1,
    hideOnEscape = 1,
    timeout = 0,
	enterClicksFirstButton = 1,
    OnShow = function()
		getglobal(this:GetName().."EditBox"):SetText("");
    end,
    OnAccept = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		SpamThrottle_AddPlayerban(variable);
    end,
	EditBoxOnEnterPressed = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		SpamThrottle_AddPlayerban(variable);
		this:GetParent():Hide();
	end,
    OnAlt = function()
		variable = getglobal(this:GetParent():GetName().."EditBox"):GetText();
    end
 }

--============================
--= Unit popup options (right clicking on character name in chat)
--= This is really dirty. It would cause taint on later versions of WoW.
--============================
UnitPopupButtons["SPAMTHROTTLE_ADD_PLAYERBAN"] = {
	text = "Ban player chat",
	dist = 0
}

UnitPopupButtons["SPAMTHROTTLE_REMOVE_PLAYERBAN"] = {
	text = "Unban player chat",
	dist = 0
}

table.insert(UnitPopupMenus["FRIEND"], 1, "SPAMTHROTTLE_ADD_PLAYERBAN");
table.insert(UnitPopupMenus["FRIEND"], 2, "SPAMTHROTTLE_REMOVE_PLAYERBAN");

local SpamThrottleUnitPopup_OnClick = UnitPopup_OnClick;
function UnitPopup_OnClick(self)
	local theFrame = UIDROPDOWNMENU_INIT_MENU
	local theName = FriendsDropDown.name;
	local theButton = this.value;
	
	if theFrame == "FriendsDropDown" then
		if theButton == "SPAMTHROTTLE_ADD_PLAYERBAN" then
			if theName ~= UnitName("player") then
				local banType;
				if SpamThrottle_Config.STBanPerm then
					banType = " (" .. SpamThrottleChatMsg.Permanent .. ")";
				else
					banType = " (" .. SpamThrottleChatMsg.Timeout .. "=" .. SpamThrottle_Config.STBanTimeout .. ")";
				end
				SpamThrottle_AddPlayerban(theName);
				SpamThrottleMessage(true,theName,SpamThrottleChatMsg.BanAdded,banType);
			end
		elseif theButton == "SPAMTHROTTLE_REMOVE_PLAYERBAN" then
			if theName ~= UnitName("player") then
				SpamThrottle_RemovePlayerban(theName);
				SpamThrottleMessage(true,theName,SpamThrottleChatMsg.BanRemoved);
			end
		else
			-- do nothing
		end
	end
	SpamThrottleUnitPopup_OnClick(self);
end

--============================
--= Message function that prints variable to default chat frame
--============================
function SpamThrottleMessage(visible, ...)
	debugWin = 0
	local name, shown;
	for i=1, NUM_CHAT_WINDOWS do
		name,_,_,_,_,_,shown = GetChatWindowInfo(i);
		if (string.lower(name) == "stdebug") then debugWin = i; break; end
	end
	if (debugWin == 0) then 
		debugWin = DEFAULT_CHAT_FRAME
	else
		debugWin = getglobal("ChatFrame"..debugWin)
	end
	for i = 1,arg.n do
		if type(arg[i]) == "nil" then
			arg[i] = "(nil)";
		elseif type(arg[i]) == "boolean" and arg[i] then
			arg[i] = "(true)";
		elseif type(arg[i]) == "boolean" and not arg[i] then
			arg[i] = "(false)";
		end
	end

	if (visible) then
		debugWin:AddMessage("SpamThrottle: " .. table.concat (arg, " "), 0.5, 0.5, 1);
	end
end

function SpamThrottleMessageHex(visible, msg)
	local Nlen = string.len(msg);
	local out = ""
	for i = 1, Nlen do
		out = out .. string.format("%X ",string.byte(msg,i,i))
	end
	if Prat_UrlCopy then out = Prat_UrlCopy:Link(out) end
	if (visible) then
		debugWin:AddMessage("SpamThrottle: " .. out, 0.5, 0.5, 1);
	end
end

--============================
--= Delay the hook of the chat messaging function
--============================

local UFStartTime = time();
local UFInitialized;
local UpdateFrame;

function UFOverHookEvents()
	if(time() - UFStartTime > 10 and UFInitialized == nil) then
		SpamThrottle_OrigChatFrame_OnEvent = ChatFrame_OnEvent;
		ChatFrame_OnEvent = SpamThrottle_ChatFrame_OnEvent;
		if WIM_ChatFrame_OnEvent then 
			SpamThrottle_Orig_WIM_ChatFrame_OnEvent = WIM_ChatFrame_OnEvent;
			WIM_ChatFrame_OnEvent = SpamThrottle_WIM_ChatFrame_OnEvent;
			WIM_Present = true;
			SpamThrottle_SetAlphas(SpamThrottle_Config.STActive);
		end
		SpamThrottleMessage(true,SpamThrottleMessageHook);
    	UFStartTime = nil;
		UFInitialized = true;
		this:Hide();
      	this:SetScript("OnUpdate", nil);
      	this = nil;
   end
end

local UpdateFrame = CreateFrame("Frame", nil);
UpdateFrame:SetScript("OnUpdate",UFOverHookEvents);
UpdateFrame:RegisterEvent("OnUpdate");


--============================
-- Local function to normalize chat strings to avoid attempts to bypass SpamThrottle
--============================
local function SpamThrottle_strNorm(msg, Author)
	local Nmsg = "";
	local c = "";
	local lastc = "";
	local Bmsg = "";

	if (msg == nil) then return end;
	
	if (not SpamThrottle_Config.STFuzzy) then
		return string.upper(Author) .. msg;
	end

	Nmsg = string.gsub(msg,"\\/\\/","W");
	Nmsg = string.gsub(Nmsg,"/\\/\\","M");
	Nmsg = string.gsub(Nmsg,"/-\\","A");
	Nmsg = string.gsub(Nmsg,"!<","K");
	Nmsg = string.gsub(Nmsg,"I<","K");
	Nmsg = string.gsub(Nmsg,"0","O");
	Nmsg = string.gsub(Nmsg,"3","E");
	Nmsg = string.gsub(Nmsg,"...hic!","");
	Nmsg = string.upper(Nmsg);
	
	Nmsg = string.gsub(Nmsg,"\|HITEM[^|]+\|H","");
	Nmsg = string.gsub(Nmsg,"\|C%S%S%S%S%S%S%S%S","");
	Nmsg = string.gsub(Nmsg,"\|H","");
	Nmsg = string.gsub(Nmsg,"\|R","");
	
		Nmsg = string.gsub(Nmsg,"%d","");
		Nmsg = string.gsub(Nmsg,"%c","");
		Nmsg = string.gsub(Nmsg,"%p","");
		Nmsg = string.gsub(Nmsg,"%s","");
	
	Nmsg = string.gsub(Nmsg,"SH","S");
	Nmsg = string.gsub(Nmsg,"RN","M");
	Nmsg = string.gsub(Nmsg,"VV","W");
	
	local Nlen = string.len(Nmsg);

	for i = 1, Nlen do
		if i ~= Nlen then
			s1 = string.sub(Nmsg,i,i);
			s2 = string.sub(Nmsg,i+1,i+1);
			c1 = string.byte(s1);
			c2 = string.byte(s2);
			
			if c1 > 192 and c1 <= 225 then -- it's a UTF-8 2 byte code
				p1 = c1 - math.floor(c1/32)*32;
				p2 = c2 - math.floor(c2/64)*64;
				p = p1*64+p2;
				
				if SpamThrottle_UTF8Convert[p] ~= nil then
					Bmsg = Bmsg .. SpamThrottle_UTF8Convert[p];
					i = i + 1;
				else
					Bmsg = Bmsg .. s1;
				end
			else
				if c1 == 151 and c2 == 139 then
					Bmsg = Bmsg .. "O";
					i = i + 1;
				else
					Bmsg = Bmsg .. s1;
				end
			end
		else
			Bmsg = Bmsg .. string.sub(Nmsg,i,i);
		end
	end
	Nmsg = Bmsg;
	Bmsg = "";

	for i = 1, string.len(Nmsg) do			-- for c in string.gmatch(Nmsg,"%u") do
		c = string.sub(Nmsg,i,i)
		if (c ~= lastc) then
			Bmsg = Bmsg .. c;
		end
		lastc = c;
	end
	Nmsg = Bmsg

	if (Author ~= nil) then
		Nmsg = string.upper(Author) .. Nmsg;
	end

	return Nmsg
end


--============================
--= Utility function to count the number of entries in a table
--============================
function table.length(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

--============================
--= Utility function to find the index of element in table T
--============================
function table.find(table, element) -- find element v of T satisfying f(v)
 	for key, value in ipairs(table) do
   		if value == element then
			return key
		end
  	end
	return nil
end


local function MergeTables(a, b)
	if type(a) == 'table' and type(b) == 'table' then
			table.foreach(b, function(k,v) 
				for	kk,vv in a do
				 if v == vv then return; end
				end
				table.insert(a,v)
			end)
	end
    return a
end


--============================
--= Utility function to check each variable in two tables making sure their variable type match.
--============================
function SpamThrottle_TableTypeMatch(table1, table2)
	for key,value in pairs(table1) do
		if type(table1[key]) ~= type(table2[key]) then
			return false
		end
	end
	return true;
end


local function StringHash(text)
	local counter = 1
  local len = string.len(text)
  for i = 1, len, 3 do 
    counter = math.mod(counter*8161, 4294967279) +  -- 2^32 - 17: Prime!
  	  (string.byte(text,i)*16776193) +
  	  ((string.byte(text,i+1) or (len-i+256))*8372226) +
  	  ((string.byte(text,i+2) or (len-i+256))*3932164)
  end
  return math.mod(counter, 4294967291) -- 2^32 - 5: Prime (and different from the prime in the loop)
end


--============================
--= OnLoad registers events and prints the welcome message
--============================
function SpamThrottle_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
UpdateFrame:Show();
	SpamThrottleMessage(true,SpamThrottleChatMsg.WelcomeMsg);
end

--============================
--= Initialize SpamThrottle
--============================
function SpamThrottle_init()
	
	-- Install or upgrade, Load Variable from default and show config window
	
	if type(SpamThrottle_Config) ~= "table" or not SpamThrottle_TableTypeMatch(Default_SpamThrottle_Config, SpamThrottle_Config) or (SpamThrottle_Config.Version ~= Default_SpamThrottle_Config.Version) then
		if SpamThrottle_Config == nil then SpamThrottle_Config = {}; end
		table.foreach(Default_SpamThrottle_Config, function(k,v)
			if SpamThrottle_Config[k] == nil then 
				SpamThrottle_Config[k] = v; 
		--		SpamThrottleMessage(true, k.." = "..v);
			end
		end)
		
		if type(SpamThrottle_KeywordFilterList) == "table" then
			MergeTables(SpamThrottle_KeywordFilterList, Default_SpamThrottle_KeywordFilterList);
		else
		SpamThrottle_KeywordFilterList = Default_SpamThrottle_KeywordFilterList;
		end
		if SpamThrottle_PlayerFilterList == nil then
		SpamThrottle_PlayerFilterList = Default_SpamThrottle_PlayerFilterList;
		end
		
		SpamThrottle_Config.Version = Default_SpamThrottle_Config.Version;
		SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.LoadDefault);
	end
	
	if type(SpamThrottle_KeywordFilterList) ~= "table" then
		SpamThrottle_KeywordFilterList = {};
		SpamThrottle_KeywordFilterList = Default_SpamThrottle_KeywordFilterList;
		SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.LoadKeywordDefault);
	end

	if type(SpamThrottle_PlayerFilterList) ~= "table" then
		SpamThrottle_PlayerFilterList = {};
		SpamThrottle_PlayerFilterList = Default_SpamThrottle_PlayerFilterList;
		SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.LoadPlayerbanDefault);
	end
	
	SpamThrottle_ToggleWispersOFF( SpamThrottle_Config.STWispMsgsOFF );
		
end


--============================
--= OnEvent is the main event handler for registered events
--============================
function SpamThrottle_OnEvent()
	if event == "PLAYER_ENTERING_WORLD" then
		SpamThrottle_init();
		SpamThrottle_SetButtonPosition();
	end
end

function SpamThrottleCreateTooltip(STTooltip)
	if SpamThrottle_LastPlayerBanned ~= " " then STTooltip:AddLine(SpamThrottleLastPlayerBannedText .. SpamThrottle_LastPlayerBanned , 0, 1, 0); end
	if SpamThrottle_LastPlayerFiltered ~= " " then STTooltip:AddLine(SpamThrottleLastPlayerFilteredText .. SpamThrottle_LastPlayerFiltered , 0, 1, 0); end
end
	
--============================
--= User Interface Handling Functions
--============================

function SpamThrottleConfigFrame_OnShow()
	local theStatusValue;
	
	SpamThrottleConfigFrameLoadSettings(SpamThrottle_Config);
	SpamThrottle_LastClickedItem = nil;
	SpamThrottle_LastClickedTable = nil;
	SpamThrottle_LastClickedValue = nil;
	
	theStatusValue = string.format("%7d",table.length(SpamThrottle_KeywordFilterList));
	SpamThrottleStatusValue1:SetTextColor(1,1,1);
	SpamThrottleStatusValue1:SetText(theStatusValue);
	SpamThrottleStatusValue1:Show();
	
	theStatusValue = string.format("%7d",table.length(SpamThrottle_PlayerFilterList));
	SpamThrottleStatusValue2:SetTextColor(1,1,1);
	SpamThrottleStatusValue2:SetText(theStatusValue);
	SpamThrottleStatusValue2:Show();
	
	theStatusValue = string.format("%7d",table.length(SpamThrottle_GlobalBanList));
	SpamThrottleStatusValue4:SetTextColor(1,1,1);
	SpamThrottleStatusValue4:SetText(theStatusValue);
	SpamThrottleStatusValue4:Show();
	
	theStatusValue = string.format("%7d",UniqueCount);
	SpamThrottleStatusValue5:SetTextColor(1,1,1);
	SpamThrottleStatusValue5:SetText(theStatusValue);
	SpamThrottleStatusValue5:Show();
	
	theStatusValue = string.format("%7d",FilteredCount);
	SpamThrottleStatusValue6:SetTextColor(1,1,1);
	SpamThrottleStatusValue6:SetText(theStatusValue);
	SpamThrottleStatusValue6:Show();
	
	for key,value in pairs(SpamThrottleStatusMsg) do
		local nametag = getglobal("SpamThrottle" .. key);
		
		nametag:SetTextColor(1,1,1);
		nametag:SetText(value);
		nametag:Show();
	end
end

function SpamThrottleConfigFrameOkay_OnClick()
	SpamThrottleConfigFrameSaveSettings(SpamThrottle_Config);
	SpamThrottleConfigFrame:Hide();
end

function SpamThrottleConfigFrameLoadSettings(configset)
	SpamThrottle_SetAlphas(SpamThrottle_Config.STActive);
	SpamThrottle_SetBanSliderAlpha(SpamThrottle_Config.STBanPerm);
	for key,value in pairs(configset) do
		SpamThrottleMessage(DebugMsg, key, value, "type=",type(value));
		if key == "Version" or string.find(key,"ST") == nil then
			-- do nothing
		elseif type(value) == "boolean"  then
			local nametag = getglobal(key .. "_CheckButton");
			if type(nametag) ~= "nil" then
				if value then
					nametag:SetChecked(1);
				else
					nametag:SetChecked(0);
				end
				nametag.tooltipText = SpamThrottleConfigObjectTooltip[key];

				nametag = getglobal(key .. "_CheckButtonText");
				nametag:SetText(SpamThrottleConfigObjectText[key]);
				nametag:SetTextColor(1,1,1);
				
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectLoadFail, key, "(", value, ")");
			end

		elseif type(value) == "number" then
			local nametag = getglobal(key .. "_Slider");
			if type(nametag) ~= "nil" then
				nametag:SetValue(value);
				nametag = getglobal(key .. "_SliderTitle");
				nametag:SetText(SpamThrottleConfigObjectText[key]);
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectLoadFail, key, "(", value, ")");
			end
		
		elseif type(value) == "string" then
			local nametag = getglobal(key .. "_EditBox");
			if type(nametag) ~= "nil" then
				nametag:SetText(value);
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectLoadFail, key, "(", value, ")");
			end
		end
	end
end

function SpamThrottleConfigFrameSaveSettings(configset)
	for key,oldvalue in pairs(configset) do
		if key == "Version" or string.find(key,"ST") == nil then
			-- do nothing
			
		elseif type(oldvalue) == "boolean"  then
			local nametag = getglobal(key .. "_CheckButton");
			if type(nametag) ~= "nil" then
				local newvalue = not not nametag:GetChecked();
				if newvalue ~= oldvalue then
					configset[key] = newvalue;
					SpamThrottleMessage(DebugMsg, key, "has been updated from", oldvalue,"to", newvalue)
				end
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectSaveFail, key, "(", oldvalue, ")");
			end
			
		elseif type(oldvalue) == "number" then
			local nametag = getglobal(key .. "_Slider");
			if type(nametag) ~= "nil" then
				local newvalue = nametag:GetValue();
				if (oldvalue ~= newvalue) then
					configset[key] = newvalue;
					SpamThrottleMessage(DebugMsg, key, "has been updated from", oldvalue,"to", newvalue)
				end
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectSaveFail, key, "(", oldvalue, ")");
			end
		
		elseif type(oldvalue) == "string" then
			local nametag = getglobal(key .. "_EditBox");
			if type(nametag) ~= "nil" then
				local newvalue = nametag:GetText();
				if (oldvalue ~= newvalue) then
					configset[key] = newvalue;
					SpamThrottleMessage(DebugMsg, key, "has been updated from", oldvalue,"to", newvalue)
				end
			else
				SpamThrottleMessage(ErrorMsg, SpamThrottleChatMsg.ObjectSaveFail, key, "(", oldvalue, ")");
			end
		end
	end
end

function SpamThrottle_SetAlphas(myStatus)
	local theAlpha = 1.0;

	if not myStatus then
		theAlpha = 0.5;
	end
	
	STDupFilter_CheckButton:SetAlpha(theAlpha);	
	STColor_CheckButton:SetAlpha(theAlpha);
	STFuzzy_CheckButton:SetAlpha(theAlpha);
	STGoldSeller_CheckButton:SetAlpha(theAlpha);
	STChinese_CheckButton:SetAlpha(theAlpha);
	STCtrlMsgs_CheckButton:SetAlpha(theAlpha);
	STYellMsgs_CheckButton:SetAlpha(theAlpha);
	STSayMsgs_CheckButton:SetAlpha(theAlpha);
	STWispMsgs_CheckButton:SetAlpha(theAlpha);
	STReverse_CheckButton:SetAlpha(theAlpha);
	STGap_Slider:SetAlpha(theAlpha);
	
	if myStatus then
		STDupFilter_CheckButton:Enable();
		STColor_CheckButton:Enable();
		STFuzzy_CheckButton:Enable();
		STGoldSeller_CheckButton:Enable();
		STChinese_CheckButton:Enable();
		STCtrlMsgs_CheckButton:Enable();
		STYellMsgs_CheckButton:Enable();
		STSayMsgs_CheckButton:Enable();
		STWispMsgs_CheckButton:Enable();
		STReverse_CheckButton:Enable();
	else
		STDupFilter_CheckButton:Disable();
		STColor_CheckButton:Disable();
		STFuzzy_CheckButton:Disable();
		STGoldSeller_CheckButton:Disable();
		STChinese_CheckButton:Disable();
		STCtrlMsgs_CheckButton:Disable();
		STYellMsgs_CheckButton:Disable();
		STSayMsgs_CheckButton:Disable();
		STWispMsgs_CheckButton:Disable();
		STReverse_CheckButton:Disable();
	end
	
	SpamThrottle_SetWispBackAlpha(myStatus);
	SpamThrottle_SetMultiWispAlpha(myStatus);
end

function SpamThrottle_SetWispBackAlpha(myStatus)
	local theAlpha = 1.0;
	
	if not myStatus or WIM_Present then
		theAlpha = 0.5;
	end
	
	STWispBack_CheckButton:SetAlpha(theAlpha);
	
	if myStatus and not WIM_Present then
		STWispBack_CheckButton:Enable();
	else
		STWispBack_CheckButton:Disable();
	end
end

function SpamThrottle_SetMultiWispAlpha(myStatus)
	local theAlpha = 1.0;
	
	if not myStatus then
		theAlpha = 0.5;
	end
	
	STMultiWisp_CheckButton:SetAlpha(theAlpha);
	
	if myStatus then
		STMultiWisp_CheckButton:Enable();
	else
		STMultiWisp_CheckButton:Disable();
	end
end

function SpamThrottle_ToggleWispersOFF(myStatus)
	if myStatus then 
		SendChatMessage(".wr on", "SAY");
	else
		SendChatMessage(".wr off", "SAY");
	end
end

function SpamThrottle_SetBanSliderAlpha(myStatus)
	if myStatus then
		STBanTimeout_Slider:SetAlpha(0.5);
	else
		STBanTimeout_Slider:SetAlpha(1.0);
	end
end


function SpamThrottle_KeywordList_Update()
	local tableLen = table.length(SpamThrottle_KeywordFilterList);
	local line; -- 1 through 9 of our window to scroll
	local lineplusoffset; -- an index into our data calculated from the scroll offset
	
	FauxScrollFrame_Update(KeywordListScrollFrame, tableLen, 9, 16);

	for line = 1,9 do
		local nametag = getglobal("SpamThrottleKeywordItem" .. line)
		lineplusoffset = line + FauxScrollFrame_GetOffset(KeywordListScrollFrame);
					
		if lineplusoffset <= tableLen and SpamThrottle_KeywordFilterList[lineplusoffset] ~= nil then
			local listword = string.gsub(SpamThrottle_KeywordFilterList[lineplusoffset]," ","_");
			nametag:SetText(listword);
			if nametag ~= SpamThrottle_LastClickedItem then
				nametag:SetTextColor(1,1,1);
			else
				nametag:SetTextColor(1,1,0);
			end
			nametag:Show();
		else
			nametag:Hide();
		end
	end
end

function SpamThrottle_AddKeyword(theKeyword)
	theKeyword = string.gsub(theKeyword,"_"," ");
	local index = table.find(SpamThrottle_KeywordFilterList,theKeyword)
	if index ~= nil then return end;

	table.insert(SpamThrottle_KeywordFilterList,theKeyword);
	table.sort(SpamThrottle_KeywordFilterList);
	SpamThrottle_KeywordList_Update();
end

function SpamThrottle_AddPlayerban(thePlayer)
	
	MultiMessageCache[thePlayer] = nil
	
	local pl  = thePlayer; 
	
	thePlayer = string.upper(string.gsub(thePlayer," ",""));
	local index = table.find(SpamThrottle_PlayerFilterList,thePlayer)
	if index then return end;

	SpamThrottle_PlayerBanTime[thePlayer] = time();
	
	SpamThrottle_LastPlayerBanned = pl; 

	table.insert(SpamThrottle_PlayerFilterList,thePlayer);
	table.sort(SpamThrottle_PlayerFilterList);
	SpamThrottle_PlayerbanList_Update();
end

function SpamThrottle_RemovePlayerban(thePlayer)
	thePlayer = string.upper(string.gsub(thePlayer," ",""));
	SpamThrottle_PlayerBanTime[thePlayer] = nil;
		
	local index = table.find(SpamThrottle_PlayerFilterList,thePlayer)
	if not index then return end;
	table.remove(SpamThrottle_PlayerFilterList,index);
	SpamThrottle_PlayerbanList_Update();
end

function SpamThrottleKeywordList_OnClick(nametag)
	local value = nametag:GetText();

	if SpamThrottle_LastClickedItem ~= nil then
		SpamThrottle_LastClickedItem:SetTextColor(1,1,1);
	end
	
	SpamThrottle_LastClickedItem = nametag;
	SpamThrottle_LastClickedTable = SpamThrottle_KeywordFilterList;
	SpamThrottle_LastClickedValue = nametag:GetText();
	
	nametag:SetTextColor(1,1,0);
	nametag:Show();
end

function SpamThrottlePlayerList_OnClick(nametag)
	local value = nametag:GetText();

	if SpamThrottle_LastClickedItem ~= nil then
		SpamThrottle_LastClickedItem:SetTextColor(1,1,1);
	end
	
	SpamThrottle_LastClickedItem = nametag;
	SpamThrottle_LastClickedTable = SpamThrottle_PlayerFilterList;
	SpamThrottle_LastClickedValue = nametag:GetText();
	
	nametag:SetTextColor(1,1,0);
	nametag:Show();
end

function SpamThrottle_RemoveLastClicked()
	if SpamThrottle_LastClickedItem then
		local index = table.find(SpamThrottle_LastClickedTable,string.gsub(SpamThrottle_LastClickedValue,"_"," "));
		table.remove(SpamThrottle_LastClickedTable,index);
	else
		return;
	end
	
	if SpamThrottle_LastClickedTable == SpamThrottle_KeywordFilterList then
		SpamThrottle_LastClickedItem = nil;
		SpamThrottle_LastClickedTable = nil;
		SpamThrottle_LastClickedValue = nil;
		SpamThrottle_KeywordList_Update();
	elseif SpamThrottle_LastClickedTable == SpamThrottle_PlayerFilterList then
		SpamThrottle_RemovePlayerban(SpamThrottle_LastClickedValue);
		SpamThrottle_LastClickedItem = nil;
		SpamThrottle_LastClickedTable = nil;
		SpamThrottle_LastClickedValue = nil;
		SpamThrottle_PlayerbanList_Update();
	else
		SpamThrottle_LastClickedItem = nil;
		SpamThrottle_LastClickedTable = nil;
		SpamThrottle_LastClickedValue = nil;
		SpamThrottleMessage(ErrorMsg,"Attempt to remove item=",SpamThrottle_LastClickedItem," from non-existent table=",SpamThrottle_LastClickedTable);
	end
end

function SpamThrottle_PlayerbanList_Update()
	local tableLen = table.length(SpamThrottle_PlayerFilterList);
	local line; -- 1 through 9 of our window to scroll
	local lineplusoffset; -- an index into our data calculated from the scroll offset
	
	FauxScrollFrame_Update(PlayerbanListScrollFrame, tableLen, 9, 16);

	for line = 1,9 do
		local nametag = getglobal("SpamThrottlePlayerbanItem" .. line)
		lineplusoffset = line + FauxScrollFrame_GetOffset(PlayerbanListScrollFrame);
					
		if lineplusoffset <= tableLen then
			nametag:SetText(SpamThrottle_PlayerFilterList[lineplusoffset]);
			if nametag ~= SpamThrottle_LastClickedItem then
				nametag:SetTextColor(1,1,1);
			else
				nametag:SetTextColor(1,1,0);
			end
			nametag:Show();
		else
			nametag:Hide();
		end
	end
end

--============================
--= DecodeMessage - Print a detailed breakdown byte-by-byte of the message
--============================
function SpamThrottle_DecodeMessage(msg,Author)
	local theString ="";
	local Nlen = string.len(msg);
	
	for i = 1, Nlen do
		if i ~= Nlen then
			s1 = string.sub(msg,i,i);
			s2 = string.sub(msg,i+1,i+1);
			c1 = string.byte(s1);
			c2 = string.byte(s2);
			
			if c1 > 192 and c1 <= 225 then -- it's a UTF-8 2 byte code
				p1 = c1 - math.floor(c1/32)*32;
				p2 = c2 - math.floor(c2/64)*64;
				p = p1*64+p2;
				
				if SpamThrottle_UTF8Convert[p] == nil then
					SpamThrottleMessage(true,Author,": Unhandled UTF code: ",string.format("%x",p));
				end
				theString = theString .. string.format("[UTF8-%x]",p);
				i = i + 1;
			else -- it's a normal char
				theString = theString .. string.format("[%s-%x]",s1,c1);
			end
		end
	end
	SpamThrottleMessage(true,"Decoded:",theString);
end


--============================
--= RecordMessage - save it in our database
--============================
function SpamThrottle_RecordMessage(msg,Author)
		local Msg = SpamThrottle_strNorm(msg,Author);
		local hash = StringHash(Msg);
		
		SpamThrottleMessage(false,"MSG: ",Msg);
		--SpamThrottleMessage(true,"MSG: ",StringHash(Msg));
		
		local frameName = this:GetName()
		if (MessageList[frameName][hash] == nil) then  -- If we have NOT seen this text before
			UniqueCount = UniqueCount + 1
			MessageList[frameName][hash] = {
				count = 1,
				firstTime = time(),
				lastTime =time()
			}
		else
			MessageList[frameName][hash].count = MessageList[frameName][hash].count  + 1;
	end
end


--============================
--= QQCheck - Determine if the message contains a QQ name
--= Make sure to send it the original message
--============================
function SpamThrottle_QQCheck(msg,Author)
	local testResult = false;
	
	if msg == nil then return false end
	
	if string.find(msg, "QQ[ :~%d][ :~%d][ :~%d][ :~%d][ :~%d][ :~%d][ :~%d]") then
		testResult = true;
	end
	
	local Nlen = string.len(msg);
	
	for i = 1, string.len(msg) do
		if string.byte(string.sub(msg,i,i)) > 225 then
			testResult = true;
		end
	end
	
	if testResult then
		SpamThrottleMessage(DebugMsg,"QQCheck flagged: (",Author,") ",msg);
	end
	
	return testResult;
end

--============================
--= SpamScoreBlock - Determine the spam score and perma-block if exceeded
--= Returns TRUE if blocked
--= Returns FALSE if clear
--============================
function SpamThrottle_SpamScoreBlock(msg,NormalizedMessage,Author,multiCheck)
	local theScore = 0;
	local theThreshold = 4;
	local BlockFlag = false;
	
--	ScoreMsg = multiCheck
	
	local index = table.find(SpamThrottle_PlayerFilterList,string.upper(Author));
	if index then return true; end
	
	for key, value in pairs(SpamThrottleGSO2) do
		local testval = SpamThrottle_strNorm(value,"");
		if (string.find(NormalizedMessage,testval) ~= nil) then
			theScore = theScore + 2
			SpamThrottleMessage(ScoreMsg, "Match : ".. testval)
		end
	end
	
	for key, value in pairs(SpamThrottleGSO1) do
		local testval = SpamThrottle_strNorm(value,"");
		if (string.find(NormalizedMessage,testval) ~= nil) then
			theScore = theScore + 1
			SpamThrottleMessage(ScoreMsg, "Match : ".. testval)
		end
	end
	
	for key, value in pairs(SpamThrottleGSC2) do
		if (string.find(msg,value) ~= nil) then
			theScore = theScore + 2
			SpamThrottleMessage(ScoreMsg, "Match : ".. value)
		end
	end
	
	for key, value in pairs(SpamThrottleGSC1) do
		if (string.find(msg,value) ~= nil) then
			theScore = theScore + 1
			SpamThrottleMessage(ScoreMsg, "Match : ".. value)
		end
	end
	
	for key, value in pairs(SpamThrottleGSUC5) do
		if (string.find(string.upper(msg),value) ~= nil) then
			theScore = theScore + 5
			SpamThrottleMessage(ScoreMsg, "Match : ".. value)
		end
	end

	for key, value in pairs(SpamThrottleSWLO) do
		local testval = SpamThrottle_strNorm(value,Author);
		if (string.find(NormalizedMessage,testval) ~= nil) then
			theScore = theScore + 100
		end
	end
	SpamThrottleMessage(ScoreMsg, "Score : "..theScore.." : "..Author.." : "..msg.." : "..NormalizedMessage);
	SpamThrottleMessageHex(ScoreMsg, msg);
	
	if theScore > theThreshold then
		BlockFlag = true;
		SpamThrottle_AddPlayerban(Author);
		SpamThrottle_PlayerbanList_Update();
		SpamThrottleMessage(ScoreMsg, "Blocked "..Author.." gold advertising: "..msg);
	end
	
	return BlockFlag;
end

--============================
--= ShouldBlock - Determine whether message should be blocked.
--= return = 0, don't block.
--= return = 1, use graytext to de-emphasize
--= return = 2, block altogether.
--============================
function SpamThrottle_ShouldBlock(msg,Author,event,channel,multiCheck)
	local BlockFlag = false;
	local NormalizedMessage = "";
	
	
	NormalizedMessage = SpamThrottle_strNorm(msg, Author);
	UpperCaseMessage = string.upper(msg);
	OriginalMessage = msg;
	

	if (NormalizedMessage == nil) then	-- If no message just tell caller to block altogether
		return 2;
	end

	if (SpamThrottle_Config.STActive == false or Author == UnitName("player")) then	-- If filter not active or it's our message, just let it go thru
		return 0;
	end

	if (SpamThrottle_Config.STWhiteChannel1 ~= "" or SpamThrottle_Config.STWhiteChannel2 ~= "" or SpamThrottle_Config.STWhiteChannel3 ~= "") then
		local normChannel = SpamThrottle_strNorm(channel,"");
		local testval1 = SpamThrottle_strNorm(SpamThrottle_Config.STWhiteChannel1,"");
		local testval2 = SpamThrottle_strNorm(SpamThrottle_Config.STWhiteChannel2,"");
		local testval3 = SpamThrottle_strNorm(SpamThrottle_Config.STWhiteChannel3,"");
						
		if (testval1 ~= "" and string.find(normChannel,testval1) ~= nil) then return 0; end;
		if (testval2 ~= "" and string.find(normChannel,testval2) ~= nil) then return 0; end;
		if (testval3 ~= "" and string.find(normChannel,testval3) ~= nil) then return 0; end;
	end

	if time() - LastPurgeTime > 5 then
		SpamThrottleMessage(DebugMsg,"purging database to free memory");
		for chan, msgs in pairs(MessageList) do
			for key, value in pairs(msgs) do
				if time() - value.firstTime > SpamThrottle_Config.STGap then
					SpamThrottleMessage(DebugMsg,"Removing key ",key," as it is older than timeout.");
					MessageList[chan][key] = nil;
				end
			end
		end
		
		if not multiCheck then
			local remove = {}
			for playerName, value in pairs(MultiMessageCache) do
				if time() - value.lastMessage > 30 then
					SpamThrottleMessage(DebugMsg,"Removing player ",playerName," from multi-message cache (timeout).");
					table.insert(remove, playerName)
				end
			end
			for _, playerName in ipairs(remove) do
				MultiMessageCache[playerName] = nil
			end
		end
		LastPurgeTime = time();
	end
	
	if string.find(msg, SpamThrottleGeneralMask) then BlockFlag = true; end
	
	if multiCheck then SpamThrottleMessage(false, "multiCheck") end
	if SpamThrottle_SpamScoreBlock(msg,NormalizedMessage,Author,multiCheck) then BlockFlag = true; end

	if not SpamThrottle_Config.STBanPerm then
		if time() - LastAuditTime > PlayerListAuditGap then
			SpamThrottleMessage(DebugMsg, "auditing player filter list and expiring timeouts");
			LastAuditTime = time();
			for key,value in pairs(SpamThrottle_PlayerBanTime) do
				if time() - value > SpamThrottle_Config.STBanTimeout then
					SpamThrottleMessage(DebugMsg, "removing playername " .. key .. " from player filter list");
					SpamThrottle_PlayerBanTime[string.upper(key)] = nil;
					local index = table.find(SpamThrottle_PlayerFilterList,string.upper(key));
					if index then table.remove(SpamThrottle_PlayerFilterList,index) end;
					SpamThrottle_PlayerbanList_Update();
				end
			end
		end
	end

	for key, value in pairs(SpamThrottle_KeywordFilterList) do
		local testval = SpamThrottle_strNorm(value,"");
		if (string.find(NormalizedMessage,testval) ~= nil) then BlockFlag = true; end
	end

	if SpamThrottle_Config.STReverse then -- Completely different processing if this is the case
		if BlockFlag then -- we have a match with the keyword filter, let it go through.
			return 0;
		else
			if SpamThrottle_Config.STColor then
				return 1;
			else
				return 2;
			end
		end
	end
	
	for key, value in pairs(SpamThrottle_PlayerFilterList) do
		local testval = string.upper(string.gsub(value," ",""));
		if (string.find(string.upper(Author),testval) ~= nil) then BlockFlag = true; end
	end

	if (SpamThrottle_Config.STChinese) then
		if (string.find(OriginalMessage,"[\228-\233]") ~=nil) then BlockFlag = true; end
		if SpamThrottle_QQCheck(OriginalMessage,Author) then BlockFlag = true; end
	end

	local frameName = this:GetName()
	
	
	if not multiCheck then
		local hash = StringHash(NormalizedMessage);
		if (SpamThrottle_Config.STDupFilter and MessageList[frameName][hash] ~= nil) then	-- If duplicate message filter enabled AND we have seen this exact text before
		
					if time() - MessageList[frameName][hash].firstTime <= SpamThrottle_Config.STGap then
				BlockFlag = true;
						SpamThrottleMessage(DebugMsg, "DUP:", msg);
			end
				
		end
				
	end

	if BlockFlag then
		FilteredCount = FilteredCount + 1;
	end
	
	if SpamThrottle_Config.STColor then
		if BlockFlag then
			return 1;
		end
	end
	
	if BlockFlag then
		return 2;
	end
		
	return 0;
end

--============================
--= SpamThrottle_ShouldMultiBlock - Determine whether message should be blocked
--= based on previous messages of the same author
--= return = 0, don't block.
--= return = 1, use graytext to de-emphasize
--= return = 2, block altogether.
--============================
function SpamThrottle_ShouldMultiBlock(msg,Author,event,channel)
	if (SpamThrottle_Config.STActive == false or Author == UnitName("player")) then -- If filter not active or it's our message, just let it go thru
		return 0
	end
	local frameName = this:GetName()
	if MultiMessageCache[Author] == nil then
		MultiMessageCache[Author] = {
			lastMessage = 0,
			history = {}
		}
	end
	local playerCache = MultiMessageCache[Author]

	local payload = {
		msg = msg,
		event = event,
		channel = channel,
		time = time()
		--playerCache.lastMessage
	}
	if playerCache.history[frameName] == nil then playerCache.history[frameName]={} end
	table.insert(playerCache.history[frameName], payload)

	-- concatenate all messages sent in the past few seconds
	local multiMsg = ""
	local numMsg = 0
	for i, pl in ipairs(playerCache.history[frameName]) do
--		SpamThrottleMessage(true, "cache "..i.." : "..pl.msg)
		local dTime = time() - pl.time
--		SpamThrottleMessage(true,"dTime: "..dTime)
		if dTime < 20 then
			multiMsg = string.format("%s%s", multiMsg, pl.msg)
			numMsg = numMsg + 1
		end
	end
	-- check if combined message should be blocked
	local ShouldBlock = 0
	if numMsg > 1 then
		--SpamThrottleMessage(true, "MultiMSG:"..multiMsg)
		ShouldBlock = SpamThrottle_ShouldBlock(multiMsg,Author,event,channel,true)
	end
	return ShouldBlock
end

--============================
--= ChatFrame_OnEvent - The main event handler
--============================
function SpamThrottle_ChatFrame_OnEvent(event, WIM_msg)
-- arg1 is the actual message
-- arg2 is the player name
-- arg4 is the composite channel name (e.g. "3. global")
-- arg8 is the channel number (e.g. "3")
-- arg9 is the channel name (e.g. "global")

	local hideColor = "|cFF5C5C5C";
	local oppFacColor = "|cA0A00000";
	local theColor = hideColor;
	local frameName = this:GetName()
	if SpamThrottle_Config == nil then SpamThrottle_init(); end
	
	if not SpamThrottle_Config.STActive then
		if WIM_msg then 
			SpamThrottle_Orig_WIM_ChatFrame_OnEvent(event)
		else 
		SpamThrottle_OrigChatFrame_OnEvent(event);
		end
		return;
	end;
	if (SpamThrottle_Config.STCtrlMsgs) then -- Remove the "has invited you to join the channel"-spam and left/joined channel spam and a few other notification messages
		if (event == "CHANNEL_INVITE_REQUEST" or event == "CHAT_MSG_CHANNEL_JOIN" or event == "CHAT_MSG_CHANNEL_LEAVE" or event == "CHAT_MSG_CHANNEL_NOTICE" or event == "CHAT_MSG_CHANNEL_NOTICE_USER") then		
  			
			return;
		end
	end
			
	if arg2 then -- if this is not a server message
		if (event == "CHAT_MSG_CHANNEL" or (event == "CHAT_MSG_YELL" and SpamThrottle_Config.STYellMsgs) or (event == "CHAT_MSG_SAY" and SpamThrottle_Config.STSayMsgs) or (event == "CHAT_MSG_WHISPER" and SpamThrottle_Config.STWispMsgs) or event == "CHAT_MSG_EMOTE" 
		or event == "CHAT_MSG_TEXT_EMOTE") then
			
			
			
			-- Code to handle message goes here. Just return if we are going to ignore it.
			local channelFound

			if event == "CHAT_MSG_CHANNEL" then
				for index, value in this.channelList do
					if ((arg7 > 0) and (this.zoneChannelList[index] == arg7)) or strupper(value) == strupper(arg9) then
						channelFound = value
					end
				end
				if not channelFound then return end
			end
			SpamThrottleMessage(false, GetTime(), frameName,event,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9);
			if arg1 and arg2 then	-- only execute this code once although event handler is called many times per message
				local NormalizedMessage = SpamThrottle_strNorm(arg1, arg2);
				--if time() == MessageLatestTime[NormalizedMessage] then return end;
			end

			
			local BlockType = SpamThrottle_ShouldBlock(arg1,arg2,event,arg9);
			

			if SpamThrottle_Config.STMultiWisp and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_CHANNEL" ) and not SpamThrottle_Config.STReverse and not WIM_msg then
				if BlockType == 0 then
					BlockType = SpamThrottle_ShouldMultiBlock(arg1,arg2,event,arg9);
				end
			end
			
			SpamThrottle_RecordMessage(arg1,arg2);
			
			if BlockType ~= 0 then
				SpamThrottle_LastPlayerFiltered = arg2
			end
			
			if SpamThrottle_Config.STWispBack and event == "CHAT_MSG_WHISPER" and not SpamThrottle_Config.STReverse and not WIM_Present then
				if BlockType == 1 or BlockType == 2 then
					SendChatMessage(SpamThrottleChatMsg.WhisperBack, "WHISPER", nil, arg2);
					SpamThrottleMessage(BlockReportMode, "BLOCKED [",arg4,"] {",arg2,"} ",arg1);
					return;
				end
			end

			if BlockType == 2 then
				SpamThrottleMessage(BlockReportMode, "BLOCKED [",arg4,"] {",arg2,"} ",arg1);
				return;
			end
			
			if BlockType == 3 then
				theColor = oppFacColor;
			end
			
			if BlockType == 1 or BlockType == 3 then
				local CleanText = "";
				CleanText = string.gsub(arg1,"|c%x%x%x%x%x%x%x%x", "");
				CleanText = string.gsub(CleanText,"|r", "");
				CleanText = string.gsub(CleanText,"|H.-|h", "");
				CleanText = string.gsub(CleanText,"|h", "");
				
				if event == "CHAT_MSG_YELL" then
					CleanText = theColor .. "[" .. arg2 .. "] yells: " .. CleanText .. "|r";
				else
					if event == "CHAT_MSG_SAY" then
						CleanText = theColor .. "[" .. arg2 .. "] says: " .. CleanText .. "|r";
					else
						if event == "CHAT_MSG_WHISPER" then
							CleanText = theColor .. "[" .. arg2 .. "] whispers: " .. CleanText .. "|r";
						else
							if event == "CHAT_MSG_EMOTE" then
								CleanText = theColor .. arg2 .. " " .. CleanText .. "|r";
						else
								CleanText = theColor .. "[" .. arg4 .. "] [" .. arg2 .. "]: " .. CleanText .. "|r";
							end
						end
					end
				end
				
				this:AddMessage(CleanText);
				return;
			end
		end
	end

	local theStatusValue = string.format("%7d",UniqueCount);
	SpamThrottleStatusValue5:SetText(theStatusValue);

	theStatusValue = string.format("%7d",FilteredCount);
	SpamThrottleStatusValue6:SetText(theStatusValue);
	
	if WIM_msg then 
		SpamThrottle_Orig_WIM_ChatFrame_OnEvent(event)
	else 
	SpamThrottle_OrigChatFrame_OnEvent(event);
	end
end

function SpamThrottle_WIM_ChatFrame_OnEvent(event)
	SpamThrottle_ChatFrame_OnEvent(event, true)
end


--============================
--= Register the Slash Command
--============================
SlashCmdList["SPTHRTL"] = function(_msg)
	if (_msg) then
		local _, _, cmd, arg1 = string.find(string.upper(_msg), "([%w]+)%s*(.*)$");
		if ("OFF" == cmd) then -- disable the filter
			local confirmMsg = SpamThrottleCmdMsg.confirmMsgDisabled
			SpamThrottle_Config.STActive = false;
			DEFAULT_CHAT_FRAME:AddMessage(confirmMsg);
		elseif ("ON" == cmd) then -- enable the filter
			local confirmMsg = SpamThrottleCmdMsg.confirmMsgEnabled
			SpamThrottle_Config.STActive = true;
			if SpamThrottle_Config.STColor then
				confirmMsg = confirmMsg .. SpamThrottleCmdMsg.confirmMsgColorMode
			else
				confirmMsg = confirmMsg .. SpamThrottleCmdMsg.confirmMsgHideMode
			end
			DEFAULT_CHAT_FRAME:AddMessage(confirmMsg);
		elseif ("COLOR" == cmd) then -- change the spam to a darker color to make it easy for your eyes to skip (but you still see it)
			SpamThrottle_Config.STColor = true;
			DEFAULT_CHAT_FRAME:AddMessage(SpamThrottleCmdMsg.COLOR);
		elseif ("HIDE" == cmd) then -- completely hide the spam
			SpamThrottle_Config.STColor = false;
			DEFAULT_CHAT_FRAME:AddMessage(SpamThrottleCmdMsg.HIDE);
		elseif ("FUZZY" == cmd) then -- enable the fuzzy matching filter (default)
			SpamThrottle_Config.STFuzzy = true;
			DEFAULT_CHAT_FRAME:AddMessage(SpamThrottleCmdMsg.FUZZY);
		elseif ("NOFUZZY" == cmd) then -- disable the fuzzy matching filter, instead requiring exact matches
			SpamThrottle_Config.STFuzzy = false;
			DEFAULT_CHAT_FRAME:AddMessage(SpamThrottleCmdMsg.NOFUZZY);
		elseif ("CBLOCK" == cmd) then -- block messages with chinese/japanese/korean characters
				SpamThrottle_Config.STChinese = true;
				DEFAULT_CHAT_FRAME:AddMessage(SpamThrottleCmdMsg.CBLOCK);
		elseif ("NOCBLOCK" == cmd) then -- allow messages with chinese/japanese/korean characters
				SpamThrottle_Config.STChinese = false;
				DEFAULT_CHAT_FRAME:AddMessage(SpamThrottleCmdMsg.NOCBLOCK);
		elseif ("RESET" == cmd) then -- reset the unique message list
			MessageList = {}
		
			DEFAULT_CHAT_FRAME:AddMessage(SpamThrottleCmdMsg.RESET);
		elseif (tonumber(_msg) ~= nil) then
			local gapseconds = tonumber(_msg);
			if (gapseconds >= 0 and gapseconds <= 10000) then
				SpamThrottle_Config.STGap = tonumber(_msg);
				DEFAULT_CHAT_FRAME:AddMessage(SpamThrottleCmdMsg.GappingSetTo .. SpamThrottle_Config.STGap .. SpamThrottleCmdMsg.GappingSeconds);
			else
				DEFAULT_CHAT_FRAME:AddMessage(SpamThrottleCmdMsg.GappingCanOnlySet);
			end
		elseif ("HELP" == cmd) then
			SpamThrottleMessage(true,SpamThrottleCmdMsg.HELP);
			
		elseif ("TEST" == cmd) then
			-- Placeholder for testing
		else -- Just show the configuration frame
			SpamThrottleConfigFrame:Show();
		end
	end
end

SLASH_SPTHRTL1 = "/spamthrottle";
SLASH_SPTHRTL2 = "/st";

local AddonName, core = ...;
LFGListFrame.SearchPanel.idHook = 0;

SLASH_RELOADUI1 = "/rl";
SlashCmdList["RELOADUI"] = ReloadUI;

SLASH_FRAMESTK1 = "/fs";
SlashCmdList["FRAMESTK"] = function()
	LoadAddOn("Blizzard_DebugTools");
	FrameStackTooltip_Toggle();
end

local L = {
    ["TOP"] = "고통의 투기장",
    ["HOA"] = "속죄의 전당",
    ["SOA"] = "승천의 첨탑",
    ["PF"] = "역병 몰락지",
    ["DOS"] = "저편",
    ["NW"] = "죽음의 상흔",
    ["MOTS"] = "티르너 사이드의 안개",
    ["SD"] = "핏빛 심연",
    ["TVM"] = "미지의 시장 타자베쉬",
    ["TSW"] = "타자베쉬: 경이의 거리",
    ["TSG"] = "타자베쉬: 소레아의 승부수",
};
local L2 = {
    ["TOP"] = "고투",
    ["HOA"] = "속죄",
    ["SOA"] = "승천",
    ["PF"] = "역병",
    ["DOS"] = "저편",
    ["NW"] = "죽상",
    ["MOTS"] = "티르",
    ["SD"] = "심연",
    ["TVM"] = "타자",
    ["TSW"] = "거리",
    ["TSG"] = "승부",
};
local dungeonPatterns = {
    ["TOP"] = {"고통", "투기", "고투"},
    ["HOA"] = {"속죄"},
    ["SOA"] = {"승천"},
    ["PF"] = {"역병"},
    ["DOS"] = {"저편"},
    ["NW"] = {"상흔", "죽상"},
    ["MOTS"] = {"티르", "안개"},
    ["SD"] = {"핏빛", "심연"},
    ["TVM"] = {"타자", "시장"},
    ["TSW"] = {"타자", "거리"},
    ["TSG"] = {"타자", "승부", "소레"},
};
local dungeonIDs = {
    ["TOP"] = {716, 719, 718, 717}, -- Theater of Pain
    ["HOA"] = {696, 697, 698, 699}, -- Halls of Atonement
    ["SOA"] = {708, 711, 710, 709}, -- Spires of Ascension
    ["PF"] = {688, 689, 690, 691},  -- Plaguefall
    ["DOS"] = {692, 693, 694, 695}, -- De Other Side
    ["NW"] = {712, 715, 714, 713},  -- The Necrotic Wake
    ["MOTS"] = {700, 701, 702, 703},-- Mists of Tirna Scithe
    ["SD"] = {704, 707, 706, 705},  -- Sanguine Depths
    ["TVM"] = {746},                -- Tazavesh, the Veiled Market
    ["TSW"] = {1018, 1016},         -- Tazavesh: Streets of Wonder
    ["TSG"] = {1019, 1017},         -- Tazavesh: So'Leah's Gambit
};

for i = 1, NUM_CHAT_WINDOWS do
	_G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false)
end
	
local function GetRioScore(fullname)    
    local score = 0;    
    
	if not RaiderIO then return score end;
	
	if not string.match(fullname, "-") then
        local realmName = string.gsub(GetRealmName(), " ", "");
        fullname = fullname.."-"..realmName;        
    end
	
    local FACTIONS = { Alliance = 1, Horde = 2, Neutral = 3 }
	local playerFactionID = FACTIONS[UnitFactionGroup("player")]	
    local playerProfile = RaiderIO.GetProfile(fullname, playerFactionID);
	local currentScore = 0;
	local previousScore = 0;

	if (playerProfile ~= nil) then
		if playerProfile.mythicKeystoneProfile ~= nil then
			currentScore = playerProfile.mythicKeystoneProfile.currentScore or 0;	
			previousScore = playerProfile.mythicKeystoneProfile.previousScore or 0;
        end
	end	

	score = currentScore

	if LFGListFrame.SearchPanel.showPreviousRIO == true and currentScore < previousScore then
		score = previousScore
	end
	
    return score;
end

local function tablefind(tab,el)
    for index, value in pairs(tab) do
        if value == el then
            return index
        end
    end
end

local function trim(str)
    local match = string.match
    return match(str,'^()%s*$') and '' or match(str,'^%s*(.*%S)')
end

local function componentToHex(c)
  c = math.floor(c * 255)
  local hex = string.format("%x", c)
  if (hex:len() == 1) then
	return "0"..hex;
  end
  return hex;
end

local function rgbToHex(r, g, b)
  return componentToHex(r)..componentToHex(g)..componentToHex(b);
end

local function getColorStr(hexColor)
	return "|cff"..hexColor.."+|r";
end

local function getRioScoreColorText(rioScore) 
    if not RaiderIO then return nil end;
    
    local r, g, b = RaiderIO.GetScoreColor(rioScore);
    local hex = rgbToHex(r, g, b);    
    return getColorStr(hex);
end

local function getRioScoreText(rioScore)
    local colorText = getRioScoreColorText(rioScore);
    if colorText == nil then return "" end
    
    local rioText = colorText:gsub("+", rioScore);
    
    local textFormat = "[@rio]"
    if (textFormat ~= nil and trim ~= nil and trim(textFormat) ~= "") then
        rioText = textFormat:gsub("@rio", rioText)        
    end
    
    return rioText.." ";
end

local function getIndex(values, val)
	local index={};
	for k,v in pairs(values) do
	   index[v]=k;
	end
	return index[val];
end

local function hasValue (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end    
    return false
end

local function countValue (tab, val)
    local count = 0;
    for index, value in ipairs(tab) do
        if value == val then
            count = count + 1;
        end
    end    
    return count
end	

local function filterTable(t, ids)
    for i, id in ipairs(ids) do
        for j = #t, 1, -1 do
            if ( t[j] == id ) then
                tremove(t, j);
                break;
            end
        end
    end
end

local function addFilteredId(self, id)
    if ( not self.filteredIDs ) then
        self.filteredIDs = { };
    end
    tinsert(self.filteredIDs, id);
end

function init(self, event, arg1)

	if (event == "ADDON_LOADED" and arg1 == AddonName ) then
		local function initDB(db, ...)
			local defaults = ...;
			if type(db) ~= "table" then db = {} end
			if type(defaults) ~= "table" then return db end
			for k, v in pairs(defaults) do
				if type(v) == "table" then
					db[k] = initDB(db[k], v)
				elseif type(v) ~= type(db[k]) then
					db[k] = v
				end
			end
			return db
		end

		LFGFilterSettings = initDB(LFGFilterSettings);

		self:UnregisterEvent("ADDON_LOADED");
	end	

	if (event == "PLAYER_LOGIN") then
        local function OnEnter(self, motion)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if self.tooltipTitle ~= nil then
                GameTooltip:SetText(self.tooltipTitle)
            elseif self:GetText() ~= nil then
                GameTooltip:SetText(self:GetText())
            end
            GameTooltip:AddLine(tostring(self.tooltipText), 1, 1, 1)
            GameTooltip:Show()
        end

        local function OnLeave(self, motion)
            GameTooltip:Hide()
        end

		local function CreateButton(relativeFrame, typebutton, text, role, name, xPoint, yPoint)
	
			local isEnabled = LFGFilterSettings[name] or false;
			local button = CreateFrame("Button", nil, relativeFrame, "GameMenuButtonTemplate");
			local disabledTexture = "Interface\\Buttons\\UI-Panel-Button-Disabled";
			local enabledTexture = "Interface\\Buttons\\UI-Panel-Button-Up";
			
			local function setTexture(self, texture)
				self.Left:SetTexture(texture);
				self.Middle:SetTexture(texture);
				self.Right:SetTexture(texture);
			end

			local function setButton(btn, enabled, fromScript)
				if (fromScript == true) then btn.enabled = not btn.enabled; else btn.enabled = enabled; end				
				if (btn.enabled == true) then				
					setTexture(btn, enabledTexture);
					if (typebutton == "Filter") then	
						if (LFGListFrame.SearchPanel.filter[role] < 3) then
							LFGListFrame.SearchPanel.filter[role] = LFGListFrame.SearchPanel.filter[role] + 1;
						end
                    elseif (typebutton == "Include") then
						if (LFGListFrame.SearchPanel.include[role] < 3) then
							LFGListFrame.SearchPanel.include[role] = LFGListFrame.SearchPanel.include[role] + 1;
						end
                    else
						if (LFGListFrame.SearchPanel.dungeon[role] < 1) then
							LFGListFrame.SearchPanel.dungeon[role] = LFGListFrame.SearchPanel.dungeon[role] + 1;
						end
					end
				else	
					setTexture(btn, disabledTexture);
					if (fromScript == true) then	
						if (typebutton == "Filter") then
							if (LFGListFrame.SearchPanel.filter[role] > 0) then
								LFGListFrame.SearchPanel.filter[role] = LFGListFrame.SearchPanel.filter[role] - 1;
							end
						elseif (typebutton == "Include") then
							if (LFGListFrame.SearchPanel.include[role] > 0) then
								LFGListFrame.SearchPanel.include[role] = LFGListFrame.SearchPanel.include[role] - 1;
							end
                        else
							if (LFGListFrame.SearchPanel.dungeon[role] > 0) then
								LFGListFrame.SearchPanel.dungeon[role] = LFGListFrame.SearchPanel.dungeon[role] - 1;
							end
						end
					end
				end					
				
				if (typebutton == "Filter") then
					LFGListFrame.SearchPanel.filterTankCount = LFGListFrame.SearchPanel.filter["TANK"];
					LFGListFrame.SearchPanel.filterHealerCount = LFGListFrame.SearchPanel.filter["HEALER"];
					LFGListFrame.SearchPanel.filterDamagerCount = LFGListFrame.SearchPanel.filter["DAMAGER"];
				elseif (typebutton == "Include") then
					LFGListFrame.SearchPanel.includeTankCount = LFGListFrame.SearchPanel.include["TANK"];
					LFGListFrame.SearchPanel.includeHealerCount = LFGListFrame.SearchPanel.include["HEALER"];
					LFGListFrame.SearchPanel.includeDamagerCount = LFGListFrame.SearchPanel.include["DAMAGER"];			
                else
                    local includeDungeons = {}
                    local includeDungeonCount = 0
                    for k,v in pairs(LFGListFrame.SearchPanel.dungeon) do
                        if v > 0 then
                            includeDungeons[k] = v
					        includeDungeonCount = includeDungeonCount + 1
                        end
                    end
                    LFGListFrame.SearchPanel.includeDungeons = includeDungeons
					LFGListFrame.SearchPanel.includeDungeonCount = includeDungeonCount
				end
			end
			
			button:SetPoint("LEFT", relativeFrame, "LEFT", xPoint, yPoint);
            if (typebutton == "Dungeon") then
			    button:SetSize(40, 20);
            else
			    button:SetSize(20, 20);
            end
			button:SetText(text);
			button:SetNormalFontObject("GameFontNormalSmall");
			button:SetHighlightFontObject("GameFontHighlightSmall");			
			button:SetScript("OnShow", function(self) end);	
			button:SetScript("OnClick", function(self)
				setButton(self, self.enabled, true);				
				LFGFilterSettings[name] = self.enabled;
			end);		
			
            if (typebutton == "Filter") then
                button.tooltipTitle = "Exclude role";
                button.tooltipText = role;
            elseif (typebutton == "Include") then
                button.tooltipTitle = "Include role";
                button.tooltipText = role;
            else
                button.tooltipText = L[role]
            end
            button:SetScript("OnEnter", OnEnter);
            button:SetScript("OnLeave", OnLeave);

			setButton(button, isEnabled, false);
		
			return button;
		end
		
		local DF = CreateFrame("Frame", "DF_Frame", LFGListFrame.SearchPanel, "InsetFrameTemplate3");
		
		DF:SetSize(160 + 40, 120 + 50);
		--DF:SetPoint("BOTTOMRIGHT", LFGListFrame.SearchPanel, "BOTTOMRIGHT", 0, -130 - 80);
		DF:SetPoint("BOTTOMLEFT", LFGListFrame.SearchPanel, "BOTTOMRIGHT", 2, 0);
		DF:SetMovable(true);
		DF:EnableMouse(true);
		DF:RegisterForDrag("LeftButton")
		DF:SetScript("OnDragStart", DF.StartMoving)
		DF:SetScript("OnDragStop", DF.StopMovingOrSizing)
		
		LFGListFrame.SearchPanel.filter = {
			["TANK"] = 0,
			["HEALER"] = 0,
			["DAMAGER"] = 0
		};
		
		LFGListFrame.SearchPanel.include = {
			["TANK"] = 0,
			["HEALER"] = 0,
			["DAMAGER"] = 0
		};

        LFGListFrame.SearchPanel.dungeon = {
            ["TOP"] = 0,
            ["HOA"] = 0,
            ["SOA"] = 0,
            ["PF"] = 0,
            ["DOS"] = 0,
            ["NW"] = 0,
            ["MOTS"] = 0,
            ["SD"] = 0,
            ["TSW"] = 0,
            ["TSG"] = 0,
        };
		
		LFGListFrame.SearchPanel.filterTankCount = 0
		LFGListFrame.SearchPanel.filterHealerCount = 0
		LFGListFrame.SearchPanel.filterDamagerCount = 0
		LFGListFrame.SearchPanel.includeTankCount = 0
		LFGListFrame.SearchPanel.includeHealerCount = 0
		LFGListFrame.SearchPanel.includeDamagerCount = 0
        LFGListFrame.SearchPanel.includeDungeons = {}
        LFGListFrame.SearchPanel.includeDungeonCount = 0

        local dy = 30
        local y = -25
		DF.applyBtn = CreateFrame("Button", nil, DF, "GameMenuButtonTemplate");
		DF.applyBtn:SetPoint("RIGHT", DF, "RIGHT", -5, -40 + y);
		DF.applyBtn:SetSize(50, 20);
		DF.applyBtn:SetText("Apply");
		DF.applyBtn:SetNormalFontObject("GameFontNormalSmall");
		DF.applyBtn:SetHighlightFontObject("GameFontHighlightSmall");	

        DF.dungeonTOPBtn = CreateButton(DF, "Dungeon", L2["TOP"], "TOP", "DungeonTOPButton", 0, 35 + dy);
        DF.dungeonHOABtn = CreateButton(DF, "Dungeon", L2["HOA"], "HOA", "DungeonHOAButton", 40, 35 + dy);
        DF.dungeonSOABtn = CreateButton(DF, "Dungeon", L2["SOA"], "SOA", "DungeonSOAButton", 80, 35 + dy);
        DF.dungeonPFBtn = CreateButton(DF, "Dungeon", L2["PF"], "PF", "DungeonPFButton", 120, 35 + dy);
        DF.dungeonPFBtn = CreateButton(DF, "Dungeon", L2["TSW"], "TSW", "DungeonTSWButton", 160, 35 + dy);
        DF.dungeonDOSBtn = CreateButton(DF, "Dungeon", L2["DOS"], "DOS", "DungeonDOSButton", 0, 10 + dy);
        DF.dungeonNWBtn = CreateButton(DF, "Dungeon", L2["NW"], "NW", "DungeonNWButton", 40, 10 + dy);
        DF.dungeonMOTSBtn = CreateButton(DF, "Dungeon", L2["MOTS"], "MOTS", "DungeonMOTSButton", 80, 10 + dy);
        DF.dungeonSDBtn = CreateButton(DF, "Dungeon", L2["SD"], "SD", "DungeonSDButton", 120, 10 + dy);
        DF.dungeonSDBtn = CreateButton(DF, "Dungeon", L2["TSG"], "TSG", "DungeonTSGButton", 160, 10 + dy);

        local x = 40
		DF.filterLabel = DF:CreateFontString(nil , "BORDER", "GameFontNormal");
		DF.filterLabel:SetJustifyH("CENTER");
		DF.filterLabel:SetPoint("LEFT", DF, "LEFT", 10, 35 + y);
		DF.filterLabel:SetText("Filter:");

		DF.tankFilterBtn = CreateButton(DF, "Filter", "T", "TANK", "TankFilterButton", x + 10, 35 + y);
		DF.healerFilterBtn = CreateButton(DF, "Filter", "H", "HEALER", "HealerFilterButton",  x + 40, 35 + y);
		DF.damager1FilterBtn = CreateButton(DF, "Filter", "D", "DAMAGER", "Damager1FilterButton", x + 70, 35 + y);
		DF.damager2FilterBtn = CreateButton(DF, "Filter", "D", "DAMAGER", "Damager2FilterButton", x + 100, 35 + y);
		DF.damager3FilterBtn = CreateButton(DF, "Filter", "D", "DAMAGER", "Damager3FilterButton", x + 130, 35 + y);

		DF.includeLabel = DF:CreateFontString(nil , "BORDER", "GameFontNormal");
		DF.includeLabel:SetJustifyH("CENTER");
		DF.includeLabel:SetPoint("LEFT", DF, "LEFT", 10, 10 + y);
		DF.includeLabel:SetText("Incl.:");

		DF.tankIncludeBtn = CreateButton(DF, "Include", "T", "TANK", "TankIncludeButton", x + 10, 10 + y);
		DF.healerIncludeBtn = CreateButton(DF, "Include", "H", "HEALER", "HealerIncludeButton", x + 40, 10 + y);
		DF.damager1IncludeBtn = CreateButton(DF, "Include", "D", "DAMAGER", "Damager1IncludeButton", x + 70, 10 + y);
		DF.damager2IncludeBtn = CreateButton(DF, "Include", "D", "DAMAGER", "Damager2IncludeButton", x + 100, 10 + y);
		DF.damager3IncludeBtn = CreateButton(DF, "Include", "D", "DAMAGER", "Damager3IncludeButton", x + 130, 10 + y);

		local function OnClickApply(self)
			DF.maxRioEdit:ClearFocus();
			DF.minRioEdit:ClearFocus();
			
			local minRio = DF.minRioEdit:GetNumber();
			local maxRio = DF.maxRioEdit:GetNumber();	
			
			if (not minRio or minRio == 0) then minRio = -1 end
			if (not maxRio or maxRio == 0) then maxRio = 9999 end

			LFGListFrame.SearchPanel.maxRio = maxRio;
			LFGListFrame.SearchPanel.minRio = minRio;			

			LFGFilterSettings["minRioEdit"] = LFGListFrame.SearchPanel.minRio;	
			LFGFilterSettings["maxRioEdit"] = LFGListFrame.SearchPanel.maxRio;
			
			LFGListSearchPanel_DoSearch(LFGListFrame.SearchPanel);
		end

		DF.applyBtn:SetScript("OnClick", OnClickApply);	
		
		DF.rioLabel = DF:CreateFontString(nil , "BORDER", "GameFontNormal");
		DF.rioLabel:SetJustifyH("CENTER");
		DF.rioLabel:SetPoint("LEFT", DF, "LEFT", 10, -15 + y);
		DF.rioLabel:SetText("R.IO:");

		DF.minRioEdit = CreateFrame("EditBox", nil, DF, "InputBoxInstructionsTemplate");
		DF.minRioEdit:SetAutoFocus(false);
		DF.minRioEdit:SetPoint("LEFT", DF, "LEFT", x + 15, -15 + y);
		DF.minRioEdit:SetSize(60, 20);
        DF.minRioEdit.tooltipText = "Filter by Raider.IO rating";
        DF.minRioEdit:SetScript("OnEnter", OnEnter);
        DF.minRioEdit:SetScript("OnLeave", OnLeave);
		
		local minRioFromDB = LFGFilterSettings["minRioEdit"];
		LFGListFrame.SearchPanel.minRio = minRioFromDB or -1;
		if (minRioFromDB and minRioFromDB ~= -1) then
			DF.minRioEdit:SetText(minRioFromDB);			
		end

		DF.minRioEdit:SetScript("OnEnterPressed", function(self)
			self:ClearFocus();
			ChatFrame1EditBox:SetFocus();			
			LFGListFrame.SearchPanel.minRio = self:GetNumber();
			LFGFilterSettings["minRioEdit"] = self:GetNumber();
		end);
		
		DF.maxRioEdit = CreateFrame("EditBox", nil, DF, "InputBoxInstructionsTemplate");
		DF.maxRioEdit:SetAutoFocus(false);
		DF.maxRioEdit:SetPoint("LEFT", DF, "LEFT", x + 90, -15 + y);
		DF.maxRioEdit:SetSize(60, 20);
        DF.maxRioEdit.tooltipText = "Filter by Raider.IO rating";
        DF.maxRioEdit:SetScript("OnEnter", OnEnter);
        DF.maxRioEdit:SetScript("OnLeave", OnLeave);
		
		local maxRioFromDB = LFGFilterSettings["maxRioEdit"];		
		LFGListFrame.SearchPanel.maxRio = maxRioFromDB or 9999;
		if (maxRioFromDB and maxRioFromDB ~= 9999) then 
			DF.maxRioEdit:SetText(maxRioFromDB);
		end;	

		DF.maxRioEdit:SetScript("OnEnterPressed", function(self)
			self:ClearFocus();
			ChatFrame1EditBox:SetFocus();
			LFGListFrame.SearchPanel.maxRio = self:GetNumber();
			LFGFilterSettings["maxRioEdit"] = self:GetNumber();
		end);		

		DF.optionLabel = DF:CreateFontString(nil , "BORDER", "GameFontNormal");
		DF.optionLabel:SetJustifyH("CENTER");
		DF.optionLabel:SetPoint("LEFT", DF, "LEFT", 10, -40 + y);
		DF.optionLabel:SetText("Opt.:");

		DF.showRIO = CreateFrame("CheckButton", nil, DF, "UICheckButtonTemplate");
		DF.showRIO:SetPoint("LEFT", DF, "LEFT", x + 5, -40 + y);
		DF.showRIO:SetSize(20, 20);
		DF.showRIO:SetScript("OnClick", function(self)
			local isChecked = self:GetChecked();
			LFGFilterSettings["showRIOChecked"] = isChecked;
			if (isChecked == true) then
				LFGListFrame.SearchPanel.showRIO = true;
			else
				LFGListFrame.SearchPanel.showRIO = false;
			end
			LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel);
		end);
        DF.showRIO.tooltipText = "Show Raider.IO rating";
        DF.showRIO:SetScript("OnEnter", OnEnter);
        DF.showRIO:SetScript("OnLeave", OnLeave);
		
		local showRIOCheckedFromDB = LFGFilterSettings["showRIOChecked"] or false;
		LFGListFrame.SearchPanel.showRIO = showRIOCheckedFromDB;
		DF.showRIO:SetChecked(showRIOCheckedFromDB);

		DF.showClass = CreateFrame("CheckButton", nil, DF, "UICheckButtonTemplate");
		DF.showClass:SetPoint("LEFT", DF, "LEFT", x + 25, -40 + y);
		DF.showClass:SetSize(20, 20);
		DF.showClass:SetScript("OnClick", function(self)
			local isChecked = self:GetChecked();
			LFGFilterSettings["showClassChecked"] = isChecked;
			LFGListFrame.SearchPanel.showClass = isChecked;
			LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel);
		end);
		local showClassCheckedFromDB = LFGFilterSettings["showClassChecked"] or false;
		LFGListFrame.SearchPanel.showClass = showClassCheckedFromDB;
		DF.showClass:SetChecked(showClassCheckedFromDB);
        DF.showClass.tooltipText = "Show classes";
        DF.showClass:SetScript("OnEnter", OnEnter);
        DF.showClass:SetScript("OnLeave", OnLeave);

		DF.removeSelfRole = CreateFrame("CheckButton", nil, DF, "UICheckButtonTemplate");
		DF.removeSelfRole:SetPoint("LEFT", DF, "LEFT", x + 45, -40 + y);
		DF.removeSelfRole:SetSize(20, 20);
		DF.removeSelfRole:SetScript("OnClick", function(self)
			local isChecked = self:GetChecked();
			LFGFilterSettings["removeSelfRoleChecked"] = isChecked;
			LFGListFrame.SearchPanel.removeSelfRole = isChecked;
			LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel);
		end);
		local removeSelfRoleCheckedFromDB = LFGFilterSettings["removeSelfRoleChecked"] or false;
		LFGListFrame.SearchPanel.removeSelfRole = removeSelfRoleCheckedFromDB;
		DF.removeSelfRole:SetChecked(removeSelfRoleCheckedFromDB);
        DF.removeSelfRole.tooltipText = "Hide parties without slot for your role";
        DF.removeSelfRole:SetScript("OnEnter", OnEnter);
        DF.removeSelfRole:SetScript("OnLeave", OnLeave);

		DF.showPreviousRIO = CreateFrame("CheckButton", nil, DF, "UICheckButtonTemplate");
		DF.showPreviousRIO:SetPoint("LEFT", DF, "LEFT", x + 65, -40 + y);
		DF.showPreviousRIO:SetSize(20, 20);
		DF.showPreviousRIO:SetScript("OnClick", function(self)
			local isChecked = self:GetChecked();
			LFGFilterSettings["showPreviousRIOChecked"] = isChecked;
			LFGListFrame.SearchPanel.showPreviousRIO = isChecked;
			LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel);
		end);
		local showPreviousRIOCheckedFromDB = LFGFilterSettings["showPreviousRIOChecked"] or false;
		LFGListFrame.SearchPanel.showPreviousRIO = showPreviousRIOCheckedFromDB;
		DF.showPreviousRIO:SetChecked(showPreviousRIOCheckedFromDB);
        DF.showPreviousRIO.tooltipText = "Show previous season RIO rating";
        DF.showPreviousRIO:SetScript("OnEnter", OnEnter);
        DF.showPreviousRIO:SetScript("OnLeave", OnLeave);

		DF.disabled = CreateFrame("CheckButton", nil, DF, "UICheckButtonTemplate");
		DF.disabled:SetPoint("LEFT", DF, "LEFT", x + 85, -40 + y);
		DF.disabled:SetSize(20, 20);
		DF.disabled:SetScript("OnClick", function(self)
			local isChecked = self:GetChecked();
			LFGFilterSettings["disabled"] = isChecked;
			LFGListFrame.SearchPanel.disabled = isChecked;
			LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel);
		end);
		local disabledCheckedFromDB = LFGFilterSettings["disabled"] or false;
		LFGListFrame.SearchPanel.disabled = disabledCheckedFromDB;
		DF.disabled:SetChecked(disabledCheckedFromDB);
        DF.disabled.tooltipText = "Disable filtering temporarily";
        DF.disabled:SetScript("OnEnter", OnEnter);
        DF.disabled:SetScript("OnLeave", OnLeave);

		SLASH_DF1 = "/df";
		SlashCmdList["DF"] = function()
			if DF:IsShown() then
				DF:Hide()
			else
				DF:Show()
			end
		end

		hooksecurefunc("LFGListSearchEntry_Update", hook_LFGListSearchEntry_Update);
		hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", hook_LFGListApplicationViewer_UpdateApplicantMember);
		hooksecurefunc("LFGListUtil_SortSearchResults", hook_LFGListUtil_SortSearchResults);	
		hooksecurefunc("LFGListUtil_SortApplicants", hook_LFGListUtil_SortApplicants);		
		self:UnregisterEvent("PLAYER_LOGIN");
	end
end

function hook_LFGListSearchEntry_Update(entry, ...)	
	if( not LFGListFrame.SearchPanel:IsShown() ) then return; end
    if( LFGListFrame.SearchPanel.disabled ) then return; end

    local categoryID = LFGListFrame.SearchPanel.categoryID;
    local resultID = entry.resultID;
    local resultInfo = C_LFGList.GetSearchResultInfo(resultID);
    local leaderName = resultInfo.leaderName;
    entry.rioScore = 0;
    
    if (leaderName ~= nil) then
        entry.rioScore = GetRioScore(leaderName);
    end
    
    for i = 1, 5 do
        local texture = "tex"..i;                
        if (entry.DataDisplay.Enumerate[texture]) then
            entry.DataDisplay.Enumerate[texture]:Hide();
        end                
    end
    
    if (categoryID == 2 and LFGListFrame.SearchPanel.showClass == true) then
        local numMembers = resultInfo.numMembers;
        local _, appStatus, pendingStatus, appDuration = C_LFGList.GetApplicationInfo(resultID);
        local isApplication = entry.isApplication;
        
        entry.DataDisplay:SetPoint("RIGHT", entry.DataDisplay:GetParent(), "RIGHT", 0, -5);
        
        local orderIndexes = {};
        
        for i=1, numMembers do                    
            local role, class = C_LFGList.GetSearchResultMemberInfo(resultID, i);
            local orderIndex = getIndex(LFG_LIST_GROUP_DATA_ROLE_ORDER, role);
            table.insert(orderIndexes, {orderIndex, class});
        end
        
        table.sort(orderIndexes, function(a,b)
                return a[1] < b[1]
        end);
        
        local xOffset = -88;
        
        for i = 1, numMembers do
            local class = orderIndexes[i][2];
            local classColor = RAID_CLASS_COLORS[class];
            local r, g, b, a = classColor:GetRGBA();
            local texture = "tex"..i;
            
            if (not entry.DataDisplay.Enumerate[texture]) then
                entry.DataDisplay.Enumerate[texture] = entry.DataDisplay.Enumerate:CreateTexture(nil, "ARTWORK");
                entry.DataDisplay.Enumerate[texture]:SetSize(10, 3);
                entry.DataDisplay.Enumerate[texture]:SetPoint("RIGHT", entry.DataDisplay.Enumerate, "RIGHT", xOffset, 15);
            end
            
            entry.DataDisplay.Enumerate[texture]:Show();                    
            entry.DataDisplay.Enumerate[texture]:SetColorTexture(r, g, b, 0.75);
            
            xOffset = xOffset + 18;                    
        end
    end            
    
    local name = entry.Name:GetText() or "";
    
    local rioText;    
    if (entry.rioScore > 0 and LFGListFrame.SearchPanel.showRIO == true) then
        rioText = getRioScoreText(entry.rioScore);
    else
        rioText = "";
    end
    entry.Name:SetText(rioText..name);
end

function hook_LFGListApplicationViewer_UpdateApplicantMember(member, appID, memberIdx, ...)
    if( RaiderIO == nil ) then return; end
    if( LFGListFrame.SearchPanel.disabled ) then return; end
    
    local textName = member.Name:GetText();
    local name, class = C_LFGList.GetApplicantMemberInfo(appID, memberIdx);
    local rioScore = GetRioScore(name);    
    local rioText;    
    if (rioScore > 0) then
        rioText = getRioScoreText(rioScore);
    else
        rioText = "";
    end
    
    if ( memberIdx > 1 ) then
        member.Name:SetText("  "..rioText..textName);
    else
        member.Name:SetText(rioText..textName);
    end
    
    local nameLength = 100;
    if ( relationship ) then
        nameLength = nameLength - 22;
    end
    
    if ( member.Name:GetWidth() > nameLength ) then
        member.Name:SetWidth(nameLength);
    end
end

function hook_LFGListUtil_SortSearchResults(results)    
    if( LFGListFrame.SearchPanel.disabled ) then return; end

    local sortMethod = 3;
    local removeRole = LFGListFrame.SearchPanel.removeSelfRole;
    local minRio = LFGListFrame.SearchPanel.minRio or -1;
	local maxRio = LFGListFrame.SearchPanel.maxRio or 9999;
    local filterRIO = true;
    local categoryID = LFGListFrame.SearchPanel.categoryID;
    
    local function RemainingSlotsForLocalPlayerRole(lfgSearchResultID)    
        local roleRemainingKeyLookup = {
            ["TANK"] = "TANK_REMAINING",
            ["HEALER"] = "HEALER_REMAINING",
            ["DAMAGER"] = "DAMAGER_REMAINING",
        };
        local roles = C_LFGList.GetSearchResultMemberCounts(lfgSearchResultID);
        local playerRole = GetSpecializationRole(GetSpecialization());
        return roles[roleRemainingKeyLookup[playerRole]];
    end
    
    local function FilterSearchResults(searchResultID)
		local searchResultInfo = C_LFGList.GetSearchResultInfo(searchResultID);
		local members = C_LFGList.GetSearchResultMemberCounts(searchResultID);
		local filterTankCount = LFGListFrame.SearchPanel.filterTankCount;
		local filterHealerCount = LFGListFrame.SearchPanel.filterHealerCount;
		local filterDamagerCount = LFGListFrame.SearchPanel.filterDamagerCount;
		local includeTankCount = LFGListFrame.SearchPanel.includeTankCount;
		local includeHealerCount = LFGListFrame.SearchPanel.includeHealerCount;
		local includeDamagerCount = LFGListFrame.SearchPanel.includeDamagerCount;
        local includeDungeons = LFGListFrame.SearchPanel.includeDungeons;
        local includeDungeonCount = LFGListFrame.SearchPanel.includeDungeonCount;
		local removedByFilter = false;
        
        if (searchResultInfo == nil) then
            return;
        end        
        
        local remainingRole = RemainingSlotsForLocalPlayerRole(searchResultID) > 0
        
        if removeRole == true then            
            if (remainingRole == false) then
                removedByFilter = true;
            end
        end 
        
        local leaderName = searchResultInfo.leaderName;
        local rioScore = 0;
        
        if (leaderName ~= nil) then
            rioScore = GetRioScore(leaderName);
        end 
        
        if (not RaiderIO) then filterRIO = false end
        
        if (filterRIO == true) then            
            if (rioScore < minRio or rioScore > maxRio) then
				removedByFilter = true;
            end
		end
		
		if (filterTankCount > 0 and members["TANK"] == filterTankCount) then
			removedByFilter = true;
		end
		if (filterHealerCount > 0 and members["HEALER"] == filterHealerCount) then
			removedByFilter = true;
		end
		if (filterDamagerCount > 0 and members["DAMAGER"] == filterDamagerCount) then
			removedByFilter = true;
		end
		
		if (includeTankCount > 0 and members["TANK"] < includeTankCount) then
			removedByFilter = true;
		end
		if (includeHealerCount > 0 and members["HEALER"] < includeHealerCount) then
			removedByFilter = true;
		end
		if (includeDamagerCount > 0 and members["DAMAGER"] < includeDamagerCount) then
			removedByFilter = true;
		end

        local title = searchResultInfo.name;
        local activityID = searchResultInfo.activityID;
        local categoryID = select(3, C_LFGList.GetActivityInfo(activityID))
        -- 2: Dungeon
        if (categoryID == 2 and includeDungeonCount > 0) then
            local removeDungeon = true;
            -- name & comment are protected by blizzard now
            --[[
            --]]
            for k,v in pairs(includeDungeons) do
                for _,q in pairs(dungeonPatterns[k]) do
                    if string.match(title, q) then
                        removeDungeon = false;
                        break
                    end
                end
            end
            --[[
            --]]
            for k,v in pairs(includeDungeons) do
                for _,id in pairs(dungeonIDs[k]) do
                    if (id == activityID) then
                        removeDungeon = false;
                        break
                    end
                end
            end
            if (removeDungeon == true) then
                removedByFilter = true;
            end
        end

		if (removedByFilter == true) then 
			addFilteredId(LFGListFrame.SearchPanel, searchResultID);
		end
    end
    
    local function SortSearchResultsCB(searchResultID1, searchResultID2)
        local searchResultInfo1 = C_LFGList.GetSearchResultInfo(searchResultID1);
        local searchResultInfo2 = C_LFGList.GetSearchResultInfo(searchResultID2);
        
        if (searchResultInfo1 == nil) then
            return false;
        end        
        
        if (searchResultInfo2 == nil) then
            return true;
        end    
        
        local remainingRole1 = RemainingSlotsForLocalPlayerRole(searchResultID1) > 0;
        local remainingRole2 = RemainingSlotsForLocalPlayerRole(searchResultID2) > 0;
        
        local leaderName1 = searchResultInfo1.leaderName;
        local leaderName2 = searchResultInfo2.leaderName;
        
        local rioScore1 = 0;
        local rioScore2 = 0;       
        
        if (leaderName1 ~= nil) then
            rioScore1 = GetRioScore(leaderName1);
        end   
        if (leaderName2 ~= nil) then
            rioScore2 = GetRioScore(leaderName2);
        end       
        
        if (remainingRole1 ~= remainingRole2) then
            return remainingRole1;
        end
        
        if (sortMethod == 3) then
            return rioScore1 > rioScore2;
        else
            return rioScore1 < rioScore2;
        end
    end
    
    if (#results > 0 and categoryID == 2) then
        for i,id in ipairs(results) do
            FilterSearchResults(id)
        end
        
        if (LFGListFrame.SearchPanel.filteredIDs) then
            filterTable(LFGListFrame.SearchPanel.results, LFGListFrame.SearchPanel.filteredIDs);
            LFGListFrame.SearchPanel.filteredIDs = nil;
        end
    end
    
    if sortMethod ~= 1 then
        table.sort(results, SortSearchResultsCB);
    end
    
    if #results > 0 then
        LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel);
    end
end

function hook_LFGListUtil_SortApplicants(applicants)    
    if( LFGListFrame.SearchPanel.disabled ) then return; end

    local sortMethod = 3;
    local minRio = -1;
    local maxRio = 9999;
    local filterRIO = false;
    local categoryID = LFGListFrame.CategorySelection.selectedCategory;
    
    local function FilterApplicants(applicantID)
        local applicantInfo = C_LFGList.GetApplicantInfo(applicantID);
        
        if (applicantInfo == nil) then
            return;
        end 
        
        local name = C_LFGList.GetApplicantMemberInfo(applicantInfo.applicantID, 1);
        local rioScore = 0;
        
        if (name ~= nil) then
            rioScore = GetRioScore(name);
        end   
        
        if (filterRIO == true) then
            if (rioScore < minRio or rioScore > maxRio) then
                addFilteredId(LFGListFrame.ApplicationViewer, applicantID)
            end
        end
    end
    
    local function SortApplicantsCB(applicantID1, applicantID2)
        local applicantInfo1 = C_LFGList.GetApplicantInfo(applicantID1);
        local applicantInfo2 = C_LFGList.GetApplicantInfo(applicantID2);
        
        if (applicantInfo1 == nil) then
            return false;
        end        
        
        if (applicantInfo2 == nil) then
            return true;
        end    
        
        local name1 = C_LFGList.GetApplicantMemberInfo(applicantInfo1.applicantID, 1);
        local name2 = C_LFGList.GetApplicantMemberInfo(applicantInfo2.applicantID, 1);
        
        local rioScore1 = 0;
        local rioScore2 = 0;       
        
        if (name1 ~= nil) then
            rioScore1 = GetRioScore(name1);
        end   
        if (name2 ~= nil) then
            rioScore2 = GetRioScore(name2);
        end
        
        if (sortMethod == 3) then
            return rioScore1 > rioScore2;
        else
            return rioScore1 < rioScore2;
        end
    end
    
    if (categoryID == 2 and #applicants > 0) then
        for i,id in ipairs(applicants) do
            FilterApplicants(id)
        end
        
        if (LFGListFrame.ApplicationViewer.filteredIDs) then
            filterTable(applicants, LFGListFrame.ApplicationViewer.filteredIDs);
            LFGListFrame.ApplicationViewer.filteredIDs = nil;
        end
    end
    
    if (sortMethod ~= 1 and #applicants > 1) then 
        table.sort(applicants, SortApplicantsCB);        
        LFGListApplicationViewer_UpdateResults(LFGListFrame.ApplicationViewer);
    end
    
    if (#applicants > 0) then        
        LFGListApplicationViewer_UpdateResults(LFGListFrame.ApplicationViewer);
    end
end

local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:RegisterEvent("PLAYER_LOGIN");
events:SetScript("OnEvent", init);

local TocName, Env = ...
local Copybara = LibStub("AceAddon-3.0"):NewAddon(TocName, "AceConsole-3.0", "AceEvent-3.0")
Copybara.displayName = GetAddOnMetadata(TocName, "Title")
Env.Addon = Copybara
setglobal("Copybara", Copybara)

-- WoW API's
local _G = _G
local GetAddOnMetadata, GetChatWindowInfo, GetChatWindowMessages, GetChatWindowChannels, RemoveChatWindowMessages, GetChatWindowSavedDimensions, GetChatWindowSavedPosition, SetChatWindowName, SetChatWindowColor, SetChatWindowAlpha, SetChatWindowSize, SetChatWindowShown, SetChatWindowLocked, SetChatWindowDocked, SetChatWindowUninteractable, SetChatWindowSavedDimensions = GetAddOnMetadata, GetChatWindowInfo, GetChatWindowMessages, GetChatWindowChannels, RemoveChatWindowMessages, GetChatWindowSavedDimensions, GetChatWindowSavedPosition, SetChatWindowName, SetChatWindowColor, SetChatWindowAlpha, SetChatWindowSize, SetChatWindowShown, SetChatWindowLocked, SetChatWindowDocked, SetChatWindowUninteractable, SetChatWindowSavedDimensions

local ChatFrame_RemoveAllMessageGroups, ChatFrame_RemoveAllChannels, ChatFrame_ReceiveAllPrivateMessages, ChatFrame_AddMessageGroup= ChatFrame_RemoveAllMessageGroups, ChatFrame_RemoveAllChannels, ChatFrame_ReceiveAllPrivateMessages, ChatFrame_AddMessageGroup

local private = {}

local Options = {}
Copybara.Options = Options

Options.defaults = {
   profile = {},
}

Options.constructor = {
   name = TocName,
   handler = Options,
   type = "group",
   set = "Setter",
   get = "Getter",
   args = {
      about = {
         name = format("%s:%s by %s\n\n", GAME_VERSION_LABEL, GetAddOnMetadata(TocName, "Version"), GetAddOnMetadata(TocName, "Author")),
         type = "description",
         order = 0,
      },
      selectedCharacter = {
         name = "Select character to copy chat settings from",
         type = "select",
         style = "dropdown",
         values = function(self)
            local profileNames = {}
            
            for name in pairs(Copybara.Options.DB.profiles) do
               profileNames[name] = name
            end
            
            return profileNames
         end,
         sorting = function(self)
            local values = self.option.values()
            local tempTbl = {}
            
            for key in pairs(values) do
               table.insert(tempTbl, key)
            end
            
            table.sort(tempTbl)
            
            return tempTbl
         end,
         order = 1,
      },
      copy = {
         type = "execute",
         desc = "Copying chat settings from the selected character to the character you are currently on",
         name = CALENDAR_COPY_EVENT,
         order = 2,
         func = function(self)
            Copybara:LoadConfig()
            ReloadUI()
         end,
      },
      br1 = { type = "description", name = "", order = 1},
      reset = {
         type = "execute",
         name = CHAT_DEFAULTS,
         func = function(self)
          FCF_ResetAllWindows()
         end,
         order = 100,
         hidden = true,
      },
      test = {
         type = "execute",
         name = SAVE,
         order = 1,
         func = function(self)
            Copybara:SaveConfig()
         end,
         hidden = true,
      },
   },
}

function Copybara:OnInitialize()
   self.DB = LibStub("AceDB-3.0"):New(TocName .. "DB", self.Options.defaults)
   self.Options.DB = self.DB
   LibStub("AceConfig-3.0"):RegisterOptionsTable(self.displayName, self.Options.constructor)
   LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.displayName, self.displayName)

   self:RegisterEvent("PLAYER_LOGOUT", "SaveConfig")
end

function Copybara:GetConfig()
   local chatConfig = {}
   
   for i = 1, NUM_CHAT_WINDOWS do
      local f = _G["ChatFrame" .. i]
      local width, height = GetChatWindowSavedDimensions(i)
      local point, xOfs, yOfs = GetChatWindowSavedPosition(i)
      local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
      local DefaultMessages = { GetChatWindowMessages(f:GetID()) }
      local DefaultChannels = { GetChatWindowChannels(f:GetID()) }

      
      chatConfig[i] = {
         width = width,
         height = height,
         point = point,
         xOfs = xOfs,
         yOfs = yOfs,
         name = name,
         fontSize = fontSize,
         r = r,
         g = g,
         b = b,
         alpha = alpha,
         shown = shown,
         locked = locked,
         docked = docked,
         uninteractable = uninteractable,
         DefaultMessages = DefaultMessages,
         DefaultChannels = DefaultChannels,
         parentName = f:GetParent():GetName(),
      }
   end
   
   return chatConfig
end

function Copybara:SaveConfig()
   local currentProfile = self.DB:GetCurrentProfile()
   
   self.DB.profiles[currentProfile].chatConfig = self:GetConfig()
end

function Copybara:LoadConfig(config)
   
   local currentProfile = self.DB:GetCurrentProfile()
   local selectedCharacter = self.DB.profiles[currentProfile].selectedCharacter
   
   if selectedCharacter then
      local config = config or self.DB.profiles[selectedCharacter].chatConfig

      
      for chatFrameIndex = 1, NUM_CHAT_WINDOWS do
          local chatFrame = _G["ChatFrame" .. chatFrameIndex]
          --local chatTab = _G["ChatFrame" .. chatFrameIndex .. "Tab"]
          local savedFrame = config[chatFrameIndex]

          if ( not savedFrame.name or savedFrame.name == "" ) then
            savedFrame.name = format(CHAT_NAME_TEMPLATE, chatFrameIndex)
          end

          -- initialize the frame
          chatFrame:SetParent(_G[savedFrame.parentName])
          SetChatWindowName(chatFrameIndex, savedFrame.name)
          SetChatWindowColor(chatFrameIndex, savedFrame.r, savedFrame.g, savedFrame.b)
          SetChatWindowAlpha(chatFrameIndex, savedFrame.alpha)
          SetChatWindowSize(chatFrameIndex, savedFrame.fontSize)
          SetChatWindowShown(chatFrameIndex, savedFrame.shown)
          SetChatWindowLocked(chatFrameIndex, savedFrame.locked)
          SetChatWindowDocked(chatFrameIndex, savedFrame.docked)
          SetChatWindowUninteractable(chatFrameIndex, savedFrame.uninteractable)
          SetChatWindowSavedDimensions(chatFrameIndex, savedFrame.width, savedFrame.height)

          if savedFrame.point then
            SetChatWindowSavedPosition(chatFrameIndex, savedFrame.point, savedFrame.xOfs, savedFrame.yOfs)
          end

          -- Remove old msg configuration
          ChatFrame_RemoveAllMessageGroups(chatFrame)
          ChatFrame_RemoveAllChannels(chatFrame)
          ChatFrame_ReceiveAllPrivateMessages(chatFrame)

          -- Restore new message groups
          for _, messageType in pairs(savedFrame.DefaultMessages) do
            ChatFrame_AddMessageGroup(chatFrame, messageType)
          end

          -- Restore new channels
          for _, channel in pairs(savedFrame.DefaultChannels) do
            ChatFrame_AddChannel(chatFrame, channel)
          end
      end
   end
end

function Options:Setter(...)
   local info, arg2, arg3 = ...
   local scope = private.GetDBScopeForInfo(self.DB.profile, info)
   
   local key = info[#info]
   local val = arg2
   
   if arg3 ~= nil then
      local subKey = arg2
      val = arg3
      scope[key][subKey] = val
   else
      scope[key] = val
   end
end

function Options:Getter(...)
   local info, subKey = ...
   local infoScope = private.GetDBScopeForInfo(self.DB.profile, info)
   local key = info[#info]
   
   if subKey then
      return infoScope[key][subKey]
   end
   
   return infoScope[key]
end

function private.GetDBScopeForInfo(DB, info)
   assert(DB and info and type(info) == "table" and type(DB) == "table")
   
   local scope = DB
   
   for i = 1, #info - 1 do
      scope = scope[info[i]]
   end
   
   return scope
end
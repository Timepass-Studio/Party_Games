local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Configuration and Wally packages
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ProfileService = require(ServerScriptService.ProfileService.ProfileService)

local PlayerData = {}

-- Event Signals for statistics changes
PlayerData.CoinsChanged = Signal.new() -- Fired with (player, newCoins, oldCoins)
PlayerData.ChestsChanged = Signal.new() -- Fired with (player, newChests, oldChests)
PlayerData.BoardSpaceChanged = Signal.new() -- Fired with (player, newSpace, oldSpace)
PlayerData.Loaded = Signal.new() -- Fired with (player)

-- ProfileService setup
local PROFILE_STORE_KEY = "RobloxBoardGame_DataStore_V1"
local ProfileTemplate = {
    Coins = GameConfig.StartingCoins,
    Chests = GameConfig.StartingChests,
    BoardSpace = GameConfig.StartingBoardSpace
}

local ProfileStore = ProfileService.GetProfileStore(PROFILE_STORE_KEY, ProfileTemplate)

-- In-memory session stores
local Profiles = {} -- Store persistent player profiles
local SessionData = {} -- Store temporary non-persistent session data (e.g. saved CFrame positions)

-- Helper to get a player's profile data
function PlayerData.Get(player: Player): any?
    local profile = Profiles[player]
    return profile and profile.Data or nil
end

-- Coins Getter/Setter
function PlayerData.GetCoins(player: Player): number
    local data = PlayerData.Get(player)
    return data and data.Coins or GameConfig.StartingCoins
end

function PlayerData.AddCoins(player: Player, amount: number)
    local data = PlayerData.Get(player)
    if data then
        local oldCoins = data.Coins
        data.Coins = math.max(0, data.Coins + amount)
        PlayerData.CoinsChanged:Fire(player, data.Coins, oldCoins)
    end
end

-- Chests Getter/Setter
function PlayerData.GetChests(player: Player): number
    local data = PlayerData.Get(player)
    return data and data.Chests or GameConfig.StartingChests
end

function PlayerData.AddChests(player: Player, amount: number)
    local data = PlayerData.Get(player)
    if data then
        local oldChests = data.Chests
        data.Chests = math.max(0, data.Chests + amount)
        PlayerData.ChestsChanged:Fire(player, data.Chests, oldChests)
    end
end

-- Board Space Getter/Setter
function PlayerData.GetBoardSpace(player: Player): number
    local data = PlayerData.Get(player)
    return data and data.BoardSpace or GameConfig.StartingBoardSpace
end

function PlayerData.SetBoardSpace(player: Player, space: number)
    local data = PlayerData.Get(player)
    if data then
        local oldSpace = data.BoardSpace
        data.BoardSpace = math.clamp(space, 1, GameConfig.TotalBoardSpaces)
        PlayerData.BoardSpaceChanged:Fire(player, data.BoardSpace, oldSpace)
    end
end

-- Non-persistent Session State (Teleport positions)
function PlayerData.GetSavedBoardCFrame(player: Player): CFrame?
    local sData = SessionData[player]
    return sData and sData.SavedBoardCFrame or nil
end

function PlayerData.SetSavedBoardCFrame(player: Player, cframe: CFrame?)
    if not SessionData[player] then
        SessionData[player] = {}
    end
    SessionData[player].SavedBoardCFrame = cframe
end

-- Handlers for Player Join / Leave
local function onPlayerAdded(player: Player)
    local profileKey = "Player_" .. player.UserId
    local profile = ProfileStore:LoadProfileAsync(profileKey)

    if profile ~= nil then
        profile:Reconcile() -- fill in missing default values if we update the template in the future
        profile:ListenToRelease(function()
            Profiles[player] = nil
            SessionData[player] = nil
            player:Kick("Profile loaded elsewhere or released. Please rejoin.")
        end)

        if player:IsDescendantOf(Players) then
            Profiles[player] = profile
            SessionData[player] = {}
            print("[PlayerData] Successfully loaded profile for " .. player.Name)
            PlayerData.Loaded:Fire(player)
        else
            profile:Release() -- player left before load completed
        end
    else
        player:Kick("Failed to load your save data. Please rejoin.")
    end
end

local function onPlayerRemoving(player: Player)
    local profile = Profiles[player]
    if profile then
        profile:Release()
    end
    SessionData[player] = nil
end

-- Initialize listeners
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle any players that joined before the script executed (important in Studio)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

return PlayerData

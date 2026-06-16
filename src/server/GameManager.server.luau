local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Load Wally packages
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

-- Load game modules
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerData = require(script.Parent.PlayerData)

-- States definition
local States = {
    WaitingForPlayers = "WaitingForPlayers",
    BoardPhase = "BoardPhase",
    MinigameSelection = "MinigameSelection",
    MinigamePhase = "MinigamePhase",
    GameEnd = "GameEnd"
}

local GameManager = {
    CurrentState = States.WaitingForPlayers,
    ActivePlayers = {},
    CurrentRound = 0,
    MaxRounds = 3,
    StateChanged = Signal.new() -- Fired with (newState, oldState)
}

-- Setup RemoteEvent for manual dice roll
local RollDiceEvent = ReplicatedStorage:FindFirstChild("RollDiceEvent")
if not RollDiceEvent then
    RollDiceEvent = Instance.new("RemoteEvent")
    RollDiceEvent.Name = "RollDiceEvent"
    RollDiceEvent.Parent = ReplicatedStorage
end

-- Setup RemoteEvent for UI synchronization and indications
local UIEvent = ReplicatedStorage:FindFirstChild("UIEvent")
if not UIEvent then
    UIEvent = Instance.new("RemoteEvent")
    UIEvent.Name = "UIEvent"
    UIEvent.Parent = ReplicatedStorage
end

-- Cleanup manager for the active state
local stateJanitor = Janitor.new()

-- Helper to replicate all player stats to clients
local function ReplicateStats(player: Player)
    UIEvent:FireAllClients("StatsUpdated", {
        UserId = player.UserId,
        Name = player.Name,
        Coins = PlayerData.GetCoins(player),
        Chests = PlayerData.GetChests(player),
        BoardSpace = PlayerData.GetBoardSpace(player)
    })
end

-- Sync stats when values change
PlayerData.CoinsChanged:Connect(function(player) ReplicateStats(player) end)
PlayerData.ChestsChanged:Connect(function(player) ReplicateStats(player) end)
PlayerData.BoardSpaceChanged:Connect(function(player) ReplicateStats(player) end)
PlayerData.Loaded:Connect(function(player)
    task.wait(0.5) -- short delay to ensure loaded on client
    for _, p in ipairs(Players:GetPlayers()) do
        ReplicateStats(p)
    end
end)

-- Replicate stats when a player joins to ensure they have the full leaderboard
Players.PlayerAdded:Connect(function(newPlayer)
    task.wait(1.5)
    for _, p in ipairs(Players:GetPlayers()) do
        ReplicateStats(p)
    end
    -- Also sync current state to new player
    UIEvent:FireClient(newPlayer, "StateChanged", {
        State = GameManager.CurrentState,
        Round = GameManager.CurrentRound,
        MaxRounds = GameManager.MaxRounds,
        SelectedMinigame = GameManager.SelectedMinigame and GameManager.SelectedMinigame.Name or nil
    })
end)

-- Robust teleportation helper
local function TeleportPlayer(player: Player, cframe: CFrame)
    local character = player.Character
    if not character or not character.Parent then
        character = player.CharacterAdded:Wait()
    end
    local rootPart = character:WaitForChild("HumanoidRootPart", 5)
    if rootPart then
        character:PivotTo(cframe)
        print(string.format("[GameManager] Teleported %s to %s", player.Name, tostring(cframe.Position)))
    else
        warn("[GameManager] Failed to find HumanoidRootPart for player: " .. player.Name)
    end
end

-- Changes the current state and cleans up old state resources
local function TransitionTo(newState: string)
    local oldState = GameManager.CurrentState
    GameManager.CurrentState = newState
    stateJanitor:Cleanup()
    print(string.format("[GameManager] State transition: %s ===> %s", oldState, newState))
    
    -- Reset minigame ref if leaving minigame phases
    if newState == States.WaitingForPlayers or newState == States.BoardPhase then
        GameManager.SelectedMinigame = nil
    end

    -- Broadcast state transition to clients
    UIEvent:FireAllClients("StateChanged", {
        State = newState,
        Round = GameManager.CurrentRound,
        MaxRounds = GameManager.MaxRounds,
        SelectedMinigame = GameManager.SelectedMinigame and GameManager.SelectedMinigame.Name or nil,
        Instructions = GameManager.SelectedMinigame and GameManager.SelectedMinigame.Instructions or nil
    })

    GameManager.StateChanged:Fire(newState, oldState)
end

-- WAITING FOR PLAYERS STATE
local function RunWaitingForPlayers()
    print("[GameManager] Waiting for players...")
    
    while #Players:GetPlayers() < GameConfig.MinPlayersToStart do
        task.wait(2)
        print(string.format("[GameManager] Current players: %d/%d", #Players:GetPlayers(), GameConfig.MinPlayersToStart))
    end
    
    print("[GameManager] Minimum player count reached! Starting game in " .. GameConfig.IntermissionDuration .. " seconds...")
    
    -- Countdown warning before start
    for i = GameConfig.IntermissionDuration, 1, -1 do
        UIEvent:FireAllClients("StateChanged", {
            State = States.WaitingForPlayers,
            Countdown = i
        })
        task.wait(1)
    end
    
    -- Cache active players for this game
    GameManager.ActivePlayers = Players:GetPlayers()
    GameManager.CurrentRound = 1
    TransitionTo(States.BoardPhase)
end

-- BOARD PHASE STATE
local function RunBoardPhase()
    print(string.format("[GameManager] Starting Board Phase (Round %d/%d)", GameManager.CurrentRound, GameManager.MaxRounds))
    
    -- Filter out players who left
    local activeInSession = {}
    for _, player in ipairs(GameManager.ActivePlayers) do
        if player.Parent == Players then
            table.insert(activeInSession, player)
        end
    end
    GameManager.ActivePlayers = activeInSession
    
    if #GameManager.ActivePlayers == 0 then
        warn("[GameManager] No active players left. Resetting loop.")
        TransitionTo(States.WaitingForPlayers)
        return
    end

    -- Process turn for each player sequentially
    for index, player in ipairs(GameManager.ActivePlayers) do
        print(string.format("[GameManager] It's %s's turn!", player.Name))
        
        -- Broadcast turn start
        UIEvent:FireAllClients("StateChanged", {
            State = States.BoardPhase,
            Round = GameManager.CurrentRound,
            MaxRounds = GameManager.MaxRounds,
            ActivePlayerName = player.Name
        })

        -- Teleport player to their current board space at start of turn if they are not there
        local currentSpace = PlayerData.GetBoardSpace(player)
        local currentCFrame = GameConfig.GetSpaceCFrame(currentSpace)
        TeleportPlayer(player, currentCFrame)
        
        local rollValue = 0

        -- Roll Dice Option 1: Wait for RemoteEvent from client (e.g. GUI click)
        -- Roll Dice Option 2: Auto-roll after 5 seconds if player is idle
        local rollPromise = Promise.new(function(resolve, reject, onCancel)
            local connection
            connection = RollDiceEvent.OnServerEvent:Connect(function(firingPlayer)
                if firingPlayer == player then
                    connection:Disconnect()
                    resolve(math.random(GameConfig.DiceRollRange.Min, GameConfig.DiceRollRange.Max))
                end
            end)
            
            onCancel(function()
                if connection then connection:Disconnect() end
            end)
        end)

        -- Timeout promise for auto-rolling
        local timeoutPromise = Promise.delay(5):andThen(function()
            print(string.format("[GameManager] %s did not roll in time. Auto-rolling dice...", player.Name))
            return math.random(GameConfig.DiceRollRange.Min, GameConfig.DiceRollRange.Max)
        end)

        -- Race the roll input and timeout
        local success, result = Promise.race({rollPromise, timeoutPromise}):await()
        rollValue = success and result or math.random(GameConfig.DiceRollRange.Min, GameConfig.DiceRollRange.Max)
        
        print(string.format("[GameManager] %s rolled a %d!", player.Name, rollValue))
        
        -- Broadcast dice roll result to trigger UI indications
        UIEvent:FireAllClients("DiceRolled", {
            PlayerName = player.Name,
            RollValue = rollValue
        })
        
        -- Move the player space-by-space
        for step = 1, rollValue do
            task.wait(0.4)
            currentSpace = (currentSpace % GameConfig.TotalBoardSpaces) + 1
            PlayerData.SetBoardSpace(player, currentSpace)
            local spaceCFrame = GameConfig.GetSpaceCFrame(currentSpace)
            TeleportPlayer(player, spaceCFrame)
        end
        
        task.wait(0.5)
        
        -- Check if player landed on a chest opportunity space (e.g., multiple of 5)
        if currentSpace % 5 == 0 then
            local coins = PlayerData.GetCoins(player)
            print(string.format("[GameManager] %s landed on a Chest Space! (Has %d/%d coins)", player.Name, coins, GameConfig.CoinsPerChest))
            if coins >= GameConfig.CoinsPerChest then
                PlayerData.AddCoins(player, -GameConfig.CoinsPerChest)
                PlayerData.AddChests(player, 1)
                print(string.format("[GameManager] %s bought a CHEST! Total chests: %d", player.Name, PlayerData.GetChests(player)))
            else
                print("[GameManager] Not enough coins to buy a chest.")
            end
            task.wait(1.5)
        end
        
        print(string.format("[GameManager] Finished turn for %s", player.Name))
        task.wait(1)
    end
    
    TransitionTo(States.MinigameSelection)
end

-- MINIGAME SELECTION STATE
local function RunMinigameSelection()
    print("[GameManager] Selecting Minigame...")
    task.wait(1)
    
    local minigames = GameConfig.Minigames
    local randomIndex = math.random(1, #minigames)
    local selectedMinigame = minigames[randomIndex]
    
    print(string.format("[GameManager] Minigame Selected: %s!", selectedMinigame.Name))
    print(string.format("[GameManager] Rules: %s", selectedMinigame.Instructions))
    
    GameManager.SelectedMinigame = selectedMinigame
    
    -- Transition to Minigame Phase passing the selected minigame index
    TransitionTo(States.MinigamePhase)
end

-- MINIGAME PHASE STATE
local function RunMinigamePhase()
    local selectedMinigame = GameManager.SelectedMinigame
    if not selectedMinigame then
        warn("[GameManager] No minigame selected. Returning to Board Phase.")
        TransitionTo(States.BoardPhase)
        return
    end

    print(string.format("[GameManager] Starting Minigame: %s", selectedMinigame.Name))
    
    -- 1. Save all board positions and teleport to minigame spawns
    for index, player in ipairs(GameManager.ActivePlayers) do
        if player.Parent == Players then
            local character = player.Character
            if character then
                local pivot = character:GetPivot()
                PlayerData.SetSavedBoardCFrame(player, pivot)
                
                local spawnCFrame = GameConfig.GetMinigameSpawnCFrame(selectedMinigame.Id, index)
                TeleportPlayer(player, spawnCFrame)
            end
        end
    end
    
    -- 2. Run Minigame Timer and Broadcast Countdown
    local timeLeft = GameConfig.MinigameDuration
    while timeLeft > 0 do
        print(string.format("[GameManager] Minigame '%s' - %d seconds remaining", selectedMinigame.Name, timeLeft))
        UIEvent:FireAllClients("MinigameTimer", {
            TimeLeft = timeLeft,
            MinigameName = selectedMinigame.Name
        })
        task.wait(1)
        timeLeft = timeLeft - 1
    end
    
    -- Broadcast that minigame timer has hit 0
    UIEvent:FireAllClients("MinigameTimer", {
        TimeLeft = 0,
        MinigameName = selectedMinigame.Name
    })

    print(string.format("[GameManager] Minigame '%s' has ENDED!", selectedMinigame.Name))
    
    -- 3. Award coins randomly to simulate minigame outcomes
    for _, player in ipairs(GameManager.ActivePlayers) do
        if player.Parent == Players then
            local coinsAwarded = math.random(selectedMinigame.CoinsAwardedRange.Min, selectedMinigame.CoinsAwardedRange.Max)
            PlayerData.AddCoins(player, coinsAwarded)
            print(string.format("[GameManager] %s earned %d coins from the minigame. Total: %d", player.Name, coinsAwarded, PlayerData.GetCoins(player)))
        end
    end
    
    task.wait(1.5)
    
    -- 4. Teleport players back to their saved board positions
    for _, player in ipairs(GameManager.ActivePlayers) do
        if player.Parent == Players then
            local savedCFrame = PlayerData.GetSavedBoardCFrame(player)
            if savedCFrame then
                TeleportPlayer(player, savedCFrame)
                PlayerData.SetSavedBoardCFrame(player, nil)
            end
        end
    end
    
    task.wait(GameConfig.IntermissionDuration)
    
    -- 5. Determine if we transition to GameEnd or next round
    if GameManager.CurrentRound >= GameManager.MaxRounds then
        TransitionTo(States.GameEnd)
    else
        GameManager.CurrentRound = GameManager.CurrentRound + 1
        TransitionTo(States.BoardPhase)
    end
end

-- GAME END STATE
local function RunGameEnd()
    print("[GameManager] Game Finished! Calculating Winner...")
    
    local winner = nil
    local maxChests = -1
    local maxCoins = -1
    
    for _, player in ipairs(GameManager.ActivePlayers) do
        if player.Parent == Players then
            local chests = PlayerData.GetChests(player)
            local coins = PlayerData.GetCoins(player)
            
            if chests > maxChests then
                winner = player
                maxChests = chests
                maxCoins = coins
            elseif chests == maxChests then
                -- Tie breaker: coins count
                if coins > maxCoins then
                    winner = player
                    maxCoins = coins
                end
            end
        end
    end
    
    local winnerName = "No One"
    if winner then
        winnerName = winner.Name
        print("==================================================")
        print(string.format("[GameManager] WINNER IS: %s!!!", winnerName))
        print(string.format("[GameManager] Chests: %d, Coins: %d", maxChests, maxCoins))
        print("==================================================")
    else
        print("[GameManager] No winner could be determined.")
    end
    
    -- Broadcast Game End details to clients for custom winner overlay display
    UIEvent:FireAllClients("StateChanged", {
        State = States.GameEnd,
        WinnerName = winnerName,
        WinnerChests = maxChests,
        WinnerCoins = maxCoins
    })

    task.wait(7)
    
    -- Reset all player stats for the next session
    for _, player in ipairs(Players:GetPlayers()) do
        local profile = PlayerData.Get(player)
        if profile then
            profile.Coins = GameConfig.StartingCoins
            profile.Chests = GameConfig.StartingChests
            profile.BoardSpace = GameConfig.StartingBoardSpace
            -- Trigger signals for UI sync
            PlayerData.CoinsChanged:Fire(player, profile.Coins, profile.Coins)
            PlayerData.ChestsChanged:Fire(player, profile.Chests, profile.Chests)
            PlayerData.BoardSpaceChanged:Fire(player, profile.BoardSpace, profile.BoardSpace)
        end
    end
    
    TransitionTo(States.WaitingForPlayers)
end

-- Main engine routine that runs continuously
local function MainLoop()
    while true do
        local currentState = GameManager.CurrentState
        
        if currentState == States.WaitingForPlayers then
            RunWaitingForPlayers()
        elseif currentState == States.BoardPhase then
            RunBoardPhase()
        elseif currentState == States.MinigameSelection then
            RunMinigameSelection()
        elseif currentState == States.MinigamePhase then
            RunMinigamePhase()
        elseif currentState == States.GameEnd then
            RunGameEnd()
        end
        
        task.wait(1)
    end
end

-- Start game engine execution
task.spawn(MainLoop)

return GameManager

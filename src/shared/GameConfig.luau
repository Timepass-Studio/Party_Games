local GameConfig = {}

-- General Game Settings
GameConfig.MinPlayersToStart = 1 -- Set to 1 for solo testing/development, normally 2+
GameConfig.CoinsPerChest = 20
GameConfig.StartingCoins = 10
GameConfig.StartingChests = 0
GameConfig.StartingBoardSpace = 1
GameConfig.TotalBoardSpaces = 20
GameConfig.MinigameDuration = 10 -- Duration of minigame phase in seconds (for testing, normally 30-60)
GameConfig.IntermissionDuration = 5 -- Duration between phases in seconds
GameConfig.DiceRollRange = { Min = 1, Max = 6 }

-- List of Minigames
GameConfig.Minigames = {
    {
        Id = "CoinRush",
        Name = "Coin Rush",
        Instructions = "Collect as many gold coins as you can!",
        SpawnCFrame = CFrame.new(100, 10, 100),
        CoinsAwardedRange = { Min = 5, Max = 15 }
    },
    {
        Id = "LavaJump",
        Name = "Lava Jump",
        Instructions = "Avoid the rising lava and survive!",
        SpawnCFrame = CFrame.new(-100, 10, -100),
        CoinsAwardedRange = { Min = 8, Max = 20 }
    },
    {
        Id = "SpeedRun",
        Name = "Speed Run",
        Instructions = "Sprint to the finish line!",
        SpawnCFrame = CFrame.new(0, 10, 200),
        CoinsAwardedRange = { Min = 5, Max = 12 }
    }
}

-- Returns the CFrame for a specific space on the board.
-- Dynamically looks for parts inside workspace.Board.Spaces or falls back to a procedural layout.
function GameConfig.GetSpaceCFrame(spaceIndex: number): CFrame
    -- Standard check for physical workspace board model:
    -- Expects workspace/Board/Spaces/1, workspace/Board/Spaces/2, etc.
    local board = workspace:FindFirstChild("Board")
    local spaces = board and board:FindFirstChild("Spaces")
    local spacePart = spaces and spaces:FindFirstChild(tostring(spaceIndex))

    if spacePart and spacePart:IsA("BasePart") then
        -- Position player slightly above the part so they don't clip
        return spacePart.CFrame + Vector3.new(0, 3, 0)
    else
        -- Procedural Fallback: Generate a circular board around the origin
        local radius = 35
        local angle = ((spaceIndex - 1) / GameConfig.TotalBoardSpaces) * math.pi * 2
        local x = math.cos(angle) * radius
        local z = math.sin(angle) * radius
        local y = 5 -- Elevate so they can stand safely
        return CFrame.new(x, y, z)
    end
end

-- Returns a CFrame for a minigame spawn point.
-- Dynamically looks for a spawn part in workspace.Minigames[MinigameId].Spawn or falls back to a default coordinate.
function GameConfig.GetMinigameSpawnCFrame(minigameId: string, playerIndex: number): CFrame
    local minigamesFolder = workspace:FindFirstChild("Minigames")
    local gameFolder = minigamesFolder and minigamesFolder:FindFirstChild(minigameId)
    local spawnFolder = gameFolder and gameFolder:FindFirstChild("Spawns")
    local spawnPart = spawnFolder and spawnFolder:FindFirstChild(tostring(playerIndex))

    if spawnPart and spawnPart:IsA("BasePart") then
        return spawnPart.CFrame + Vector3.new(0, 3, 0)
    else
        -- Fallback: Use configuration-defined CFrame with a slight offset per player index to avoid stacking
        local baseConfig = nil
        for _, mg in ipairs(GameConfig.Minigames) do
            if mg.Id == minigameId then
                baseConfig = mg
                break
            end
        end

        local baseCFrame = baseConfig and baseConfig.SpawnCFrame or CFrame.new(0, 50, 0)
        -- Offset players in a row
        local offset = Vector3.new((playerIndex - 1) * 4, 0, 0)
        return baseCFrame + offset
    end
end

return GameConfig

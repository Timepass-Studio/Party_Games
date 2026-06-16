<<<<<<< HEAD
print("Hello world, from client!")
=======
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Get RemoteEvents
local UIEvent = ReplicatedStorage:WaitForChild("UIEvent")
local RollDiceEvent = ReplicatedStorage:WaitForChild("RollDiceEvent")

-- Define Color Palette (Glassmorphism & Rich HSL UI)
local COLORS = {
    Background = Color3.fromRGB(15, 16, 22),
    Border = Color3.fromRGB(255, 255, 255),
    PrimaryBlue = Color3.fromRGB(24, 119, 242),
    TextWhite = Color3.fromRGB(245, 246, 250),
    TextMuted = Color3.fromRGB(164, 176, 190),
    CoinGold = Color3.fromRGB(255, 195, 18),
    ChestRuby = Color3.fromRGB(235, 77, 75),
    GreenSuccess = Color3.fromRGB(46, 204, 113),
    LavaRed = Color3.fromRGB(230, 126, 34)
}

-- Create Main ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BoardGameHUD"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- Create UI Helper function for glassmorphic style
local function CreateGlassFrame(name: string, size: UDim2, position: UDim2, anchorPoint: Vector2)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = size
    frame.Position = position
    frame.AnchorPoint = anchorPoint
    frame.BackgroundColor3 = COLORS.Background
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.Border
    stroke.Thickness = 1.5
    stroke.Transparency = 0.8
    stroke.Parent = frame

    return frame
end

-- ============================================================================
-- 1. TOP STATUS BAR
-- ============================================================================
local TopBar = CreateGlassFrame("TopBar", UDim2.new(0, 420, 0, 60), UDim2.new(0.5, 0, 0, 20), Vector2.new(0.5, 0))
TopBar.Parent = ScreenGui

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(1, -20, 0, 25)
StatusLabel.Position = UDim2.new(0, 10, 0, 8)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Waiting for Players..."
StatusLabel.TextColor3 = COLORS.TextWhite
StatusLabel.Font = Enum.Font.BuilderSansBold
StatusLabel.TextSize = 20
StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
StatusLabel.Parent = TopBar

local SubStatusLabel = Instance.new("TextLabel")
SubStatusLabel.Name = "SubStatusLabel"
SubStatusLabel.Size = UDim2.new(1, -20, 0, 18)
SubStatusLabel.Position = UDim2.new(0, 10, 0, 32)
SubStatusLabel.BackgroundTransparency = 1
SubStatusLabel.Text = "Waiting for game to initialize"
SubStatusLabel.TextColor3 = COLORS.TextMuted
SubStatusLabel.Font = Enum.Font.SourceSansItalic
SubStatusLabel.TextSize = 14
SubStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
SubStatusLabel.Parent = TopBar

-- ============================================================================
-- 2. LEADERBOARD / STATS SIDEBAR (Left)
-- ============================================================================
local Sidebar = CreateGlassFrame("Sidebar", UDim2.new(0, 240, 0, 320), UDim2.new(0, 20, 0.2, 0), Vector2.new(0, 0))
Sidebar.Parent = ScreenGui

local SidebarTitle = Instance.new("TextLabel")
SidebarTitle.Name = "Title"
SidebarTitle.Size = UDim2.new(1, -20, 0, 35)
SidebarTitle.Position = UDim2.new(0, 10, 0, 5)
SidebarTitle.BackgroundTransparency = 1
SidebarTitle.Text = "🏆 LEADERBOARD"
SidebarTitle.TextColor3 = COLORS.TextWhite
SidebarTitle.Font = Enum.Font.BuilderSansBold
SidebarTitle.TextSize = 18
SidebarTitle.TextXAlignment = Enum.TextXAlignment.Left
SidebarTitle.Parent = Sidebar

local ListContainer = Instance.new("Frame")
ListContainer.Name = "List"
ListContainer.Size = UDim2.new(1, -20, 1, -50)
ListContainer.Position = UDim2.new(0, 10, 0, 40)
ListContainer.BackgroundTransparency = 1
ListContainer.Parent = Sidebar

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 8)
ListLayout.Parent = ListContainer

local leaderboardCards = {}

local function UpdateLeaderboardCard(userId: number, name: string, coins: number, chests: number, boardSpace: number)
    local card = leaderboardCards[userId]
    if not card then
        -- Construct a new player card
        card = Instance.new("Frame")
        card.Name = name .. "_Card"
        card.Size = UDim2.new(1, 0, 0, 55)
        card.BackgroundColor3 = Color3.fromRGB(30, 31, 40)
        card.BackgroundTransparency = 0.4
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = card

        local pStroke = Instance.new("UIStroke")
        pStroke.Color = COLORS.Border
        pStroke.Thickness = 1
        pStroke.Transparency = 0.9
        pStroke.Parent = card

        -- Player Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(0.6, 0, 0, 20)
        nameLabel.Position = UDim2.new(0, 10, 0, 6)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = name
        nameLabel.TextColor3 = (name == LocalPlayer.Name) and COLORS.PrimaryBlue or COLORS.TextWhite
        nameLabel.Font = Enum.Font.BuilderSansBold
        nameLabel.TextSize = 15
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = card

        -- Player space tag
        local spaceLabel = Instance.new("TextLabel")
        spaceLabel.Name = "SpaceLabel"
        spaceLabel.Size = UDim2.new(0.35, 0, 0, 20)
        spaceLabel.Position = UDim2.new(0.6, 0, 0, 6)
        spaceLabel.BackgroundTransparency = 1
        spaceLabel.Text = "Space: " .. boardSpace
        spaceLabel.TextColor3 = COLORS.TextMuted
        spaceLabel.Font = Enum.Font.SourceSans
        spaceLabel.TextSize = 13
        spaceLabel.TextXAlignment = Enum.TextXAlignment.Right
        spaceLabel.Parent = card

        -- Stats readout
        local statsLabel = Instance.new("TextLabel")
        statsLabel.Name = "StatsLabel"
        statsLabel.Size = UDim2.new(1, -20, 0, 20)
        statsLabel.Position = UDim2.new(0, 10, 0, 28)
        statsLabel.BackgroundTransparency = 1
        statsLabel.RichText = true
        statsLabel.Text = string.format("<font color='#%s'>🪙 %d</font>    <font color='#%s'>🏆 %d</font>", 
            COLORS.CoinGold:ToHex(), coins, 
            COLORS.ChestRuby:ToHex(), chests
        )
        statsLabel.Font = Enum.Font.BuilderSansBold
        statsLabel.TextSize = 14
        statsLabel.TextXAlignment = Enum.TextXAlignment.Left
        statsLabel.Parent = card

        card.Parent = ListContainer
        leaderboardCards[userId] = card
    else
        -- Update existing card
        card.SpaceLabel.Text = "Space: " .. boardSpace
        card.StatsLabel.Text = string.format("<font color='#%s'>🪙 %d</font>    <font color='#%s'>🏆 %d</font>", 
            COLORS.CoinGold:ToHex(), coins, 
            COLORS.ChestRuby:ToHex(), chests
        )
    end
end

-- Cleanup card when player leaves
Players.PlayerRemoving:Connect(function(player)
    if leaderboardCards[player.UserId] then
        leaderboardCards[player.UserId]:Destroy()
        leaderboardCards[player.UserId] = nil
    end
end)

-- ============================================================================
-- 3. INTERACTIVE ROLL DICE BUTTON (Bottom-Right)
-- ============================================================================
local RollButton = Instance.new("TextButton")
RollButton.Name = "RollDiceButton"
RollButton.Size = UDim2.new(0, 160, 0, 65)
RollButton.Position = UDim2.new(1, -180, 1, -85)
RollButton.BackgroundColor3 = COLORS.PrimaryBlue
RollButton.AutoButtonColor = false
RollButton.Text = "🎲 ROLL DICE"
RollButton.TextColor3 = COLORS.TextWhite
RollButton.Font = Enum.Font.BuilderSansBold
RollButton.TextSize = 18
RollButton.Visible = false -- Off by default
RollButton.Parent = ScreenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 14)
btnCorner.Parent = RollButton

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = COLORS.Border
btnStroke.Thickness = 2
btnStroke.Transparency = 0.5
btnStroke.Parent = RollButton

-- Micro-animations for the button (Hover/Press)
RollButton.MouseEnter:Connect(function()
    TweenService:Create(RollButton, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 170, 0, 70),
        Position = UDim2.new(1, -185, 1, -88),
        BackgroundColor3 = Color3.fromRGB(40, 140, 255)
    }):Play()
end)

RollButton.MouseLeave:Connect(function()
    TweenService:Create(RollButton, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 160, 0, 65),
        Position = UDim2.new(1, -180, 1, -85),
        BackgroundColor3 = COLORS.PrimaryBlue
    }):Play()
end)

RollButton.MouseButton1Down:Connect(function()
    TweenService:Create(RollButton, TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 150, 0, 60),
        Position = UDim2.new(1, -175, 1, -82)
    }):Play()
    
    -- Fire to server
    RollDiceEvent:FireServer()
    RollButton.Visible = false -- Hide button immediately after roll
end)

-- ============================================================================
-- 4. CENTER OVERLAY SPLASH (Announcements & Turn banners)
-- ============================================================================
local CenterOverlay = CreateGlassFrame("CenterOverlay", UDim2.new(0, 480, 0, 130), UDim2.new(0.5, 0, 0.4, 0), Vector2.new(0.5, 0.5))
CenterOverlay.Visible = false
CenterOverlay.Parent = ScreenGui

local SplashTitle = Instance.new("TextLabel")
SplashTitle.Name = "SplashTitle"
SplashTitle.Size = UDim2.new(1, -20, 0, 40)
SplashTitle.Position = UDim2.new(0, 10, 0, 15)
SplashTitle.BackgroundTransparency = 1
SplashTitle.Text = "DICE ROLL"
SplashTitle.TextColor3 = COLORS.CoinGold
SplashTitle.Font = Enum.Font.BuilderSansBold
SplashTitle.TextSize = 24
SplashTitle.TextXAlignment = Enum.TextXAlignment.Center
SplashTitle.Parent = CenterOverlay

local SplashBody = Instance.new("TextLabel")
SplashBody.Name = "SplashBody"
SplashBody.Size = UDim2.new(1, -20, 0, 60)
SplashBody.Position = UDim2.new(0, 10, 0, 55)
SplashBody.BackgroundTransparency = 1
SplashBody.Text = "Ginger rolled a 5!"
SplashBody.TextColor3 = COLORS.TextWhite
SplashBody.Font = Enum.Font.BuilderSansBold
SplashBody.TextSize = 20
SplashBody.TextWrapped = true
SplashBody.TextXAlignment = Enum.TextXAlignment.Center
SplashBody.Parent = CenterOverlay

local function ShowAnnouncement(title: string, body: string, duration: number, titleColor: Color3)
    SplashTitle.Text = title
    SplashTitle.TextColor3 = titleColor or COLORS.TextWhite
    SplashBody.Text = body
    
    CenterOverlay.Size = UDim2.new(0, 480, 0, 10)
    CenterOverlay.BackgroundTransparency = 1
    CenterOverlay.Visible = true
    
    -- Animation: Expand frame and fade in
    TweenService:Create(CenterOverlay, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 480, 0, 130),
        BackgroundTransparency = 0.25
    }):Play()
    
    task.wait(duration)
    
    -- Animation: Shrink and fade out
    local closeTween = TweenService:Create(CenterOverlay, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 480, 0, 10),
        BackgroundTransparency = 1
    })
    closeTween:Play()
    closeTween.Completed:Wait()
    CenterOverlay.Visible = false
end

-- ============================================================================
-- 5. MINIGAME COUNTDOWN OVERLAY (Bottom Center)
-- ============================================================================
local MinigameHUD = CreateGlassFrame("MinigameHUD", UDim2.new(0, 360, 0, 65), UDim2.new(0.5, 0, 1, -85), Vector2.new(0.5, 1))
MinigameHUD.BackgroundColor3 = COLORS.LavaRed
MinigameHUD.Visible = false
MinigameHUD.Parent = ScreenGui

local MinigameTitle = Instance.new("TextLabel")
MinigameTitle.Name = "Title"
MinigameTitle.Size = UDim2.new(1, -20, 0, 22)
MinigameTitle.Position = UDim2.new(0, 10, 0, 8)
MinigameTitle.BackgroundTransparency = 1
MinigameTitle.Text = "COIN RUSH"
MinigameTitle.TextColor3 = COLORS.TextWhite
MinigameTitle.Font = Enum.Font.BuilderSansBold
MinigameTitle.TextSize = 16
MinigameTitle.TextXAlignment = Enum.TextXAlignment.Center
MinigameTitle.Parent = MinigameHUD

local MinigameTimerLabel = Instance.new("TextLabel")
MinigameTimerLabel.Name = "TimerLabel"
MinigameTimerLabel.Size = UDim2.new(1, -20, 0, 25)
MinigameTimerLabel.Position = UDim2.new(0, 10, 0, 30)
MinigameTimerLabel.BackgroundTransparency = 1
MinigameTimerLabel.Text = "Time Remaining: 10s"
MinigameTimerLabel.TextColor3 = COLORS.TextWhite
MinigameTimerLabel.Font = Enum.Font.BuilderSansBold
MinigameTimerLabel.TextSize = 18
MinigameTimerLabel.TextXAlignment = Enum.TextXAlignment.Center
MinigameTimerLabel.Parent = MinigameHUD

-- ============================================================================
-- EVENT LISTENERS & STATE HANDLING
-- ============================================================================

-- Replicated Stats update
UIEvent.OnClientEvent:Connect(function(actionType, data)
    if actionType == "StatsUpdated" then
        UpdateLeaderboardCard(data.UserId, data.Name, data.Coins, data.Chests, data.BoardSpace)
        
    elseif actionType == "DiceRolled" then
        -- Play sound or show center announcement
        task.spawn(function()
            ShowAnnouncement("🎲 DICE ROLL RESULT", string.format("%s rolled a %d!", data.PlayerName, data.RollValue), 3, COLORS.CoinGold)
        end)
        
    elseif actionType == "MinigameTimer" then
        if data.TimeLeft > 0 then
            MinigameHUD.Visible = true
            MinigameTitle.Text = string.format("🎮 MINIGAME: %s", data.MinigameName:upper())
            MinigameTimerLabel.Text = string.format("Time Remaining: %ds", data.TimeLeft)
        else
            MinigameTimerLabel.Text = "Minigame Ended!"
            task.wait(1)
            MinigameHUD.Visible = false
        end
        
    elseif actionType == "StateChanged" then
        local state = data.State
        
        if state == "WaitingForPlayers" then
            StatusLabel.Text = "Waiting for Players..."
            if data.Countdown then
                SubStatusLabel.Text = string.format("Starting game in %d seconds...", data.Countdown)
            else
                SubStatusLabel.Text = "Waiting for other players to join..."
            end
            RollButton.Visible = false
            MinigameHUD.Visible = false
            
        elseif state == "BoardPhase" then
            StatusLabel.Text = string.format("BOARD PHASE - Round %d/%d", data.Round, data.MaxRounds)
            
            if data.ActivePlayerName then
                SubStatusLabel.Text = string.format("Active Turn: %s", data.ActivePlayerName)
                
                -- Check if it's the local player's turn
                if data.ActivePlayerName == LocalPlayer.Name then
                    RollButton.Visible = true
                    -- Slide in or bounce button
                    RollButton.Size = UDim2.new(0, 0, 0, 0)
                    RollButton.Position = UDim2.new(1, -100, 1, -40)
                    TweenService:Create(RollButton, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Size = UDim2.new(0, 160, 0, 65),
                        Position = UDim2.new(1, -180, 1, -85)
                    }):Play()
                else
                    RollButton.Visible = false
                end
            end
            
        elseif state == "MinigameSelection" then
            StatusLabel.Text = "MINIGAME SELECTION"
            SubStatusLabel.Text = "Choosing a minigame automatically..."
            RollButton.Visible = false
            
        elseif state == "MinigamePhase" then
            StatusLabel.Text = "MINIGAME PHASE"
            SubStatusLabel.Text = string.format("Playing '%s'!", data.SelectedMinigame or "Minigame")
            RollButton.Visible = false
            
            -- Display instructional popup
            task.spawn(function()
                ShowAnnouncement(
                    string.format("🎮 MINIGAME: %s", (data.SelectedMinigame or "Get Ready")):upper(),
                    data.Instructions or "Complete the objectives to earn coins!",
                    3,
                    COLORS.LavaRed
                )
            end)
            
        elseif state == "GameEnd" then
            StatusLabel.Text = "GAME OVER"
            SubStatusLabel.Text = "Declaring the champion!"
            RollButton.Visible = false
            MinigameHUD.Visible = false
            
            -- Display winner splash
            task.spawn(function()
                ShowAnnouncement(
                    "🏆 CHAMPION DECLARED 🏆",
                    string.format("%s wins with %d chests and %d coins!", 
                        data.WinnerName or "No One", 
                        data.WinnerChests or 0, 
                        data.WinnerCoins or 0
                    ),
                    6,
                    COLORS.GreenSuccess
                )
            end)
        end
    end
end)

print("[HUD UI] Initialized successfully!")
>>>>>>> 83ab5a3ab630fe244391d5eebef64b46a2a0f3ed

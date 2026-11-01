local Services = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    PathfindingService = game:GetService("PathfindingService"),
    TeleportService = game:GetService("TeleportService"),
    GuiService = game:GetService("GuiService"),
    CollectionService = game:GetService("CollectionService"),
    VirtualUser = game:GetService("VirtualUser"),
    VirtualInputManager = game:GetService("VirtualInputManager"),
    HttpService = game:GetService("HttpService"),
    Workspace = game:GetService("Workspace"),
}
local LocalPlayer = Services.Players.LocalPlayer
if not LocalPlayer then
    Services.Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Services.Players.LocalPlayer
end
Services.LocalPlayer = LocalPlayer
function Services.getCharacter()
    return LocalPlayer and LocalPlayer.Character
end
function Services.getHRP()
    local char = Services.getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end
function Services.getHumanoid()
    local char = Services.getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end
function Services.getPlayerGui()
    return LocalPlayer and (LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5))
end
return Services

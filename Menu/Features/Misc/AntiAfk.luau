local AntiAfk = {}
function AntiAfk.init(Services, State, Cleanup)
    local LocalPlayer = Services.LocalPlayer
    if not LocalPlayer then return end
    local idledConn = LocalPlayer.Idled:Connect(function()
        if State.Running and State.AntiAfk then
            pcall(function()
                if Services.VirtualUser then
                    Services.VirtualUser:CaptureController()
                    Services.VirtualUser:ClickButton2(Vector2.new(0, 0))
                end
            end)
        end
    end)
    Cleanup.addConnection(idledConn)
end
return AntiAfk

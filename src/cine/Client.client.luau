local root=game:GetService("ReplicatedStorage"):WaitForChild("CineForgePro")
local Players=game:GetService("Players")
local Config=require(root.Config)
local Player=require(root.Player)
local gui=Instance.new("ScreenGui") gui.Name="CineForgePro" gui.ResetOnSpawn=false gui.IgnoreGuiInset=true gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local current
local function stop() if current then current:Destroy() current=nil end end
root.Play.Event:Connect(function(id)
 stop()
 for _,project in ipairs(Config.projects) do
  if project.id==id then
   local ok,result=pcall(Player.New,project,gui,false)
   if not ok then warn("CineForge: "..tostring(result)) return end
   current=result
   local instance=current
   instance.Completed:Connect(function(completedId)
    root.Completed:Fire(completedId)
    if current==instance then stop() end
   end)
   current:Play() return
  end
 end
 warn("CineForge: unknown cutscene "..tostring(id))
end)
root.Stop.Event:Connect(stop)
root.PlayForClient.OnClientEvent:Connect(function(id) if type(id)=="string" then root.Play:Fire(id) end end)

-- This flag is local to this client. Scripts can wait for the event listeners.
root:SetAttribute("ClientReady",true)

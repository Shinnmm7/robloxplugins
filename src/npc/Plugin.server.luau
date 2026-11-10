local toolbar=plugin:CreateToolbar("NPC Creator Pro")
local button=toolbar:CreateButton("NPCCreatorPro","Create and manage custom or player avatar NPCs","","NPC Creator Pro")
button.ClickableWhenViewportHidden=true
local widget=plugin:CreateDockWidgetPluginGuiAsync("NPCCreatorPro.v1",DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,false,false,1160,820,860,660))
widget.Title="NPC Creator Pro"
local cleanup=require(script.Editor).Mount(plugin,widget)
button.Click:Connect(function() widget.Enabled=not widget.Enabled end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function() button:SetActive(widget.Enabled) end)
plugin.Unloading:Connect(function() cleanup() widget:Destroy() toolbar:Destroy() end)

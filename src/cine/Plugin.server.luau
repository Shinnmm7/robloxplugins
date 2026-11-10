local toolbar=plugin:CreateToolbar("CineForge Pro")
local button=toolbar:CreateButton("CineForgePro","Open cinematic editor","","CineForge Pro")
button.ClickableWhenViewportHidden=true
local widget=plugin:CreateDockWidgetPluginGuiAsync("CineForgePro.v1",DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,false,false,1200,800,780,520))
widget.Title="CineForge Pro"
local cleanup=require(script.Editor).Mount(plugin,widget)
button.Click:Connect(function() widget.Enabled=not widget.Enabled end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function() button:SetActive(widget.Enabled) end)
plugin.Unloading:Connect(function() cleanup() widget:Destroy() toolbar:Destroy() end)

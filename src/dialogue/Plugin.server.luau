local toolbar=plugin:CreateToolbar("DialogueCraft Pro")
local button=toolbar:CreateButton("DialogueCraftPro","Open dialogue builder","","DialogueCraft Pro") button.ClickableWhenViewportHidden=true
local widget=plugin:CreateDockWidgetPluginGuiAsync("DialogueCraftPro.v1",DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,false,false,1200,780,800,540)) widget.Title="DialogueCraft Pro"
local cleanup=require(script.Editor).Mount(plugin,widget)
button.Click:Connect(function() widget.Enabled=not widget.Enabled button:SetActive(widget.Enabled) end)
plugin.Unloading:Connect(function() cleanup() widget:Destroy() toolbar:Destroy() end)

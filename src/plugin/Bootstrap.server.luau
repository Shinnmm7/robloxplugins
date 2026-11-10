-- Installed as a local Studio plugin; child modules and templates are bundled.
local toolbar = plugin:CreateToolbar("QuestForge Pro")
local button = toolbar:CreateButton("QuestForgePro", "Open QuestForge Pro quest editor", "", "QuestForge Pro")
button.ClickableWhenViewportHidden = true
local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 960, 720, 620, 450)
local widget = plugin:CreateDockWidgetPluginGuiAsync("QuestForgePro.Editor.v1", info)
widget.Title = "QuestForge Pro"
local Editor = require(script.Editor)
local cleanup = Editor.Mount(plugin, widget)
button.Click:Connect(function() widget.Enabled = not widget.Enabled end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function() button:SetActive(widget.Enabled) end)
plugin.Unloading:Connect(function() cleanup() widget:Destroy() toolbar:Destroy() end)

local Players=game:GetService("Players")
local Root=game:GetService("ReplicatedStorage"):WaitForChild("DialogueCraftPro")
local gui=Instance.new("ScreenGui") gui.Name="DialogueCraftPro" gui.ResetOnSpawn=false gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local function make(class,parent,props) local o=Instance.new(class) for k,v in pairs(props) do o[k]=v end o.Parent=parent return o end
local bg=Color3.fromRGB(23,26,36) local fg=Color3.fromRGB(240,242,250)
local panel=make("Frame",gui,{Size=UDim2.new(0.9,0,0.45,0),Position=UDim2.new(0.05,0,0.5,0),BackgroundColor3=bg,Visible=false})
make("UISizeConstraint",panel,{MaxSize=Vector2.new(800,500)})
make("UICorner",panel,{CornerRadius=UDim.new(0,12)})
local speaker=make("TextLabel",panel,{Position=UDim2.fromOffset(16,8),Size=UDim2.new(1,-70,0,28),BackgroundTransparency=1,TextColor3=fg,Font=Enum.Font.GothamBold,TextSize=18,TextXAlignment=Enum.TextXAlignment.Left})
local text=make("TextLabel",panel,{Position=UDim2.fromOffset(16,42),Size=UDim2.new(1,-32,0.35,0),BackgroundTransparency=1,TextColor3=fg,Font=Enum.Font.Gotham,TextSize=16,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
local choices=make("ScrollingFrame",panel,{Position=UDim2.new(0,16,0.5,0),Size=UDim2.new(1,-32,0.5,-12),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=4})
make("UIListLayout",choices,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local current
local function send(choice) if current then Root.Request:FireServer(current.token,current.turn,choice) end end
local close=make("TextButton",panel,{Text="×",Position=UDim2.new(1,-46,0,8),Size=UDim2.fromOffset(36,28),BackgroundColor3=bg,TextColor3=fg,TextSize=22})
close.Activated:Connect(function() if current then send("close") else panel.Visible=false end end)
Root.Response.OnClientEvent:Connect(function(view)
 if view.error then panel.Visible=true text.Text=view.error return end
 current=view panel.Visible=not view.ended
 for _,o in ipairs(choices:GetChildren()) do if o:IsA("TextButton") then o:Destroy() end end
 if view.ended then current=nil return end
 speaker.Text=view.speaker or "" text.Text=view.text or ""
 for i,c in ipairs(view.choices or {}) do
  local b=make("TextButton",choices,{Text=(if c.default then "› " else "")..c.text,Size=UDim2.new(1,-6,0,40),BackgroundColor3=Color3.fromRGB(80,66,160),TextColor3=fg,Font=Enum.Font.Gotham,TextSize=15,TextWrapped=true,AutoButtonColor=c.enabled,TextTransparency=if c.enabled then 0 else 0.6,LayoutOrder=i})
  b.Activated:Connect(function() if c.enabled then send(c.id) end end)
 end
end)

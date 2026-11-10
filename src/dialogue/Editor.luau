local Http=game:GetService("HttpService")
local Input=game:GetService("UserInputService")
local Model=require(script.Parent.Model)
local Example=require(script.Parent.Example)
local Generator=require(script.Parent.Generator)
local Editor={}
local C={bg=Color3.fromRGB(18,21,30),card=Color3.fromRGB(30,35,48),field=Color3.fromRGB(44,50,68),text=Color3.fromRGB(235,240,250),accent=Color3.fromRGB(113,91,225),active=Color3.fromRGB(45,144,113)}
local function new(class,parent,props) local o=Instance.new(class) for k,v in pairs(props or {}) do o[k]=v end o.Parent=parent return o end
local function label(parent,value,height)
 return new("TextLabel",parent,{Text=value,Size=UDim2.new(1,-8,0,height or 24),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=12,LayoutOrder=#parent:GetChildren()})
end
local function button(parent,value,callback)
 local b=new("TextButton",parent,{Text=value,Size=UDim2.new(1,-8,0,30),BackgroundColor3=C.field,TextColor3=C.text,Font=Enum.Font.GothamMedium,TextSize=12,TextWrapped=true,BorderSizePixel=0,LayoutOrder=#parent:GetChildren()})
 new("UICorner",b,{CornerRadius=UDim.new(0,5)}) b.Activated:Connect(callback) return b
end
local function layout(frame) new("UIListLayout",frame,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder}) end
local function scroll(parent,pos,size)
 local s=new("ScrollingFrame",parent,{Position=pos,Size=size,BackgroundColor3=C.card,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y}) layout(s) return s
end
local function clear(frame) for _,o in ipairs(frame:GetChildren()) do if o:IsA("GuiObject") then o:Destroy() end end end
function Editor.Mount(pluginObject,widget)
 local config=Model.Clone(Example) local pi,selected,zoom=1,"greeting",1
 local pending,drag,pan,preview=nil,nil,nil,nil
 local search="" local connections={} local render,draw,properties,browser,previewPanel
 local root=new("Frame",widget,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0})
 local toolbar=new("Frame",root,{Position=UDim2.fromOffset(10,8),Size=UDim2.new(1,-20,0,66),BackgroundTransparency=1})
 new("UIGridLayout",toolbar,{CellSize=UDim2.new(0.125,-5,0,29),CellPadding=UDim2.fromOffset(5,5),SortOrder=Enum.SortOrder.LayoutOrder})
 local projects=scroll(root,UDim2.new(0,10,0,82),UDim2.new(0.16,-14,1,-146))
 local canvas=new("ScrollingFrame",root,{Position=UDim2.new(0.16,0,0,82),Size=UDim2.new(0.54,-8,0.7,-82),BackgroundColor3=C.bg,BorderSizePixel=0,ScrollBarThickness=7,CanvasSize=UDim2.fromOffset(6000,4000),ScrollingDirection=Enum.ScrollingDirection.XY})
 local inspector=scroll(root,UDim2.new(0.7,0,0,82),UDim2.new(0.3,-10,1,-146))
 local previewBox=scroll(root,UDim2.new(0.16,0,0.7,8),UDim2.new(0.54,-8,0.3,-72))
 local status=label(root,"DIALOGUECRAFT PRO • Select an output, then click a destination node to connect.",48) status.Position=UDim2.new(0,10,1,-56) status.Size=UDim2.new(1,-20,0,48)
 local function message(s) status.Text=tostring(s) end
 local function protect(f) local ok,result=pcall(f) message(if ok then result or "Done" else result) end
 local function project() return config.projects[pi] end
 local function unique(prefix,list) local used={} for _,n in ipairs(list) do used[n.id]=true end local i=1 while used[prefix..i] do i+=1 end return prefix..i end
 local function field(parent,title,value,callback,multi)
  label(parent,title)
  local t=new("TextBox",parent,{Text=tostring(value or ""),Size=UDim2.new(1,-8,0,if multi then 72 else 30),TextColor3=C.text,BackgroundColor3=C.field,Font=Enum.Font.Code,TextSize=12,TextWrapped=true,MultiLine=multi==true,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=#parent:GetChildren()})
  t.FocusLost:Connect(function() callback(t.Text) end) return t
 end
 local function edit(parent,title,obj,key,multi) field(parent,title,obj[key],function(v) obj[key]=v browser() draw() end,multi) end
 local function number(parent,title,obj,key)
  field(parent,title,obj[key],function(v) local n=tonumber(v) if n and n==n and n%1==0 and n>=1 and n<=1e9 then obj[key]=n else message("Enter a positive integer") end end)
 end
 local function cycle(parent,title,obj,key,options)
  button(parent,title..": "..tostring(obj[key]).." ▸",function() local i=table.find(options,obj[key]) or 0 obj[key]=options[i%#options+1] properties() draw() end)
 end
 local function condition(parent,c)
  cycle(parent,"Condition",c,"type",Model.Conditions)
  if c.type~="Always" then edit(parent,"Item / quest / attribute key",c,"key") number(parent,"Required amount / level",c,"amount") if c.type=="Attribute" then edit(parent,"Attribute value (as text)",c,"value") end end
 end
 local function connectTo(n)
  if pending then
   if type(pending.key)=="number" then pending.node.choices[pending.key].next=n.id else pending.node[pending.key]=n.id end
   pending=nil message("Connection created")
  end selected=n.id properties() draw()
 end
 browser=function()
  clear(projects)
  label(projects,"PROJECTS")
  field(projects,"Search",search,function(v) search=v browser() end)
  button(projects,"+ Project",function() table.insert(config.projects,Model.Project(unique("dialogue_",config.projects))) pi=#config.projects selected="start" preview=nil render() end)
  for i,p in ipairs(config.projects) do if (p.name.." "..p.id):lower():find(search:lower(),1,true) then
   button(projects,p.name.."\n"..p.id,function() pi=i selected=p.start preview=nil pending=nil render() end).Size=UDim2.new(1,-8,0,48)
  end end
 end
 draw=function()
  clear(canvas) local p=project() if not p then return end
  local nodes={} for _,n in ipairs(p.nodes) do nodes[n.id]=n end
  local function line(a,b)
   local delta=b-a local center=(a+b)/2
   new("Frame",canvas,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(center.X,center.Y),Size=UDim2.fromOffset(delta.Magnitude,2),Rotation=math.deg(math.atan2(delta.Y,delta.X)),BorderSizePixel=0,BackgroundColor3=C.accent,ZIndex=1})
  end
  for _,n in ipairs(p.nodes) do for _,e in ipairs(Model.Edges(n)) do local target=nodes[e.target] if target then line(Vector2.new((n.x+190)*zoom,(n.y+36)*zoom),Vector2.new(target.x*zoom,(target.y+36)*zoom)) end end end
  for _,n in ipairs(p.nodes) do
   local card=new("Frame",canvas,{Position=UDim2.fromOffset(n.x*zoom,n.y*zoom),Size=UDim2.fromOffset(190*zoom,(100+#Model.Edges(n)*30)*zoom),BackgroundColor3=if (preview and preview.view and preview.view.node==n.id) then C.active elseif selected==n.id then C.accent else C.card,BorderSizePixel=0,ZIndex=2})
   new("UICorner",card,{CornerRadius=UDim.new(0,6)})
   local title=button(card,n.type.." • "..n.id,function() connectTo(n) end) title.Size=UDim2.new(1,0,0,30*zoom) title.ZIndex=3
   title.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then drag={node=n,origin=Vector2.new(input.Position.X,input.Position.Y),x=n.x,y=n.y,card=card} end
   end)
   local summary=label(card,n.text~="" and n.text or n.type,48*zoom) summary.Position=UDim2.fromOffset(5,32*zoom) summary.TextSize=math.max(9,12*zoom) summary.ZIndex=3
   for i,e in ipairs(Model.Edges(n)) do
    local port=button(card,tostring(e.key).." → "..(e.target=="" and "connect" or e.target),function() pending={node=n,key=e.key} message("Click the destination node title. Cancel connection using Escape.") end)
    port.Position=UDim2.fromOffset(5,(80+(i-1)*30)*zoom) port.Size=UDim2.new(1,-10,0,26*zoom) port.TextSize=math.max(9,11*zoom) port.ZIndex=3
   end
  end
 end
 properties=function()
  clear(inspector) local p=project() if not p then return end
  label(inspector,"PROJECT PROPERTIES") edit(inspector,"Name",p,"name") edit(inspector,"Unique dialogue ID",p,"id") edit(inspector,"NPC name",p,"npc") edit(inspector,"Starting node ID",p,"start")
  button(inspector,"Repeatable: "..tostring(p.repeatable),function() p.repeatable=not p.repeatable properties() end)
  button(inspector,"Duplicate project",function() local copy=Model.Clone(p) copy.id=unique("dialogue_",config.projects) table.insert(config.projects,copy) pi=#config.projects render() end)
  button(inspector,"Delete project",function() table.remove(config.projects,pi) pi=math.max(1,math.min(pi,#config.projects)) preview=nil render() end)
  label(inspector,"CREATE NODE")
  for _,kind in ipairs(Model.Types) do button(inspector,"+ "..kind,function() local n=Model.Node(unique("node_",p.nodes),kind) n.x=canvas.CanvasPosition.X/zoom+40 n.y=canvas.CanvasPosition.Y/zoom+40 table.insert(p.nodes,n) selected=n.id properties() draw() end) end
  local n for _,node in ipairs(p.nodes) do if node.id==selected then n=node end end if not n then return end
  label(inspector,"NODE PROPERTIES • "..n.id)
  field(inspector,"Node ID",n.id,function(v)
   if v==n.id then return end for _,other in ipairs(p.nodes) do if other.id==v then message("Duplicate node ID") return end end
   local old=n.id n.id=v selected=v if p.start==old then p.start=v end
   for _,other in ipairs(p.nodes) do for _,e in ipairs(Model.Edges(other)) do if e.target==old then if type(e.key)=="number" then other.choices[e.key].next=v else other[e.key]=v end end end end properties() draw()
  end)
  cycle(inspector,"Node type",n,"type",Model.Types)
  if n.type=="Text" or n.type=="Choice" then edit(inspector,"Speaker",n,"speaker") edit(inspector,"Dialogue text",n,"text",true) end
  if n.type=="Condition" then condition(inspector,n.condition) end
  if n.type=="Action" then cycle(inspector,"Action",n.action,"type",Model.Actions) edit(inspector,"Item / quest / server event ID",n.action,"key") number(inspector,"Amount",n.action,"amount") end
  if n.type=="Choice" then
   for i,c in ipairs(n.choices) do
    label(inspector,"RESPONSE "..i) edit(inspector,"Response text",c,"text") condition(inspector,c.condition) cycle(inspector,"Unavailable choice",c,"visibility",{"Hide","Disable"})
    button(inspector,"Default: "..tostring(c.default),function() for _,other in ipairs(n.choices) do other.default=false end c.default=true properties() end)
    button(inspector,"Remove response "..i,function() table.remove(n.choices,i) properties() draw() end)
   end
   button(inspector,"+ Response",function() table.insert(n.choices,{text="New response",next="",condition={type="Always",key="",amount=1,value="true"},visibility="Hide",default=#n.choices==0}) properties() draw() end)
  end
  for _,e in ipairs(Model.Edges(n)) do
   local holder=if type(e.key)=="number" then n.choices[e.key] else n local key=if type(e.key)=="number" then "next" else e.key
   edit(inspector,"Connection "..tostring(e.key).." (target node ID)",holder,key)
   button(inspector,"Disconnect "..tostring(e.key),function() holder[key]="" properties() draw() end)
  end
  button(inspector,"Set as project start",function() if n.type=="Start" then p.start=n.id properties() else message("Choose a Start node") end end)
  button(inspector,"Duplicate node",function() local copy=Model.Clone(n) copy.id=unique("node_",p.nodes) copy.x+=50 copy.y+=50 table.insert(p.nodes,copy) selected=copy.id properties() draw() end)
  button(inspector,"Delete node",function() for i,o in ipairs(p.nodes) do if o==n then table.remove(p.nodes,i) break end end selected=nil properties() draw() message("Node deleted. Validate to locate connections that need repair.") end)
 end
 previewPanel=function()
  clear(previewBox)
  if not preview then label(previewBox,"PREVIEW • Start to test the current project. Preview actions only change the simulated state.",48) return end
  local view=preview.view
  if not view then label(previewBox,preview.error or "No preview",56) return end
  label(previewBox,"PREVIEW • "..(view.speaker or "").." • currency "..preview.state.currency,28)
  label(previewBox,view.ended and "Conversation ended" or view.text,54)
  for _,c in ipairs(view.choices or {}) do button(previewBox,(if c.default then "› " else "")..c.text..(if not c.enabled then " (unavailable)" else ""),function()
   if not c.enabled then return end local state,session=Model.Clone(preview.state),Model.Clone(preview.session)
   local result,err=Model.Advance(project(),session,state,c.id)
   if result then preview.state=state preview.session=session preview.view=result else message(err) end previewPanel() draw()
  end) end
  for _,e in ipairs(view.events or {}) do label(previewBox,"Simulated server event: "..(if type(e)=="table" then e.questAction.." "..e.id else e)) end
 end
 render=function() browser() properties() draw() previewPanel() end
 button(toolbar,"Save",function() protect(function() pluginObject:SetSetting("DialogueCraftPro.v1",Http:JSONEncode(config)) return "Saved local dialogue projects" end) end)
 button(toolbar,"Load",function() protect(function() local value=pluginObject:GetSetting("DialogueCraftPro.v1") assert(value,"No saved projects") local loaded=Http:JSONDecode(value) assert(loaded.version==1 and type(loaded.projects)=="table","Invalid draft") config=loaded pi=1 preview=nil render() return "Loaded" end) end)
 button(toolbar,"Export JSON",function() protect(function() return Generator.Export(config) end) end)
 button(toolbar,"Import selection",function() protect(function() config=Generator.Import() pi=1 preview=nil render() return "Imported" end) end)
 button(toolbar,"Generate",function() protect(function() return Generator.Generate(config) end) end)
 button(toolbar,"Example NPC",function() protect(function() assert(project(),"Select a project") return Generator.Demo(project().id,project().npc) end) end)
 button(toolbar,"Validate",function() local errors=Model.Validate(config) clear(previewBox) label(previewBox,"VALIDATION • "..#errors.." errors") for _,err in ipairs(errors) do label(previewBox,err,46) end if #errors==0 then label(previewBox,"All connections, node content, and reachability checks pass.",48) end message("Validation: "..#errors.." errors") end)
 button(toolbar,"Preview",function()
  local p=project() if not p then return end local errors=Model.Validate({version=1,projects={p}}) if #errors>0 then message(table.concat(errors," • ")) return end
  local state=Model.State() local session={node=p.start} local view,err=Model.Advance(p,session,state) preview={state=state,session=session,view=view,error=err} previewPanel() draw()
 end)
 button(toolbar,"Preview state",function()
  clear(previewBox) local state=if preview then preview.state else Model.State()
  local raw=Http:JSONEncode(state)
  field(previewBox,"Simulation state JSON: items, currency, level, quests, attributes, completed",raw,function(v)
   protect(function() local s=Http:JSONDecode(v) assert(type(s.items)=="table" and type(s.currency)=="number" and type(s.level)=="number" and type(s.quests)=="table" and type(s.attributes)=="table" and type(s.completed)=="table","Invalid simulation state")
    local p=project() assert(p,"Select a project") local session={node=p.start} local view,err=Model.Advance(p,session,s) preview={state=s,session=session,view=view,error=err} previewPanel() draw() return "Simulation restarted with your state" end)
  end,true)
 end)
 button(toolbar,"Zoom +",function() zoom=math.min(1.5,zoom+0.1) draw() end)
 button(toolbar,"Zoom −",function() zoom=math.max(0.4,zoom-0.1) draw() end)
 button(toolbar,"Arrange",function()
  local p=project() if not p then return end local depths,queue={[p.start]=0},{p.start} local index=1
  while index<=#queue do local key=queue[index] index+=1 for _,n in ipairs(p.nodes) do if n.id==key then for _,e in ipairs(Model.Edges(n)) do if depths[e.target]==nil then depths[e.target]=depths[key]+1 table.insert(queue,e.target) end end end end end
  local rows={} for _,n in ipairs(p.nodes) do local d=depths[n.id] or 0 rows[d]=(rows[d] or 0)+1 n.x=40+d*250 n.y=40+(rows[d]-1)*260 end draw()
 end)
 button(toolbar,"Example project",function() table.insert(config.projects,Model.Clone(Example.projects[1])) pi=#config.projects project().id=unique("example_",config.projects) selected=project().start preview=nil render() end)
 canvas.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton3 then pan={origin=Vector2.new(input.Position.X,input.Position.Y),scroll=canvas.CanvasPosition} end end)
 table.insert(connections,Input.InputChanged:Connect(function(input)
  if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
  local position=Vector2.new(input.Position.X,input.Position.Y)
  if drag then local delta=(position-drag.origin)/zoom drag.node.x=math.clamp(drag.x+delta.X,0,5500) drag.node.y=math.clamp(drag.y+delta.Y,0,3500) drag.card.Position=UDim2.fromOffset(drag.node.x*zoom,drag.node.y*zoom)
  elseif pan then local d=pan.scroll-(position-pan.origin) canvas.CanvasPosition=Vector2.new(math.max(0,d.X),math.max(0,d.Y)) end
 end))
 table.insert(connections,Input.InputEnded:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 and drag then drag=nil task.defer(draw) end
  if input.UserInputType==Enum.UserInputType.MouseButton3 then pan=nil end
 end))
 table.insert(connections,Input.InputBegan:Connect(function(input) if input.KeyCode==Enum.KeyCode.Escape then pending=nil message("Connection cancelled") end end))
 local ok,saved=pcall(function() return pluginObject:GetSetting("DialogueCraftPro.v1") end)
 if ok and type(saved)=="string" then local good,value=pcall(Http.JSONDecode,Http,saved) if good and type(value)=="table" and value.version==1 and type(value.projects)=="table" then config=value end end
 render()
 return function() pcall(function() pluginObject:SetSetting("DialogueCraftPro.v1",Http:JSONEncode(config)) end) for _,c in ipairs(connections) do c:Disconnect() end root:Destroy() end
end
return Editor

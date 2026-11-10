local M = {}
M.Types = {"Start", "Text", "Choice", "Condition", "Action", "End"}
M.Conditions = {"Always", "Item", "Currency", "Quest", "Level", "Attribute"}
M.Actions = {"GiveItem", "RemoveItem", "GiveCurrency", "StartQuest", "CompleteQuest", "Event"}
function M.Clone(t)
 if type(t) ~= "table" then return t end
 local c = {} for k,v in pairs(t) do c[k] = M.Clone(v) end return c
end
function M.Node(id, kind)
 return {id=id, type=kind, speaker="Rowan", text="Hello, traveler.", x=100, y=100, next="", yes="", no="", choices={},
 condition={type="Always", key="", amount=1, value="true"}, action={type="GiveCurrency", key="", amount=1}}
end
function M.Project(id)
 local a,b,c=M.Node("start","Start"),M.Node("hello","Text"),M.Node("end","End")
 a.next="hello" b.next="end" a.x=40 b.x=300 c.x=560
 return {id=id,name="New conversation",npc="Rowan",start="start",repeatable=false,nodes={a,b,c}}
end
function M.Edges(node)
 local e={}
 if node.type=="Choice" then for i,c in ipairs(node.choices) do table.insert(e,{key=i,target=c.next}) end
 elseif node.type=="Condition" then e={{key="yes",target=node.yes},{key="no",target=node.no}}
 elseif node.type~="End" then e={{key="next",target=node.next}} end
 return e
end
local function id(s) return type(s)=="string" and #s>0 and #s<=100 and s:match("^[%w_.%-]+$") end
local function positive(n) return type(n)=="number" and n==n and n>=1 and n<=1e9 and n%1==0 end
local function condition(c)
 return type(c)=="table" and table.find(M.Conditions,c.type) and
 (c.type=="Always" or ((c.type=="Currency" or c.type=="Level" or id(c.key)) and positive(c.amount)))
 and (c.type~="Attribute" or type(c.value)=="string")
end
function M.Validate(config)
 local errors,projectIds={},{}
 local function err(s) table.insert(errors,s) end
 if type(config)~="table" or config.version~=1 or type(config.projects)~="table" then return {"Invalid configuration version/projects"} end
 for pi,p in ipairs(config.projects) do
  local prefix="Project "..pi..": "
  if type(p)~="table" then err(prefix.."invalid project") continue end
  if not id(p.id) or projectIds[p.id] then err(prefix.."missing or duplicate dialogue ID") else projectIds[p.id]=true end
  if type(p.name)~="string" or #p.name==0 or type(p.npc)~="string" or type(p.repeatable)~="boolean" then err(prefix.."invalid name, NPC, or repeatable flag") end
  if type(p.nodes)~="table" then err(prefix.."nodes must be an array") continue end
  local nodes,valid={},true
  for _,n in ipairs(p.nodes) do
   if type(n)~="table" or not id(n.id) or nodes[n.id] or not table.find(M.Types,n.type) then err(prefix.."invalid/duplicate node ID or type") valid=false continue end
   nodes[n.id]=n
   if type(n.x)~="number" or n.x~=n.x or math.abs(n.x)>1e6 or type(n.y)~="number" or n.y~=n.y or math.abs(n.y)>1e6 then err(prefix..n.id..": invalid position") end
   if (n.type=="Text" or n.type=="Choice") and (type(n.text)~="string" or #n.text==0 or #n.text>10000 or type(n.speaker)~="string") then err(prefix..n.id..": missing dialogue text/speaker") end
   if n.type=="Condition" and not condition(n.condition) then err(prefix..n.id..": invalid condition") end
   if n.type=="Action" then
    local a=n.action
    if type(a)~="table" or not table.find(M.Actions,a.type) or not positive(a.amount) or (a.type~="GiveCurrency" and not id(a.key)) then err(prefix..n.id..": invalid action") end
   end
   if n.type=="Choice" then
    if type(n.choices)~="table" or #n.choices==0 then err(prefix..n.id..": choices required") valid=false
    else
     local defaults=0
     for _,c in ipairs(n.choices) do
      if type(c)~="table" or type(c.text)~="string" or #c.text==0 or #c.text>500 or not condition(c.condition) or not table.find({"Hide","Disable"},c.visibility) or type(c.default)~="boolean" then err(prefix..n.id..": invalid response") valid=false
      elseif c.default then defaults+=1 if c.condition.type~="Always" then err(prefix..n.id..": default response must always be available") end end
     end
     if defaults~=1 then err(prefix..n.id..": exactly one default response is required") end
    end
   end
  end
  if not valid then continue end
  if not nodes[p.start] or nodes[p.start].type~="Start" then err(prefix.."starting node must be a Start node") end
  local incoming={}
  for _,n in ipairs(p.nodes) do for _,edge in ipairs(M.Edges(n)) do
   if not nodes[edge.target] then err(prefix..n.id..": broken "..tostring(edge.key).." connection") else incoming[edge.target]=true end
  end end
  local active,visited={},{}
  local function visit(key)
   if active[key] then err(prefix.."cycle at "..key.."; dialogue graphs must terminate") return end
   if visited[key] or not nodes[key] then return end
   visited[key]=true active[key]=true
   for _,e in ipairs(M.Edges(nodes[key])) do visit(e.target) end
   active[key]=nil
  end
  visit(p.start)
  for _,n in ipairs(p.nodes) do
   if not visited[n.id] then err(prefix..n.id..": unreachable node") end
   if n.id~=p.start and not incoming[n.id] then err(prefix..n.id..": disconnected node") end
  end
 end
 return errors
end
function M.State() return {items={},currency=0,level=1,quests={},attributes={},completed={},executed={}} end
function M.Test(c,s)
 if c.type=="Always" then return true elseif c.type=="Item" then return (s.items[c.key] or 0)>=c.amount
 elseif c.type=="Currency" then return s.currency>=c.amount elseif c.type=="Level" then return s.level>=c.amount
 elseif c.type=="Quest" then return s.quests[c.key]=="Completed"
 elseif c.type=="Attribute" then return tostring(s.attributes[c.key])==c.value end return false
end
function M.Apply(a,s,events)
 if a.type=="GiveItem" then s.items[a.key]=math.min(1e12,(s.items[a.key] or 0)+a.amount)
 elseif a.type=="RemoveItem" then if (s.items[a.key] or 0)<a.amount then return false,"Missing item: "..a.key end s.items[a.key]-=a.amount
 elseif a.type=="GiveCurrency" then s.currency=math.min(1e12,s.currency+a.amount)
 elseif a.type=="StartQuest" then if s.quests[a.key]~="Completed" then s.quests[a.key]="Active" table.insert(events,{questAction="StartQuest",id=a.key}) end
 elseif a.type=="CompleteQuest" then if s.quests[a.key]~="Active" then return false,"Quest is not active: "..a.key end s.quests[a.key]="Completed" table.insert(events,{questAction="CompleteQuest",id=a.key})
 elseif a.type=="Event" then table.insert(events,a.key) end
 return true
end
function M.Advance(project,session,state,choice)
 local nodes={} for _,n in ipairs(project.nodes) do nodes[n.id]=n end
 local current=nodes[session.node]
 if session.waiting then
  if current.type=="Choice" then
   local c=current.choices[choice]
   if not c or not M.Test(c.condition,state) then return nil,"Response unavailable" end
   session.node=c.next
  elseif current.type=="Text" and choice=="continue" then session.node=current.next
  else return nil,"Invalid response" end
  session.waiting=false
 end
 local events={}
 for _=1,#project.nodes+1 do
  local n=nodes[session.node]
  if not n then return nil,"Broken connection" end
  if n.type=="End" then session.ended=true state.completed[project.id]=true return {node=n.id,ended=true,events=events}
  elseif n.type=="Text" or n.type=="Choice" then
   session.waiting=true
   local view={node=n.id,speaker=if n.speaker=="" then project.npc else n.speaker,text=n.text,choices={},events=events}
   if n.type=="Text" then view.choices={{id="continue",text="Continue",enabled=true,default=true}}
   else
    for i,c in ipairs(n.choices) do
     local allowed=M.Test(c.condition,state)
     if allowed or c.visibility=="Disable" then table.insert(view.choices,{id=i,text=c.text,enabled=allowed,default=c.default}) end
    end
   end
   return view
  elseif n.type=="Condition" then session.node=if M.Test(n.condition,state) then n.yes else n.no
  elseif n.type=="Action" then
   state.executed=state.executed or {}
   local receipt=project.id..":"..n.id
   if project.repeatable or not state.executed[receipt] then
    local ok,message=M.Apply(n.action,state,events) if not ok then return nil,message end
    state.executed[receipt]=true
   end
   session.node=n.next
  else session.node=n.next end
 end
 return nil,"Automatic traversal limit exceeded"
end
return M

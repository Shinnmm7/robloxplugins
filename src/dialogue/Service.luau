local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Store=game:GetService("DataStoreService"):GetDataStore("DialogueCraftPro_v1")
local Collection=game:GetService("CollectionService")
local Root=game:GetService("ReplicatedStorage"):WaitForChild("DialogueCraftPro")
local Config=require(Root.Config)
local Model=require(script.Parent.Model)
local Service={}
local busy,last,targets={}, {}, {}
local owner=game.JobId..Http:GenerateGUID(false)
local started=false
local questBridge
local questFolder=game:GetService("ServerScriptService"):FindFirstChild("QuestForgePro")
if questFolder and questFolder:FindFirstChild("QuestService") then questBridge=require(questFolder.QuestService) end
local updated=Instance.new("BindableEvent") Service.Changed=updated.Event
local function project(id) for _,p in ipairs(Config.projects) do if p.id==id then return p end end end
local function near(player,part)
 local c=player.Character local h=c and c:FindFirstChildOfClass("Humanoid") local r=c and c:FindFirstChild("HumanoidRootPart")
 return part and part:IsDescendantOf(workspace) and h and h.Health>0 and r and (r.Position-part.Position).Magnitude<=18
end
local function publish(player,record)
 Root.Response:FireClient(player,record.view)
 updated:Fire(player,Model.Clone(record.state))
 -- Bindable listeners receive a durable receipt ID and must deduplicate external side effects.
 local folder=game:GetService("ServerStorage"):FindFirstChild("DialogueCraftActions")
 for index,key in ipairs(record.view.events or {}) do
  if type(key)=="table" and key.questAction then
   if questBridge and questBridge.DialogueQuest then
    local ok,reason=questBridge.DialogueQuest(player,key.questAction,key.id)
    if not ok then warn("DialogueCraft quest bridge: "..tostring(reason)) end
   end
  elseif type(key)=="string" then
   local event=folder and folder:FindFirstChild(key)
   if event and event:IsA("BindableEvent") then event:Fire(player,record.receipt..":"..index,Model.Clone(record.state)) end
  end
 end
end
local function transact(player,operation)
 if busy[player] then return false,"Dialogue data is busy" end
 busy[player]=true
 local receipt=Http:GenerateGUID(false)
 local result,reason
 for attempt=1,3 do
  local ok,value=pcall(function()
   return Store:UpdateAsync("p_"..player.UserId,function(old)
    if old and old.receipt==receipt then return old end
    local record=old or {state=Model.State()}
    record=Model.Clone(record)
    record.state.attributes=player:GetAttributes()
    if questBridge then
     local qs=questBridge.GetState(player)
     if not qs then reason="QuestForge player data is still loading" return nil end
     record.state.level=qs.level
     for id,q in pairs(qs.quests) do if q.status=="Active" or (q.completions or 0)>0 then record.state.quests[id]=if (q.completions or 0)>0 then "Completed" else "Active" end end
    end
    local accepted,message=operation(record)
    if not accepted then reason=message return nil end
    record.receipt=receipt
    return record
   end)
  end)
  if ok then result=value break end
  if attempt<3 then task.wait(attempt) end
 end
 busy[player]=nil
 if result and player.Parent==Players then publish(player,result) return true end
 if player.Parent==Players then Root.Response:FireClient(player,{error=reason or "Dialogue could not be saved. Try again."}) end
 return false,reason
end
function Service.Begin(player,id,part)
 local p=project(id)
 if not p then return false,"Unknown dialogue" end
 if not near(player,part) then return false,"Move closer to the NPC" end
 local now=os.clock()
 if now-(last[player] or -100)<0.5 then return false,"Please wait" end last[player]=now
 return transact(player,function(record)
  if not near(player,part) then return false,"Move closer to the NPC" end
  if record.session and record.session.owner==owner and record.session.expires>os.time() and not record.session.ended then
   if record.session.project==id then record.view.events={} return true end
   return false,"Finish or close conversation: "..record.session.project
  end
  if record.state.completed[id] and not p.repeatable then return false,"Conversation already completed" end
  local session={node=p.start,project=id,token=Http:GenerateGUID(false),owner=owner,turn=1,expires=os.time()+180}
  local view,message=Model.Advance(p,session,record.state)
  if not view then return false,message end
  view.token=session.token view.turn=session.turn view.project=id
  record.session=session record.view=view
  return true
 end)
end
function Service.Start()
 if started then return end
 assert(#Model.Validate(Config)==0,table.concat(Model.Validate(Config),"\n")) started=true
 Root.Request.OnServerEvent:Connect(function(player,token,turn,choice)
  if type(token)~="string" or #token>100 or type(turn)~="number" or turn%1~=0 then return end
  if choice~="continue" and choice~="close" and (type(choice)~="number" or choice%1~=0 or choice<1) then return end
  local now=os.clock() if now-(last[player] or -100)<0.3 then return end last[player]=now
  local target=targets[player]
  transact(player,function(record)
   local s=record.session
   if not s or s.owner~=owner or s.token~=token or s.turn~=turn or s.ended or s.expires<os.time() then return false,"Expired dialogue response" end
   if choice=="close" then s.ended=true record.view={ended=true,events={}} return true end
   if not near(player,target) then return false,"Move closer to the NPC" end
   local p=project(s.project) if not p then return false,"Missing project" end
   local view,message=Model.Advance(p,s,record.state,choice)
   if not view then return false,message end
   s.turn+=1 s.expires=os.time()+180
   view.token=s.token view.turn=s.turn view.project=s.project record.view=view
   return true
  end)
 end)
 local function bind(part)
  if not part:IsA("BasePart") then return end
  local prompt=part:FindFirstChildOfClass("ProximityPrompt") if not prompt then return end
  prompt.Triggered:Connect(function(player)
   if not Collection:HasTag(part,"DialogueCraftNPC") then return end
   local id=part:GetAttribute("DialogueId")
   if type(id)=="string" then local ok=Service.Begin(player,id,part) if ok then targets[player]=part end end
  end)
 end
 Collection:GetInstanceAddedSignal("DialogueCraftNPC"):Connect(bind)
 for _,part in ipairs(Collection:GetTagged("DialogueCraftNPC")) do bind(part) end
 Players.PlayerRemoving:Connect(function(player) targets[player]=nil last[player]=nil end)
end
-- Trusted game systems can set the standalone ledger without accepting client state.
function Service.UpdateState(player,transform)
 assert(type(transform)=="function","Expected a server state transform")
 return transact(player,function(record)
  if record.session and not record.session.ended and record.session.expires>os.time() then return false,"Close the conversation before changing its ledger" end
  transform(record.state)
  assert(type(record.state.items)=="table" and type(record.state.currency)=="number" and record.state.currency>=0 and record.state.currency<=1e12,"Invalid ledger")
  record.view={ended=true,events={}}
  return true
 end)
end
-- Trusted server integrations can open a conversation against a real nearby NPC part.
function Service.Open(player,id,part) local ok,reason=Service.Begin(player,id,part) if ok then targets[player]=part end return ok,reason end
return Service

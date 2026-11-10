-- Optional server AI template. Configuration is written by the Studio plugin.
-- No client remotes or client supplied damage/targets are accepted.
local Players=game:GetService("Players")
local Pathfinding=game:GetService("PathfindingService")
local Http=game:GetService("HttpService")
local npc=script.Parent
local config=Http:JSONDecode(npc:WaitForChild("NPCCreatorConfig").Value)
local b=config.behavior
if not b.enabled then return end
local humanoid=npc:FindFirstChildOfClass("Humanoid")
local root=npc:FindFirstChild("HumanoidRootPart")
if not humanoid or not root then return end
for _,part in ipairs(npc:GetDescendants()) do
 if part:IsA("BasePart") and not part.Anchored then pcall(function() part:SetNetworkOwner(nil) end) end
end
local animator=humanoid:FindFirstChildOfClass("Animator")
if not animator then animator=Instance.new("Animator") animator.Parent=humanoid end
local tracks={}
for _,pair in ipairs({{"idle",b.idleAnimation},{"walk",b.walkAnimation}}) do
 if pair[2]>0 then
  local asset=Instance.new("Animation") asset.AnimationId="rbxassetid://"..tostring(pair[2])
  local ok,track=pcall(animator.LoadAnimation,animator,asset) asset:Destroy()
  if ok then track.Looped=true track.Priority=if pair[1]=="idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement tracks[pair[1]]=track
  else warn("NPC Creator animation failed for "..npc.Name..": "..tostring(track)) end
 end
end
local current
local function animate(name)
 if current==name then return end
 for key,track in pairs(tracks) do if key==name then track:Play(.2) else track:Stop(.2) end end current=name
end
local origin=root.Position
local walkTarget=origin+root.CFrame.LookVector*b.walkDistance
local patrolIndex=1
local waypoints,index,lastPath,lastGoal={},1,-math.huge,nil
local lastAttack=-math.huge
local alive=true
local removed=npc.AncestryChanged:Connect(function() if not npc:IsDescendantOf(workspace) then alive=false end end)
local function nearest()
 local chosen,dist=nil,b.range
 for _,player in ipairs(Players:GetPlayers()) do
  local char=player.Character local hrp=char and char:FindFirstChild("HumanoidRootPart") local h=char and char:FindFirstChildOfClass("Humanoid")
  if hrp and h and h.Health>0 then local d=(hrp.Position-root.Position).Magnitude if d<dist then dist=d chosen={root=hrp,humanoid=h,character=char} end end
 end
 return chosen,dist
end
local function visible(target)
 local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances={npc}
 local hit=workspace:Raycast(root.Position,target.root.Position-root.Position,params)
 return not hit or hit.Instance:IsDescendantOf(target.character)
end
local function steer(goal,now)
 if now-lastPath>1.25 or (lastGoal and (lastGoal-goal).Magnitude>8) then
  lastPath=now lastGoal=goal
  local _,size=npc:GetBoundingBox()
  local path=Pathfinding:CreatePath({AgentRadius=math.clamp(math.max(size.X,size.Z)*.35,1,6),AgentHeight=math.clamp(size.Y,3,15),AgentCanJump=humanoid.JumpPower>0,WaypointSpacing=4})
  local ok=pcall(path.ComputeAsync,path,root.Position,goal)
  if not alive or not root.Parent then return end
  if ok and path.Status==Enum.PathStatus.Success then waypoints=path:GetWaypoints() index=math.min(2,#waypoints) else waypoints={} index=1 end
  path:Destroy()
 end
 local waypoint=waypoints[index]
 if waypoint and (root.Position-waypoint.Position).Magnitude<3 then index+=1 waypoint=waypoints[index] end
 if waypoint then if waypoint.Action==Enum.PathWaypointAction.Jump then humanoid.Jump=true end humanoid:MoveTo(waypoint.Position)
 else humanoid:MoveTo(goal) end
end
while alive and npc:IsDescendantOf(workspace) and humanoid.Health>0 do
 local now=os.clock() local goal,target,distance
 if b.motion=="Follow" or b.disposition=="Enemy" then target,distance=nearest() end
 if target and b.disposition=="Enemy" and distance<=b.stopDistance+1 and now-lastAttack>=b.attackInterval and visible(target) then
  lastAttack=now target.humanoid:TakeDamage(b.damage)
 end
 if b.motion~="Stationary" then
  if target and (b.motion=="Follow" or b.disposition=="Enemy") then if distance>b.stopDistance then goal=target.root.Position end
  elseif b.motion=="Walking" and (root.Position-walkTarget).Magnitude>3 then goal=walkTarget
  elseif b.motion=="Patrol" and #b.patrol>=2 then
   goal=Vector3.new(table.unpack(b.patrol[patrolIndex]))
   if (root.Position-goal).Magnitude<3 then patrolIndex=patrolIndex%#b.patrol+1 goal=Vector3.new(table.unpack(b.patrol[patrolIndex])) end
  end
 end
 if goal then animate("walk") steer(goal,now) else humanoid:MoveTo(root.Position) animate("idle") end
 task.wait(.2)
end
removed:Disconnect()
for _,track in pairs(tracks) do track:Stop() track:Destroy() end

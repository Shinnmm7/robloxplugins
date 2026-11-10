local function exercise(motion,disposition,blocked)
 local world=Fixture.New("Workspace") local npc=Fixture.Rig() npc.Parent=world
 local root=npc.HumanoidRootPart root.Position=Fixture.Vector(0,0,0) root.Anchored=motion=="Stationary"
 local h=npc:FindFirstChildOfClass("Humanoid") h.JumpPower=50
 local moves,damage,pathCalls,waits,animated=0,0,0,0,0
 h.MoveTo=function(_,goal) moves+=1 h.goal=goal end
 local animator=Fixture.New("Animator") animator.Parent=h animator.LoadAnimation=function() return {Play=function() animated+=1 end,Stop=function() end,Destroy=function() end} end
 local playerChar=Fixture.Rig() playerChar.Parent=world local target=playerChar.HumanoidRootPart target.Position=Fixture.Vector(if disposition=="Enemy" then 3 else 20,0,0)
 local th=playerChar:FindFirstChildOfClass("Humanoid") th.TakeDamage=function(_,value) damage+=value end
 npc.WaitForChild=function(_,name) assert(name=="NPCCreatorConfig") return {Value="config"} end
 local b={enabled=true,motion=motion,disposition=disposition,range=60,stopDistance=5,damage=10,attackInterval=1,walkDistance=20,patrol={{10,0,0},{20,0,0}},idleAnimation=1,walkAnimation=2}
 local pathService={CreatePath=function()
  return {Status=Fixture.Enum.PathStatus.Success,ComputeAsync=function() pathCalls+=1 end,GetWaypoints=function() return {{Position=Fixture.Vector(0,0,0)},{Position=Fixture.Vector(8,0,0),Action=Fixture.Enum.PathWaypointAction.Jump}} end,Destroy=function() end}
 end}
 world.Raycast=function() if blocked then return {Instance=Fixture.New("Part")} end return nil end
 local env={game={GetService=function(_,name) return ({Players={GetPlayers=function() return {{Character=playerChar}} end},PathfindingService=pathService,HttpService={JSONDecode=function() return {behavior=b} end}})[name] end},script={Parent=npc},workspace=world,
  Instance={new=Fixture.New},Enum=Fixture.Enum,Vector3={new=Fixture.Vector},RaycastParams={new=function() return {} end},task={wait=function() waits+=1 h.Health=0 end}}
 local chunk=assert(loadstring(BEHAVIOR_SOURCE)) setfenv(chunk,setmetatable(env,{__index=getfenv()})) chunk()
 assert(waits==1 and moves==1 and animated>0)
 return damage,pathCalls,h.goal,h.Jump
end
for _,motion in ipairs({"Idle","Stationary","Walking","Patrol","Follow"}) do
 local damage,paths,_,jump=exercise(motion,"Friendly",false) assert(damage==0,"Friendly NPC attacked")
 assert(paths==(if motion=="Idle" or motion=="Stationary" then 0 else 1),motion) if paths>0 then assert(jump) end
end
local damage,paths=exercise("Idle","Enemy",false) assert(damage==10 and paths==0)
damage=exercise("Idle","Enemy",true) assert(damage==0,"Enemy must not damage through a wall")
damage,paths=exercise("Stationary","Enemy",false) assert(damage==10 and paths==0)
print("PASS NPC server behavior: idle, stationary, walking, patrol, follow, path/jump dispatch, animation selection, friendly noncombat, enemy server damage and line-of-sight blocking")

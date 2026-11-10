-- Serializable configuration shared by the editor, rig loader and saved presets.
local M={}
M.Assets={"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","Face","Shirt","Pants","GraphicTShirt","IdleAnimation","WalkAnimation","RunAnimation","JumpAnimation","FallAnimation","ClimbAnimation","SwimAnimation","MoodAnimation"}
M.Flags={"StaticFacialAnimation"}
M.Colors={"HeadColor","TorsoColor","LeftArmColor","RightArmColor","LeftLegColor","RightLegColor"}
M.Scales={"HeightScale","WidthScale","DepthScale","HeadScale","BodyTypeScale","ProportionScale"}
M.Motions={"Idle","Walking","Patrol","Follow","Stationary"}
function M.Clone(v)
 if type(v)~="table" then return v end
 local out={} for k,x in pairs(v) do out[k]=M.Clone(x) end return out
end
function M.New(mode)
 local appearance={properties={StaticFacialAnimation=false},colors={},accessories={}}
 for _,key in ipairs(M.Assets) do appearance.properties[key]=0 end
 for _,key in ipairs(M.Scales) do appearance.properties[key]=if key=="BodyTypeScale" or key=="ProportionScale" then 0 else 1 end
 for _,key in ipairs(M.Colors) do appearance.colors[key]={163,162,165} end
 return {version=1,mode=mode or "Custom",name="New NPC",displayName="NPC",description="",rig="R15",username="",userId=0,
  health=100,speed=16,jump=50,showName=true,appearance=if mode=="Avatar" then nil else appearance,
  behavior={enabled=false,motion="Idle",disposition="Friendly",range=60,stopDistance=5,damage=10,attackInterval=1.5,walkDistance=20,patrol={},idleAnimation=0,walkAnimation=0}}
end
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function number(n,min,max,integer) return finite(n) and n>=min and n<=max and (not integer or n%1==0) end
function M.Validate(c,requireAppearance)
 local errors={}
 local function check(ok,msg) if not ok then table.insert(errors,msg) end end
 if type(c)~="table" then return {"NPC configuration must be a table"} end
 check(c.version==1,"Unsupported NPC preset version")
 check(c.mode=="Custom" or c.mode=="Avatar","Choose Custom or Avatar mode")
 check(type(c.name)=="string" and #c.name>0 and #c.name<=80 and c.name:find("%S")~=nil,"NPC name must contain 1–80 characters")
 check(type(c.displayName)=="string" and #c.displayName<=80,"Display name must be at most 80 characters")
 check(type(c.description)=="string" and #c.description<=2000,"Description must be at most 2000 characters")
 check(c.rig=="R6" or c.rig=="R15","Rig must be R6 or R15")
 check(number(c.health,1,1000000),"Health must be 1–1000000") check(number(c.speed,0,200),"Walk speed must be 0–200") check(number(c.jump,0,300),"Jump power must be 0–300")
 check(type(c.showName)=="boolean","Name visibility must be a boolean")
 check(type(c.username)=="string" and #c.username<=20,"Invalid source username")
 check(number(c.userId,0,9007199254740991,true),"Invalid source UserId")
 if c.mode=="Avatar" then
  check(type(c.username)=="string" and #c.username>=1 and #c.username<=20 and c.username:match("^[%w_]+$")~=nil,"Enter a Roblox username, without @ or a display name")
  check(number(c.userId,0,9007199254740991,true),"Invalid UserId")
 end
 local a=c.appearance
 if a==nil then check(not requireAppearance and c.mode=="Avatar","Load an avatar appearance first")
 elseif type(a)~="table" or type(a.properties)~="table" or type(a.colors)~="table" or type(a.accessories)~="table" then table.insert(errors,"Invalid appearance data")
 else
  for _,key in ipairs(M.Assets) do check(a.properties[key]~=nil,"Missing appearance property: "..key) end
  for _,key in ipairs(M.Scales) do check(a.properties[key]~=nil,"Missing appearance property: "..key) end
  for _,key in ipairs(M.Flags) do check(type(a.properties[key])=="boolean","Missing or invalid appearance flag: "..key) end
  for _,key in ipairs(M.Colors) do check(a.colors[key]~=nil,"Missing color: "..key) end
  for key,value in pairs(a.properties) do
   if table.find(M.Assets,key) then check(number(value,0,9007199254740991,true),key.." must be a nonnegative asset ID")
   elseif table.find(M.Flags,key) then check(type(value)=="boolean",key.." must be a boolean")
   elseif table.find(M.Scales,key) then check(number(value,if key=="BodyTypeScale" or key=="ProportionScale" then 0 else .1,if key=="BodyTypeScale" or key=="ProportionScale" then 1 else 2),key.." is outside its supported range")
   else table.insert(errors,"Unknown appearance property: "..tostring(key)) end
  end
  for key,color in pairs(a.colors) do
   check(table.find(M.Colors,key)~=nil and type(color)=="table" and #color==3 and number(color[1],0,255) and number(color[2],0,255) and number(color[3],0,255),"Invalid RGB color: "..tostring(key))
  end
  check(#a.accessories<=100,"At most 100 accessories per NPC")
  for _,entry in ipairs(a.accessories) do
   check(type(entry)=="table" and number(entry.AssetId,1,9007199254740991,true) and type(entry.AccessoryType)=="string" and #entry.AccessoryType<=40
    and type(entry.IsLayered)=="boolean" and (entry.Order==nil or number(entry.Order,0,1000,true)) and (entry.Puffiness==nil or number(entry.Puffiness,0,1)),"Invalid accessory configuration")
  end
 end
 local b=c.behavior
 if type(b)~="table" then table.insert(errors,"Missing behavior configuration") else
  check(type(b.enabled)=="boolean","Behavior enabled must be a boolean") check(table.find(M.Motions,b.motion)~=nil,"Unknown movement behavior")
  check(b.disposition=="Friendly" or b.disposition=="Enemy","Unknown disposition")
  for _,rule in ipairs({{"range",1,1000},{"stopDistance",1,50},{"damage",0,100000},{"attackInterval",0.25,60},{"walkDistance",1,1000},{"idleAnimation",0,9007199254740991},{"walkAnimation",0,9007199254740991}}) do
   check(number(b[rule[1]],rule[2],rule[3],rule[1]:find("Animation")~=nil),"Invalid behavior "..rule[1])
  end
  check(type(b.patrol)=="table" and #b.patrol<=100,"Patrol must contain at most 100 points")
  if type(b.patrol)=="table" then
   for _,point in ipairs(b.patrol) do check(type(point)=="table" and #point==3 and number(point[1],-1000000,1000000) and number(point[2],-1000000,1000000) and number(point[3],-1000000,1000000),"Invalid patrol point") end
   check(not b.enabled or b.motion~="Patrol" or #b.patrol>=2,"Patrol behavior needs at least two waypoints")
  end
 end
 return errors
end
return M

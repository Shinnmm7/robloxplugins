local function node(id,kind,x,y) return {id=id,type=kind,x=x,y=y,speaker="Rowan",text="",next="",yes="",no="",choices={},condition={type="Always",key="",amount=1,value="true"},action={type="GiveCurrency",key="",amount=1}} end
local a=node("start","Start",30,60) a.next="greeting"
local b=node("greeting","Choice",280,60) b.text="Welcome! Would you like a village token?"
b.choices={{text="Yes, please.",next="gift",condition={type="Always",key="",amount=1,value="true"},visibility="Hide",default=true},{text="Goodbye.",next="end",condition={type="Always",key="",amount=1,value="true"},visibility="Hide",default=false}}
local c=node("gift","Action",530,60) c.action={type="GiveItem",key="village_token",amount=1} c.next="thanks"
local d=node("thanks","Text",780,60) d.text="Here you go. Safe travels!" d.next="end"
local e=node("end","End",1030,60)
return {version=1,projects={{id="rowan_welcome",name="Rowan's welcome",npc="Rowan",start="start",repeatable=false,nodes={a,b,c,d,e}}}}

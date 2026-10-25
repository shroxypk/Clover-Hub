-- Exercise the real request/cleanup functions with an input recorder, no movement.
local G=getgenv()
local source=readfile("CloverRPG/main.lua")
local inputs={}
G.CRLF_DodgeTestInput=function(down,key) table.insert(inputs,{down,key}) end
local count
source,count=source:gsub('local pressKey,releaseKey,windowActive=keypress,keyrelease,iswindowactive',
 'local pressKey=function(key) getgenv().CRLF_DodgeTestInput(true,key) end local releaseKey=function(key) getgenv().CRLF_DodgeTestInput(false,key) end local windowActive=function() return true end')
assert(count==1,"Input adapter not found")
source,count=source:gsub('return "Clover Hub v4 loaded: automation, cursor, resize, unload"',
 'H.testDodge=requestDodge H.testRelease=releaseDodge H.testVirtualKey=virtualKey return "test ready"')
assert(count==1,"Test entry not found")
assert(loadstring(source,"CloverHub_DodgeTest"))()
local h=G.CRLF_HubController
local me=game.Players.LocalPlayer.Character
local realState=h.stateManager
local canDash,blocking=true,false
h.stateManager={Model=me,CanDash=function() return canDash end,IsBlocking=function() return blocking end}
G.CRLF_Minigames.paused=false
local ok,err=xpcall(function()
 local now=os.clock()
 assert(not h.testDodge(now,me),"Default-off dodge sent input")
 h.dodge=true h.parry=false canDash=false
 assert(not h.testDodge(now,me),"Dash cooldown ignored")
 canDash=true blocking=true
 assert(not h.testDodge(now,me),"Dodge while blocking")
 blocking=false
 assert(h.testDodge(now,me),"Eligible request rejected")
 assert(#inputs==1 and inputs[1][1]==true,"Expected one key down")
 assert(inputs[1][2]==h.testVirtualKey(Enum.KeyCode:FromName(game.Players.LocalPlayer.Binds.Roll.Value)),"Wrong roll bind")
 assert(h.testVirtualKey(Enum.KeyCode.Q)==0x51 and h.testVirtualKey(Enum.KeyCode.LeftShift)==0xA0 and h.testVirtualKey(Enum.KeyCode.F12)==0x7B)
 assert(not h.testDodge(now+0.1,me),"Duplicate roll request")
 h.testRelease()
 assert(#inputs==2 and inputs[2][1]==false,"Key not released")
 h.testRelease()
 assert(#inputs==2,"Duplicate key release")
 assert(h.testDodge(now+1,me))
 h.unload()
 assert(#inputs==4 and inputs[4][1]==false,"Unload leaked roll key")
end,tostring)
if h.alive then h.stateManager=realState h.unload() end
G.CRLF_DodgeTestInput=nil
assert(loadstring(readfile("CloverRPG/main.lua"),"CloverHub"))()
assert(ok,err)
return "PASS: dodge opt-in, independent toggle, cooldown/block gates, rebound key, debounce, release and unload"

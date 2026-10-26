-- Deterministic asset-provider replay; no network or combat requests.
local source=readfile("Veyra/src/attack_catalog.lua")
local prefix=[[
local tasks={}
local task={spawn=function(f) table.insert(tasks,f) end,wait=function() end}
local calls={}
local order={}
local destroyed={}
local writes=0
local provider={GetKeyframeSequenceAsync=function(_,asset)
 local id=asset:match("%d+")
 table.insert(order,id)
 calls[id]=(calls[id] or 0)+1
 if id=="3" or (id=="2" and calls[id]==1) then error("transient asset failure") end
 return {Destroy=function() destroyed[id]=(destroyed[id] or 0)+1 end,GetKeyframes=function() return {
  {Time=0.7,Name="HitWindow",GetMarkers=function()
   if id=="6" then error("corrupt marker") end
   return {}
  end},
  {Time=1,Name="End",GetMarkers=function() return {} end},
 } end}
end}
local saved={version=1,placeId=8248288152,records={
 ["1"]={hits={0.2},length=1,source="contact-marker estimate"},
 ["7"]={hits={},length=1,source="unknown",markers={"broken",{name="Slash",time=0.5}}},
 ["8"]={hits={},length=1,source="unknown",markers="invalid"},
}}
local http={JSONDecode=function() return saved end,JSONEncode=function() return "{}" end}
local game={PlaceId=8248288152,GetService=function(_,name)
 return name=="HttpService" and http or provider
end}
local isfile=function() return true end
local readfile=function() return "{}" end
local isfolder=function() return true end
local writefile=function() writes+=1 end
]]
source=prefix..source:gsub("return Catalog%s*$",[[
local c=Catalog.new({placeId=8248288152,records={
 ["1"]={hits={0.8},length=1,source="HitWindow"},
}})
assert(c.records["1"].hits[1]==0.8,"Stale estimate replaced explicit seed")
assert(c.records["7"].hits[1]==0.5,"Valid cached marker was lost")
assert(c.records["8"].source=="unknown","Corrupt marker structure was not handled")
local function animation(id)
 return {AnimationId="rbxassetid://"..id,GetFullName=function() return id end}
end
c:request(animation("2")) c:request(animation("2")) c:request(animation("3"))
c:request(animation("3"),true)
assert(#tasks==1,"Concurrent catalog workers")
tasks[1]()
assert(order[1]=="3","Live attack did not bypass background scan queue")
assert(calls["2"]==2 and c.records["2"].hits[1]==0.7,"Transient failure did not recover")
assert(calls["3"]==3 and not c.records["3"],"Permanent failure was not bounded")
assert(writes==1,"Catalog should save new records once on worker completion")
c:save()
assert(writes==1,"Clean catalog made a redundant disk write")
-- A bad clip must be destroyed on every failed parsing attempt.
c:request(animation("6"))
assert(#tasks==2,"Expected one additional worker")
tasks[2]()
assert(destroyed["6"]==3 and not c.records["6"],"Failed clip leaked or was accepted")
assert(writes==1,"Failed clip triggered a redundant cache write")
c:request(animation("3"))
assert(#tasks==1,"Permanent failure retried without bound")
local root={}
local folder={Name="Combat",Parent=root}
local a=animation("4") a.Parent=folder a.IsDescendantOf=function(_,r) return r==root end
c:classify(a,root) assert(c.attacks["4"],"New attack not classified")
folder={Name="Hit",Parent=root}
a=animation("5") a.Parent=folder a.IsDescendantOf=function(_,r) return r==root end
c:classify(a,root) assert(c.noncombat["5"],"New reaction not classified")
c:stop()
assert(writes==1,"Stop wrote an unchanged catalog")
return "PASS: cache validation, seed precedence, bounded retries, failed-clip cleanup, dirty saves, deduplication, classification"
]])
return assert(loadstring(source,"CatalogReplay"))()

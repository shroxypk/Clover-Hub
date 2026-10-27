-- Read-only quest TRACKING diagnostic for Madium.
-- Track exactly one quest in the game's J menu, close the menu, then run.
local player=game:GetService("Players").LocalPlayer
local HTTP=game:GetService("HttpService")
if not player then warn("[Veyra] No LocalPlayer") return end
local data={version=1,placeId=game.PlaceId,questRecords={},guiRoots={},questGui={},warnings={}}
local function short(value)
 value=tostring(value or "")
 return #value>180 and value:sub(1,180) or value
end
local function simple(value)
 local t=typeof(value)
 if t=="string" then return short(value) end
 if t=="number" or t=="boolean" then return value end
 if t=="Vector3" then return {x=value.X,y=value.Y,z=value.Z} end
 if t=="CFrame" then local p=value.Position return {x=p.X,y=p.Y,z=p.Z} end
 return t
end
local function attrs(o)
 local out={}
 for k,v in pairs(o:GetAttributes()) do
  if #k<90 then out[k]=simple(v) end
 end
 return out
end
local questFolder=player:FindFirstChild("Quests")
if not questFolder then table.insert(data.warnings,"LocalPlayer.Quests unavailable") end
if questFolder then
 for _,q in ipairs(questFolder:GetChildren()) do
  if q:FindFirstChild("Tasks") and q:GetAttribute("Completed")~=true then
   table.insert(data.questRecords,{id=short(q.Name),name=short(q:GetAttribute("Quest")),attributes=attrs(q)})
  end
 end
end
local roots=player:FindFirstChildOfClass("PlayerGui")
if not roots then table.insert(data.warnings,"PlayerGui unavailable") end
local function questRelated(o)
 local at=o
 while at and at~=roots do
  local s=at.Name:lower()
  if s:find("quest",1,true) or s:find("track",1,true) or s:find("journal",1,true)
   or s:find("mission",1,true) then return true end
  at=at.Parent
 end
 return false
end
if roots then
 for _,r in ipairs(roots:GetChildren()) do
  if #data.guiRoots>=80 then break end
  table.insert(data.guiRoots,{name=short(r.Name),class=r.ClassName})
 end
 local count=0
 for _,o in ipairs(roots:GetDescendants()) do
  count+=1
  if questRelated(o) and #data.questGui<550 then
   local entry={path=short(o:GetFullName()),class=o.ClassName,name=short(o.Name)}
   if o:IsA("GuiObject") then
    entry.visible=o.Visible
    entry.layoutOrder=o.LayoutOrder
   end
   if o:IsA("TextLabel") or o:IsA("TextButton") then
    if o.Text~="" then entry.text=short(o.Text) end
   end
   local attributes=attrs(o)
   if next(attributes) then entry.attributes=attributes end
   table.insert(data.questGui,entry)
  end
  if count%1400==0 then task.wait() end
 end
 data.guiObjectsScanned=count
 if #data.questGui>=550 then table.insert(data.warnings,"Quest UI snapshot truncated to 550 entries") end
end
local json=HTTP:JSONEncode(data)
local filename="Veyra_tracking_diagnostic.json"
if type(writefile)=="function" then
 local ok=pcall(writefile,filename,json)
 if ok then print("[Veyra] Saved "..filename..". Upload it to ChatGPT.") return end
end
if type(setclipboard)=="function" then
 local ok=pcall(setclipboard,json)
 if ok then print("[Veyra] Tracking diagnostic copied to clipboard.") return end
end
warn("[Veyra] No file/clipboard support. Copy the lines below:")
for i=1,#json,1600 do print(json:sub(i,i+1599)) end

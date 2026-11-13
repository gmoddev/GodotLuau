-- Only Server calls this module. Transforms are pure because GL-009 may retry.
local Store=game:GetService('DataStoreService'):GetDataStore('FoundryExpeditionV1')
local Progress={Value={Completed=0,Wins=0,Receipts={}},Status='Loading',Busy=false,Dirty=false,Pending={},Attempts=0}
local function Integer(Value,Maximum)
 return type(Value)=='number' and Value==math.floor(Value) and Value>=0 and Value<=Maximum
end
function Progress.Load()
 local OK,Value=pcall(function() return Store:GetAsync('campaign') end)
 if not OK then Progress.Status='Load failed; stored progress preserved';return end
 if Value~=nil then
  if type(Value)~='table' or not Integer(Value.Completed,3) or not Integer(Value.Wins,1000000) or type(Value.Receipts)~='table' then
   Progress.Status='Invalid stored progress; preserved';return
  end
  Progress.Value=Value
 end
 Progress.Status='Ready'
end
function Progress.Complete(Level,Receipt)
 Progress.Value.Completed=math.max(Progress.Value.Completed,Level)
 Progress.PendingLevel=math.max(Progress.PendingLevel or 0,Level)
 assert(#Progress.Pending<3,'Pending receipt budget exceeded')
 table.insert(Progress.Pending,{Level=Level,Receipt=Receipt})
 Progress.Attempts=0
 Progress.Dirty=true
end
function Progress.Save()
 if Progress.Busy or not Progress.Dirty or Progress.Attempts>=3 then return end
 Progress.Busy=true
 Progress.Attempts+=1
 Progress.Status='Committing'
 local Pending=Progress.Pending[1]
 local Level,Receipt=Pending.Level,Pending.Receipt
 local OK,Value=pcall(function()
  return Store:UpdateAsync('campaign',function(Old)
   Old=Old or {Completed=0,Wins=0,Receipts={}}
   assert(type(Old)=='table' and Integer(Old.Completed,3) and Integer(Old.Wins,1000000) and type(Old.Receipts)=='table','Stored progress is invalid; no mutation')
   local Receipts={}
   local Seen=false
   for Index,ID in ipairs(Old.Receipts) do
    assert(Index<=32 and type(ID)=='string' and #ID<=64,'Stored receipts are invalid; no mutation')
    if ID==Receipt then Seen=true end
    table.insert(Receipts,ID)
   end
   if not Seen then table.insert(Receipts,Receipt) end
   while #Receipts>32 do table.remove(Receipts,1) end
   return {Completed=math.max(Old.Completed,Level),Wins=math.min(1000000,Old.Wins+(Seen and 0 or 1)),Receipts=Receipts}
  end)
 end)
 Progress.Busy=false
 if OK then
  Progress.Value=Value
  Progress.Value.Completed=math.max(Progress.Value.Completed,Progress.PendingLevel)
  table.remove(Progress.Pending,1)
  Progress.Dirty=#Progress.Pending>0
  Progress.Attempts=0
  Progress.Status=Progress.Dirty and 'Pending next sector commit' or 'Durably saved'
 else Progress.Status='Save not acknowledged; retry available' end
end
return Progress

local Sum=0
local Ready=true -- GL067:Setup
for Index=1,5 do
 Sum+=Index -- GL067:True
 local FalseProbe=Index -- GL067:False
 local ErrorProbe=Index -- GL067:Error
end
game:SetAttribute('ConditionalDone',Sum)

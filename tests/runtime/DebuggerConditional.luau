local Sum=0
local Ready=true -- GL067:Setup
for Index=1,5 do
 Sum+=Index -- GL067:True
 game:SetAttribute('ConditionalFalseProbe',Index) -- GL067:False
 game:SetAttribute('ConditionalErrorProbe',Index) -- GL067:Error
end
game:SetAttribute('ConditionalDone',Sum)

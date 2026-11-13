-- All presentation handles belong to this Client scope, never the Server world.
local Interface={}
function Interface.Build(Parent,Send)
 local S=Scene.new(Parent)
 S.Name='ExpeditionInterface'
 local Layer=S:New('CanvasLayer',{Name='HUD',Layer=10})
 local Pixels=S:New('Image',{})
 S:Call(Pixels,'SetData',2,2,false,Scene.Enums.Image.Format.FORMAT_RGBA8,{20,230,200,255,20,70,90,255,20,70,90,255,20,230,200,255})
 local Icon=S:New('ImageTexture',{})
 S:Call(Icon,'SetImage',Pixels)
 S:New('TextureRect',{Name='Icon',Texture=Icon,Position={X=850,Y=20},MinSize={X=32,Y=32},ExpandMode=1},Layer)
 local Stats=S:New('VBoxContainer',{Name='Stats',Position={X=24,Y=18},MinSize={X=650,Y=100},Separation=4},Layer)
 S:New('Label',{Text='FOUNDRY EXPEDITION',FontSize=26},Stats)
 local Health=S:New('Label',{Name='Health',Text='Connecting to local rules…',FontSize=20},Stats)
 local Objective=S:New('Label',{Name='Objective',Text=''},Stats)
 local Persistence=S:New('Label',{Name='Persistence',Text=''},Stats)
 local Panel=S:New('PanelContainer',{Name='Menu',Position={X=310,Y=170},MinSize={X=480,Y=430}},Layer)
 local Box=S:New('VBoxContainer',{Name='Content',Separation=12,MinSize={X=450,Y=420}},Panel)
 local Title=S:New('Label',{Name='Title',Text='Restore the three sectors',FontSize=26},Box)
 S:New('Label',{Text='WASD / left stick: move • Space / A: jump\nShift / LB: dash • F / RB: pulse\nE / X: extract • Escape / Start: pause',FontSize=16},Box)
 local Start=S:New('Button',{Name='Start',Text='Start expedition',MinSize={X=420,Y=42}},Box)
 S:New('Label',{Text='Field of view'},Box)
 local Fov=S:New('HSlider',{Name='Fov',MinValue=55,MaxValue=90,Value=65,Step=1,MinSize={X=420,Y=26}},Box)
 S:New('Label',{Text='Sound volume'},Box)
 local Volume=S:New('HSlider',{Name='Volume',MinValue=-60,MaxValue=0,Value=-18,Step=1,MinSize={X=420,Y=26}},Box)
 local Save=S:New('Button',{Name='Save',Text='Retry progress save',MinSize={X=420,Y=32}},Box)
 local Pause=S:New('Button',{Name='Pause',Text='Pause / settings',Position={X=900,Y=20},MinSize={X=170,Y=36}},Layer)
 local Current='Loading'
 S:Connect(Start,'Pressed',function() Send(Current=='Paused' and 'Pause' or 'Start') end)
 S:Connect(Pause,'Pressed',function() Send('Pause') end)
 S:Connect(Save,'Pressed',function() Send('Save') end)
 S:Connect(Fov,'ValueChanged',function(Value) game:SetAttribute('FoundryFov',Value) end)
 S:Connect(Volume,'ValueChanged',function(Value) game:SetAttribute('FoundryVolume',Value) end)
 local Result={Scope=S,Panel=Panel}
 function Result.Update(State)
  Current=State.Phase
  Panel.Visible=Current~='Active'
  Pause.Visible=Current=='Active' or Current=='Paused'
  Start.Disabled=Current=='Loading'
  Start.Text=Current=='Paused' and 'Resume expedition' or 'Start expedition'
  Title.Text=Current=='Dead' and 'Expedition lost' or Current=='Complete' and 'Foundry restored' or Current=='Paused' and 'Paused / settings' or 'Restore the three sectors'
  Health.Text=string.format('%s • Health %d • Energy %d • Cells %d / 3 • Guards %d',State.Room,State.Health,State.Energy,State.Cells,State.Remaining)
  Objective.Text=State.Message
  Persistence.Text=string.format('%s • Highest sector %d • Saved sector clears %d',State.Persistence,State.Completed,State.Wins)
 end
 return Result
end
return Interface

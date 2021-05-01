-- nmRain
-- 1.0.0 @NightMachines
-- llllllll.co/t/nmrain/
--
-- a weird stereo delay
-- for external audio or
-- tape signals
--
-- E1: choose cloud
-- K2: make it rain
-- K3: make it windy
-- E2: dry/wet
-- E3: cloud altitude


-- _norns.screen_export_png("/home/we/dust/<FILENAME>.png")
-- norns.script.load("code/nmRain/nmRain.lua")


--adjust encoder settigns to your liking
--norns.enc.sens(0,2)
--norns.enc.accel(0,false)

local devices = {}

local voice = 1 -- selected voice/cloud 1-6
local vState = {0,0,0,0,0,0} -- 0=idle, 1=recording, 2=playing
local vStartPos = {0,4,8,12,16,20}
local vPos = {0.0,0.0,0.0,0.0,0.0,0.0}
local vLenInUse = {1.0,1.0,1.0,1.0,1.0,1.0}
local vRates = {1,1,1,1,1,1}
local overload = 0

function init()
  for id,device in pairs(midi.vports) do
    devices[id] = device.name
  end
  
  params:add_group("nmRain",13)
  params:add{type = "option", id = "midi_input", name = "Midi Input", options = devices, default = 1, action=set_midi_input}
  
  params:add_separator()
  params:add{type = "number", id = "selVoice", name = "Choose Cloud", min = 1, max = 6, default = 1, wrap = false}
  params:add{type = "number", id = "rain", name = "Make It Rain", min=0, max=1, default = 0, wrap = false, action=function(x) if x==1 then makeItRain() end end}
  params:add{type = "number", id = "rndLen", name = "Make It Windy", min = 0, max = 1, default = 0, wrap = false}
  params:add{type = "number", id = "dryWet", name = "Dry/Wet", min=0, max=10, default = 5, wrap = false, action=function(x) audio.level_monitor(((x/10)-1)*-1) end}
  params:add_separator()
  params:add_control("vLen1","Cloud 1 Altitude", controlspec.new(0.1,4,"lin",0.1,1.0,"",0.026,false))
  params:add_control("vLen2","Cloud 2 Altitude", controlspec.new(0.1,4,"lin",0.1,1.0,"",0.026,false))
  params:add_control("vLen3","Cloud 3 Altitude", controlspec.new(0.1,4,"lin",0.1,1.0,"",0.026,false))
  params:add_control("vLen4","Cloud 4 Altitude", controlspec.new(0.1,4,"lin",0.1,1.0,"",0.026,false))
  params:add_control("vLen5","Cloud 5 Altitude", controlspec.new(0.1,4,"lin",0.1,1.0,"",0.026,false))
  params:add_control("vLen6","Cloud 6 Altitude", controlspec.new(0.1,4,"lin",0.1,1.0,"",0.026,false))
  
  softcut.buffer_clear()
  softcut.buffer_clear_region_channel(1,0,25)
  audio.level_adc_cut(1)

  audio.level_monitor(0.5)
  
  softcut.pan(1,-1)
  softcut.pan(2,-0.6)
  softcut.pan(3,-0.2)
  softcut.pan(4,0.2)
  softcut.pan(5,0.6)
  softcut.pan(6,1)
  
  for i=1,6 do
    softcut.enable(i,1)
    softcut.buffer(i,1)
    softcut.level(i,((params:get("dryWet")/10)-1)*-1)
    softcut.rate(i,vRates[i])
    softcut.loop(i,0)
    softcut.loop_start(i,vStartPos[i])
    softcut.loop_end(i,vStartPos[i]+4)
    softcut.fade_time(i,0.0)
    softcut.recpre_slew_time(i,0)
    softcut.pre_level(i,0.5)
    softcut.rec_level(i,1.0)
    softcut.position(i,vStartPos[i])
    vPos[i] = vStartPos[i]
    softcut.phase_quant(i,0.01)
    
    softcut.level_input_cut(1,i,1.0)
    softcut.level_input_cut(2,i,1.0)
  end
  
  redraw()
  
  softcut.event_phase(updatePos)
  softcut.poll_start_phase()
  
end



function updatePos(v,p) -- v = voice, p = position
  vPos[v]=round(p*100)/100
  
  if vState[v]==2 then -- if playing
    softcut.rate(v,1*(1+((vPos[v]-vStartPos[v])/vLenInUse[v])*-0.5) ) -- decrease rate/pitch as playback progresses
    
    if (vPos[v]-vStartPos[v])/vLenInUse[v] <= 0.5 then
      softcut.level(v,(params:get("dryWet")/10) * (((vPos[v]-vStartPos[v])/vLenInUse[v])*2))--() -- fade in
    else
      softcut.level(v,(params:get("dryWet")/10) * (1-((((vPos[v]-vStartPos[v])/vLenInUse[v])-0.5)*2)))-- fade out
    end

  end
  

  if vPos[v]>=vLenInUse[v]+vStartPos[v] then -- when play- or recordhead reaches the end
    if vState[v]==1 then -- if recording: stop rec and play back recording
      vPlay(v)
    elseif vState[v]==2 then -- it playing: stop
      vStop(v)
        if overload==1 then
          params:set("rain",0)
          params:set("rain",1)
        end
    end
  end
end



function vRec(v) -- record function, v = voice/cloud
  vLenInUse[v] = params:get("vLen"..v)
  softcut.play(v,0)
  vState[v]=1
  softcut.pre_level(v,0.5)
  softcut.rate(v,1.0)
  softcut.position(v,vStartPos[v])
  softcut.rec(v,1)
end



function vPlay(v) -- playback function, v = voice/cloud
  vState[v]=2
  softcut.play(v,0)
  softcut.rec(v,0)
  softcut.rate(v,1.0)
  softcut.pre_level(v,0.5)
  softcut.position(v,vStartPos[v])
  softcut.play(v,1)
  if params:get("rain")==1 then
    makeItRain()
  end
end



function vStop(v) -- stop function, v = voice/cloud
  vState[v]=0
  softcut.rate(v,1.0)
  softcut.play(v,0)
  softcut.position(v,vStartPos[v])
end



function dryWet(x) -- adjust input monitor level on param change
  audio.level_monitor(x/10)
end



function makeItRain() -- the engine
  
  while true do
    local freeStates = {}  
    local counter = 0
    
    for c=1,6 do -- check which voices/clouds are idle and put them into an array
      if vState[c]==0 then
        counter = counter+1
        freeStates[counter] = c
      end
    end
    
    if #freeStates>0 then -- if there are idle voices/clouds, pick one randomly to record and play next
      overload=0
      local i = math.random(1,#freeStates)
      
      if vState[freeStates[i]]==0 then
        voice=freeStates[i]

        if params:get("rndLen")==1 then -- if randomizer/wind is on, randomly change playback rate and sample length/cloud altitude
          params:delta("vLen"..voice, (math.random(0,2)-1))
          vRates[voice] = math.random(5,10)/10
          softcut.rate(voice, vRates[voice])
        else
          softcut.rate(voice,1.0)
        end
        vRec(voice)
        break
      end
    else
      overload=1
      break
    end
  end  
end


-- BUTTONS
function key(id,st)
  if id==1 and st==1 then
  elseif id==2 and st==1 then
    params:set("rain",(params:get("rain")-1)*-1)
  elseif id==3 and st==1 then
    params:set("rndLen",(params:get("rndLen")-1)*-1)
  end
end


-- ENCODERS
function enc(id,delta)
  if id==1 then
    params:delta("selVoice",delta)
  elseif id==2 then
    params:delta("dryWet", delta)
  elseif id==3 then
    params:delta("vLen"..params:get("selVoice"), delta)
  end
end



function redraw()
  screen.clear()
  screen.line_width(1)

  -- draw black background
  screen.level(0)
  screen.move(0,0)
  screen.rect(0,0,128,64)
  screen.fill()
  
  -- draw the bottom lines
  screen.level(4)
  screen.move(0,52)
  screen.line(128,52)
  screen.stroke()
  screen.level(2)
  screen.move(0,55)
  screen.line(128,55)
  screen.stroke()
  screen.level(1)
  screen.move(0,58)
  screen.line(128,58)
  screen.stroke()
  screen.level(1)
  screen.move(0,61)
  screen.line(128,61)
  screen.stroke()
  
  -- draw clouds
  for i=1,6 do
    if params:get("selVoice")==i then -- draw selected cloud brighter
      screen.level(15)
    else
      screen.level(4)
    end
    drawCloud(i,params:get("vLen"..i))

    if vState[i]==1 then -- if recording then draw raindrop
      screen.level(15)
      drawRain(i,vPos[i]-vStartPos[i],vLenInUse[i])
      
    elseif vState[i]==2 then --if playing, draw ripple on ground
      drawRipple(i,vPos[i]-vStartPos[i],vLenInUse[i])
    end
    
  end
  
  screen.update()
end



function getX(n) -- returns x coordinate for clouds/raindrops/ripples, for for conveniece while testing the UI drawing
  return 12+(n-1)*21
end



function drawCloud(n,v) -- draw a nice cloud, n = voice, v = vertical position
  local x = getX(n)
  local y = round(-v*8)+36
  screen.circle(x-5,y+2,4)
  screen.fill()
  screen.circle(x,y,5)
  screen.fill()
  screen.circle(x,y+3,5)
  screen.fill()
  screen.circle(x+5,y+2,3)
  screen.fill()
  
  screen.level(0)
  screen.move(x-9,y+2)
  screen.line_rel(18,0)
  screen.stroke()
  
  screen.level(0)
  screen.move(x-9,y+4)
  screen.line_rel(18,0)
  screen.stroke()
  
  screen.level(0)
  screen.move(x-9,y+6)
  screen.line_rel(18,0)
  screen.stroke()
end



function drawRain(n,v,offset) -- draw a raindrop, n = voice, v = vertical position, offset = cloud altitude
  local o = round(-offset*8)+45
  local y = o + ((50-o)*(v/offset))
  local x = getX(n)-((y/10)*params:get("rndLen"))
  
  screen.circle(x,y-2,1)
  screen.fill()
  screen.circle(x,y,2)
  screen.fill()
  if y>48 then
    drawSplash(n,y)
  end
end



function drawSplash(n,m) -- draw a tiny splash, n = voice, v = vertical position
  local y = 52
  local s = 4
  local x = getX(n)-((y/10)*params:get("rndLen"))
  
  screen.level(4)
  screen.move(x,y)
  screen.line_rel(-s,-s)
  screen.move(x,y)
  screen.line_rel(s,-s)
  screen.stroke()
end



function drawRipple(n,p,len) -- draw a ripple, n = voice, p = playhead position, len = sample length
  local y = 52
  local x = getX(n)-((y/10)*params:get("rndLen"))

  
  screen.level(15-round(11*(p/len)))
  
  screen.move(x-2-(5*(p/len)),y)
  screen.line(x+2+(5*(p/len)),y)
  screen.stroke()

  screen.move(x-1-(3*(p/len)),y+3*(p/len))
  screen.line(x+1+(3*(p/len)),y+3*(p/len))
  screen.stroke()

  screen.move(x-(2*(p/len)),y+6*(p/len))
  screen.line(x+(2*(p/len)),y+6*(p/len))
  screen.stroke()
end



re = metro.init() -- screen refresh
re.time = 1.0 / 15
re.event = function()
  redraw()
end
re:start()


-- MIDI Stuff
function set_midi_input(x)
  update_midi()
end

function update_midi()
  if midi_input and midi_input.event then
    midi_input.event = nil
  end
  midi_input = midi.connect(params:get("midi_input"))
  midi_input.event = midi_input_event
end

function midi_input_event(data)
  msg = midi.to_msg(data)
  -- do something if you want
end

-- custom round function (not neccessary)
function round(n)
  return n % 1 >= 0.5 and math.ceil(n) or math.floor(n)
end
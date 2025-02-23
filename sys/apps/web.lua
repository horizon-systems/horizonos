local arg={...}--command line arguments

term.setBackgroundColor(colours.white)
term.setTextColor(colours.black)
term.clear()
term.setCursorPos(1,1)
term.setCursorBlink(false)
version="MyBrowser 1"
siteName=""
currentSite=""
siteID=-1
pageName=""
currentX=1
currentY=1
menuMode=false
ddns=true
ddnsID=-1
webType=0--0=no site, 1=normal site, 2=menu
-------------------------
--web related functions--
-------------------------

function whois(name)--returns ID if found, -1 if not on dns, and nil if no dns
	--prevent unnecessary communication
	if name~=currentSite then
		if ddns==true then rednet.send(ddnsID,"@whois "..name)
		else rednet.broadcast("@whois "..name) end
		_,webID=rednet.receive(1)
		siteID=tonumber(webID)--convert it to a number
		currentSite=name
	end
	return siteID
end
function getColour(value)
	--TODO prevent crashing on invalid number
	number=tonumber(value)
	if number==nil then--convert hexadecimal
		if value=="A" then
			number=10
		elseif value=="B" then
			number=11
		elseif value=="C" then
			number=12
		elseif value=="D" then
			number=13
		elseif value=="E" then
			number=14
		elseif value=="F" then
			number=15
		else
			return colours.black
		end
	end
	return bit.blshift(1,number)
end
function loadPage(webID,page)
	rednet.send(webID,page or "/home")
	pagetext=""
	for i=1,17 do
		from,text=rednet.receive(0.5)
		if text==nil then break end
		pagetext=pagetext..text.."\n"
	end
	
	--term.write(pagetext)--doesn't support newline apparently
	--print(pagetext)
	line=1
	term.setCursorPos(2,line)
	colourmode=0--1=^ detected 2=nextchar text 3=nextchar backround
	term.setBackgroundColor(colours.white)
	term.setTextColor(colours.black)
	--my slow and tedious method of rendering the page
	for current=1,string.len(pagetext) do
		letter=string.sub(pagetext,current,current)--TODO surely an easier way?
		if letter==nil then letter=" " end
		if colourmode==0 then --normal
			if letter=="^" then 
				colourmode=1
			elseif letter=="\n" then
				line=line+1--next line
				if line==17 then break end--too much! TODO tweak this value
				term.setCursorPos(2,line)
				term.setBackgroundColor(colours.white)
				term.setTextColor(colours.black)--reset colours for next line
			else
				term.write(letter)--nothing special
			end
		elseif colourmode==1 then --might be a colour
			if letter=="f" then--foreground colour
				colourmode=2--next char will set foreground
			elseif letter=="b" then--background colour
				colourmode=3--next char will set background
			else--not correct, probably not intended as a colour
				term.write("^"..letter)--put ^ back as well
			end
		elseif colourmode==2 then--set text colour
			--print(letter)--debug
			term.setTextColor(getColour(letter))
			colourmode=0--back to normal
		elseif colourmode==3 then--set background colour
			term.setBackgroundColor(getColour(letter))
			colourmode=0--back to normal
		end
	end
end

-----------------
--GUI functions--
-----------------
function drawError(text)
	term.setBackgroundColor(colours.white)
	term.setTextColor(colours.red)
	term.setCursorPos(2,1)
	term.write("ERROR:")
	term.setCursorPos(2,2)
	term.write(text)
	webType=0
end
function drawButton(x,y,text,conditionA,conditionB,active)
	term.setCursorPos(x,y)
	if conditionA==conditionB and active then
		term.setBackgroundColor(colours.grey)
		term.write("[")
	else
		term.setBackgroundColor(colours.lightGrey)
		term.write(" ")
	end
	
	term.write(text)
	
	if conditionA==conditionB and active then
		term.write("]")
	else
		--term.write(" ")
	end
end

function renderGUI()
	--draw left bar
	term.setTextColor(colours.white)
	term.setBackgroundColor(colours.lightGrey)
	for line=1,17 do
		term.setCursorPos(1,line)
		term.write(" ")
	end
	--draw right cursor
	if menuMode==false then
		term.setCursorPos(1,currentY)
		term.setBackgroundColor(colours.grey)
		term.write(">")
	end
	--draw bottom bar
	term.setBackgroundColor(colours.lightGrey)
	term.setCursorPos(1,18)
	for line=1,51 do
		term.write(" ")
	end
	--term.setCursorPos(1,19)
	--term.write(siteName..pageName)
	--draw menu bar items
	drawButton(42,18,"refresh",currentX,3,menuMode)
	drawButton(36,18,"menu",currentX,2,menuMode)
	drawButton(1,18,siteName..pageName,currentX,1,menuMode)
end

function popup(text)--a nice GUI popup asking for text
	term.setTextColor(colours.white)
	term.setCursorPos(7,5)
	term.setBackgroundColor(colours.blue)
	for y=5,13 do
		term.setCursorPos(7,y)
		for x=7,47 do
			if y==8 then--user input row
				if x==7 or x== 47 then
					term.setBackgroundColor(colours.lightGrey)
				else
					term.setBackgroundColor(colours.grey)
				end
			end
			term.write(" ")
		end
		term.setBackgroundColor(colours.lightGrey)
	end
	--finished drawing window. add text
	term.setBackgroundColor(colours.blue)
	term.setCursorPos(7,5)--TODO: center text
	term.write(text)
	term.setBackgroundColor(colours.grey)
	term.setCursorPos(8,8)
	return io.read()
end

function refresh()
	webType=1--website
	term.setTextColor(colours.black)
	term.setBackgroundColor(colours.white)
	
	term.clear()
	term.setCursorPos(1,1)
	
	renderGUI()
	
	webID=whois(siteName)
	if webID==nil or webID==-1 then--find what went wrong
		    if webID==nil and ddns==false then drawError("server not found (spelt wrong?)")
		elseif webID==nil and ddns==true then drawError("no response from ddns")
		elseif webID==-1 and ddns==true then drawError("site not found on ddns (spelt wrong?)")
		else drawError("I honestly have no idea what happened") end
		
	else loadPage(webID,pageName) end
	
	renderGUI()
end
-------------------
--other functions--
-------------------
function getDeviceSide(deviceType)
  -- List of all sides
  local lstSides = {"left","right","top","bottom","front","back"};
  -- Now loop through all the sides
  for i, side in pairs(lstSides) do
    if (peripheral.isPresent(side)) then
      -- Yup, there is something on this side
      if (peripheral.getType(side) == string.lower(deviceType)) then
        -- Yes, this is the device type we need, so return the side
        return side;
      end
    end
  end
  --nothing found, return nill
  return nil;
end
function split(text,splitAt)
	state=false
	outA=""
	outB=""
	for i=1,string.len(text) do 
		if string.sub(text,i,i)==splitAt then
			state=true
		end
		if state==false then
			outA=outA..string.sub(text,i,i)
		else
			outB=outB..string.sub(text,i,i)
		end
	end
	return outA,outB
end
--like split, but removes extra char
function split2(text,splitAt)
	outA,outB=split(text,splitAt)
	outB=string.sub(outB,2,-1)--remove first char (= to splitAt)
	return outA,outB
end

function interpret(text)
	command,args=split2(text,":")
	if command=="glob" then
		siteName,pageName=split2(args,"/")
		pageName="/"..pageName
		refresh()
	end
	if command=="loc" then
		pageName="/"..args
		refresh()
	end
	if command=="ref" then
		refresh()
	end
	if command=="ask" then
		arg1,arg2=split2(args,":")--expected format: ask:cookie:question
		rednet.send(siteID,"ans:"..arg1..":"..popup(arg2))
		print("please wait...")--TODO place this nicely in the text entry field
		--note: server should send refresh as soon as it is done
	end
	--TODO add input command
end
function enterPage()
	siteName,pageName=split(popup("web address"),"/")
	if pageName==nil or pageName=="" then
		pageName="/home"
	end
	refresh()
end
function renderMenu()
	term.setTextColor(colours.black)
	term.setBackgroundColor(colours.white)

	term.clear()
	term.setCursorPos(1,1)
	--add one space before every line due to side bar
	print(" "..version)
	print(" by Horizon Systems")
	print("")
	if ddnsID~=nil then print(" ID of dedicated DNS: "..ddnsID) end
	if siteID~=nil then print(" ID of current website: "..siteID) end
	print(" using modem on side: "..portSide)
	renderGUI()
end
function handleSelect()
	if menuMode==true then
		--edit web adress
		if currentX==1 then
			enterPage()
		end
		if currentX==2 then
			renderMenu()
		end
		--refresh
		if currentX==3 then
			refresh()
		end
	else--clicked on site
		if webType==1 then 
			rednet.send(siteID,"exec:"..pageName..":"..currentY)
		end
		--TODO add interactive menu
	end
end
-----------------------
--program begins here--
-----------------------
portSide=getDeviceSide("modem")
if portSide==nil then
	print("no modems found!")
end
rednet.open(portSide)
rednet.broadcast("@ddns")--search for dedicated dns
ddnsID,result=rednet.receive(1)
if result==nil then
ddns=false 
print(" warning: no ddns found")
end
renderGUI()
enterPage()
renderGUI()
while true do
	event, p1, p2, p3 = os.pullEventRaw()
	if event=="key" or event=="char" then
		--up
		if p1==200 then
			if currentY~=1 then currentY=currentY-1 end
			menuMode=false
		end
		--down
		if p1==208  then
			if currentY~=18 then currentY=currentY+1 end
			menuMode=false
		end
		
		--left
		if p1==203 then
			if currentX~=1 then currentX=currentX-1 end
			menuMode=true
		end
		--right
		if p1==205 then
			if currentX~=3 then currentX=currentX+1 end
			menuMode=true
		end
		--enter or space (select)
		if p1==28 or p1==" "  then --removed 57
			handleSelect()
		end
		renderGUI()
	elseif event=="mouse_click" then
		if p3==18 then
			menuMode=true
			currentX=1--default if below is false
			if p2>36 then currentX=2 end
			if p2>42 then currentX=3 end
		else
			menuMode=false
			currentY=p3
		end
		handleSelect()
		renderGUI()
	--only receive messages from current website
	elseif event=="rednet_message" and p1==siteID then
		interpret(p2)
	elseif event=="terminate" then
		term.setBackgroundColor(colours.black)
		term.setTextColor(colours.white)
		term.clear()
		term.setCursorPos(1,1)
	break
	end
	--TODO make an options menu
	--TODO add error handling
end
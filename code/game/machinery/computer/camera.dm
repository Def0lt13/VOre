//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:31

/obj/machinery/computer/security
	name = "security camera monitor"
	desc = "Used to access the various cameras on the station."
	icon_keyboard = "security_key"
	icon_screen = "cameras"
	light_color = "#a91515"
	var/current_network = null
	var/obj/machinery/camera/current_camera = null
	var/last_pic = 1.0
	var/list/network
	var/mapping = 0//For the overview file, interesting bit of code.
	var/cache_id = 0
	circuit = /obj/item/weapon/circuitboard/security

/obj/machinery/computer/security/New()
	if(!network)
		network = using_map.station_networks.Copy()
	..()
	if(network.len)
		current_network = network[1]

/obj/machinery/computer/security/attack_ai(var/mob/user as mob)
	return attack_hand(user)

/obj/machinery/computer/security/check_eye(var/mob/user as mob)
	if (user.stat || ((get_dist(user, src) > 1 || !( user.canmove ) || user.blinded) && !istype(user, /mob/living/silicon))) //user can't see - not sure why canmove is here.
		return -1
	if(!current_camera)
		return 0
	var/viewflag = current_camera.check_eye(user)
	if ( viewflag < 0 ) //camera doesn't work
		reset_current()
	return viewflag

/obj/machinery/computer/security/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = 1)
	if(stat & (NOPOWER|BROKEN)) return
	if(user.stat) return

	var/data[0]

	data["current_camera"] = current_camera ? current_camera.nano_structure() : null
	data["current_network"] = current_network
	data["networks"] = network ? network : list()
	if(current_network)
		data["cameras"] = camera_repository.cameras_in_network(current_network)
	if(current_camera)
		switch_to_camera(user, current_camera)
	data["map_levels"] = using_map.get_map_levels(src.z)

	ui = SSnanoui.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "sec_camera.tmpl", "Camera Console", 900, 800)

		// adding a template with the key "mapContent" enables the map ui functionality
		ui.add_template("mapContent", "sec_camera_map_content.tmpl")
		// adding a template with the key "mapHeader" replaces the map header content
		ui.add_template("mapHeader", "sec_camera_map_header.tmpl")

		ui.set_initial_data(data)
		ui.open()

/obj/machinery/computer/security/Topic(href, href_list)
	if(..())
		return 1
	if(href_list["switch_camera"])
		if(stat&(NOPOWER|BROKEN)) return //VOREStation Edit - Removed zlevel check
		if(usr.stat || ((get_dist(usr, src) > 1 || !( usr.canmove ) || usr.blinded) && !istype(usr, /mob/living/silicon))) return
		var/obj/machinery/camera/C = locate(href_list["switch_camera"]) in cameranet.cameras
		if(!C)
			return
		if(!(current_network in C.network))
			return

		switch_to_camera(usr, C)
		return 1
	else if(href_list["switch_network"])
		if(stat&(NOPOWER|BROKEN)) return //VOREStation Edit - Removed zlevel check
		if(usr.stat || ((get_dist(usr, src) > 1 || !( usr.canmove ) || usr.blinded) && !istype(usr, /mob/living/silicon))) return
		if(href_list["switch_network"] in network)
			current_network = href_list["switch_network"]
		return 1
	else if(href_list["reset"])
		if(stat&(NOPOWER|BROKEN)) return //VOREStation Edit - Removed zlevel check
		if(usr.stat || ((get_dist(usr, src) > 1 || !( usr.canmove ) || usr.blinded) && !istype(usr, /mob/living/silicon))) return
		reset_current()
		usr.reset_view(current_camera)
		return 1
	else
		. = ..()

/obj/machinery/computer/security/attack_hand(var/mob/user as mob)
	if (using_map && !(src.z in using_map.contact_levels))
		user << "<span class='danger'>Unable to establish a connection:</span> You're too far away from the station!"
		return
	if(stat & (NOPOWER|BROKEN))	return

	if(!isAI(user))
		user.set_machine(src)
	ui_interact(user)

/obj/machinery/computer/security/proc/switch_to_camera(var/mob/user, var/obj/machinery/camera/C)
	//don't need to check if the camera works for AI because the AI jumps to the camera location and doesn't actually look through cameras.
	if(isAI(user))
		var/mob/living/silicon/ai/A = user
		// Only allow non-carded AIs to view because the interaction with the eye gets all wonky otherwise.
		if(!A.is_in_chassis())
			return 0

		A.eyeobj.setLoc(get_turf(C))
		A.client.eye = A.eyeobj
		return 1

	if (!C.can_use() || user.stat || (get_dist(user, src) > 1 || user.machine != src || user.blinded || !( user.canmove ) && !istype(user, /mob/living/silicon)))
		return 0
	set_current(C)
	user.reset_view(current_camera)
	check_eye(user)
	return 1

//Camera control: moving.
/obj/machinery/computer/security/proc/jump_on_click(var/mob/user,var/A)
	if(user.machine != src)
		return
	var/obj/machinery/camera/jump_to
	if(istype(A,/obj/machinery/camera))
		jump_to = A
	else if(ismob(A))
		if(ishuman(A))
			jump_to = locate() in A:head
		else if(isrobot(A))
			jump_to = A:camera
	else if(isobj(A))
		jump_to = locate() in A
	else if(isturf(A))
		var/best_dist = INFINITY
		for(var/obj/machinery/camera/camera in get_area(A))
			if(!camera.can_use())
				continue
			if(!can_access_camera(camera))
				continue
			var/dist = get_dist(camera,A)
			if(dist < best_dist)
				best_dist = dist
				jump_to = camera
	if(isnull(jump_to))
		return
	if(can_access_camera(jump_to))
		switch_to_camera(user,jump_to)

/obj/machinery/computer/security/process()
	if(cache_id != camera_repository.camera_cache_id)
		cache_id = camera_repository.camera_cache_id
		SSnanoui.update_uis(src)

/obj/machinery/computer/security/proc/can_access_camera(var/obj/machinery/camera/C)
	var/list/shared_networks = src.network & C.network
	if(shared_networks.len)
		return 1
	return 0

/obj/machinery/computer/security/proc/set_current(var/obj/machinery/camera/C)
	if(current_camera == C)
		return

	if(current_camera)
		reset_current()

	src.current_camera = C
	if(current_camera)
		current_camera.camera_computers_using_this.Add(src)
		use_power = 2
		var/mob/living/L = current_camera.loc
		if(istype(L))
			L.tracking_initiated()

/obj/machinery/computer/security/proc/reset_current()
	if(current_camera)
		current_camera.camera_computers_using_this.Remove(src)
		var/mob/living/L = current_camera.loc
		if(istype(L))
			L.tracking_cancelled()
	current_camera = null
	use_power = 1

//Camera control: mouse.
/atom/DblClick()
	..()
	if(istype(usr.machine,/obj/machinery/computer/security))
		var/obj/machinery/computer/security/console = usr.machine
		console.jump_on_click(usr,src)
//Camera control: arrow keys.
/mob/Move(n,direct)
	if(istype(machine,/obj/machinery/computer/security))
		var/obj/machinery/computer/security/console = machine
		var/turf/T = get_turf(console.current_camera)
		for(var/i;i<10;i++)
			T = get_step(T,direct)
		console.jump_on_click(src,T)
		return
	return ..(n,direct)

/obj/machinery/computer/security/telescreen
	name = "Telescreen"
	desc = "Used for watching an empty arena."
	icon_state = "wallframe"
	plane = TURF_PLANE
	layer = ABOVE_TURF_LAYER
	icon_keyboard = null
	icon_screen = null
	light_range_on = 0
	network = list(NETWORK_THUNDER)
	density = 0
	circuit = null

/obj/machinery/computer/security/telescreen/entertainment
	name = "entertainment monitor"
	desc = "Damn, why do they never have anything interesting on these things?"
	icon = 'icons/obj/status_display.dmi'
	icon_screen = "entertainment"
	light_color = "#FFEEDB"
	light_range_on = 2
	network = list(NETWORK_THUNDER)
	circuit = /obj/item/weapon/circuitboard/security/telescreen/entertainment
	var/obj/item/device/radio/radio = null

/obj/machinery/computer/security/telescreen/entertainment/Initialize()
	. = ..()
	radio = new(src)
	radio.listening = TRUE
	radio.broadcasting = FALSE
	radio.set_frequency(ENT_FREQ)
	radio.canhear_range = 7 // Same as default sight range.
	power_change()

/obj/machinery/computer/security/telescreen/entertainment/power_change()
	..()
	if(radio)
		if(stat & NOPOWER)
			radio.on = FALSE
		else
			radio.on = TRUE

/obj/machinery/computer/security/wooden_tv
	name = "security camera monitor"
	desc = "An old TV hooked into the stations camera network."
	icon_state = "television"
	icon_keyboard = null
	icon_screen = "detective_tv"
	circuit = null
	light_color = "#3848B3"
	light_power_on = 0.5

/obj/machinery/computer/security/mining
	name = "outpost camera monitor"
	desc = "Used to access the various cameras on the outpost."
	icon_keyboard = "mining_key"
	icon_screen = "mining"
	network = list("Mining Outpost")
	circuit = /obj/item/weapon/circuitboard/security/mining
	light_color = "#F9BBFC"

/obj/machinery/computer/security/engineering
	name = "engineering camera monitor"
	desc = "Used to monitor fires and breaches."
	icon_keyboard = "power_key"
	icon_screen = "engie_cams"
	circuit = /obj/item/weapon/circuitboard/security/engineering
	light_color = "#FAC54B"

/obj/machinery/computer/security/engineering/New()
	if(!network)
		network = engineering_networks.Copy()
	..()

/obj/machinery/computer/security/nuclear
	name = "head mounted camera monitor"
	desc = "Used to access the built-in cameras in helmets."
	icon_state = "syndicam"
	network = list(NETWORK_MERCENARY)
	circuit = null

/obj/machinery/computer/security/nuclear/New()
	..()
	req_access = list(150)
// PRESETS
/*
var/global/list/station_networks = list(
//										NETWORK_CAFE_DOCK,
										NETWORK_CARGO,
										NETWORK_CIVILIAN,
//										NETWORK_CIVILIAN_EAST,
//										NETWORK_CIVILIAN_WEST,
										NETWORK_COMMAND,
										NETWORK_ENGINE,
										NETWORK_ENGINEERING,
										NETWORK_ENGINEERING_OUTPOST,
										NETWORK_DEFAULT,
										NETWORK_MEDICAL,
										NETWORK_MINE,
										NETWORK_NORTHERN_STAR,
										NETWORK_RESEARCH,
										NETWORK_RESEARCH_OUTPOST,
										NETWORK_ROBOTS,
										NETWORK_PRISON,
										NETWORK_SECURITY,
										NETWORK_INTERROGATION
										)
*/
var/global/list/engineering_networks = list(
										NETWORK_ENGINE,
										NETWORK_ENGINEERING,
										NETWORK_ENGINEERING_OUTPOST,
										NETWORK_ALARM_ATMOS,
										NETWORK_ALARM_FIRE,
										NETWORK_ALARM_POWER)
/obj/machinery/camera/network/crescent
	network = list(NETWORK_CRESCENT)

/*
/obj/machinery/camera/network/cafe_dock
	network = list(NETWORK_CAFE_DOCK)
*/

/obj/machinery/camera/network/cargo
	network = list(NETWORK_CARGO)

/obj/machinery/camera/network/civilian
	network = list(NETWORK_CIVILIAN)

/*
/obj/machinery/camera/network/civilian_east
	network = list(NETWORK_CIVILIAN_EAST)

/obj/machinery/camera/network/civilian_west
	network = list(NETWORK_CIVILIAN_WEST)
*/

/obj/machinery/camera/network/command
	network = list(NETWORK_COMMAND)

/obj/machinery/camera/network/engine
	network = list(NETWORK_ENGINE)

/obj/machinery/camera/network/engineering
	network = list(NETWORK_ENGINEERING)

/obj/machinery/camera/network/engineering_outpost
	network = list(NETWORK_ENGINEERING_OUTPOST)

/obj/machinery/camera/network/ert
	network = list(NETWORK_ERT)

/obj/machinery/camera/network/exodus
	network = list(NETWORK_DEFAULT)

/obj/machinery/camera/network/interrogation
	network = list(NETWORK_INTERROGATION)

/obj/machinery/camera/network/mining
	network = list(NETWORK_MINE)

/obj/machinery/camera/network/northern_star
	network = list(NETWORK_NORTHERN_STAR)

/obj/machinery/camera/network/prison
	network = list(NETWORK_PRISON)

/obj/machinery/camera/network/medbay
	network = list(NETWORK_MEDICAL)

/obj/machinery/camera/network/research
	network = list(NETWORK_RESEARCH)

/obj/machinery/camera/network/research_outpost
	network = list(NETWORK_RESEARCH_OUTPOST)

/obj/machinery/camera/network/security
	network = list(NETWORK_SECURITY)

/obj/machinery/camera/network/telecom
	network = list(NETWORK_TELECOM)

/obj/machinery/camera/network/thunder
	network = list(NETWORK_THUNDER)
	invuln = 1

// EMP

/obj/machinery/camera/emp_proof/New()
	..()
	upgradeEmpProof()

// X-RAY

/obj/machinery/camera/xray
	icon_state = "xraycam" // Thanks to Krutchen for the icons.

/obj/machinery/camera/xray/command
	network = list(NETWORK_COMMAND)

/obj/machinery/camera/xray/security
	network = list(NETWORK_SECURITY)

/obj/machinery/camera/xray/medbay
	network = list(NETWORK_MEDICAL)

/obj/machinery/camera/xray/research
	network = list(NETWORK_RESEARCH)

/obj/machinery/camera/xray/New()
	..()
	upgradeXRay()

// MOTION

/obj/machinery/camera/motion/New()
	..()
	upgradeMotion()

/obj/machinery/camera/motion/engineering_outpost
	network = list(NETWORK_ENGINEERING_OUTPOST)

/obj/machinery/camera/motion/security
	network = list(NETWORK_SECURITY)

// ALL UPGRADES


/obj/machinery/camera/all/command
	network = list(NETWORK_COMMAND)

/obj/machinery/camera/all/New()
	..()
	upgradeEmpProof()
	upgradeXRay()
	upgradeMotion()

// AUTONAME
/obj/machinery/camera/autoname
	var/number = 0 //camera number in area

//This camera type automatically sets it's name to whatever the area that it's in is called.
/obj/machinery/camera/autoname/New()
	..()
	spawn(10)
		number = 1
		var/area/A = get_area(src)
		if(A)
			for(var/obj/machinery/camera/autoname/C in machines)
				if(C == src) continue
				var/area/CA = get_area(C)
				if(CA.type == A.type)
					if(C.number)
						number = max(number, C.number+1)
			c_tag = "[A.name] #[number]"
		invalidateCameraCache()


// CHECKS

/obj/machinery/camera/proc/isEmpProof()
	var/O = locate(/obj/item/stack/material/osmium) in assembly.upgrades
	return O

/obj/machinery/camera/proc/isXRay()
	var/obj/item/weapon/stock_parts/scanning_module/O = locate(/obj/item/weapon/stock_parts/scanning_module) in assembly.upgrades
	if (O && O.rating >= 2)
		return O
	return null

/obj/machinery/camera/proc/isMotion()
	var/O = locate(/obj/item/device/assembly/prox_sensor) in assembly.upgrades
	return O

// UPGRADE PROCS

/obj/machinery/camera/proc/upgradeEmpProof()
	assembly.upgrades.Add(new /obj/item/stack/material/osmium(assembly))
	setPowerUsage()
	update_coverage()

/obj/machinery/camera/proc/upgradeXRay()
	assembly.upgrades.Add(new /obj/item/weapon/stock_parts/scanning_module/adv(assembly))
	setPowerUsage()
	update_coverage()

/obj/machinery/camera/proc/upgradeMotion()
	assembly.upgrades.Add(new /obj/item/device/assembly/prox_sensor(assembly))
	setPowerUsage()
	START_MACHINE_PROCESSING(src)
	update_coverage()

/obj/machinery/camera/proc/setPowerUsage()
	var/mult = 1
	if (isXRay())
		mult++
	if (isMotion())
		mult++
	active_power_usage = mult*initial(active_power_usage)

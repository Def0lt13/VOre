/*		Portable Turrets:
		Constructed from metal, a gun of choice, and a prox sensor.
		This code is slightly more documented than normal, as requested by XSI on IRC.
*/

/datum/category_item/catalogue/technology/turret
	name = "Turrets"
	desc = "This imtimidating machine is essentially an automated gun. It is able to \
	scan its immediate environment, and if it determines that a threat is nearby, it will \
	open up, aim the barrel of the weapon at the threat, and engage it until the threat \
	goes away, it dies (if using a lethal gun), or the turret is destroyed. This has made them \
	well suited for long term defense for a static position, as electricity costs much \
	less than hiring a person to stand around. Despite this, the lack of a sapient entity's \
	judgement has sometimes lead to tragedy when turrets are poorly configured.\
	<br><br>\
	Early models generally had simple designs, and would shoot at anything that moved, with only \
	the option to disable it remotely for maintenance or to let someone pass. More modern iterations \
	of turrets have instead replaced those simple systems with intricate optical sensors and \
	image recognition software that allow the turret to distinguish between several kinds of \
	entities, and to only engage whatever their owners configured them to fight against.\
	Some models also have the ability to switch between a lethal and non-lethal mode.\
	<br><br>\
	Today's cutting edge in static defense development has shifted away from improving the \
	software of the turret, and instead towards the hardware. The newest solutions for \
	automated protection includes new hardware capabilities such as thicker armor, more \
	advanced integrated weapons, and some may even have been built with EM hardening in \
	mind."
	value = CATALOGUER_REWARD_MEDIUM


#define TURRET_PRIORITY_TARGET 2
#define TURRET_SECONDARY_TARGET 1
#define TURRET_NOT_TARGET 0

/obj/machinery/porta_turret
	name = "turret"
	catalogue_data = list(/datum/category_item/catalogue/technology/turret)
	icon = 'icons/obj/turrets.dmi'
	icon_state = "turret_cover"
	anchored = 1

	density = 0
	use_power = 1				//this turret uses and requires power
	idle_power_usage = 50		//when inactive, this turret takes up constant 50 Equipment power
	active_power_usage = 300	//when active, this turret takes up constant 300 Equipment power
	power_channel = EQUIP	//drains power from the EQUIPMENT channel
	req_one_access = list(access_security, access_heads)

	// icon_states for turrets.
	// These are for the turret covers.
	var/closed_state = "turret_cover"					// For when it is closed.
	var/raising_state = "popup"							// When turret is opening.
	var/opened_state = "open"							// When fully opened.
	var/lowering_state = "popdown"						// When closing.
	var/gun_active_state = "target_prism"				// The actual gun's icon_state when active.
	var/gun_disabled_state = "grey_target_prism"		// Gun sprite when depowered/disabled.
	var/gun_destroyed_state = "destroyed_target_prism"	// Turret sprite for when the turret dies.

	var/raised = 0			//if the turret cover is "open" and the turret is raised
	var/raising= 0			//if the turret is currently opening or closing its cover
	var/health = 80			//the turret's health
	var/maxhealth = 80		//turrets maximal health.
	var/auto_repair = 0		//if 1 the turret slowly repairs itself.
	var/locked = 1			//if the turret's behaviour control access is locked
	var/controllock = 0		//if the turret responds to control panels

	var/installation = /obj/item/weapon/gun/energy/gun		//the type of weapon installed
	var/gun_charge = 0		//the charge of the gun inserted
	var/projectile = null	//holder for bullettype
	var/eprojectile = null	//holder for the shot when emagged
	var/reqpower = 500		//holder for power needed
	var/iconholder = null	//holder for the icon_state. 1 for sprite based on icon_color, null for blue.
	var/icon_color = "orange" // When iconholder is set to 1, the icon_state changes based on what is in this variable.
	var/egun = null			//holder to handle certain guns switching bullettypes

	var/last_fired = 0		//1: if the turret is cooling down from a shot, 0: turret is ready to fire
	var/shot_delay = 15		//1.5 seconds between each shot

	var/check_arrest = 1	//checks if the perp is set to arrest
	var/check_records = 1	//checks if a security record exists at all
	var/check_weapons = 0	//checks if it can shoot people that have a weapon they aren't authorized to have
	var/check_access = 1	//if this is active, the turret shoots everything that does not meet the access requirements
	var/check_anomalies = 1	//checks if it can shoot at unidentified lifeforms (ie xenos)
	var/check_synth	 = 0 	//if active, will shoot at anything not an AI or cyborg
	var/check_all = 0		//If active, will fire on anything, including synthetics.
	var/ailock = 0 			// AI cannot use this
	var/faction = null		//if set, will not fire at people in the same faction for any reason.

	var/attacked = 0		//if set to 1, the turret gets pissed off and shoots at people nearby (unless they have sec access!)

	var/enabled = 1				//determines if the turret is on
	var/lethal = 0			//whether in lethal or stun mode
	var/disabled = 0

	var/shot_sound 			//what sound should play when the turret fires
	var/eshot_sound			//what sound should play when the emagged turret fires

	var/datum/effect/effect/system/spark_spread/spark_system	//the spark system, used for generating... sparks?

	var/wrenching = 0
	var/last_target			//last target fired at, prevents turrets from erratically firing at all valid targets in range
	var/timeout = 10		// When a turret pops up, then finds nothing to shoot at, this number decrements until 0, when it pops down.
	var/can_salvage = TRUE	// If false, salvaging doesn't give you anything.

/obj/machinery/porta_turret/crescent
	req_one_access = list(access_cent_specops)
	enabled = 0
	ailock = 1
	check_synth	 = 0
	check_access = 1
	check_arrest = 1
	check_records = 1
	check_weapons = 1
	check_anomalies = 1
	check_all = 0

/obj/machinery/porta_turret/can_catalogue(mob/user) // Dead turrets can't be scanned.
	if(stat & BROKEN)
		to_chat(user, span("warning", "\The [src] was destroyed, so it cannot be scanned."))
		return FALSE
	return ..()

/obj/machinery/porta_turret/stationary
	ailock = 1
	lethal = 1
	installation = /obj/item/weapon/gun/energy/laser

/obj/machinery/porta_turret/stationary/syndie // Generic turrets for POIs that need to not shoot their buddies.
	req_one_access = list(access_syndicate)
	enabled = TRUE
	check_all = TRUE
	faction = "syndicate" // Make sure this equals the faction that the mobs in the POI have or they will fight each other.

/obj/machinery/porta_turret/ai_defense
	name = "defense turret"
	desc = "This variant appears to be much more durable."
	req_one_access = list(access_synth) // Just in case.
	installation = /obj/item/weapon/gun/energy/xray // For the armor pen.
	health = 250 // Since lasers do 40 each.
	maxhealth = 250


/datum/category_item/catalogue/anomalous/precursor_a/alien_turret
	name = "Precursor Alpha Object - Turrets"
	desc = "An autonomous defense turret created by unknown ancient aliens. It utilizes an \
	integrated laser projector to harm, firing a cyan beam at the target. The signal processing \
	of this mechanism appears to be radically different to conventional electronics used by modern \
	technology, which appears to be much less susceptible to external electromagnetic influences.\
	<br><br>\
	This makes the turret be very resistant to the effects of an EM pulse. It is unknown if whatever \
	species that built the turret had intended for it to have that quality, or if it was an incidental \
	quirk of how they designed their electronics."
	value = CATALOGUER_REWARD_MEDIUM

/obj/machinery/porta_turret/alien // The kind used on the UFO submap.
	name = "interior anti-boarding turret"
	desc = "A very tough looking turret made by alien hands."
	catalogue_data = list(/datum/category_item/catalogue/anomalous/precursor_a/alien_turret)
	icon_state = "alien_turret_cover"
	req_one_access = list(access_alien)
	installation = /obj/item/weapon/gun/energy/alien
	enabled = TRUE
	lethal = TRUE
	ailock = TRUE
	check_all = TRUE
	health = 250 // Similar to the AI turrets.
	maxhealth = 250

	closed_state = "alien_turret_cover"
	raising_state = "alien_popup"
	opened_state = "alien_open"
	lowering_state = "alien_popdown"
	gun_active_state = "alien_gun"
	gun_disabled_state = "alien_gun_disabled"
	gun_destroyed_state = "alien_gun_destroyed"

/obj/machinery/porta_turret/alien/destroyed // Turrets that are already dead, to act as a warning of what the rest of the submap contains.
	name = "broken interior anti-boarding turret"
	desc = "A very tough looking turret made by alien hands. This one looks destroyed, thankfully."
	icon_state = "alien_gun_destroyed"
	stat = BROKEN
	can_salvage = FALSE // So you need to actually kill a turret to get the alien gun.

/obj/machinery/porta_turret/poi	//These are always angry
	enabled = TRUE
	lethal = TRUE
	ailock = TRUE
	check_all = TRUE
	can_salvage = FALSE	// So you can't just twoshot a turret and get a fancy gun

/obj/machinery/porta_turret/Initialize()
	//Sets up a spark system
	spark_system = new /datum/effect/effect/system/spark_spread
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)

	setup()

	// If turrets ever switch overlays, this will need to be cached and reapplied each time overlays_cut() is called.
	var/image/turret_opened_overlay = image(icon, opened_state)
	turret_opened_overlay.layer = layer-0.1
	add_overlay(turret_opened_overlay)
	return ..()

/obj/machinery/porta_turret/Destroy()
	qdel(spark_system)
	spark_system = null
	return ..()

/obj/machinery/porta_turret/update_icon()
	if(stat & BROKEN) // Turret is dead.
		icon_state = gun_destroyed_state

	else if(raised || raising)
		// Turret is open.
		if(powered() && enabled)
			// Trying to shoot someone.
			icon_state = gun_active_state

		else
			// Disabled.
			icon_state = gun_disabled_state

	else
		// Its closed.
		icon_state = closed_state


/obj/machinery/porta_turret/proc/setup()
	var/obj/item/weapon/gun/energy/E = installation	//All energy-based weapons are applicable
	//var/obj/item/ammo_casing/shottype = E.projectile_type

	projectile = initial(E.projectile_type)
	eprojectile = projectile
	shot_sound = initial(E.fire_sound)
	eshot_sound = shot_sound

	weapon_setup(installation)

/obj/machinery/porta_turret/proc/weapon_setup(var/guntype)
	switch(guntype)
		if(/obj/item/weapon/gun/energy/laser/practice)
			iconholder = 1
			eprojectile = /obj/item/projectile/beam

//			if(/obj/item/weapon/gun/energy/laser/practice/sc_laser)
//				iconholder = 1
//				eprojectile = /obj/item/projectile/beam

		if(/obj/item/weapon/gun/energy/retro)
			iconholder = 1

//			if(/obj/item/weapon/gun/energy/retro/sc_retro)
//				iconholder = 1

		if(/obj/item/weapon/gun/energy/captain)
			iconholder = 1

		if(/obj/item/weapon/gun/energy/lasercannon)
			iconholder = 1

		if(/obj/item/weapon/gun/energy/taser)
			eprojectile = /obj/item/projectile/beam
			eshot_sound = 'sound/weapons/Laser.ogg'

		if(/obj/item/weapon/gun/energy/stunrevolver)
			eprojectile = /obj/item/projectile/beam
			eshot_sound = 'sound/weapons/Laser.ogg'

		if(/obj/item/weapon/gun/energy/gun)
			eprojectile = /obj/item/projectile/beam	//If it has, going to kill mode
			eshot_sound = 'sound/weapons/Laser.ogg'
			egun = 1

		if(/obj/item/weapon/gun/energy/gun/nuclear)
			eprojectile = /obj/item/projectile/beam	//If it has, going to kill mode
			eshot_sound = 'sound/weapons/Laser.ogg'
			egun = 1

		if(/obj/item/weapon/gun/energy/xray)
			eprojectile = /obj/item/projectile/beam/xray
			projectile = /obj/item/projectile/beam/stun // Otherwise we fire xrays on both modes.
			eshot_sound = 'sound/weapons/eluger.ogg'
			shot_sound = 'sound/weapons/Taser.ogg'
			iconholder = 1
			icon_color = "green"

/obj/machinery/porta_turret/proc/isLocked(mob/user)
	if(ailock && issilicon(user))
		to_chat(user, "<span class='notice'>There seems to be a firewall preventing you from accessing this device.</span>")
		return 1

	if(locked && !issilicon(user))
		to_chat(user, "<span class='notice'>Access denied.</span>")
		return 1

	return 0

/obj/machinery/porta_turret/attack_ai(mob/user)
	if(isLocked(user))
		return

	ui_interact(user)

/obj/machinery/porta_turret/attack_hand(mob/user)
	if(isLocked(user))
		return

	ui_interact(user)

/obj/machinery/porta_turret/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)
	var/data[0]
	data["access"] = !isLocked(user)
	data["locked"] = locked
	data["enabled"] = enabled
	data["is_lethal"] = 1
	data["lethal"] = lethal

	if(data["access"])
		var/settings[0]
		settings[++settings.len] = list("category" = "Neutralize All Non-Synthetics", "setting" = "check_synth", "value" = check_synth)
		settings[++settings.len] = list("category" = "Check Weapon Authorization", "setting" = "check_weapons", "value" = check_weapons)
		settings[++settings.len] = list("category" = "Check Security Records", "setting" = "check_records", "value" = check_records)
		settings[++settings.len] = list("category" = "Check Arrest Status", "setting" = "check_arrest", "value" = check_arrest)
		settings[++settings.len] = list("category" = "Check Access Authorization", "setting" = "check_access", "value" = check_access)
		settings[++settings.len] = list("category" = "Check misc. Lifeforms", "setting" = "check_anomalies", "value" = check_anomalies)
		settings[++settings.len] = list("category" = "Neutralize All Entities", "setting" = "check_all", "value" = check_all)
		data["settings"] = settings

	ui = SSnanoui.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "turret_control.tmpl", "Turret Controls", 500, 300)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/porta_turret/proc/HasController()
	var/area/A = get_area(src)
	return A && A.turret_controls.len > 0

/obj/machinery/porta_turret/CanUseTopic(var/mob/user)
	if(HasController())
		to_chat(user, "<span class='notice'>Turrets can only be controlled using the assigned turret controller.</span>")
		return STATUS_CLOSE

	if(isLocked(user))
		return STATUS_CLOSE

	if(!anchored)
		to_chat(user, "<span class='notice'>\The [src] has to be secured first!</span>")
		return STATUS_CLOSE

	return ..()

/obj/machinery/porta_turret/Topic(href, href_list)
	if(..())
		return 1

	if(href_list["command"] && href_list["value"])
		var/value = text2num(href_list["value"])
		if(href_list["command"] == "enable")
			enabled = value
		else if(href_list["command"] == "lethal")
			lethal = value
		else if(href_list["command"] == "check_synth")
			check_synth = value
		else if(href_list["command"] == "check_weapons")
			check_weapons = value
		else if(href_list["command"] == "check_records")
			check_records = value
		else if(href_list["command"] == "check_arrest")
			check_arrest = value
		else if(href_list["command"] == "check_access")
			check_access = value
		else if(href_list["command"] == "check_anomalies")
			check_anomalies = value
		else if(href_list["command"] == "check_all")
			check_all = value

		return 1

/obj/machinery/porta_turret/power_change()
	if(powered())
		stat &= ~NOPOWER
		update_icon()
	else
		spawn(rand(0, 15))
			stat |= NOPOWER
			update_icon()


/obj/machinery/porta_turret/attackby(obj/item/I, mob/user)
	if(stat & BROKEN)
		if(I.is_crowbar())
			//If the turret is destroyed, you can remove it with a crowbar to
			//try and salvage its components
			to_chat(user, "<span class='notice'>You begin prying the metal coverings off.</span>")
			if(do_after(user, 20))
				if(can_salvage && prob(70))
					to_chat(user, "<span class='notice'>You remove the turret and salvage some components.</span>")
					if(installation)
						var/obj/item/weapon/gun/energy/Gun = new installation(loc)
						Gun.power_supply.charge = gun_charge
						Gun.update_icon()
					if(prob(50))
						new /obj/item/stack/material/steel(loc, rand(1,4))
					if(prob(50))
						new /obj/item/device/assembly/prox_sensor(loc)
				else
					to_chat(user, "<span class='notice'>You remove the turret but did not manage to salvage anything.</span>")
				qdel(src) // qdel

	else if(I.is_wrench())
		if(enabled || raised)
			to_chat(user, "<span class='warning'>You cannot unsecure an active turret!</span>")
			return
		if(wrenching)
			to_chat(user, "<span class='warning'>Someone is already [anchored ? "un" : ""]securing the turret!</span>")
			return
		if(!anchored && isinspace())
			to_chat(user, "<span class='warning'>Cannot secure turrets in space!</span>")
			return

		user.visible_message(\
				"<span class='warning'>[user] begins [anchored ? "un" : ""]securing the turret.</span>", \
				"<span class='notice'>You begin [anchored ? "un" : ""]securing the turret.</span>" \
			)

		wrenching = 1
		if(do_after(user, 50 * I.toolspeed))
			//This code handles moving the turret around. After all, it's a portable turret!
			if(!anchored)
				playsound(loc, I.usesound, 100, 1)
				anchored = 1
				update_icon()
				to_chat(user, "<span class='notice'>You secure the exterior bolts on the turret.</span>")
			else if(anchored)
				playsound(loc, I.usesound, 100, 1)
				anchored = 0
				to_chat(user, "<span class='notice'>You unsecure the exterior bolts on the turret.</span>")
				update_icon()
		wrenching = 0

	else if(istype(I, /obj/item/weapon/card/id)||istype(I, /obj/item/device/pda))
		//Behavior lock/unlock mangement
		if(allowed(user))
			locked = !locked
			to_chat(user, "<span class='notice'>Controls are now [locked ? "locked" : "unlocked"].</span>")
			updateUsrDialog()
		else
			to_chat(user, "<span class='notice'>Access denied.</span>")

	else
		//if the turret was attacked with the intention of harming it:
		user.setClickCooldown(user.get_attack_speed(I))
		take_damage(I.force * 0.5)
		if(I.force * 0.5 > 1) //if the force of impact dealt at least 1 damage, the turret gets pissed off
			if(!attacked && !emagged)
				attacked = 1
				spawn()
					sleep(60)
					attacked = 0
		..()

/obj/machinery/porta_turret/attack_generic(mob/living/L, damage)
	if(isanimal(L))
		var/mob/living/simple_mob/S = L
		if(damage >= STRUCTURE_MIN_DAMAGE_THRESHOLD)
			var/incoming_damage = round(damage - (damage / 5)) //Turrets are slightly armored, assumedly.
			visible_message("<span class='danger'>\The [S] [pick(S.attacktext)] \the [src]!</span>")
			take_damage(incoming_damage)
			S.do_attack_animation(src)
			return 1
		visible_message("<span class='notice'>\The [L] bonks \the [src]'s casing!</span>")
	return ..()

/obj/machinery/porta_turret/emag_act(var/remaining_charges, var/mob/user)
	if(!emagged)
		//Emagging the turret makes it go bonkers and stun everyone. It also makes
		//the turret shoot much, much faster.
		to_chat(user, "<span class='warning'>You short out [src]'s threat assessment circuits.</span>")
		visible_message("[src] hums oddly...")
		emagged = 1
		iconholder = 1
		controllock = 1
		enabled = 0 //turns off the turret temporarily
		sleep(60) //6 seconds for the traitor to gtfo of the area before the turret decides to ruin his shit
		enabled = 1 //turns it back on. The cover popUp() popDown() are automatically called in process(), no need to define it here
		return 1

/obj/machinery/porta_turret/proc/take_damage(var/force)
	if(!raised && !raising)
		force = force / 8
		if(force < 5)
			return

	health -= force
	if(force > 5 && prob(45))
		spark_system.start()
	if(health <= 0)
		die()	//the death process :(

/obj/machinery/porta_turret/bullet_act(obj/item/projectile/Proj)
	var/damage = Proj.get_structure_damage()

	if(!damage)
		return

	if(enabled)
		if(!attacked && !emagged)
			attacked = 1
			spawn()
				sleep(60)
				attacked = 0

	..()

	take_damage(damage)

/obj/machinery/porta_turret/emp_act(severity)
	if(enabled)
		//if the turret is on, the EMP no matter how severe disables the turret for a while
		//and scrambles its settings, with a slight chance of having an emag effect
		check_arrest = prob(50)
		check_records = prob(50)
		check_weapons = prob(50)
		check_access = prob(20)	// check_access is a pretty big deal, so it's least likely to get turned on
		check_anomalies = prob(50)
		if(prob(5))
			emagged = 1

		enabled=0
		spawn(rand(60,600))
			if(!enabled)
				enabled=1

	..()

/obj/machinery/porta_turret/ai_defense/emp_act(severity)
	if(prob(33)) // One in three chance to resist an EMP.  This is significant if an AoE EMP is involved against multiple turrets.
		return
	..()

/obj/machinery/porta_turret/alien/emp_act(severity) // This is overrided to give an EMP resistance as well as avoid scambling the turret settings.
	if(prob(75)) // Superior alien technology, I guess.
		return
	enabled = FALSE
	spawn(rand(1 MINUTE, 2 MINUTES))
		if(!enabled)
			enabled = TRUE

/obj/machinery/porta_turret/ex_act(severity)
	switch (severity)
		if(1)
			qdel(src)
		if(2)
			if(prob(25))
				qdel(src)
			else
				take_damage(initial(health) * 8) //should instakill most turrets
		if(3)
			take_damage(initial(health) * 8 / 3) //Level 4 is too weak to bother turrets

/obj/machinery/porta_turret/proc/die()	//called when the turret dies, ie, health <= 0
	health = 0
	stat |= BROKEN	//enables the BROKEN bit
	spark_system.start()	//creates some sparks because they look cool
	update_icon()

/obj/machinery/porta_turret/process()
	//the main machinery process

	if(stat & (NOPOWER|BROKEN))
		//if the turret has no power or is broken, make the turret pop down if it hasn't already
		popDown()
		return

	if(!enabled)
		//if the turret is off, make it pop down
		popDown()
		return

	var/list/targets = list()			//list of primary targets
	var/list/secondarytargets = list()	//targets that are least important

	for(var/mob/M in mobs_in_xray_view(world.view, src))
		assess_and_assign(M, targets, secondarytargets)

	if(!tryToShootAt(targets))
		if(!tryToShootAt(secondarytargets)) // if no valid targets, go for secondary targets
			timeout--
			if(timeout <= 0)
				spawn()
					popDown() // no valid targets, close the cover

	if(auto_repair && (health < maxhealth))
		use_power(20000)
		health = min(health+1, maxhealth) // 1HP for 20kJ

/obj/machinery/porta_turret/proc/assess_and_assign(var/mob/living/L, var/list/targets, var/list/secondarytargets)
	switch(assess_living(L))
		if(TURRET_PRIORITY_TARGET)
			targets += L
		if(TURRET_SECONDARY_TARGET)
			secondarytargets += L

/obj/machinery/porta_turret/proc/assess_living(var/mob/living/L)
	if(!istype(L))
		return TURRET_NOT_TARGET

	if(L.invisibility >= INVISIBILITY_LEVEL_ONE) // Cannot see him. see_invisible is a mob-var
		return TURRET_NOT_TARGET

	if(!L)
		return TURRET_NOT_TARGET

	if(faction && L.faction == faction)
		return TURRET_NOT_TARGET

	if(!emagged && issilicon(L) && check_all == 0)	// Don't target silica, unless told to neutralize everything.
		return TURRET_NOT_TARGET

	if(L.stat && !emagged)		//if the perp is dead/dying, no need to bother really
		return TURRET_NOT_TARGET	//move onto next potential victim!

	if(get_dist(src, L) > 7)	//if it's too far away, why bother?
		return TURRET_NOT_TARGET

	if(!(L in check_trajectory(L, src)))	//check if we have true line of sight
		return TURRET_NOT_TARGET

	if(emagged)		// If emagged not even the dead get a rest
		return L.stat ? TURRET_SECONDARY_TARGET : TURRET_PRIORITY_TARGET

	if(lethal && locate(/mob/living/silicon/ai) in get_turf(L))		//don't accidentally kill the AI!
		return TURRET_NOT_TARGET

	if(check_synth || check_all)	//If it's set to attack all non-silicons or everything, target them!
		if(L.lying)
			return lethal ? TURRET_SECONDARY_TARGET : TURRET_NOT_TARGET
		return TURRET_PRIORITY_TARGET

	if(iscuffed(L)) // If the target is handcuffed, leave it alone
		return TURRET_NOT_TARGET

	if(isanimal(L) || issmall(L)) // Animals are not so dangerous
		return check_anomalies ? TURRET_SECONDARY_TARGET : TURRET_NOT_TARGET

	if(isxenomorph(L) || isalien(L)) // Xenos are dangerous
		return check_anomalies ? TURRET_PRIORITY_TARGET	: TURRET_NOT_TARGET

	if(ishuman(L))	//if the target is a human, analyze threat level
		if(assess_perp(L) < 4)
			return TURRET_NOT_TARGET	//if threat level < 4, keep going

	if(L.lying)		//if the perp is lying down, it's still a target but a less-important target
		return lethal ? TURRET_SECONDARY_TARGET : TURRET_NOT_TARGET

	return TURRET_PRIORITY_TARGET	//if the perp has passed all previous tests, congrats, it is now a "shoot-me!" nominee

/obj/machinery/porta_turret/proc/assess_perp(var/mob/living/carbon/human/H)
	if(!H || !istype(H))
		return 0

	if(emagged)
		return 10

	return H.assess_perp(src, check_access, check_weapons, check_records, check_arrest)

/obj/machinery/porta_turret/proc/tryToShootAt(var/list/mob/living/targets)
	if(targets.len && last_target && (last_target in targets) && target(last_target))
		return 1

	while(targets.len > 0)
		var/mob/living/M = pick(targets)
		targets -= M
		if(target(M))
			return 1


/obj/machinery/porta_turret/proc/popUp()	//pops the turret up
	if(disabled)
		return
	if(raising || raised)
		return
	if(stat & BROKEN)
		return
	set_raised_raising(raised, 1)
	update_icon()

	var/atom/flick_holder = new /atom/movable/porta_turret_cover(loc)
	flick_holder.layer = layer + 0.1
	flick(raising_state, flick_holder)
	sleep(10)
	qdel(flick_holder)

	set_raised_raising(1, 0)
	update_icon()
	timeout = 10

/obj/machinery/porta_turret/proc/popDown()	//pops the turret down
	last_target = null
	if(disabled)
		return
	if(raising || !raised)
		return
	if(stat & BROKEN)
		return
	set_raised_raising(raised, 1)
	update_icon()

	var/atom/flick_holder = new /atom/movable/porta_turret_cover(loc)
	flick_holder.layer = layer + 0.1
	flick(lowering_state, flick_holder)
	sleep(10)
	qdel(flick_holder)

	set_raised_raising(0, 0)
	update_icon()
	timeout = 10

/obj/machinery/porta_turret/proc/set_raised_raising(var/incoming_raised, var/incoming_raising)
	raised = incoming_raised
	raising = incoming_raising
	density = raised || raising

/obj/machinery/porta_turret/proc/target(var/mob/living/target)
	if(disabled)
		return
	if(target)
		last_target = target
		spawn()
			popUp()				//pop the turret up if it's not already up.
		set_dir(get_dir(src, target))	//even if you can't shoot, follow the target
		spawn()
			shootAt(target)
		return 1
	return

/obj/machinery/porta_turret/proc/shootAt(var/mob/living/target)
	//any emagged turrets will shoot extremely fast! This not only is deadly, but drains a lot power!
	if(!(emagged || attacked))		//if it hasn't been emagged or attacked, it has to obey a cooldown rate
		if(last_fired || !raised)	//prevents rapid-fire shooting, unless it's been emagged
			return
		last_fired = 1
		spawn()
			sleep(shot_delay)
			last_fired = 0

	var/turf/T = get_turf(src)
	var/turf/U = get_turf(target)
	if(!istype(T) || !istype(U))
		return

	if(!raised) //the turret has to be raised in order to fire - makes sense, right?
		return

	update_icon()
	var/obj/item/projectile/A
	if(emagged || lethal)
		A = new eprojectile(loc)
		playsound(loc, eshot_sound, 75, 1)
	else
		A = new projectile(loc)
		playsound(loc, shot_sound, 75, 1)

	// Lethal/emagged turrets use twice the power due to higher energy beams
	// Emagged turrets again use twice as much power due to higher firing rates
	use_power(reqpower * (2 * (emagged || lethal)) * (2 * emagged))

	//Turrets aim for the center of mass by default.
	//If the target is grabbing someone then the turret smartly aims for extremities
	var/def_zone
	var/obj/item/weapon/grab/G = locate() in target
	if(G && G.state >= GRAB_NECK) //works because mobs are currently not allowed to upgrade to NECK if they are grabbing two people.
		def_zone = pick(BP_HEAD, BP_L_HAND, BP_R_HAND, BP_L_FOOT, BP_R_FOOT, BP_L_ARM, BP_R_ARM, BP_L_LEG, BP_R_LEG)
	else
		def_zone = pick(BP_TORSO, BP_GROIN)

	//Shooting Code:
	A.firer = src
	A.old_style_target(target)
	A.def_zone = def_zone
	A.fire()

	// Reset the time needed to go back down, since we just tried to shoot at someone.
	timeout = 10

/datum/turret_checks
	var/enabled
	var/lethal
	var/check_synth
	var/check_access
	var/check_records
	var/check_arrest
	var/check_weapons
	var/check_anomalies
	var/check_all
	var/ailock

/obj/machinery/porta_turret/proc/setState(var/datum/turret_checks/TC)
	if(controllock)
		return
	enabled = TC.enabled
	lethal = TC.lethal
	iconholder = TC.lethal

	check_synth = TC.check_synth
	check_access = TC.check_access
	check_records = TC.check_records
	check_arrest = TC.check_arrest
	check_weapons = TC.check_weapons
	check_anomalies = TC.check_anomalies
	check_all = TC.check_all
	ailock = TC.ailock

	power_change()

/*
		Portable turret constructions
		Known as "turret frame"s
*/

/obj/machinery/porta_turret_construct
	name = "turret frame"
	icon = 'icons/obj/turrets.dmi'
	icon_state = "turret_frame"
	density=1
	var/target_type = /obj/machinery/porta_turret	// The type we intend to build
	var/build_step = 0			//the current step in the building process
	var/finish_name="turret"	//the name applied to the product turret
	var/installation = null		//the gun type installed
	var/gun_charge = 0			//the gun charge of the gun type installed

/obj/machinery/porta_turret_construct/attackby(obj/item/I, mob/user)
	//this is a bit unwieldy but self-explanatory
	switch(build_step)
		if(0)	//first step
			if(I.is_wrench() && !anchored)
				playsound(loc, I.usesound, 100, 1)
				to_chat(user, "<span class='notice'>You secure the external bolts.</span>")
				anchored = 1
				build_step = 1
				return

			else if(I.is_crowbar() && !anchored)
				playsound(loc, I.usesound, 75, 1)
				to_chat(user, "<span class='notice'>You dismantle the turret construction.</span>")
				new /obj/item/stack/material/steel(loc, 5)
				qdel(src)
				return

		if(1)
			if(istype(I, /obj/item/stack/material) && I.get_material_name() == DEFAULT_WALL_MATERIAL)
				var/obj/item/stack/M = I
				if(M.use(2))
					to_chat(user, "<span class='notice'>You add some metal armor to the interior frame.</span>")
					build_step = 2
					icon_state = "turret_frame2"
				else
					to_chat(user, "<span class='warning'>You need two sheets of metal to continue construction.</span>")
				return

			else if(I.is_wrench())
				playsound(loc, I.usesound, 75, 1)
				to_chat(user, "<span class='notice'>You unfasten the external bolts.</span>")
				anchored = 0
				build_step = 0
				return

		if(2)
			if(I.is_wrench())
				playsound(loc, I.usesound, 100, 1)
				to_chat(user, "<span class='notice'>You bolt the metal armor into place.</span>")
				build_step = 3
				return

			else if(istype(I, /obj/item/weapon/weldingtool))
				var/obj/item/weapon/weldingtool/WT = I
				if(!WT.isOn())
					return
				if(WT.get_fuel() < 5) //uses up 5 fuel.
					to_chat(user, "<span class='notice'>You need more fuel to complete this task.</span>")
					return

				playsound(loc, I.usesound, 50, 1)
				if(do_after(user, 20 * I.toolspeed))
					if(!src || !WT.remove_fuel(5, user)) return
					build_step = 1
					to_chat(user, "You remove the turret's interior metal armor.")
					new /obj/item/stack/material/steel(loc, 2)
					return

		if(3)
			if(istype(I, /obj/item/weapon/gun/energy)) //the gun installation part

				if(isrobot(user))
					return
				var/obj/item/weapon/gun/energy/E = I //typecasts the item to an energy gun
				if(!user.unEquip(I))
					to_chat(user, "<span class='notice'>\the [I] is stuck to your hand, you cannot put it in \the [src]</span>")
					return
				installation = I.type //installation becomes I.type
				gun_charge = E.power_supply.charge //the gun's charge is stored in gun_charge
				to_chat(user, "<span class='notice'>You add [I] to the turret.</span>")
				target_type = /obj/machinery/porta_turret

				build_step = 4
				qdel(I) //delete the gun :(
				return

			else if(I.is_wrench())
				playsound(loc, I.usesound, 100, 1)
				to_chat(user, "<span class='notice'>You remove the turret's metal armor bolts.</span>")
				build_step = 2
				return

		if(4)
			if(isprox(I))
				build_step = 5
				if(!user.unEquip(I))
					to_chat(user, "<span class='notice'>\the [I] is stuck to your hand, you cannot put it in \the [src]</span>")
					return
				to_chat(user, "<span class='notice'>You add the prox sensor to the turret.</span>")
				qdel(I)
				return

			//attack_hand() removes the gun

		if(5)
			if(I.is_screwdriver())
				playsound(loc, I.usesound, 100, 1)
				build_step = 6
				to_chat(user, "<span class='notice'>You close the internal access hatch.</span>")
				return

			//attack_hand() removes the prox sensor

		if(6)
			if(istype(I, /obj/item/stack/material) && I.get_material_name() == DEFAULT_WALL_MATERIAL)
				var/obj/item/stack/M = I
				if(M.use(2))
					to_chat(user, "<span class='notice'>You add some metal armor to the exterior frame.</span>")
					build_step = 7
				else
					to_chat(user, "<span class='warning'>You need two sheets of metal to continue construction.</span>")
				return

			else if(I.is_screwdriver())
				playsound(loc, I.usesound, 100, 1)
				build_step = 5
				to_chat(user, "<span class='notice'>You open the internal access hatch.</span>")
				return

		if(7)
			if(istype(I, /obj/item/weapon/weldingtool))
				var/obj/item/weapon/weldingtool/WT = I
				if(!WT.isOn()) return
				if(WT.get_fuel() < 5)
					to_chat(user, "<span class='notice'>You need more fuel to complete this task.</span>")

				playsound(loc, WT.usesound, 50, 1)
				if(do_after(user, 30 * WT.toolspeed))
					if(!src || !WT.remove_fuel(5, user))
						return
					build_step = 8
					to_chat(user, "<span class='notice'>You weld the turret's armor down.</span>")

					//The final step: create a full turret
					var/obj/machinery/porta_turret/Turret = new target_type(loc)
					Turret.name = finish_name
					Turret.installation = installation
					Turret.gun_charge = gun_charge
					Turret.enabled = 0
					Turret.setup()

					qdel(src) // qdel

			else if(I.is_crowbar())
				playsound(loc, I.usesound, 75, 1)
				to_chat(user, "<span class='notice'>You pry off the turret's exterior armor.</span>")
				new /obj/item/stack/material/steel(loc, 2)
				build_step = 6
				return

	if(istype(I, /obj/item/weapon/pen))	//you can rename turrets like bots!
		var/t = sanitizeSafe(input(user, "Enter new turret name", name, finish_name) as text, MAX_NAME_LEN)
		if(!t)
			return
		if(!in_range(src, usr) && loc != usr)
			return

		finish_name = t
		return

	..()

/obj/machinery/porta_turret_construct/attack_hand(mob/user)
	switch(build_step)
		if(4)
			if(!installation)
				return
			build_step = 3

			var/obj/item/weapon/gun/energy/Gun = new installation(loc)
			Gun.power_supply.charge = gun_charge
			Gun.update_icon()
			installation = null
			gun_charge = 0
			to_chat(user, "<span class='notice'>You remove [Gun] from the turret frame.</span>")

		if(5)
			to_chat(user, "<span class='notice'>You remove the prox sensor from the turret frame.</span>")
			new /obj/item/device/assembly/prox_sensor(loc)
			build_step = 4

/obj/machinery/porta_turret_construct/attack_ai()
	return

/atom/movable/porta_turret_cover
	icon = 'icons/obj/turrets.dmi'

#undef TURRET_PRIORITY_TARGET
#undef TURRET_SECONDARY_TARGET
#undef TURRET_NOT_TARGET



/datum/reagent
	var/name = "Reagent"
	var/id = "reagent"
	var/description = "A non-descript chemical."
	var/taste_description = "bitterness"
	var/taste_mult = 1 //how this taste compares to others. Higher values means it is more noticable
	var/datum/reagents/holder = null
	var/reagent_state = SOLID
	var/list/data = null
	var/volume = 0
	var/metabolism = REM // This would be 0.2 normally
	var/list/filtered_organs = list()	// Organs that will slow the processing of this chemical.
	var/mrate_static = FALSE	//If the reagent should always process at the same speed, regardless of species, make this TRUE
	var/ingest_met = 0
	var/touch_met = 0
	var/dose = 0
	var/max_dose = 0
	var/overdose = 0		//Amount at which overdose starts
	var/overdose_mod = 2	//Modifier to overdose damage
	var/scannable = 0 // Shows up on health analyzers.
	var/affects_dead = 0
	var/cup_icon_state = null
	var/cup_name = null
	var/cup_desc = null
	var/cup_center_of_mass = null

	var/color = "#000000"
	var/color_weight = 1

	var/glass_icon = DRINK_ICON_DEFAULT
	var/glass_name = "something"
	var/glass_desc = "It's a glass of... what, exactly?"
	var/list/glass_special = null // null equivalent to list()

/datum/reagent/proc/remove_self(var/amount) // Shortcut
	if(holder)
		holder.remove_reagent(id, amount)

// This doesn't apply to skin contact - this is for, e.g. extinguishers and sprays. The difference is that reagent is not directly on the mob's skin - it might just be on their clothing.
/datum/reagent/proc/touch_mob(var/mob/M, var/amount)
	return

/datum/reagent/proc/touch_obj(var/obj/O, var/amount) // Acid melting, cleaner cleaning, etc
	return

/datum/reagent/proc/touch_turf(var/turf/T, var/amount) // Cleaner cleaning, lube lubbing, etc, all go here
	return

/datum/reagent/proc/on_mob_life(var/mob/living/carbon/M, var/alien, var/datum/reagents/metabolism/location) // Currently, on_mob_life is called on carbons. Any interaction with non-carbon mobs (lube) will need to be done in touch_mob.
	if(!istype(M))
		return
	if(!affects_dead && M.stat == DEAD)
		return
	if(!istype(location))
		return

	var/datum/reagents/metabolism/active_metab = location
	var/removed = metabolism

	if(!mrate_static == TRUE)
		// Modifiers
		for(var/datum/modifier/mod in M.modifiers)
			if(!isnull(mod.metabolism_percent))
				removed *= mod.metabolism_percent
		// Species
		removed *= M.species.metabolic_rate
		// Metabolism
		removed *= active_metab.metabolism_speed

		if(ishuman(M))
			var/mob/living/carbon/human/H = M
			if(H.species.has_organ[O_HEART])
				var/obj/item/organ/internal/heart/Pump = H.internal_organs_by_name[O_HEART]
				if(!Pump)
					removed *= 0.1
				else if(Pump.standard_pulse_level == PULSE_NONE)	// No pulse normally means chemicals process a little bit slower than normal.
					removed *= 0.8
				else	// Otherwise, chemicals process as per percentage of your current pulse, or, if you have no pulse but are alive, by a miniscule amount.
					removed *= max(0.1, H.pulse / Pump.standard_pulse_level)
			if(filtered_organs && filtered_organs.len)
				for(var/organ_tag in filtered_organs)
					var/obj/item/organ/internal/O = H.internal_organs_by_name[organ_tag]
					if(O && !O.is_broken() && prob(max(0, O.max_damage - O.damage)))
						removed *= 0.8

	if(ingest_met && (active_metab.metabolism_class == CHEM_INGEST))
		removed = ingest_met
	if(touch_met && (active_metab.metabolism_class == CHEM_TOUCH))
		removed = touch_met
	removed = min(removed, volume)
	max_dose = max(volume, max_dose)
	dose = min(dose + removed, max_dose)
	if(removed >= (metabolism * 0.1) || removed >= 0.1) // If there's too little chemical, don't affect the mob, just remove it
		switch(active_metab.metabolism_class)
			if(CHEM_BLOOD)
				affect_blood(M, alien, removed)
			if(CHEM_INGEST)
				affect_ingest(M, alien, removed)
			if(CHEM_TOUCH)
				affect_touch(M, alien, removed)
	if(overdose && (volume > overdose) && (active_metab.metabolism_class != CHEM_TOUCH))
		overdose(M, alien, removed)
	remove_self(removed)
	return

/datum/reagent/proc/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	return

/datum/reagent/proc/affect_ingest(var/mob/living/carbon/M, var/alien, var/removed)
	M.bloodstr.add_reagent(id, removed)
	return

/datum/reagent/proc/affect_touch(var/mob/living/carbon/M, var/alien, var/removed)
	return

/datum/reagent/proc/overdose(var/mob/living/carbon/M, var/alien, var/removed) // Overdose effect.
	if(alien == IS_DIONA)
		return
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		overdose_mod *= H.species.chemOD_mod
	M.adjustToxLoss(removed * overdose_mod)

/datum/reagent/proc/initialize_data(var/newdata) // Called when the reagent is created.
	if(!isnull(newdata))
		data = newdata
	return

/datum/reagent/proc/mix_data(var/newdata, var/newamount) // You have a reagent with data, and new reagent with its own data get added, how do you deal with that?
	return

/datum/reagent/proc/get_data() // Just in case you have a reagent that handles data differently.
	if(data && istype(data, /list))
		return data.Copy()
	else if(data)
		return data
	return null

/datum/reagent/Destroy() // This should only be called by the holder, so it's already handled clearing its references
	holder = null
	. = ..()

/* DEPRECATED - TODO: REMOVE EVERYWHERE */

/datum/reagent/proc/reaction_turf(var/turf/target)
	touch_turf(target)

/datum/reagent/proc/reaction_obj(var/obj/target)
	touch_obj(target)

/datum/reagent/proc/reaction_mob(var/mob/target)
	touch_mob(target)

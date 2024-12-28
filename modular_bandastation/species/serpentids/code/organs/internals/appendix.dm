
/obj/item/organ/appendix/serpentid
	name = "food processor"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	icon_state = "kidneys"
	desc = "A large looking appendix."

/obj/item/organ/appendix/serpentid/on_life(seconds_per_tick, times_fired)
	. = ..()
	for(var/datum/disease/illness in owner.diseases)
		illness.update_stage(max(illness.stage - 1, 1))
		if(illness.disease_flags & CURABLE && illness.stage == 1)
			illness.cure()

#define SERPENTID_EARS_SENSE_TIME 5 SECONDS

//Уши серпентидов позволяют постоянно сканировать окружение в поисках существ в зависимости от их состояния
/obj/item/organ/ears/serpentid
	name = "acoustic sensor"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	icon_state = "ears"
	desc = "An organ that can sense vibrations."
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	var/chemical_consuption = SERPENTID_ORGAN_HUNGER_EARS
	var/active = FALSE
	radial_action_state = "serpentid_hear"
	radial_action_icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'

/obj/item/organ/ears/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/organ_toxin_damage, 0.05)
	AddComponent(/datum/component/hunger_organ)
	AddComponent(/datum/component/organ_action, radial_action_state, radial_action_icon)

/obj/item/organ/ears/serpentid/on_life()
	. = ..()
	if(chemical_consuption <= owner?.nutrition && active)
		damage_multiplier = 2
		if(prob(((maxHealth - damage)/maxHealth) * 100))
			sense_creatures()
	else
		damage_multiplier = 1

/obj/item/organ/ears/serpentid/switch_mode(force_off = FALSE)
	. = ..()
	if(!force_off && owner?.nutrition >= NUTRITION_LEVEL_STARVING && !(organ_flags & ORGAN_FAILING) && !active)
		active = TRUE
		chemical_consuption = initial(chemical_consuption)
	else
		active = FALSE
		chemical_consuption = 0
	SEND_SIGNAL(src, COMSIG_ORGAN_CHANGE_CHEM_CONSUPTION, chemical_consuption)

/obj/item/organ/ears/serpentid/proc/sense_creatures()
	for(var/mob/living/creature in range(9, owner))
		var/last_movement_timer = world.time - creature.last_pushoff
		if(creature == owner || creature.stat == DEAD || last_movement_timer > SERPENTID_EARS_SENSE_TIME)
			continue
		new /obj/effect/temp_visual/sonar_ping(owner.loc, owner, creature)

#undef SERPENTID_EARS_SENSE_TIME

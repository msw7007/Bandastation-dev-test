/obj/item/organ/stomach/serpentid
	name = "food processor"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	icon_state = "kidneys"
	desc = "A large looking stomatch."
	hunger_modifier = 1.3

/obj/item/organ/stomach/serpentid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/organ_toxin_damage, 0.1)

/obj/item/organ/stomach/serpentid/handle_hunger(mob/living/carbon/human/human, seconds_per_tick, times_fired)
	. = ..()
	if(human.nutrition > NUTRITION_LEVEL_HUNGRY && owner.reagents.has_reagent(/datum/reagent/consumable/cabbagilium))
		for(var/datum/wound/carapace_damaged/potentail_wound in owner.all_wounds)
			if(ispath(potentail_wound, /datum/wound/carapace_damaged))
				potentail_wound.carapace_damage_value -= 1

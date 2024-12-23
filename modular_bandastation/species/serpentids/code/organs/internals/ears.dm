/obj/item/organ/ears/serpentid
	desc = "Большие ушки позволяют легче слышать шепот."
	damage_multiplier = 2

/obj/item/organ/ears/serpentid/on_mob_insert(mob/living/carbon/ear_owner)
	. = ..()
	ADD_TRAIT(ear_owner, TRAIT_GOOD_HEARING, ORGAN_TRAIT)

/obj/item/organ/ears/serpentid/on_mob_remove(mob/living/carbon/ear_owner)
	. = ..()
	REMOVE_TRAIT(ear_owner, TRAIT_GOOD_HEARING, ORGAN_TRAIT)

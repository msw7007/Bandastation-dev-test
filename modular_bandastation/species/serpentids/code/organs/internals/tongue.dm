/obj/item/organ/tongue/serpentid
	name = "serpentid vocal cords"
	desc = "Short and spliced tongue"
	icon = 'modular_bandastation/species/serpentids/icons/organs.dmi'
	icon_state = "tongue"
	taste_sensitivity = 10
	modifies_speech = FALSE
	languages_native = list(/datum/language/canilunzt)
	liked_foodtypes = RAW | MEAT | SEAFOOD
	disliked_foodtypes =  FRUIT | NUTS | GROSS | GRAIN

/obj/item/organ/tongue/serpentid/get_possible_languages()
	return ..() + /datum/language/nabberian

/obj/item/organ/tongue/serpentid/on_mob_insert(mob/living/carbon/owner)
	. = ..()
	add_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_serpentidroar)
	add_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_serpentidhiss)
	add_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_serpentidwiggle)

/obj/item/organ/tongue/serpentid/on_mob_remove(mob/living/carbon/owner)
	. = ..()
	remove_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_serpentidroar)
	remove_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_serpentidhiss)
	remove_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_serpentidwiggle)

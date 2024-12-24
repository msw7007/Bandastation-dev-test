/obj/item/organ/tongue/serpentid
	name = "Длинный язык"
	desc = "Длинный и более чувствительный язык, может различить больше вкусов"
	icon_state = "tongue"
	taste_sensitivity = 10
	modifies_speech = FALSE
	languages_native = list(/datum/language/canilunzt)
	liked_foodtypes = RAW | MEAT | SEAFOOD
	disliked_foodtypes =  FRUIT | NUTS | GROSS | GRAIN

/obj/item/organ/tongue/serpentid/get_possible_languages()
	return ..() + /datum/language/canilunzt

/obj/item/organ/tongue/serpentid/on_mob_insert(mob/living/carbon/owner)
	. = ..()
	add_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_howl)
	add_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_growl)
	add_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_purr)
	add_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_bark)
	add_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_wbark)

/obj/item/organ/tongue/serpentid/on_mob_remove(mob/living/carbon/owner)
	. = ..()
	remove_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_howl)
	remove_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_growl)
	remove_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_purr)
	remove_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_bark)
	remove_verb(owner, /mob/living/carbon/human/species/serpentid/proc/emote_wbark)

/obj/item/organ/internal/vocal_cords/serpentid
	name = "serpentid vocal cords"
















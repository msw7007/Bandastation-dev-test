/datum/emote/living/carbon/human/serpentid/can_run_emote(mob/user, status_check = TRUE, intentional = FALSE)
	var/organ = user.get_organ_slot(ORGAN_SLOT_TONGUE)
	if(istype(organ, /obj/item/organ/tongue/serpentid))
		return ..()

/datum/emote/living/carbon/human/serpentid/serpentidroar
	key = "serpentidroar"
	key_third_person = "serpentidroar"
	message = "утробно рычит."
	message_mime = "бесшумно рычит."
	message_param = "утробно рычит на %t."
	sound = "modular_bandastation/species/serpentids/sounds/serpentid_roar.ogg"

/datum/emote/living/carbon/human/serpentid/serpentidhiss
	key = "serpentidhiss"
	key_third_person = "serpentidhisses"
	message = "шипит."
	message_param = "шипит на %t."
	sound = "modular_bandastation/species/serpentids/sounds/serpentid_hiss.ogg"

/datum/emote/living/carbon/human/serpentid/serpentidwiggles
	key = "serpentidwiggles"
	key_third_person = "serpentidwiggles"
	message = "шевелит усиками."
	message_param = "шевелит усиками в сторону %t."
	cooldown = 5 SECONDS
	sound = 'modular_bandastation/species/serpentids/sounds/serpentid_tendrils.ogg'

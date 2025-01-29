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

/datum/emote/living/carbon/human/serpentidblinks
	key = "serpentidblinks"
	key_third_person = "serpentidblinks"
	message = "опускает и поднимает глазные щитки."
	message_param = "опускает и поднимает глазные щитки, смотря на %t."
	sound = null

/datum/emote/living/carbon/human/serpentidblinksblades
	key = "serpentidblinksblades"
	key_third_person = "serpentidblinksblades"
	message = "прочищает глаза краями лезвий."
	message_param = "прочищает глаза краями лезвий, смотря на %t."
	sound = null

/datum/emote/living/carbon/human/serpentidbuzzes
	key = "serpentidbuzzes"
	key_third_person = "serpentidbuzzes"
	message = "слегка вибрирует спинным панцирем."
	message_param = "слегка вибрирует спинным панцирем в сторону %t."
	cooldown = 5 SECONDS
	sound = 'modular_bandastation/species/serpentids/sounds/scream_moth.ogg'

/datum/emote/living/carbon/human/serpentidmandibles
	key = "serpentidmandibles"
	key_third_person = "serpentidmandibles"
	message = "стучит мандибулами"
	message_param = "стучит мандибулами в сторону %t."
	cooldown = 5 SECONDS
	sound = 'modular_bandastation/species/serpentids/sounds/Kidanclack.ogg'

/datum/emote/living/carbon/human/serpentidblades
	key = "serpentidblades"
	key_third_person = "serpentidblades"
	message = "стучит лезвиями."
	message_param = "стучит лезвиями в сторону %t."
	cooldown = 5 SECONDS
	sound = 'sound/items/weapons/blade1.ogg'

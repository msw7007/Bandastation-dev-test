/// serpentid TAIL

/obj/item/organ/tail/serpentid
	name = "serpentid tail"
	preference = "feature_serpentid_tail"

	//bodypart_overlay = /datum/bodypart_overlay/mutant/tail/serpentid

	wag_flags = WAG_ABLE
	var/datum/bodypart_overlay/mutant/serpentid_tail_markings/tail_markings_overlay

/obj/item/organ/tail/serpentid/on_mob_insert(mob/living/carbon/owner)
	. = ..()
	add_verb(owner, /mob/living/carbon/human/proc/emote_wag)

/obj/item/organ/tail/serpentid/on_mob_remove(mob/living/carbon/owner)
	. = ..()
	remove_verb(owner, /mob/living/carbon/human/proc/emote_wag)

/datum/bodypart_overlay/mutant/tail/serpentid
	feature_key = "tail_serpentid"

/datum/bodypart_overlay/mutant/tail/serpentid/get_global_feature_list()
	return SSaccessories.tails_list_serpentid

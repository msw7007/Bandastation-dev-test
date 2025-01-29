#define ORGAN_SLOT_EXTERNAL_SERPENBLADES "serpenblades"

/datum/mood_event/blades_lost
	description = "My blades!! Why?!"
	mood_change = -8
	timeout = 10 MINUTES

/datum/mood_event/blades_regained_wrong
	description = "Is blades some kind of sick joke?! This is NOT the right tail."
	mood_change = -12 // -8 for tail still missing + -4 bonus for being frakenstein's monster
	timeout = 5 MINUTES

/datum/mood_event/blades_regained_species
	description = "This blades is not mine, but at least it balances me out..."
	mood_change = -5
	timeout = 5 MINUTES

/datum/mood_event/blades_regained_right
	description = "My blades is back, but that was traumatic..."
	mood_change = -2
	timeout = 5 MINUTES

/obj/item/organ/serpenblades
	name = "serpentid blades"
	desc = "A severed tail. What did you cut this off of?"
	icon_state = "severedtail"

	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_EXTERNAL_TAIL

	dna_block = DNA_MUTANT_COLOR_BLOCK
	restyle_flags = EXTERNAL_RESTYLE_FLESH

	// defaults to cat, but the parent type shouldn't be created regardless
	bodypart_overlay = /datum/bodypart_overlay/mutant/tail/cat

	organ_flags = parent_type::organ_flags | ORGAN_EXTERNAL

	///Does this tail have a wagging sprite, and is it currently wagging?
	var/wag_flags = NONE
	///The original owner of this tail
	var/original_owner //Yay, snowflake code!
	///The overlay for tail spines, if any
	var/datum/bodypart_overlay/mutant/serpenblades_spines/blades_spines_overlay

/obj/item/organ/serpenblades/on_mob_insert(mob/living/carbon/receiver, special, movement_flags)
	. = ..()
	receiver.clear_mood_event("blades_lost")

	if(!special) // if some admin wants to give someone tail moodles for tail shenanigans, they can spawn it and do it by hand
		original_owner ||= WEAKREF(receiver)

		// If it's your blades, an infinite debuff is replaced with a timed one
		// If it's not your blades but of same species, I guess it works, but we are more sad
		// If it's not your blades AND of different species, we are horrified
		if(IS_WEAKREF_OF(receiver, original_owner))
			receiver.add_mood_event("blades_regained", /datum/mood_event/tail_regained_right)
		else if(type in receiver.dna.species.mutant_organs)
			receiver.add_mood_event("blades_regained", /datum/mood_event/tail_regained_species)
		else
			receiver.add_mood_event("blades_regained", /datum/mood_event/tail_regained_wrong)

/obj/item/organ/serpenblades/on_bodypart_insert(obj/item/bodypart/bodypart)
	var/obj/item/organ/spines/our_spines = bodypart.owner.get_organ_slot(ORGAN_SLOT_EXTERNAL_SPINES)
	if(our_spines)
		try_insert_blades_spines(bodypart)
	return ..()

/obj/item/organ/serpenblades/on_bodypart_remove(obj/item/bodypart/bodypart)
	remove_blades_spines(bodypart)
	return ..()

/// If the owner has spines and an appropriate overlay exists, add a tail spines overlay.
/obj/item/organ/serpenblades/proc/try_insert_blades_spines(obj/item/bodypart/bodypart)
	// Don't insert another overlay if there already is one.
	if(blades_spines_overlay)
		return
	// If this tail doesn't have a valid set of tail spines, don't insert them
	var/datum/sprite_accessory/serpenblades/blades_sprite_datum = bodypart_overlay.sprite_datum
	if(!istype(blades_sprite_datum))
		return
	var/blades_spine_key = blades_sprite_datum.spine_key
	if(!blades_spine_key)
		return

	blades_spines_overlay = new
	blades_spines_overlay.blades_spine_key = blades_spine_key
	var/feature_name = bodypart.owner.dna.features["spines"] //tail spines don't live in DNA, but share feature names with regular spines
	blades_spines_overlay.set_appearance_from_name(feature_name)
	bodypart.add_bodypart_overlay(blades_spines_overlay)

/// If we have a tail spines overlay, delete it
/obj/item/organ/serpenblades/proc/remove_blades_spines(obj/item/bodypart/bodypart)
	if(!blades_spines_overlay)
		return
	bodypart.remove_bodypart_overlay(blades_spines_overlay)
	QDEL_NULL(blades_spines_overlay)

/obj/item/organ/serpenblades/on_mob_remove(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()

	organ_owner.clear_mood_event("blades_regained")

	if(type in organ_owner.dna.species.mutant_organs)
		organ_owner.add_mood_event("blades_lost", /datum/mood_event/tail_lost)

///Tail parent type, with wagging functionality
/datum/bodypart_overlay/mutant/serpenblades
	layers = EXTERNAL_FRONT|EXTERNAL_BEHIND
	dyable = TRUE
	var/wagging = FALSE

/datum/bodypart_overlay/mutant/serpenblades/get_base_icon_state()
	return "[wagging ? "wagging_" : ""][sprite_datum.icon_state]" //add the wagging tag if we be wagging

/datum/bodypart_overlay/mutant/serpenblades/can_draw_on_bodypart(mob/living/carbon/human/human)
	if(human.wear_suit && (human.wear_suit.flags_inv & HIDEJUMPSUIT))
		return FALSE
	return TRUE

///Cat tail bodypart overlay
/datum/bodypart_overlay/mutant/serpenblades
	feature_key = "tail_cat"
	color_source = ORGAN_COLOR_HAIR

/datum/bodypart_overlay/mutant/serpenblades/get_global_feature_list()
	return SSaccessories.serpenblades

///Bodypart overlay for tail spines. Handled by the tail - has no actual organ associated.
/datum/bodypart_overlay/mutant/serpenblades_spines
	layers = EXTERNAL_ADJACENT|EXTERNAL_BEHIND
	feature_key = "tailspines"
	///Spines wag when the tail does
	var/wagging = FALSE
	/// Key for tail spine states, depends on the shape of the tail. Defined in the tail sprite datum.
	var/blades_spine_key = NONE

/datum/bodypart_overlay/mutant/serpenblades_spines/get_global_feature_list()
	return SSaccessories.serpenblades

/datum/bodypart_overlay/mutant/serpenblades_spines/get_base_icon_state()
	return (!isnull(blades_spine_key) ? "[blades_spine_key]_" : "") + (wagging ? "wagging_" : "") + sprite_datum.icon_state // Select the wagging state if appropriate

/datum/bodypart_overlay/mutant/serpenblades_spines/can_draw_on_bodypart(mob/living/carbon/human/human)
	. = ..()
	if(human.wear_suit && (human.wear_suit.flags_inv & HIDEJUMPSUIT))
		return FALSE

/datum/bodypart_overlay/mutant/serpenblades_spines/set_dye_color(new_color, obj/item/organ/organ)
	dye_color = new_color //no update_body_parts() call, tail/set_dye_color will do it.

/datum/bodypart_overlay/mutant/serpenblades/serpentid
	feature_key = "tail_serpentid"

/datum/bodypart_overlay/mutant/serpenblades/serpentid/get_global_feature_list()
	return SSaccessories.tails_list_serpentid

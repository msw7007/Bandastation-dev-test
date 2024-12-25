//////////////////////////////////////////////////////////////////
//					Хирургия для панциря						//
//////////////////////////////////////////////////////////////////
/datum/surgery/carapace
	name = "Parent Surgery"
	possible_locs = list()

/datum/surgery/carapace/break_shell
	name = "Break carapace"
	possible_locs = list(BODY_ZONE_CHEST, BODY_ZONE_HEAD, BODY_ZONE_PRECISE_GROIN, BODY_ZONE_PRECISE_EYES, BODY_ZONE_PRECISE_MOUTH, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_R_LEG, BODY_ZONE_L_LEG,)
	steps = list(
		/datum/surgery_step/saw,
		/datum/surgery_step/incise,
		/datum/surgery_step/retract_carapace
	)

/datum/surgery/carapace/shell_repair
	name = "Carapace Integrity Repair"
	steps = list(
		/datum/surgery_step/saw,
		/datum/surgery_step/incise,
		/datum/surgery_step/retract_carapace,
		/datum/surgery_step/mend_carapace,
		/datum/surgery_step/close
	)
	possible_locs = list(BODY_ZONE_CHEST)

/datum/surgery/carapace/gastrectomy
	name = "Carapace gastrectomy"
	surgery_flags = SURGERY_REQUIRE_RESTING | SURGERY_REQUIRE_LIMB | SURGERY_REQUIRES_REAL_LIMB
	organ_to_manipulate = ORGAN_SLOT_STOMACH
	steps = list(
		/datum/surgery_step/saw,
		/datum/surgery_step/clamp_bleeders,
		/datum/surgery_step/incise,
		/datum/surgery_step/gastrectomy,
		/datum/surgery_step/clamp_bleeders,
	)
	possible_locs = list(BODY_ZONE_CHEST)

/datum/surgery/carapace/coronary_bypass
	name = "Carapace coronary bypass"
	surgery_flags = SURGERY_REQUIRE_RESTING | SURGERY_REQUIRE_LIMB | SURGERY_REQUIRES_REAL_LIMB
	organ_to_manipulate = ORGAN_SLOT_HEART
	steps = list(
		/datum/surgery_step/saw,
		/datum/surgery_step/clamp_bleeders,
		/datum/surgery_step/incise,
		/datum/surgery_step/incise_heart,
		/datum/surgery_step/coronary_bypass,
	)
	possible_locs = list(BODY_ZONE_CHEST)

/datum/surgery/carapace/lobectomy
	name = "Carapace lobectomy"
	surgery_flags = SURGERY_REQUIRE_RESTING | SURGERY_REQUIRE_LIMB | SURGERY_REQUIRES_REAL_LIMB
	organ_to_manipulate = ORGAN_SLOT_LUNGS
	steps = list(
		/datum/surgery_step/saw,
		/datum/surgery_step/clamp_bleeders,
		/datum/surgery_step/incise,
		/datum/surgery_step/lobectomy,
	)
	possible_locs = list(BODY_ZONE_CHEST)

/datum/surgery/carapace/hepatectomy
	name = "Carapace hepatectomy"
	surgery_flags = SURGERY_REQUIRE_RESTING | SURGERY_REQUIRE_LIMB | SURGERY_REQUIRES_REAL_LIMB
	organ_to_manipulate = ORGAN_SLOT_LIVER
	steps = list(
		/datum/surgery_step/saw,
		/datum/surgery_step/clamp_bleeders,
		/datum/surgery_step/incise,
		/datum/surgery_step/hepatectomy,
	)
	possible_locs = list(BODY_ZONE_CHEST)

/datum/surgery/carapace/organ_manipulation
	name = "Organ Manipulation"
	steps = list(
		/datum/surgery_step/saw,
		/datum/surgery_step/clamp_bleeders,
		/datum/surgery_step/incise,
		/datum/surgery_step/manipulate_organs/internal,
	)
	possible_locs = list(BODY_ZONE_CHEST, BODY_ZONE_HEAD, BODY_ZONE_PRECISE_GROIN, BODY_ZONE_PRECISE_EYES, BODY_ZONE_PRECISE_MOUTH, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_R_LEG, BODY_ZONE_L_LEG,)

/datum/surgery/carapace/revival
	name = "Revival"
	desc = "An experimental surgical procedure which involves reconstruction and reactivation of the patient's brain even long after death. \
		The body must still be able to sustain life."
	possible_locs = list(BODY_ZONE_CHEST)
	target_mobtypes = list(/mob/living)
	surgery_flags = SURGERY_REQUIRE_RESTING | SURGERY_MORBID_CURIOSITY
	steps = list(
		/datum/surgery_step/clamp_bleeders,
		/datum/surgery_step/incise,
		/datum/surgery_step/revive,
	)

/datum/surgery/carapace/brain_surgery
	name = "Brain surgery"
	possible_locs = list(BODY_ZONE_HEAD)
	steps = list(
		/datum/surgery_step/clamp_bleeders,
		/datum/surgery_step/fix_brain,
	)

/datum/surgery/carapace/ear_surgery
	name = "Ear surgery"
	requires_bodypart_type = NONE
	organ_to_manipulate = ORGAN_SLOT_EARS
	possible_locs = list(BODY_ZONE_HEAD)
	steps = list(
		/datum/surgery_step/clamp_bleeders,
		/datum/surgery_step/fix_ears,
	)

/datum/surgery/carapace/eye_surgery
	name = "Eye surgery"
	requires_bodypart_type = NONE
	organ_to_manipulate = ORGAN_SLOT_EYES
	possible_locs = list(BODY_ZONE_PRECISE_EYES)
	steps = list(
		/datum/surgery_step/clamp_bleeders,
		/datum/surgery_step/fix_eyes,
	)

/datum/surgery/carapace/repair_shell
	name = "Carapace Repair"
	steps = list(
		/datum/surgery_step/set_carapace,
		/datum/surgery_step/mend_carapace,
		/datum/surgery_step/close
	)
	possible_locs = list(BODY_ZONE_CHEST, BODY_ZONE_HEAD, BODY_ZONE_PRECISE_GROIN, BODY_ZONE_PRECISE_EYES, BODY_ZONE_PRECISE_MOUTH, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_R_LEG, BODY_ZONE_L_LEG,)

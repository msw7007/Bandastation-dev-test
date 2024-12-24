//////////////////////////////////////////////////////////////////
//					Хирургия для панциря						//
//////////////////////////////////////////////////////////////////
///Датумы для операций
/datum/surgery/carapace_break
	name = "Break carapace"
	steps = list(
		/datum/surgery_step/saw_carapace,
		/datum/surgery_step/cut_carapace,
		/datum/surgery_step/retract_carapace
	)

	possible_locs = list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_R_HAND, BODY_ZONE_R_LEG, BODY_ZONE_PRECISE_R_FOOT, BODY_ZONE_L_LEG, BODY_ZONE_PRECISE_L_FOOT, BODY_ZONE_PRECISE_GROIN)
	requires_organic_bodypart = TRUE

/datum/surgery/organ_manipulation/carapace
	name = "Organ Manipulation"
	steps = list(
		/datum/surgery_step/open_encased/retract,
		/datum/surgery_step/proxy/manipulate_organs,
		/datum/surgery_step/internal/manipulate_organs/finish,
	)
	possible_locs = list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_R_HAND, BODY_ZONE_R_LEG, BODY_ZONE_PRECISE_R_FOOT, BODY_ZONE_L_LEG, BODY_ZONE_PRECISE_L_FOOT, BODY_ZONE_PRECISE_GROIN)
	requires_organic_bodypart = TRUE

/datum/surgery/bone_repair/carapace
	name = "Carapace Repair"
	steps = list(
		/datum/surgery_step/glue_bone,
		/datum/surgery_step/set_bone,
		/datum/surgery_step/finish_bone,
		/datum/surgery_step/generic/cauterize
	)
	possible_locs = list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_R_HAND, BODY_ZONE_R_LEG, BODY_ZONE_PRECISE_R_FOOT, BODY_ZONE_L_LEG, BODY_ZONE_PRECISE_L_FOOT, BODY_ZONE_PRECISE_GROIN)
	requires_organic_bodypart = TRUE

//Оверрайды для операций, которые могут применяться для панциря.
//Возможный рефактор - отослать сигнал в компоненнт с параметрами "операция, зона операции" и вернуть значение оттуда?
/datum/surgery/can_start(mob/user, mob/living/carbon/target)
	var/obj/item/organ/external/affected = target.get_organ(user.zone_selected)
	if(affected?.encased == CARAPACE_ENCASE_WORD)
		if((src.type in CARAPACE_BLOCK_OPERATION) || !(affected.status & ORGAN_BROKEN)) //отключить стандартные операции класса "манипуляция органов", восстановить кость/череп.
			return FALSE
	. = .. ()

//Общие операции - проверка, на доступной карапасовых карапасовым и vice versa
/datum/surgery/bone_repair/can_start(mob/user, mob/living/carbon/target)
	var/obj/item/organ/external/affected = target.get_organ(user.zone_selected)
	if(affected?.encased == CARAPACE_ENCASE_WORD)
		return FALSE
	. = .. ()

//Чинить карапас можно если он сломан
/datum/surgery/bone_repair/carapace/can_start(mob/user, mob/living/carbon/target)
	var/obj/item/organ/external/affected = target.get_organ(user.zone_selected)
	if((affected?.encased == CARAPACE_ENCASE_WORD) && (affected.status & ORGAN_BROKEN))
		return TRUE
	return FALSE

//Ломать карапас можно если он цел
/datum/surgery/carapace_break/can_start(mob/user, mob/living/carbon/target)
	var/obj/item/organ/external/affected = target.get_organ(user.zone_selected)
	if((affected?.encased == CARAPACE_ENCASE_WORD) && !(affected.status & ORGAN_BROKEN))
		return TRUE
	return FALSE

//Манипуляция органов возможна если карапас и он сломан
/datum/surgery/organ_manipulation/carapace/can_start(mob/user, mob/living/carbon/target)
	var/obj/item/organ/external/affected = target.get_organ(user.zone_selected)
	if((affected?.encased == CARAPACE_ENCASE_WORD) && (affected.status & ORGAN_BROKEN))
		return TRUE
	return FALSE

//Блокировка простого скальпеля (базовый начальный шаг любой операции), если карапас не был сломан, но появилась какая-то операция, которая не должна быть
/datum/surgery_step/generic/cut_open/begin_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, datum/surgery/surgery)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	if((affected?.encased == CARAPACE_ENCASE_WORD) && !(affected.status & ORGAN_BROKEN))
		to_chat(user, span_notice("[capitalize(target.declent_ru(NOMINATIVE))] покрыта крепким хитином. Сломайте его, прежде чем начать операцию."))
		return SURGERY_BEGINSTEP_ABORT
	. = .. ()

/datum/surgery_step/retract_carapace/end_step(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	var/obj/item/organ/external/affected = target.get_organ(user.zone_selected)
	if((affected?.encased == CARAPACE_ENCASE_WORD) && !(affected.status & ORGAN_BROKEN))
		affected.fracture()
	. = .. ()

/datum/surgery_step/set_bone/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(user.zone_selected)
	if((affected?.encased == CARAPACE_ENCASE_WORD) && !(affected.status & ORGAN_BROKEN))
		affected.mend_fracture()
	. = .. ()

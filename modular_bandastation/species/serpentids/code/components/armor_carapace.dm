/*
===Модуль панциря (карапаса)
Цепляется на конечность. Особенность в том, что изначально придает конечности усиленную броню, но по достиженю трешхолда слома (устаналивается тут) конечность ломается

Сломанная конечность увеличивает входящий по ней урон. Считает и брут и берн уроны. В случае получения берн урона процент урона переносится на органы.area

Сопротивление/уязвимость к урону ожогами всегда ниже/выше сопротивления травмам.

Панцирь блокирует стандартные операции, пока не будет сломан.

Панцирь самовосстановится, если полностью вылечить конечность. Но есть параметр, который разрешает 100% или иное заживление при исцелении урона конечности.
*/
#define CARAPACE_OPEN_THRESHOLD 30
//Вероятность восстановления конечности при достижении 0 урона
#define CARAPACE_HEAL_BROKEN_PROB 50
//Список операций, которые будут заблокированы пока панцирь не будет сломан
#define CARAPACE_BLOCK_OPERATION list( /datum/surgery/revival, /datum/surgery/brain_surgery, /datum/surgery/ear_surgery, /datum/surgery/eye_surgery, /datum/surgery/organ_manipulation, /datum/surgery/hepatectomy, /datum/surgery/lobectomy, /datum/surgery/coronary_bypass, /datum/surgery/gastrectomy)

/obj/item/bodypart
	var/encased = FALSE
	var/open_threshold = CARAPACE_OPEN_THRESHOLD
	var/isOpen = FALSE

//Овверайд направленный на проверку, возможна ли операция (является ли конечность хитиновой или панцирной) и открыта или нет травма
/datum/surgery/can_start(mob/user, mob/living/carbon/target)
	var/obj/item/bodypart/affected = target.get_bodypart(user.zone_selected)
	if(affected?.encased == CARAPACE_ENCASE_WORD)
		if((src.type in CARAPACE_BLOCK_OPERATION) || !affected?.isOpen) //отключить стандартные операции класса "манипуляция органов", восстановить кость/череп.
			return FALSE
		if(ispath(src, /datum/surgery/carapace))
			if (istype(src, /datum/surgery/carapace/break_shell) && affected?.isOpen)
				return FALSE
			if (istype(src, /datum/surgery/carapace/repair_shell) && !affected?.isOpen)
				return FALSE
	. = .. ()

/datum/component/carapace
	var/self_mending = FALSE

/datum/component/carapace/Initialize(allow_self_mending, break_threshold)
	src.self_mending = allow_self_mending
	var/obj/item/bodypart/affected_limb = parent
	affected_limb.encased = CARAPACE_ENCASE_WORD

/datum/component/carapace/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIMB_RECEIVE_DAMAGE, PROC_REF(receive_damage))
	RegisterSignal(parent, COMSIG_LIMB_HEAL_DAMAGE, PROC_REF(heal_damage))

/datum/component/carapace/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_LIMB_RECEIVE_DAMAGE)
	UnregisterSignal(parent, COMSIG_LIMB_HEAL_DAMAGE)

//Проки, срабатываемые при получении или исцелении урона
/datum/component/carapace/proc/receive_damage(obj/item/bodypart/affected_limb, brute, burn, sharp, used_weapon = null, list/forbidden_limbs = list(), ignore_resists = FALSE, updating_health = TRUE)
	SIGNAL_HANDLER
	if(!affected_limb.encased)
		return
	if(!affected_limb.isOpen && affected_limb.get_damage() >= affected_limb.open_threshold)
		affected_limb.isOpen = TRUE
	if(length(affected_limb.contents))
		var/obj/item/organ/O = pick(affected_limb.contents)
		O.apply_organ_damage(burn * affected_limb.burn_dam, required_organ_flag = ORGAN_ORGANIC)

/datum/component/carapace/proc/heal_damage(obj/item/bodypart/affected_limb, brute, burn, internal = 0, robo_repair = 0, updating_health = TRUE)
	SIGNAL_HANDLER
	if(!affected_limb.encased)
		return
	if(length(affected_limb.wounds) && affected_limb.get_damage() == 0)
		for(var/datum/wound/wound as anything in affected_limb.wounds)
			if(self_mending || prob(CARAPACE_HEAL_BROKEN_PROB))
				wound.remove_wound()
		if(affected_limb.isOpen && prob(CARAPACE_HEAL_BROKEN_PROB))
			affected_limb.isOpen = FALSE

#undef CARAPACE_HEAL_BROKEN_PROB
#undef CARAPACE_BLOCK_OPERATION
#undef CARAPACE_OPEN_THRESHOLD

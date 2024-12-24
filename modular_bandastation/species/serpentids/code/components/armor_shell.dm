/*
===Модуль панциря (карапаса)
Цепляется на конечность. Особенность в том, что изначально придает конечности усиленную броню, но по достиженю трешхолда слома (устаналивается тут) конечность ломается

Сломанная конечность увеличивает входящий по ней урон. Считает и брут и берн уроны. В случае получения берн урона процент урона переносится на органы.area

Сопротивление/уязвимость к урону ожогами всегда ниже/выше сопротивления травмам.

Панцирь блокирует стандартные операции, пока не будет сломан.

Панцирь самовосстановится, если полностью вылечить конечность. Но есть параметр, который разрешает 100% или иное заживление при исцелении урона конечности.
*/
//Базовый трешхолд урона, при достижение или выше которого будет слом.
#define CARAPACE_BROKEN_STATE 20
//Базовая уязвимость к урону травмами (0.8 = 80%)
#define CARAPACE_BASIC_BRUTE_VULNERABILITY 0.8
//Бонус к уязвимости ожогу относительно урона травм
#define CARAPACE_ADDITIVE_BURN_VULNERABILITY 0.1
//Функция на будущее - позволяет переносить проценты урона
#define CARAPACE_DAMAGE_TRANSFER_PERCENTAGES 1
//Вероятность восстановления конечности при достижении 0 урона
#define CARAPACE_HEAL_BROKEN_PROB 50
//Список операций, которые будут заблокированы пока панцирь не будет сломан
#define CARAPACE_BLOCK_OPERATION list(/datum/surgery/bone_repair,/datum/surgery/bone_repair/skull,/datum/surgery/organ_manipulation)
#define CARAPACE_ENCASE_WORD "chitin"

/datum/component/carapace
	var/self_mending = FALSE
	var/broken_treshold = CARAPACE_BROKEN_STATE

/datum/component/carapace/Initialize(allow_self_mending, break_threshold)
	src.self_mending = allow_self_mending
	src.broken_treshold = break_threshold
	var/obj/item/organ/external/affected_limb = parent
	affected_limb.encased = CARAPACE_ENCASE_WORD

/datum/component/carapace/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIMB_RECEIVE_DAMAGE, PROC_REF(receive_damage))
	RegisterSignal(parent, COMSIG_LIMB_HEAL_DAMAGE, PROC_REF(heal_damage))

/datum/component/carapace/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_LIMB_RECEIVE_DAMAGE)
	UnregisterSignal(parent, COMSIG_LIMB_HEAL_DAMAGE)

//Проки, срабатываемые при получении или исцелении урона
/datum/component/carapace/proc/receive_damage(obj/item/organ/external/affected_limb, brute, burn, sharp, used_weapon = null, list/forbidden_limbs = list(), ignore_resists = FALSE, updating_health = TRUE)
	SIGNAL_HANDLER
	if(affected_limb.get_damage() > broken_treshold)
		affected_limb.fracture()
	if(length(affected_limb.internal_organs))
		var/obj/item/organ/internal/O = pick(affected_limb.internal_organs)
		O.receive_damage(burn * affected_limb.burn_dam)

/datum/component/carapace/proc/heal_damage(obj/item/organ/external/affected_limb, brute, burn, internal = 0, robo_repair = 0, updating_health = TRUE)
	SIGNAL_HANDLER
	if((affected_limb.status & ORGAN_BROKEN) && affected_limb.get_damage() == 0)
		if(self_mending || prob(CARAPACE_HEAL_BROKEN_PROB))
			affected_limb.mend_fracture()

#undef CARAPACE_BROKEN_STATE
#undef CARAPACE_BASIC_BRUTE_VULNERABILITY
#undef CARAPACE_ADDITIVE_BURN_VULNERABILITY
#undef CARAPACE_DAMAGE_TRANSFER_PERCENTAGES
#undef CARAPACE_HEAL_BROKEN_PROB
#undef CARAPACE_BLOCK_OPERATION

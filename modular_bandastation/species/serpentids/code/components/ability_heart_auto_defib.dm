/*
=== Компонент запуска сердца ===
Отслеживает смерть носителя, и в случае чего - запускает сердце с неким шансом
*/
#define AUTO_DEFIBRILATION_THRESHOLD 100

/datum/component/defib_heart_hunger
	var/obj/item/organ/organ

/datum/component/defib_heart_hunger/Initialize(human, income_chemical_id = "")
	organ = parent
	START_PROCESSING(SSdcs, src)

/datum/component/defib_heart_hunger/Destroy(force, silent)
	STOP_PROCESSING(SSdcs, src)
	. = ..()

/datum/component/defib_heart_hunger/process()
	var/mob/living/carbon/human/owner = organ.owner
	if(!owner)
		var/obj/item/organ/limb = parent
		owner = limb.owner
	if(!owner)
		qdel(src)
	var/levelOfDamage = (owner.getBruteLoss() + owner.getFireLoss())
	if(owner?.nutrition < NUTRITION_LEVEL_FED || owner.stat != DEAD || levelOfDamage > AUTO_DEFIBRILATION_THRESHOLD)
		return
	var/defib_chance = owner.nutrition - NUTRITION_LEVEL_FED
	owner.adjust_nutrition(-defib_chance)
	if(prob(defib_chance))
		owner.grab_ghost()
		owner.revive()
		owner.emote("gasp")
		owner.set_jitter_if_lower(200 SECONDS)
		SEND_SIGNAL(owner, COMSIG_LIVING_MINOR_SHOCK)
		log_combat(src, owner, "revived", src)
		SSblackbox.record_feedback("tally", "players_revived", 1, "self_revived")

#undef AUTO_DEFIBRILATION_THRESHOLD

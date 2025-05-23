/datum/lazy_template/virtual_domain/wendigo
	name = "Ледяной пожиратель"
	cost = BITRUNNER_COST_HIGH
	desc = "Легенды гласят о хищных Вендиго, скрытых в глубине пещер Айсмуна."
	difficulty = BITRUNNER_DIFFICULTY_HIGH
	forced_outfit = /datum/outfit/job/miner
	key = "wendigo"
	map_name = "wendigo"
	reward_points = BITRUNNER_REWARD_HIGH

/obj/effect/mob_spawn/corpse/human/bitrunner/special(mob/living/spawned_mob)
	. = ..()
	spawned_mob.apply_status_effect(/datum/status_effect/gutted)

/obj/effect/mob_spawn/corpse/human/cyber_police/special(mob/living/spawned_mob)
	. = ..()
	spawned_mob.apply_status_effect(/datum/status_effect/gutted)

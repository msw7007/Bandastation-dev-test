/obj/item/seeds/cabbage
	reagents_add = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1, /datum/reagent/consumable/cabbagilium = 0.1)

/datum/reagent/consumable/cabbagilium
	name = "Капустолетий"
	taste_description = "generic food"
	taste_mult = 2
	inverse_chem_val = 0.1
	inverse_chem = null
	creation_purity = CONSUMABLE_STANDARD_PURITY

/datum/reagent/consumable/cabbagilium/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, times_fired)
	. = ..()
	//Повышает настроение у Серпентидов и Молей
	if(affected_mob.dna.species == SPECIES_SERPENTID || affected_mob.dna.species == SPECIES_MOTH)
		affected_mob.mood.add_mood_event(MOOD_CATEGORY_SPECIFIC_FOOD, /datum/mood_event/oblivious)
	if(affected_mob.dna.species == SPECIES_SERPENTID)
		var/mob/living/carbon/human/affected_human = affected_mob
		affected_human.adjust_nutrition(get_nutriment_factor(affected_mob) * REM * seconds_per_tick)

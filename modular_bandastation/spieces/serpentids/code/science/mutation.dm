/datum/reagent/mutationtoxin/serpentid
	name = "Serpentid Mutation Toxin"
	description = "Мутационный токсин для превращения в ГБС"
	color = "#4ff34a"
	race = /datum/species/serpentid
	taste_description = "кислоты"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED

/datum/chemical_reaction/slime/slimeserpentid
	results = list(/datum/reagent/mutationtoxin/serpentid = 1)
	required_reagents = list(/datum/reagent/cabbagilium = 5)
	required_container = /obj/item/slime_extract/green

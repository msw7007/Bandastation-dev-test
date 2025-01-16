#define SPECIES_SERPENTID "serpentid"
#define BUTT_SPRITE_SERPENTID "serpentid"

#define EMOTE_HUMAN_SERPENTIDROAR 			"Рычать"
#define EMOTE_HUMAN_SERPENTIDHISS 			"Шипеть"
#define EMOTE_HUMAN_SERPENTIDWIGGLE 		"Шевелить усиками"

#define MOOD_CATEGORY_SPECIFIC_FOOD "spieces_food"

/// Базовое время погрузки ящиков/мобов на куклу
#define GADOM_BASIC_LOAD_TIMER 2 SECONDS

//Обычный, здоровый ГБС без дополнительных химикатов и болезней потребляет 0.1 единицы голода в тик (2 секунды), считаем от хорошо насыщенного до истощения
//Сколько голода потребляют легкие (сальбутамол и подвыработка кислорода)
#define SERPENTID_ORGAN_HUNGER_LUNGS 1 //11 минут
//Сколько голода потребляют почки (скрытность)
#define SERPENTID_ORGAN_HUNGER_KIDNEYS 0.5 //19 минут
//Сколько голода потребляют глаза (ПНВ)
#define SERPENTID_ORGAN_HUNGER_EYES 0.05  //58 минут
//Сколько голода потребляют уши (сонар)
#define SERPENTID_ORGAN_HUNGER_EARS 0.1  //78 минут

//минимальное цветовосприятие
#define SERPENTID_EYES_LOW_VISIBLE_VALUE 0.5
//Максимальное цветовосприяте
#define SERPENTID_EYES_MAX_VISIBLE_VALUE 1

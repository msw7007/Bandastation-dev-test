/obj/item/integrated_circuit/attackby(obj/item/I, mob/user, params)
    if(istype(I, /obj/item/concert_remote))
        var/obj/item/concert_remote/P = I
        P.try_toggle_on(src, user)
        return TRUE
    return ..()

/obj/item/circuitboard/machine/concert_controller
	name = "Circuit Board (Concert Controller)"
	desc = "Плата концертного контроллера."
	build_path = /obj/machinery/jukebox/concertspeaker
	req_components = list(
		/obj/item/stack/sheet/glass = 1,
		/obj/item/stack/cable_coil  = 5,
		/obj/item/stack/sheet/plastic = 1
		)



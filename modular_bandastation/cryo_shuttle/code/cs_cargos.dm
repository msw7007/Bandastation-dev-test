var/global/list/cargo_items = list()

/datum/shuttle/cargo_shuttle/proc/arrive()
    // Existing cargo arrival logic
    for (var/item in global.cargo_items)
        var/obj/item/cargo_box = new /obj/item/storage/box()
        cargo_box.add_to_contents(item)
        // Assume there's a mechanism to deliver cargo boxes
        deliver_cargo_box(cargo_box)
    global.cargo_items = list() // Clear the cargo items list

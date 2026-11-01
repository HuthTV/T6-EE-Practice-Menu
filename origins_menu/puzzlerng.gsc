#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;

/*##############################################################################
                              Staff puzzle RNG
##############################################################################*/
// Settings that force the random parts of the staff puzzles. Each puzzle's RNG is
// offered by the modes that still have it ahead:
//   Ice code       Fullgame, Icestart
//   Wind rings     Fullgame, Icestart, Windstart
//   Fire torches   Fullgame, Icestart, Windstart, Firestart
//   Crazy Place walls   Fullgame and every segment start
// A mode calls puzzle_rng_install and puzzle_rng_defaults while it loads, and its
// menu calls puzzle_rng_build_menus (Fullgame, inside its Randomness menu) or
// puzzle_rng_build_root_menu (the segment starts, a Randomness menu of their own).
// The puzzles read their settings when they start, so a change applies on restart.

puzzle_rng_has(puzzle)
{
    switch(puzzle)
    {
        case "ice":
            return level.gamemode == "fullgame" || level.gamemode == "icestart";
        case "wind":
            return level.gamemode == "fullgame" || level.gamemode == "icestart" || level.gamemode == "windstart";
        case "fire":
            return level.gamemode == "fullgame" || level.gamemode == "icestart" || level.gamemode == "windstart" || level.gamemode == "firestart";
        case "chamber":
            return level.gamemode == "fullgame" || level.gamemode == "icestart" || level.gamemode == "windstart" || level.gamemode == "firestart" || level.gamemode == "lightningstart";
    }
    return false;
}

// Load time: replaces the puzzles' random choices.
puzzle_rng_install()
{
    if(puzzle_rng_has("ice"))  replacefunc(maps\mp\zm_tomb_quest_ice::change_ice_gem_value, ::puzzle_rng_change_ice_gem_value);
    if(puzzle_rng_has("wind")) replacefunc(maps\mp\zm_tomb_quest_air::ceiling_ring_randomize, ::puzzle_rng_ceiling_ring_randomize);
    if(puzzle_rng_has("fire")) replacefunc(maps\mp\zm_tomb_quest_fire::fire_puzzle_2_init, ::puzzle_rng_fire_puzzle_2_init);
    if(puzzle_rng_has("chamber")) replacefunc(maps\mp\zm_tomb_chamber::chamber_wall_change_randomly, ::puzzle_rng_chamber_wall_change_randomly);
}

// 0 is random everywhere.
puzzle_rng_defaults(settings_ar)
{
    if(puzzle_rng_has("ice"))
        for(tile = 1; tile <= 6; tile++) settings_ar["ice_tile_" + tile] = 0;
    if(puzzle_rng_has("wind"))
        for(ring = 1; ring <= 4; ring++) settings_ar["wind_ring_" + ring] = 0;
    if(puzzle_rng_has("fire"))
        for(group = 1; group <= 4; group++) settings_ar["fire_torch_" + group] = 0;
    if(puzzle_rng_has("chamber"))
    {
        // Two staffs to clear per visit to the Crazy Place: 0 none, else 1 Fire, 2 Wind, 3 Lightning, 4 Ice.
        for(visit = 1; visit <= puzzle_rng_visit_count(); visit++)
        {
            settings_ar["chamber_v" + visit + "_a"] = 0;
            settings_ar["chamber_v" + visit + "_b"] = 0;
        }
    }
    return settings_ar;
}

// The segment starts have no Randomness menu otherwise.
puzzle_rng_build_root_menu(root)
{
    if(!puzzle_rng_has("chamber")) return;
    rng = add_submenu(root, "randomness", "Randomness", "RNG");
    self puzzle_rng_build_menus(rng);
}

puzzle_rng_build_menus(parent)
{
    if(puzzle_rng_has("ice"))
    {
        ice = add_submenu(parent, "ice_code", "Ice Code Order", "Ice Code");
            // Row = a tile, left to right as seen from the shooting spot; value =
            // which shot of the code it is. 1 6 5 4 3 2 is the optimal order.
            for(tile = 1; tile <= 6; tile++)
            {
                label = "Tile " + tile;
                if(tile == 1) label += " (left)";
                if(tile == 6) label += " (right)";
                create_option(ice, label + ": ^3" + puzzle_rng_ice_text(tile), ::puzzle_rng_ice_step, tile);
            }
            create_option(ice, "Optimal (1 6 5 4 3 2)", ::puzzle_rng_ice_optimal);
            create_option(ice, "All random", ::puzzle_rng_ice_random);
    }
    if(puzzle_rng_has("wind"))
    {
        wind = add_submenu(parent, "wind_rings", "Wind Rings", "Wind Rings");
            // Shots each ring needs. The game gives every ring 1 to 3, so one shot
            // on all four is possible (4 shots in all, the least).
            labels = array("Outer", "Ring 2", "Ring 3", "Inner");
            names = array("random", "1 shot", "2 shots", "3 shots");
            for(ring = 1; ring <= 4; ring++)
                add_cfg_choice(wind, labels[ring - 1], "wind_ring_" + ring, names);
            wind_keys = array("wind_ring_1", "wind_ring_2", "wind_ring_3", "wind_ring_4");
            create_option(wind, "All 1 shot (best)", ::puzzle_rng_set_keys, wind_keys, 1);
            create_option(wind, "All random", ::puzzle_rng_set_keys, wind_keys, 0);
    }
    if(puzzle_rng_has("chamber"))
    {
        // Per visit to the Crazy Place (see the Crazy Place walls section), up to two
        // staffs to clear. The wall never lands on a cleared staff during the visit.
        walls = add_submenu(parent, "chamber_walls", "Crazy Place Walls", "Walls");
            names = puzzle_rng_chamber_names();
            choices = array("none", names[0], names[1], names[2], names[3]);
            wall_keys = [];
            for(visit = 1; visit <= puzzle_rng_visit_count(); visit++)
            {
                title = "Visit " + visit;
                page = add_submenu(walls, "chamber_visit_" + visit, title + puzzle_rng_visit_text(visit), title);
                    add_cfg_choice(page, "Clear staff", "chamber_v" + visit + "_a", choices);
                    add_cfg_choice(page, "Clear staff", "chamber_v" + visit + "_b", choices);
                wall_keys[wall_keys.size] = "chamber_v" + visit + "_a";
                wall_keys[wall_keys.size] = "chamber_v" + visit + "_b";
            }
            create_option(walls, "All random", ::puzzle_rng_set_keys, wall_keys, 0);
    }
    if(puzzle_rng_has("fire") && isDefined(level.puzzle_fire_sizes))
    {
        fire = add_submenu(parent, "fire_torches", "Fire Torches", "Fire Torches");
            // One row per torch group that has a choice (the game picks one of its
            // two candidates at random). The torch numbers of the three pairs are the
            // user's (2026-10-29): in map order 11 5 9 7 3 6, taken as three groups of
            // two candidates. If a number lights the other torch, swap the pair.
            numbers = array(array(11, 5), array(9, 7), array(3, 6));
            keys = [];
            row = 0;
            for(group = 1; group <= 4; group++)
            {
                if(level.puzzle_fire_sizes[group] < 2) continue;
                row++;
                names = array("random");
                label = "Torch " + row;
                if(row <= numbers.size && level.puzzle_fire_sizes[group] == 2)
                {
                    names[1] = "" + numbers[row - 1][0];
                    names[2] = "" + numbers[row - 1][1];
                    label = names[1] + " / " + names[2];
                }
                else
                    for(candidate = 0; candidate < level.puzzle_fire_sizes[group]; candidate++)
                        names[names.size] = "" + (candidate + 1);
                add_cfg_choice(fire, label, "fire_torch_" + group, names);
                keys[keys.size] = "fire_torch_" + group;
            }
            create_option(fire, "All random", ::puzzle_rng_set_keys, keys, 0);
    }
}

// "All ..." rows: sets every key to value.
puzzle_rng_set_keys(keys, value)
{
    foreach(key in keys)
        level.mode_cfg[key] = value;
    write_config(level.mode_cfg, level.mode_cfg_str);
    self refresh_menu();
}

/*##############################################################################
                              Ice code
##############################################################################*/
puzzle_rng_ice_text(tile)
{
    value = get_cfg_int("ice_tile_" + tile);
    if(value == 0) return "random";
    return "shot " + value;
}

// Steps random, then each shot number no other tile has.
puzzle_rng_ice_step(tile)
{
    value = get_cfg_int("ice_tile_" + tile) + 1;
    while(value <= 6 && puzzle_rng_ice_taken(value, tile)) value++;
    if(value > 6) value = 0;
    self cfg_set_int("ice_tile_" + tile, value);
}

puzzle_rng_ice_taken(value, except_tile)
{
    for(tile = 1; tile <= 6; tile++)
        if(tile != except_tile && get_cfg_int("ice_tile_" + tile) == value) return true;
    return false;
}

puzzle_rng_ice_optimal()
{
    // Shots go tile 1, then 6 5 4 3 2: the values by tile are 1 6 5 4 3 2.
    level.mode_cfg["ice_tile_1"] = 1;
    for(tile = 2; tile <= 6; tile++) level.mode_cfg["ice_tile_" + tile] = 8 - tile;
    write_config(level.mode_cfg, level.mode_cfg_str);
    self refresh_menu();
}

puzzle_rng_ice_random()
{
    for(tile = 1; tile <= 6; tile++) level.mode_cfg["ice_tile_" + tile] = 0;
    write_config(level.mode_cfg, level.mode_cfg_str);
    self refresh_menu();
}

// Vanilla change_ice_gem_value picks a random unsolved tile as the next answer. A
// wrong shot flips every tile back, so the shot being asked for is the number of
// tiles solved since then, plus one. Tiles are numbered by x, smallest first, the
// way the MP40 tile clue counts them (icestart_mp40_index), so the numbers match
// what runners already read. A shot with no setting, or whose tile is already
// solved, picks randomly as vanilla does.
puzzle_rng_change_ice_gem_value()
{
    ice_gem = getent("ice_chamber_gem", "targetname");
    if(level.unsolved_tiles.size != 0)
    {
        correct_tile = puzzle_rng_next_ice_tile();
        ice_gem.value = correct_tile.value;
        level notify("update_ice_chamber_digits", ice_gem.value);
    }
    else
        level notify("update_ice_chamber_digits", -1);
}

// The tiles ordered by x, smallest first (left to right).
puzzle_rng_ice_sorted()
{
    ordered = [];
    foreach(tile in getentarray("ice_ceiling_tile", "script_noteworthy"))
    {
        pos = ordered.size;
        while(pos > 0 && ordered[pos - 1].origin[0] > tile.origin[0]) pos--;
        for(j = ordered.size; j > pos; j--) ordered[j] = ordered[j - 1];
        ordered[pos] = tile;
    }
    return ordered;
}

puzzle_rng_next_ice_tile()
{
    ordered = puzzle_rng_ice_sorted();

    // Vanilla reset_tiles flips every tile to its tile side and appends each one to
    // level.unsolved_tiles again, so after the first wrong shot the list holds
    // every tile twice. Count each tile once.
    unsolved = [];
    foreach(tile in level.unsolved_tiles)
    {
        listed = false;
        foreach(known in unsolved)
            if(known == tile) listed = true;
        if(!listed) unsolved[unsolved.size] = tile;
    }

    shot = ordered.size - unsolved.size + 1;
    chosen = undefined;
    for(i = 0; i < ordered.size && !isDefined(chosen); i++)
    {
        if(get_cfg_int("ice_tile_" + (i + 1)) != shot) continue;
        foreach(tile in unsolved)
            if(tile == ordered[i]) chosen = ordered[i];
    }
    if(!isDefined(chosen)) chosen = random(unsolved);

    return chosen;
}

/*##############################################################################
                              Wind rings
##############################################################################*/
// Vanilla starts each ring 1 to 3 positions short of solved and one shot turns it
// one position, so a ring needs 1 to 3 shots, never 0 or 4. Rings are numbered
// outer to inner by their targetname (ceiling_ring_01 ...).
puzzle_rng_ring_number(ring)
{
    if(!isDefined(ring.targetname)) return 0;
    tokens = strtok(ring.targetname, "_");
    return int(tokens[tokens.size - 1]);
}

puzzle_rng_ceiling_ring_randomize()
{
    shots = 1 + randomint(3);

    ordered = [];
    foreach(ring in level.a_ceiling_rings)
    {
        pos = ordered.size;
        while(pos > 0 && puzzle_rng_ring_number(ordered[pos - 1]) > puzzle_rng_ring_number(ring)) pos--;
        for(j = ordered.size; j > pos; j--) ordered[j] = ordered[j - 1];
        ordered[pos] = ring;
    }
    for(i = 0; i < ordered.size; i++)
    {
        if(ordered[i] != self) continue;
        forced = get_cfg_int("wind_ring_" + (i + 1));
        if(forced > 0) shots = forced;
    }

    self.position = (self.script_int + 4 - shots) % 4;
    self maps\mp\zm_tomb_quest_air::ceiling_ring_update_position();
}

/*##############################################################################
                              Fire torches
##############################################################################*/
// Vanilla fire_puzzle_2_init, with the saved candidate of each group (1 based, 0
// random) in place of the random one. Groups with one candidate have no choice.
puzzle_rng_fire_puzzle_2_init()
{
    level.puzzle_fire_sizes = [];
    for(i = 1; i <= 4; i++)
    {
        a_ternary = getentarray("fire_torch_ternary_group_0" + i, "targetname");
        level.puzzle_fire_sizes[i] = a_ternary.size;

        if(a_ternary.size > 1)
        {
            index_to_save = randomintrange(0, a_ternary.size);
            forced = get_cfg_int("fire_torch_" + i);
            if(forced > 0 && forced <= a_ternary.size) index_to_save = forced - 1;
            a_ternary[index_to_save] ghost();
            arrayremoveindex(a_ternary, index_to_save, 0);
            array_delete(a_ternary);
            continue;
        }

        a_ternary[0] ghost();
    }

    a_torches = getstructarray("church_torch_target", "script_noteworthy");
    array_thread(a_torches, maps\mp\zm_tomb_quest_fire::fire_puzzle_torch_run);
}

/*##############################################################################
                              Crazy Place walls
##############################################################################*/
// Four walls, one per element (script_int 1 Fire, 2 Wind, 3 Lightning, 4 Ice), and
// only one lands at a time. Vanilla chamber_wall_change_randomly, every 15 s down
// to 5 s by round while a player is inside, picks the next wall at random from the
// three that did not land last.
//
// A visit is one stay in the chamber: it starts when a player is inside and a
// crystal has been picked up (vanilla changes no wall before that) and ends when
// the chamber is empty. Visits are counted from 1 for the whole game. For each of
// the first 8 the menu has two staffs to clear. The wall never lands on a cleared
// staff during that visit; it goes between the others, so with two cleared it goes
// back and forth between the other two. A visit with nothing cleared, and every
// visit after the 8th, is vanilla random. The settings are read at every change,
// so a menu change applies at the next one.
// Timing is vanilla: a change as soon as a visit starts if the last one is older
// than its wait, otherwise when that wait ends. The one addition: if the wall left
// from the last visit is a staff this visit clears, it changes at once.
puzzle_rng_visit_count()
{
    return 8;
}

puzzle_rng_chamber_names()
{
    return array("Fire", "Wind", "Lightning", "Ice");
}

// The staffs cleared for a visit (element numbers, no repeats).
puzzle_rng_chamber_cleared(visit)
{
    cleared = [];
    if(visit < 1 || visit > puzzle_rng_visit_count()) return cleared;
    foreach(side in array("a", "b"))
    {
        element = get_cfg_int("chamber_v" + visit + "_" + side);
        if(element < 1 || element > 4) continue;
        if(!puzzle_rng_chamber_is_cleared(cleared, element)) cleared[cleared.size] = element;
    }
    return cleared;
}

puzzle_rng_chamber_is_cleared(cleared, element)
{
    foreach(known in cleared)
        if(known == element) return true;
    return false;
}

// " (Fire, Ice)" for the row of a visit that clears staffs, else "".
puzzle_rng_visit_text(visit)
{
    names = puzzle_rng_chamber_names();
    text = "";
    foreach(element in puzzle_rng_chamber_cleared(visit))
    {
        if(text != "") text += ", ";
        text += names[element - 1];
    }
    if(text == "") return "";
    return " (" + text + ")";
}

// The wall that lands next: not the one that landed last and not a cleared staff.
puzzle_rng_chamber_next_wall(cleared, previous)
{
    pool = [];
    for(element = 1; element <= 4; element++)
    {
        if(element == previous) continue;
        if(puzzle_rng_chamber_is_cleared(cleared, element)) continue;
        pool[pool.size] = element;
    }
    return random(pool);
}

// Vanilla chamber_wall_change_randomly, with the visits and their cleared staffs.
puzzle_rng_chamber_wall_change_randomly()
{
    flag_wait("start_zombie_round_logic");
    level endon("stop_random_chamber_walls");

    visit = 0;
    inside = false;
    change_at = 0;

    for(;;)
    {
        if(!maps\mp\zm_tomb_chamber::is_chamber_occupied())
        {
            inside = false;
            wait 1.0;
            continue;
        }
        if(!flag("any_crystal_picked_up"))
        {
            wait 0.05;
            continue;
        }

        due = getTime() >= change_at;
        if(!inside)
        {
            inside = true;
            visit++;
            level.puzzle_walls_visit = visit;
            if(puzzle_rng_chamber_is_cleared(puzzle_rng_chamber_cleared(visit), level.n_chamber_wall_active)) due = true;
        }

        if(due)
        {
            n_round = maps\mp\zm_tomb_chamber::cap_value(level.round_number, 10, 30);
            f_progression_pct = (n_round - 10) / (30 - 10);
            n_change_wall_time = lerpfloat(15, 5, f_progression_pct);

            n_elem = puzzle_rng_chamber_next_wall(puzzle_rng_chamber_cleared(visit), level.n_chamber_wall_active);
            maps\mp\zm_tomb_chamber::chamber_change_walls(n_elem);
            change_at = getTime() + int(n_change_wall_time * 1000);
        }

        wait 0.05;
    }
}
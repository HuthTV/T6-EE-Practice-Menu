#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zm_tomb_utility;
#include maps\mp\zm_tomb_quest_crypt;
#include maps\mp\zm_tomb_main_quest;
#include maps\mp\zm_tomb_craftables;
#include maps\mp\zombies\_zm_craftables;

#include scripts\zm\origins_menu\segmentutil;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Staff setup
##############################################################################*/
// Completes staffs during a mode's setup the way the player would: collect the
// pieces, craft, solve both puzzles, return the orb and place the staff on its
// Crazy Place plinth. A segment start lists the staffs in its description
// (segment.staffs); shared_segment_install then calls shared_staff_install, and
// the mode's setup calls shared_complete_staff.

// Installs the hooks the setup needs. staffs: the staffs this mode's setup
// completes; their orb, plinth and insertion hooks are chosen at load. The held
// start sets "segment_ready" on release (shared_setup_places_staff) and
// level.segment_player.
shared_staff_install(staffs)
{
    level.segment_setup_staffs = staffs;
    replacefunc( maps\mp\zm_tomb_main_quest::waittill_staff_inserted, ::shared_waittill_staff_inserted);
    replacefunc( maps\mp\zm_tomb_quest_crypt::init_crypt_gems, ::shared_init_crypt_gems);
    replacefunc( maps\mp\zm_tomb_main_quest::run_gramophone_teleporter, ::shared_run_gramophone_teleporter);
    replacefunc( maps\mp\zm_tomb_main_quest::staff_crystal_wait_for_teleport, ::shared_staff_crystal_wait_for_teleport);
    replacefunc( maps\mp\zm_tomb_teleporter::run_chamber_exit, ::shared_run_chamber_exit);
}

// First step of a staff setup: the start's parts, mound open, Fire crystal showing.
shared_staff_setup_start()
{
    self shared_get_parts();
    shared_setup_trace("parts given, waiting chamber_entrance_opened");
    flag_wait("chamber_entrance_opened");
    shared_setup_trace("waiting fire crystal");
    self shared_awaken_fire_crystal();
    shared_setup_trace("setup_start done");
    self thread shared_start_puzzles();
}

// Scoreboard staff icons (quest_state: 2 crystal, 3 crafted, 4 upgraded). The last
// staff the setup completes was left showing its crystal; set every completed
// staff to its real state once setup is done.
shared_refresh_staff_icons()
{
    if(!isdefined(level.segment_setup_staffs)) return;
    foreach(staff_id in level.segment_setup_staffs)
    {
        staff = maps\mp\zm_tomb_craftables::get_staff_info_from_element_index(staff_id);
        state = 3;
        if(is_true(staff.charger.is_charged)) state = 4;
        level setclientfield("quest_state" + staff_id, state);
    }
}

// TEMP: traces the setup steps to the console to find where a start hangs.
// The stamp is game milliseconds (real time is a tenth of that at timescale 10).
shared_setup_trace(text)
{
    print("O-Prac trace [" + gettime() + " ms]: " + text + "\n");
}

/*##############################################################################
                              Staff completion
##############################################################################*/
// Collects the staff's pieces, crafts it, solves its Crazy Place and overground
// puzzles, returns its orb and places it on its Crazy Place plinth with
// num_souls (0-20) collected; 20 upgrades it. The staff must be in the list the
// mode passed to shared_staff_install, because its hooks are chosen at load.
shared_complete_staff(staff_id, num_souls)
{
    staff = shared_staff_names(staff_id);
    shared_setup_trace(staff.name + ": pieces");
    self shared_get_staff_pieces(staff_id);
    shared_setup_trace(staff.name + ": craft");
    self shared_craft_staff(staff.craftable);
    shared_setup_trace(staff.name + ": take");
    self shared_take_staff(staff.craftable, staff.weapname);
    shared_setup_trace(staff.name + ": puzzles");
    while(!isDefined(level.setup_puzzles_done) || !isDefined(level.setup_puzzles_done[staff_id])) wait 0.05;
    shared_setup_trace(staff.name + ": orb");
    self shared_shoot_orb(staff_id);
    shared_setup_trace(staff.name + ": place");
    self shared_place_staff(staff_id);
    shared_setup_trace(staff.name + ": souls");
    self shared_fill_souls(staff_id, num_souls);
    shared_setup_trace(staff.name + ": done");
}

// Collects the staff's pieces, crafts it and puts it in the player's hands: a
// start just after the craft. Its puzzles stay native unless the setup solves them.
shared_craft_and_take_staff(staff_id)
{
    staff = shared_staff_names(staff_id);
    self shared_get_staff_pieces(staff_id);
    shared_setup_trace(staff.name + ": craft");
    self shared_craft_staff(staff.craftable);
    shared_setup_trace(staff.name + ": take");
    self shared_take_staff(staff.craftable, staff.weapname);
}

// Native names: craftable, weapon, crypt gem and orb plinth prefix.
shared_staff_names(staff_id)
{
    staff = spawnstruct();
    switch(staff_id)
    {
        case ICE:       staff.name = "water";     staff.gem = "crypt_gem_ice";  staff.orb = "ice";       break;
        case WIND:      staff.name = "air";       staff.gem = "crypt_gem_air";  staff.orb = "air";       break;
        case FIRE:      staff.name = "fire";      staff.gem = "crypt_gem_fire"; staff.orb = "fire";      break;
        case LIGHTNING: staff.name = "lightning"; staff.gem = "crypt_gem_elec"; staff.orb = "lightning"; break;
    }
    staff.craftable = "elemental_staff_" + staff.name;
    staff.weapname = "staff_" + staff.name + "_zm";
    return staff;
}

// Collects the staff's three pieces and its crystal, skipping any already held.
// The player carries one crystal at a time: taking one drops the one held.
shared_get_staff_pieces(staff_id)
{
    staff = shared_staff_names(staff_id);
    foreach(piece_name in array("upper_staff", "middle_staff", "lower_staff", "gem"))
    {
        piece = maps\mp\zombies\_zm_craftables::get_craftable_piece(staff.craftable, piece_name);
        if(!isDefined(piece) || is_true(piece.in_shared_inventory)) continue;
        if(isDefined(self.current_craftable_piece) && self.current_craftable_piece == piece) continue;
        self maps\mp\zombies\_zm_craftables::player_take_piece(piece);
    }
}

// Sets a placed staff's souls; at 20 the native checker upgrades it and spawns
// its pickup on the plinth.
shared_fill_souls(staff_id, num_souls)
{
    if(num_souls <= 0) return;
    if(num_souls > 20) num_souls = 20;
    staff = maps\mp\zm_tomb_craftables::get_staff_info_from_element_index(staff_id);
    staff.charger.charges_received = num_souls;
    if(num_souls == 20)
        while(!staff.charger.is_charged) wait 0.05;
}

// Opens the element's portal with the gramophone. open_exit: the matching Crazy
// Place exit opens at the same time. Both play the same opening animation (about
// 12 s), so a setup starts them early (shared_portals_begin) and waits for them as
// its last step (shared_portals_wait). The exit then stays open until the player
// is released (shared_run_chamber_exit). take_gram: the gramophone comes back in
// hand once the portal is open (the Craft starts). exit_element: the exit to
// open when it is not the gramophone's element (Post-Fire torches).
shared_portals_begin(element, open_exit, take_gram, exit_element)
{
    if(!isdefined(exit_element)) exit_element = element;
    flag_clear("segment_portals_open");
    self thread shared_portals_run(element, open_exit, take_gram, exit_element);
}

shared_portals_run(element, open_exit, take_gram, exit_element)
{
    if(open_exit) self thread shared_open_exit_portal(exit_element);
    shared_setup_trace("gramophone portal " + element);
    self shared_open_gramophone_portal(element);
    if(open_exit) flag_wait("segment_exit_open");
    if(take_gram) self shared_take_gramophone(element);
    shared_setup_trace("portals open");
    flag_set("segment_portals_open");
}

shared_portals_wait()
{
    flag_wait("segment_portals_open");
}

// Whether this mode's setup completes the staff (the list passed to
// shared_staff_install). Afterwards every staff is native again.
shared_setup_places_staff(staff_id)
{
    if(flag("segment_ready")) return false;
    foreach(staff in level.segment_setup_staffs)
        if(staff == staff_id) return true;
    return false;
}

// shared_unlock_gem raises the Fire plinth; wait until its crystal is showing.
shared_awaken_fire_crystal()
{
    while(!isDefined(level.setup_fire_crystal_ready)) wait 0.05;
}

shared_craft_staff(craftable)
{
    stub = maps\mp\zombies\_zm_craftables::find_craftable_stub(craftable);
    while(!isDefined(stub) || !isDefined(stub.craftablespawn))
    {
        wait 0.05;
        stub = maps\mp\zombies\_zm_craftables::find_craftable_stub(craftable);
    }
    // player_craft consumes shared pieces and the carried crystal, updates
    // inventory/tracking, emits crafted notifications and completes the model.
    self maps\mp\zombies\_zm_craftables::player_craft(stub.craftablespawn);
    // Wake an existing native crafting waiter so it enters persistent pickup.
    index = self getentitynumber();
    if(isDefined(stub.playertrigger) && isDefined(stub.playertrigger[index]))
    {
        stub.playertrigger[index] notify("trigger", self);
        wait 0.1;
    }
    // Keeps the native persistent excavation pickup stub registered.
    stub [[stub.craftablestub.onfullycrafted]]();
}

shared_take_staff(craftable, weapname)
{
    stub = maps\mp\zombies\_zm_craftables::find_craftable_stub(craftable);
    // Run the native pickup callbacks without moving the frozen player into range.
    // A temporary use trigger provides the same stub context as the unitrigger.
    pickup = spawn("trigger_radius_use", stub.origin, 0, 32, 64);
    pickup.stub = stub;
    pickup setinvisibletoall();
    if(pickup maps\mp\zm_tomb_craftables::tomb_custom_craftable_validation(self))
        pickup maps\mp\zm_tomb_craftables::tomb_check_crafted_weapon_persistence(self);
    pickup delete();
    // Native ownership tracking clears availability in a separate thread.
    flag_waitopen(weapname + "_enabled");
}

// Every staff's two puzzles are independent of each other and of the crafting, so
// they all start together once the mound is open. shared_complete_staff waits for
// its staff's flag (the orb shot needs the puzzles done, and the discs it shares
// are the reason the orbs themselves stay in order).
shared_start_puzzles()
{
    level.setup_puzzles_done = [];
    foreach(staff_id in level.segment_setup_staffs)
        self thread shared_run_staff_puzzles(staff_id);
}

shared_run_staff_puzzles(staff_id)
{
    staff = shared_staff_names(staff_id);
    switch(staff_id)
    {
        case ICE:       self shared_ice_puzzles(); break;
        case WIND:      self shared_wind_puzzles(); break;
        case FIRE:      self shared_fire_puzzles(); break;
        case LIGHTNING: self shared_lightning_puzzles(); break;
    }
    shared_setup_trace(staff.name + ": puzzles done");
    level.setup_puzzles_done[staff_id] = true;
}

shared_ice_puzzles()
{
    while(!isDefined(level.unsolved_tiles)) wait 0.05;
    // Native flips remove each tile from unsolved_tiles and complete puzzle 1.
    tiles = arraycopy(level.unsolved_tiles);
    foreach(tile in tiles) tile thread maps\mp\zm_tomb_quest_ice::ceiling_tile_flip(0);
    flag_wait("ice_puzzle_1_complete");

    // Native stone handlers freeze, shatter, count completion and weather.
    foreach(stone in getstructarray("puzzle_stone_water", "targetname"))
    {
        while(!isDefined(stone.e_model)) wait 0.05;
        wait 0.05;
        stone.e_model notify("damage", 1, self, (0,0,0), stone.origin, "MOD_PROJECTILE", "", "", "", "staff_water_zm", 0);
        wait 0.1;
        stone.e_model notify("damage", 1, self, (0,0,0), stone.origin, "MOD_RIFLE_BULLET", "", "", "", "mp40_zm", 0);
        wait 0.1;
    }
    flag_wait("ice_puzzle_2_complete");
}

shared_wind_puzzles()
{
    // Crazy Place: set each ceiling ring one turn short of solved and turn it with
    // the native rotate, which also checks for completion.
    while(!isDefined(level.a_ceiling_rings)) wait 0.05;
    foreach(ring in level.a_ceiling_rings)
    {
        ring.position = (ring.script_int + 3) % 4;
        ring thread maps\mp\zm_tomb_quest_air::ceiling_ring_rotate();
    }
    flag_wait("air_puzzle_1_complete");

    // Overground: blow each smoke stack toward its destination through the native
    // damage handler. The stacks exist once the ring puzzle is complete.
    destination = getstruct("puzzle_smoke_dest", "targetname");
    foreach(smoke in getstructarray("puzzle_smoke_origin", "targetname"))
    {
        while(!isDefined(smoke.e_fx) || !isDefined(smoke.solved)) wait 0.05;
        direction = vectornormalize(destination.origin - smoke.origin);
        smoke.detector_brush notify("damage", 1, self, direction, smoke.origin, "MOD_PROJECTILE", "", "", "", "staff_air_zm");
    }
    flag_wait("air_puzzle_2_complete");
}

shared_fire_puzzles()
{
    shared_fire_sacrifices();

    // Church: light the four torches the symbols point to. The native puzzle marks
    // them once the sacrifices are done, and the last flame completes it.
    torches = [];
    while(torches.size < 4)
    {
        wait 0.05;
        torches = [];
        foreach(torch in getstructarray("church_torch_target", "script_noteworthy"))
            if(is_true(torch.b_correct_torch)) torches[torches.size] = torch;
    }
    foreach(torch in torches) torch thread maps\mp\zm_tomb_quest_fire::fire_puzzle_2_torch_flame();
    flag_wait("fire_puzzle_2_complete");
}

// The Fire staff's Crazy Place puzzle: every sacrifice volume has had its 32
// kills. The native puzzle checks the volumes when a sacrifice completes.
shared_fire_sacrifices()
{
    while(!isDefined(level.sacrifice_volumes) || level.sacrifice_volumes.size == 0) wait 0.05;
    foreach(volume in level.sacrifice_volumes)
    {
        volume.num_sacrifices_received = 32;
        volume.pct_sacrifices_received = 1;
        volume.b_gods_pleased = 1;
    }
    level notify("fire_sacrifice_completed");
    flag_wait("fire_puzzle_1_complete");
}

shared_lightning_puzzles()
{
    // Crazy Place: play the three chords in order on the native piano keys. The
    // native puzzle rings each solved chord for 4 seconds before the next.
    keys = getstructarray("piano_key", "script_noteworthy");
    foreach(chord_name in array("a_minor", "e_minor", "d_minor"))
    {
        chord = getstruct("piano_chord_" + chord_name, "script_noteworthy");
        flag_waitopen("piano_chord_ringing");
        foreach(note in strtok(chord.script_string, " "))
        {
            foreach(key in keys)
                if(key.script_string == note) key notify("piano_key_shot");
            wait 0.05;
        }
        flag_wait("piano_chord_ringing");
    }
    flag_wait("electric_puzzle_1_complete");

    // Overground: turn every relay to carry power from the Lightning generator to
    // the Crazy Place (the same solved positions as shared_relays).
    solved = [];
    solved["elec"] = 0;
    solved["ice"] = 3;
    solved["village"] = 2;
    solved["air"] = 2;
    solved["start"] = 1;
    solved["tank_platform"] = 0;
    solved["ruins"] = 2;
    foreach(name, position in solved)
    {
        level.electric_relays[name].position = position;
        level.electric_relays[name] thread maps\mp\zm_tomb_quest_elec::update_relay_rotation();
    }
    maps\mp\zm_tomb_quest_elec::update_relays();
    flag_wait("electric_puzzle_2_complete");
}

// Lines the discs up with the staff's crypt gem and shoots its orb. The scramble
// from the previous orb can still be moving the discs, and the orb ignores a hit
// without clearance, so line up and shoot again until the orb takes it.
shared_shoot_orb(staff_id)
{
    staff = shared_staff_names(staff_id);
    shared_setup_trace(staff.name + ": waiting for orb");
    while(!isDefined(level.setup_orbs) || !isDefined(level.setup_orbs[staff_id])) wait 0.05;
    orb = level.setup_orbs[staff_id];
    unlocked = staff.weapname + "_upgrade_unlocked";
    shots = 0;
    while(!flag(unlocked))
    {
        flag_waitopen("disc_rotation_active");
        gem_position = maps\mp\zm_tomb_quest_crypt::chamber_disc_get_gem_position(staff.gem);
        discs = getentarray("crypt_puzzle_disc", "script_noteworthy");
        foreach(disc in discs)
            if(!isdefined(disc.targetname) || disc.targetname != "crypt_puzzle_disc_main") disc.position = gem_position;
        foreach(disc in discs)
            disc.angles = (disc.angles[0], disc.position * 90, disc.angles[2]);
        level notify("crypt_disc_rotation");
        wait 0.1;
        if(!isDefined(orb)) break; // Taken: the orb thread deletes it.
        shots++;
        shared_setup_trace(staff.name + ": shot " + shots + ", clearance " + maps\mp\zm_tomb_quest_crypt::chamber_disc_gem_has_clearance(staff.gem));
        orb notify("damage", 1, self, (0,0,0), orb.origin, "MOD_PROJECTILE", "", "", "", staff.weapname);
        wait 0.5;
    }
    // The orb thread handles scramble and unlock.
    flag_wait(unlocked);
}

// Inserts the held staff on its Crazy Place plinth with zero souls.
shared_place_staff(element)
{
    staff = maps\mp\zm_tomb_craftables::get_staff_info_from_element_index(element);
    while(!isDefined(staff.charge_trigger)) wait 0.05;
    wait 0.1;
    // shared_waittill_staff_inserted performs the native insertion.
    level.setup_insert[element] = true;
    while(!staff.charger.is_inserted) wait 0.05;
    // Leave the native soul collector/checker running from zero souls.
    staff.charger.charges_received = 0;
    plinth = getent("crystal_plinth" + element, "targetname");
    while(distance(plinth.origin, plinth.v_staff) > 1) wait 0.05;
}

// Places the gramophone at the element's portal, which opens it.
shared_open_gramophone_portal(element)
{
    gram = undefined;
    foreach(candidate in getstructarray("stargate_gramophone_pos", "targetname"))
        if(candidate.script_int == element) gram = candidate;
    shared_setup_trace("waiting gramophone has_vinyl");
    while(!gram.has_vinyl) wait 0.05;
    // The mound opening takes the gramophone back a moment after the mound is
    // open, and a placed one cannot be placed again.
    while(flag("gramophone_placed")) wait 0.05;
    shared_setup_trace("placing gramophone");
    wait 0.1;
    gram.setup_trigger notify("trigger", self);
    flag_wait("enable_teleporter_" + element);
    flag_wait("teleporter_building_" + element);
    flag_waitopen("teleporter_building_" + element);
}

shared_init_crypt_gems()
{
    disc = getent("crypt_puzzle_disc_main", "targetname");
    foreach(gem in getentarray("crypt_gem", "script_noteworthy"))
    {
        gem linkto(disc);
        // Orbs of the staffs the setup completes finish in place.
        staff_id = shared_gem_staff(gem.targetname);
        if(shared_setup_places_staff(staff_id))
            gem thread shared_run_fast_orb(staff_id);
        else
            gem thread maps\mp\zm_tomb_quest_crypt::run_crypt_gem_pos();
    }
}

// The gem's staff, from its name. Its script_int does not follow the staff
// numbers: the gem numbered as Wind waits for the Fire puzzle.
shared_gem_staff(gem_name)
{
    switch(gem_name)
    {
        case "crypt_gem_fire": return FIRE;
        case "crypt_gem_air":  return WIND;
        case "crypt_gem_elec": return LIGHTNING;
        case "crypt_gem_ice":  return ICE;
    }
    return undefined;
}

// Vanilla gramophone loop, with its trigger exposed for setup notifications.
shared_run_gramophone_teleporter( str_vinyl_record )
{
    self.has_vinyl = 0;
    self.gramophone_model = undefined;
    self thread watch_gramophone_vinyl_pickup();
    t_gramophone = tomb_spawn_trigger_radius( self.origin, 60.0, 1 );
    self.setup_trigger = t_gramophone;
    t_gramophone set_unitrigger_hint_string( &"ZOMBIE_BUILD_PIECE_MORE" );
    level waittill( "gramophone_vinyl_player_picked_up" );
    str_craftablename = "gramophone";
    t_gramophone set_unitrigger_hint_string( &"ZM_TOMB_RU" );

    while ( !self.has_vinyl )
        wait 0.05;

    t_gramophone set_unitrigger_hint_string( &"ZM_TOMB_PLGR" );

    while ( true )
    {
        t_gramophone waittill( "trigger", player );

        if ( !isdefined( self.gramophone_model ) )
        {
            if ( !flag( "gramophone_placed" ) )
            {
                self.gramophone_model = spawn( "script_model", self.origin );
                self.gramophone_model.angles = self.angles;
                self.gramophone_model setmodel( "p6_zm_tm_gramophone" );
                level setclientfield( "piece_record_zm_player", 0 );
                flag_set( "gramophone_placed" );
                t_gramophone set_unitrigger_hint_string( "" );
                t_gramophone trigger_off();
                str_song_id = self get_gramophone_song();
                self.gramophone_model playsound( str_song_id );
                player thread maps\mp\zm_tomb_vo::play_gramophone_place_vo();
                maps\mp\zm_tomb_teleporter::stargate_teleport_enable( self.script_int );
                flag_wait( "teleporter_building_" + self.script_int );
                flag_waitopen( "teleporter_building_" + self.script_int );
                t_gramophone trigger_on();
                t_gramophone set_unitrigger_hint_string( &"ZM_TOMB_PUGR" );

                if ( isdefined( self.script_flag ) )
                    flag_set( self.script_flag );
            }
            else
                player door_gramophone_elsewhere_hint();
        }
        else
        {
            self.gramophone_model delete();
            self.gramophone_model = undefined;
            player playsound( "zmb_craftable_pickup" );
            flag_clear( "gramophone_placed" );
            level setclientfield( "piece_record_zm_player", 1 );
            maps\mp\zm_tomb_teleporter::stargate_teleport_disable( self.script_int );
            t_gramophone set_unitrigger_hint_string( &"ZM_TOMB_PLGR" );
        }
    }
}

// Orb completes in place: no path travel, same unlock and scramble.
// self is the staff's crypt gem.
shared_run_fast_orb(staff_id)
{
    staff = shared_staff_names(staff_id);
    flags = strtok(self.script_flag, " ");
    foreach(puzzle_flag in flags)
    {
        shared_setup_trace(staff.name + " orb: waiting flag " + puzzle_flag);
        flag_wait(puzzle_flag);
    }
    shared_setup_trace(staff.name + " orb: ready");
    self setcandamage(1);
    level.setup_orbs[staff_id] = self;
    while(true)
    {
        self waittill("damage", damage, attacker, direction_vec, point, mod, tagname, modelname, partname, weaponname);
        if(weaponname == staff.weapname && maps\mp\zm_tomb_quest_crypt::chamber_disc_gem_has_clearance(self.targetname)) break;
    }
    // Preserve the normal returned orb entity, quest unlock and scramble callback.
    final = getstruct(staff.orb + "_orb_plinth_final", "targetname");
    orb = spawn("script_model", final.origin);
    orb setmodel(self.model);
    orb.script_int = self.script_int;
    orb setclientfield("element_glow_fx", self.script_int);
    orb playsound("zmb_squest_crystal_arrive");
    orb playloopsound("zmb_squest_crystal_charge_loop", 0.1);
    self delete();
    level thread maps\mp\zm_tomb_quest_crypt::chamber_discs_randomize();
    flag_set(staff.weapname + "_upgrade_unlocked");
}

// Vanilla crystal/plinth lifecycle; setup skips the look-at and occupancy gates.
shared_staff_crystal_wait_for_teleport( n_element_enum )
{
    flag_init( "charger_ready_" + n_element_enum );
    self craftable_waittill_spawned();
    self.origin = self.piecespawn.model.origin;
    self.piecespawn.model ghost();
    self.piecespawn.model movez( -1000, 0.05 );
    e_plinth = getent( "crystal_plinth" + n_element_enum, "targetname" );
    e_plinth.v_start = e_plinth.origin;
    e_plinth.v_start = ( e_plinth.v_start[0], e_plinth.v_start[1], e_plinth.origin[2] - 78 );
    e_plinth.v_crystal = e_plinth.origin;
    e_plinth.v_crystal = ( e_plinth.v_crystal[0], e_plinth.v_crystal[1], e_plinth.origin[2] - 40 );
    e_plinth.v_staff = e_plinth.origin;
    e_plinth.v_staff = ( e_plinth.v_staff[0], e_plinth.v_staff[1], e_plinth.origin[2] + 15 );
    e_plinth moveto( e_plinth.v_start, 0.05 );
    if(n_element_enum == 1) level.setup_fire_crystal = self;

    while ( true )
    {
        level waittill( "player_teleported", e_player, n_teleport_enum );

        if ( n_teleport_enum == n_element_enum )
            break;
    }

    e_plinth moveto( e_plinth.v_crystal, 6.0 );
    e_plinth thread sndmoveplinth( 6 );
    lookat_dot = cos( 90.0 );
    dist_sq = 250000.0;
    lookat_time = 0.0;

    while ( lookat_time < 1.0 && isdefined( self.piecespawn.model ) )
    {
        wait 0.1;

        if ( !isdefined( self.piecespawn.model ) )
            break;

        if ( (n_element_enum == 1 && !flag("segment_ready")) || self.piecespawn.model any_player_looking_at_plinth( lookat_dot, dist_sq ) )
            lookat_time = lookat_time + 0.1;
        else
            lookat_time = 0.0;
    }

    if ( isdefined( self.piecespawn.model ) )
    {
        self.piecespawn.model movez( 985, 0.05 );
        self.piecespawn.model waittill( "movedone" );
        self.piecespawn.model show();
        self.piecespawn.model thread rotate_forever();
        self.piecespawn.model movez( 15, 2.0 );
        self.piecespawn.model playloopsound( "zmb_squest_crystal_loop", 4.25 );
        if(n_element_enum == 1 && !flag("segment_ready"))
        {
            self.piecespawn.model waittill("movedone");
            level.setup_fire_crystal_ready = true;
        }
    }

    flag_wait( "charger_ready_" + n_element_enum );

    if ( !shared_setup_places_staff( n_element_enum ) )
    {
        while ( !maps\mp\zm_tomb_chamber::is_chamber_occupied() )
            wait_network_frame();
    }

    e_plinth moveto( e_plinth.v_staff, 3.0 );
    e_plinth thread sndmoveplinth( 3 );
    e_plinth waittill( "movedone" );
}

// Vanilla waittill_staff_inserted; setup inserts its staffs without the player in range.
shared_waittill_staff_inserted()
{
    if(shared_setup_places_staff(self.enum))
    {
        while(!isDefined(level.setup_insert) || !isDefined(level.setup_insert[self.enum])) wait 0.05;
        self shared_insert_staff(level.segment_player);
        return;
    }
    while ( true )
    {
        self.charge_trigger waittill( "trigger", player );
        weapon_available = 1;

        if ( isdefined( player ) )
        {
            weapon_available = player hasweapon( self.weapname );

            if ( weapon_available )
                player takeweapon( self.weapname );
        }

        if ( weapon_available )
        {
            self.charger.is_inserted = 1;
            self thread debug_staff_charge();
            maps\mp\zm_tomb_craftables::clear_player_staff( self.weapname );
            self.charge_trigger trigger_off();

            if ( isdefined( self.charger.angles ) )
                self.angles = self.charger.angles;

            self moveto( self.charger.origin, 0.05 );
            self waittill( "movedone" );
            self setclientfield( "staff_charger", self.enum );
            self.charger.full = 0;
            self show();
            self playsound( "zmb_squest_charge_place_staff" );
            return;
        }
    }
}

// Native insertion body; self is the staff entity.
shared_insert_staff(player)
{
    player takeweapon(self.weapname);
    self.charger.is_inserted = 1;
    self.charger.charges_received = 0;
    maps\mp\zm_tomb_craftables::clear_player_staff(self.weapname);
    self.charge_trigger trigger_off();
    if(isDefined(self.charger.angles)) self.angles = self.charger.angles;
    self moveto(self.charger.origin, 0.05);
    self waittill("movedone");
    self setclientfield("staff_charger", self.enum);
    self.charger.full = 0;
    self show();
    self playsound("zmb_squest_charge_place_staff");
    craft_model = getent("craftable_" + self.weapname, "targetname");
    if(isDefined(craft_model)) craft_model ghost();
}

// Exit start: opens the element's Crazy Place exit portal as if the player had
// used its trigger (native run_chamber_exit). Once open it stays open for 20
// seconds. shared_unlock_gem has already enabled the exit.
shared_open_exit_portal(element)
{
    exit_trigger = level.a_teleport_exit_triggers[element];
    while(!isdefined(exit_trigger.trigger_stub)) wait 0.05;
    flag_wait("start_zombie_round_logic"); // run_chamber_exit only listens after this.
    wait 0.1; // Let run_chamber_exit reach its trigger wait.
    exit_trigger.trigger_stub notify("trigger", self);
}

// Vanilla run_chamber_exit. MODIFIED: once open, the exit stays open while a held
// start's setup is still running (level.segment_setup_running), so it can open as
// early as the other setup steps allow and the player is released the moment it
// has finished opening. Its 20 seconds then start at the release.
#using_animtree("fxanim_props_dlc4");

shared_run_chamber_exit( n_enum ) // OVERRIDE: maps\mp\zm_tomb_teleporter::run_chamber_exit
{
    s_portal = level.a_teleport_exits[n_enum];
    s_activate_pos = level.a_teleport_exit_triggers[n_enum];
    e_portal_frame = level.a_portal_exit_frames[n_enum];
    e_portal_frame show();
    str_building_flag = e_portal_frame.targetname + "_building";
    flag_init( str_building_flag );
    s_activate_pos.trigger_stub = tomb_spawn_trigger_radius( s_activate_pos.origin, 50.0, 1 );
    s_activate_pos.trigger_stub set_unitrigger_hint_string( &"ZM_TOMB_TELE" );
    s_portal.target = s_activate_pos.target;
    s_portal.origin = e_portal_frame gettagorigin( "fx_portal_jnt" );
    s_portal.angles = e_portal_frame gettagangles( "fx_portal_jnt" );
    s_portal.angles = ( s_portal.angles[0], s_portal.angles[1] + 180, s_portal.angles[2] );
    str_fx = get_teleport_fx_from_enum( n_enum );
    collapse_time = getanimlength( %fxanim_zom_tomb_portal_collapse_anim );
    open_time = getanimlength( %fxanim_zom_tomb_portal_open_anim );
    flag_wait( "start_zombie_round_logic" );

    while ( true )
    {
        s_activate_pos.trigger_stub waittill( "trigger", e_player );

        if ( !is_player_valid( e_player ) )
            continue;

        if ( e_player.score < level.teleport_cost )
            continue;

        s_activate_pos.trigger_stub set_unitrigger_hint_string( "" );
        s_activate_pos.trigger_stub trigger_off();

        if ( level.teleport_cost > 0 )
            e_player maps\mp\zombies\_zm_score::minus_to_player_score( level.teleport_cost );

        e_portal_frame playloopsound( "zmb_teleporter_loop_pre", 1 );
        e_portal_frame setanim( %fxanim_zom_tomb_portal_open_anim, 1.0, 0.1, 1 );
        flag_set( str_building_flag );
        e_portal_frame thread whirlwind_rumble_nearby_players( str_building_flag );
        wait( open_time );
        e_portal_frame setanim( %fxanim_zom_tomb_portal_open_1frame_anim, 1.0, 0.1, 1 );
        wait_network_frame();
        flag_clear( str_building_flag );
        e_fx = spawn( "script_model", s_portal.origin );
        e_fx.angles = s_portal.angles;
        e_fx setmodel( "tag_origin" );
        e_fx setclientfield( "element_glow_fx", n_enum + 4 );
        rumble_nearby_players( e_fx.origin, 1000, 2 );
        e_portal_frame playloopsound( "zmb_teleporter_loop_post", 1 );
        s_portal thread maps\mp\zm_tomb_teleporter::teleporter_radius_think();

        //MODIFIED
        if(isdefined(level.segment_setup_running))
        {
            flag_set( "segment_exit_open" );
            while(isdefined(level.segment_setup_running)) wait 0.05;
        }
        //MODIFIED END

        wait 20.0;
        e_portal_frame setanim( %fxanim_zom_tomb_portal_collapse_anim, 1.0, 0.1, 1 );
        e_portal_frame stoploopsound( 0.5 );
        e_portal_frame playsound( "zmb_teleporter_anim_collapse_pew" );
        s_portal notify( "teleporter_radius_stop" );
        e_fx setclientfield( "element_glow_fx", 0 );
        wait( collapse_time );
        e_fx delete();
        s_activate_pos.trigger_stub trigger_on();
        s_activate_pos.trigger_stub set_unitrigger_hint_string( &"ZM_TOMB_TELE" );
    }
}


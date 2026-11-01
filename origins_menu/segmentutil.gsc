#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zm_tomb_utility;
#include maps\mp\gametypes_zm\_hud_util;

#include scripts\zm\utility_core\basegame;
#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\rounds;
#include scripts\zm\origins_menu\origins;
#include scripts\zm\origins_menu\staffutil;
#include scripts\zm\origins_menu\puzzlerng;
#inline scripts\zm\origins_menu\oprac;

/*##############################################################################
                              Segment replacefuncs
##############################################################################*/
// Hooks every segment start (Ice, Wind, Fire, Lightning) installs. Callers set
// level.shared_tank_setup_trips, call shared_schedules_init, and add their own
// disc and checkpoint hooks. delete_zombie_noone_looking is not hooked: the
// former copy matched vanilla exactly.
shared_segment_replacefuncs()
{
    // Tank
    replacefunc( maps\mp\zm_tomb_tank::tank_movement, ::shared_tank_movement );
    replacefunc( maps\mp\zm_tomb_tank::activate_tank_wait_with_no_cost, ::shared_tank_disable_free_ride );

    // Digs
    replacefunc( maps\mp\zm_tomb_dig::dig_spots_respawn, ::shared_dig_spots_respawn );
    replacefunc( maps\mp\zm_tomb_dig::waittill_dug, ::shared_waittill_dug );

    // Templars and Panzers
    replacefunc( maps\mp\zm_tomb_capture_zones::get_recapture_zone, ::shared_get_recapture_zone );
    replacefunc( maps\mp\zm_tomb_capture_zones::recapture_round_tracker, ::shared_recapture_round_tracker );
    replacefunc( maps\mp\zombies\_zm_ai_mechz_ffotd::mechz_round_tracker_loop_start, ::shared_mechz_round_tracker_loop_start );

    // Robots
    replacefunc( maps\mp\zm_tomb_giant_robot::robot_cycling, ::shared_robot_cycling );

    // Items and powerups
    replacefunc( maps\mp\zm_tomb_utility::zone_capture_powerup, ::shared_zone_capture_powerup );
    replacefunc( maps\mp\zombies\_zm_craftables::generate_zombie_craftable_piece, ::shared_generate_zombie_craftable_piece );
    replacefunc( maps\mp\zm_tomb_craftables::randomize_craftable_spawns, ::shared_randomize_craftable_spawns );

    // Out-of-playable-area and despawn checks on a real run's timing from the
    // start's clock (start_robots, set by shared_craft_time_start_clock). Held
    // starts hold them until release (shared_held_start_install); Icestart, from
    // the black screen. The out-of-area check is the core monitor (basegame).
    practice_check_phasing(undefined, "start_robots");
    replacefunc( maps\mp\zm_tomb_distance_tracking::zombie_tracking_init, ::shared_segment_zombie_tracking_init );
}

/*##############################################################################
                              Tank functions
##############################################################################*/
// Setup trip speed (vanilla drives at 8 mph) and the slow final stretch before a
// station (shared_tank_slow_arrival).
#define TANK_SETUP_MPH      100
#define TANK_SLOW_DISTANCE  400

shared_tank_disable_free_ride() //OVERRIDE: maps\mp\zm_tomb_tank::activate_tank_wait_with_no_cost
{
    return 0;
}

shared_tank_movement() //OVERRIDE: maps\mp\zm_tomb_tank::tank_movement
{
    n_path_start = getvehiclenode( "tank_start", "targetname" );
    self attachpath( n_path_start );
    self startpath();
    self thread maps\mp\zm_tomb_tank::follow_path( n_path_start );
    self setspeedimmediate( 0 );
    self.a_locations = array( "village", "bunkers" );
    n_location_index = 0;
    self.str_location_current = self.a_locations[n_location_index];
    maps\mp\zm_tomb_tank::tank_call_boxes_update();
    
    //MODIFIED
    n_original_max_mph = self getmaxspeed() / 17.6;
    b_setup_trip = level.shared_tank_setup_trips > 0;
    if ( !b_setup_trip ) flag_set( "shared_tank_setup_done" );
    flag_wait( "initial_players_connected" );
    level.tank_boxes_enabled = 1;
    self.t_use setvisibletoall();
    self.t_use sethintstring( &"ZM_TOMB_X2AT", 500 );
    maps\mp\zm_tomb_tank::tank_call_boxes_update();
    if ( b_setup_trip )
    {
        self ent_flag_set( "tank_activated" );
        self ent_flag_set( "tank_moving" );
    }
    //MODIFIED END

    while ( true )
    {
        self ent_flag_wait( "tank_activated" );
        self thread maps\mp\zm_tomb_tank::tank_connect_paths();
        self playsound( "evt_tank_call" );

        //MODIFIED
        if ( b_setup_trip )
        {
            // Setup trips at TANK_SETUP_MPH (vanilla is 8).
            self setvehmaxspeed( TANK_SETUP_MPH );
            self setspeedimmediate( TANK_SETUP_MPH );
            self thread shared_tank_slow_arrival( n_original_max_mph );
        }
        else
            self setspeedimmediate( 8 );
        //MODIFIED END

        self.t_use setinvisibletoall();
        maps\mp\zm_tomb_tank::tank_call_boxes_update();
        self thread maps\mp\zm_tomb_tank::tank_kill_players();
        self thread maps\mp\zm_tomb_tank::tank_cooldown_timer();
        self waittill( "tank_stop" );
        self ent_flag_set( "tank_cooldown" );
        self.t_use setvisibletoall();
        self.t_use sethintstring( &"ZM_TOMB_TNKC" );
        self ent_flag_clear( "tank_moving" );
        self thread maps\mp\zm_tomb_tank::tank_disconnect_paths();
        self setspeedimmediate( 0 );

        //MODIFIED
        if ( b_setup_trip )
        {
            self setvehmaxspeed( n_original_max_mph );
            self playsound( "zmb_tank_stop" );
            self stoploopsound( 0.1 );
        }
        //MODIFIED END

        n_location_index++;

        if ( n_location_index == self.a_locations.size )
            n_location_index = 0;

        self.str_location_current = self.a_locations[n_location_index];
        maps\mp\zm_tomb_tank::tank_call_boxes_update();
        self maps\mp\zm_tomb_tank::wait_for_tank_cooldown();
        self ent_flag_clear( "tank_cooldown" );

        if ( isdefined( self.b_no_cost ) && self.b_no_cost )
            self.t_use sethintstring( &"ZM_TOMB_X2ATF" );
        else
            self.t_use sethintstring( &"ZM_TOMB_X2AT", 500 );

        self ent_flag_clear( "tank_activated" );
        maps\mp\zm_tomb_tank::tank_call_boxes_update();

        //MODIFIED
        if ( b_setup_trip )
        {
            // 1 trip to bunkers. 2 trips to church.
            level.shared_tank_setup_trips--;
            b_setup_trip = level.shared_tank_setup_trips > 0;
            if ( !b_setup_trip )
            {
                shared_setup_trace("tank setup done");
                flag_set( "shared_tank_setup_done" ); // Parked: held starts release now.
            }
            if ( b_setup_trip )
            {
                self ent_flag_set( "tank_activated" );
                self ent_flag_set( "tank_moving" );
            }
        }
        //MODIFIED END
    }
}

// Setup trips cruise at TANK_SETUP_MPH; this drops the tank to the vanilla 8 mph
// for the last TANK_SLOW_DISTANCE before the next station. Fast enough, the tank
// passes several path nodes in one server frame, and vanilla follow_path only
// catches one "reached_node" per frame, so it could miss the station's node that
// sends "tank_stop": at 400 mph (about 350 units a frame) the tank drove on and
// was gone (user, 2026-10-20). 100 mph is about 88 units a frame, and the slow
// stretch is 4+ frames of it. The station is the first "tank_stop" node ahead on
// the path, found from follow_path's n_next_node. (TANK_SETUP_MPH and
// TANK_SLOW_DISTANCE are defined above shared_tank_movement.)

shared_tank_slow_arrival(n_original_max_mph)
{
    self endon("death");
    self endon("tank_stop");
    while(!isdefined(self.n_next_node)) wait 0.05;

    stop_node = self.n_next_node;
    for(i = 0; i < 1000 && isdefined(stop_node); i++)
    {
        if(isdefined(stop_node.script_noteworthy) && stop_node.script_noteworthy == "tank_stop") break;
        if(!isdefined(stop_node.target)) { stop_node = undefined; break; }
        stop_node = getvehiclenode(stop_node.target, "targetname");
    }
    if(!isdefined(stop_node) || !isdefined(stop_node.script_noteworthy) || stop_node.script_noteworthy != "tank_stop")
    {
        // No station found ahead: play it safe at the vanilla speed.
        self setvehmaxspeed(n_original_max_mph);
        self setspeedimmediate(8);
        return;
    }

    while(distancesquared(self.origin, stop_node.origin) > TANK_SLOW_DISTANCE * TANK_SLOW_DISTANCE)
        wait 0.05;
    self setvehmaxspeed(n_original_max_mph);
    self setspeedimmediate(8);
}

/*##############################################################################
                              Door functions
##############################################################################*/
shared_open_doors(excluded_targets)
{
    if(!isdefined(excluded_targets)) excluded_targets = [];
    player = get_players()[0];
    setdvar("zombie_unlock_all", 1);

    foreach(kind in array("zombie_door", "zombie_debris"))
    {
        foreach(trigger in getentarray(kind, "targetname"))
        {
            if(!isdefined(trigger)) continue;
            if(isinarray(excluded_targets, trigger.target)) continue;
            if(isdefined(trigger.has_been_opened) && trigger.has_been_opened) continue;

            trigger notify("trigger", player, 1);
            wait 0.05;
        }
    }
    setdvar("zombie_unlock_all", 0);
}

/*##############################################################################
                              Relay functions
##############################################################################*/
shared_relays()
{
	if(shared_relay_solved("relay_start"))   level.electric_relays["start"].position = 1;         //3 start
	if(shared_relay_solved("relay_tank"))    level.electric_relays["tank_platform"].position = 0; //1 start
	if(shared_relay_solved("relay_air"))     level.electric_relays["air"].position = 2;           //0 start
	if(shared_relay_solved("relay_elec"))    level.electric_relays["elec"].position = 0;          //1 start
	if(shared_relay_solved("relay_ruins"))   level.electric_relays["ruins"].position = 2;         //3 start
	if(shared_relay_solved("relay_ice"))     level.electric_relays["ice"].position = 3;           //1 start
	if(shared_relay_solved("relay_village")) level.electric_relays["village"].position = 2;       //1 start
	foreach(relay in level.electric_relays)  relay thread maps\mp\zm_tomb_quest_elec::update_relay_rotation();
}

// A relay the start always has solved (the mode's solved_relays: the route has
// done it by then), else the relay setting.
shared_relay_forced(key)
{
	if(!isdefined(level.segment) || !isdefined(level.segment.solved_relays)) return false;
	foreach(forced in level.segment.solved_relays)
		if(forced == key) return true;
	return false;
}

shared_relay_solved(key)
{
	return shared_relay_forced(key) || get_cfg_int(key);
}

// Relays menu row: a toggle, or a fixed row for a relay the start always solves.
shared_add_relay_row(menu, label, key)
{
	if(shared_relay_forced(key))
		create_option(menu, label + ": ^2solved ^7(route)", ::shared_relay_fixed);
	else
		add_cfg_toggle(menu, label, key, "^2solved", "^1unsolved");
}

shared_relay_fixed()
{
	self iprintln("This start always has it solved");
}

// "Zombies left" setting text: 0 is the full round.
shared_zombies_left_text(key)
{
	if(get_cfg_int(key) > 0) return get_cfg_int(key);
	return "full round";
}

// Picks the gramophone back up from an element's portal, as using it again does
// (vanilla run_gramophone_teleporter, here shared_run_gramophone_teleporter): the
// player carries it on and that portal closes. Retries until the gramophone
// loop is waiting for the use again (at most 5 s).
shared_take_gramophone(element)
{
    gram = undefined;
    foreach(candidate in getstructarray("stargate_gramophone_pos", "targetname"))
        if(candidate.script_int == element) gram = candidate;
    if(!isdefined(gram)) return;
    for(i = 0; i < 50 && flag("gramophone_placed"); i++)
    {
        gram.setup_trigger notify("trigger", self);
        wait 0.1;
    }
    shared_setup_trace("gramophone in hand: " + !flag("gramophone_placed"));
}

/*##############################################################################
                              Mound functions
##############################################################################*/
shared_open_mound(leave_gramophone)
{
    if(!isdefined(level.shared_mound_discs_armed)) // First opening silent discs.
    {
        level.shared_mound_discs_armed = true;
        level.shared_mound_discs_pending = true;
        replacefunc( maps\mp\zm_tomb_quest_crypt::chamber_discs_randomize, ::shared_chamber_discs_randomize );
    }
    foreach(stairs in getentarray("chamber_entrance", "targetname"))
        stairs thread shared_open_mound_stairs(leave_gramophone);
}

shared_open_mound_stairs(leave_gramophone)
{
    position = getstruct(self.targetname + "_position", "targetname");
    while(!isdefined(position) || !isdefined(position.trigger) || !position.has_vinyl)
    {
        wait 0.05;
        position = getstruct(self.targetname + "_position", "targetname");
    }
    self.shared_mound_silent = true; // Only openings requested by this helper.
    flag_clear("gramophone_placed");
    position.trigger notify("trigger", get_players()[0]);
    self waittill("movedone");
    wait 0.05; 
    if(!isdefined(leave_gramophone) || !leave_gramophone) position.trigger notify("trigger", get_players()[0]);
}

shared_fast_mound_unlock( str_vinyl_record ) // OVERRIDE: maps\mp\zm_tomb_main_quest::run_gramophone_door
{
    flag_init( self.targetname + "_opened" );
    trig_position = getstruct( self.targetname + "_position", "targetname" );
    trig_position.has_vinyl = 0;
    trig_position.gramophone_model = undefined;
    trig_position thread maps\mp\zm_tomb_main_quest::watch_gramophone_vinyl_pickup();
    trig_position thread maps\mp\zm_tomb_main_quest::door_watch_open_sesame();
    t_door = tomb_spawn_trigger_radius( trig_position.origin, 60.0, 1 );
    t_door set_unitrigger_hint_string( &"ZOMBIE_BUILD_PIECE_MORE" );
    level waittill_any( "gramophone_vinyl_player_picked_up", "open_sesame", "open_all_gramophone_doors" );
    str_craftablename = "gramophone";
    t_door set_unitrigger_hint_string( &"ZM_TOMB_RU" );
    trig_position.trigger = t_door;

    while ( !trig_position.has_vinyl )
        wait 0.05;

    t_door set_unitrigger_hint_string( &"ZM_TOMB_PLGR" );

    while ( true )
    {
        t_door waittill( "trigger", player );

        if ( !isdefined( trig_position.gramophone_model ) )
        {
            if ( !flag( "gramophone_placed" ) || isdefined( level.b_open_all_gramophone_doors ) && level.b_open_all_gramophone_doors )
            {
                if ( !( isdefined( level.b_open_all_gramophone_doors ) && level.b_open_all_gramophone_doors ) )
                {
                    trig_position.gramophone_model = spawn( "script_model", trig_position.origin );
                    trig_position.gramophone_model.angles = trig_position.angles;
                    trig_position.gramophone_model setmodel( "p6_zm_tm_gramophone" );
                    flag_set( "gramophone_placed" );
                    level setclientfield( "piece_record_zm_player", 0 );
                }

                t_door trigger_off();
                // MODIFIED: shared setup omits music/stairs audio. Ordinary
                // openings retain native sounds, even if this override is installed.
                if(!isdefined(self.shared_mound_silent) || !self.shared_mound_silent)
                {
                    str_song = trig_position maps\mp\zm_tomb_main_quest::get_gramophone_song();
                    playsoundatposition( str_song, self.origin );
                    self playsound( "zmb_crypt_stairs" );
                }
                wait 0.05;  // MODIFIED: vanilla waits 6
                maps\mp\zm_tomb_main_quest::chamber_blocker();
                flag_set( self.targetname + "_opened" );

                if ( isdefined( trig_position.script_flag ) )
                    flag_set( trig_position.script_flag );

                level setclientfield( "crypt_open_exploder", 1 ); // MODIFIED: vanilla 10 seconds
                self movez( -260, 0.05, 0, 0 );
                self waittill( "movedone" );
                self connectpaths();
                self delete();
                t_door trigger_on();
                t_door set_unitrigger_hint_string( &"ZM_TOMB_PUGR" );

                if ( isdefined( level.b_open_all_gramophone_doors ) && level.b_open_all_gramophone_doors )
                    break;
            }
            else
                player door_gramophone_elsewhere_hint();
        }
        else
        {
            trig_position.gramophone_model delete();
            trig_position.gramophone_model = undefined;
            flag_clear( "gramophone_placed" );
            player playsound( "zmb_craftable_pickup" );
            level setclientfield( "piece_record_zm_player", 1 );
            break;
        }
    }

    t_door tomb_unitrigger_delete();
    trig_position.trigger = undefined;
}

shared_chamber_discs_randomize() // OVERRIDE: maps\mp\zm_tomb_quest_crypt::chamber_discs_randomize
{
    // Native calls: mound opening, then each completed chamber-orb puzzle.
    level.n_disc_scrambles++;
    scramble = get_cfg_int("disc_" + level.n_disc_scrambles);
    discs = getentarray("crypt_puzzle_disc", "script_noteworthy");
    foreach(disc in discs)
        while(!isdefined(disc.position)) wait 0.05;

    //MODIFIED: the four dials, as vanilla picks them (the ones with levers).
    // The main disc carries the gems; its position must stay untouched, and the
    // entity array does not promise it comes first.
    dials = [];
    foreach(disc in discs)
        if(isdefined(disc.target)) dials[dials.size] = disc;
    //MODIFIED END

    //MODIFIED: opening shortcut. Every dial shows the start's staff colour except
    // one, which the "Disc Turn" option (last_disc) sets: 0 random, 1 = 0 turns,
    // 2 = 1 turn... An explicit disc_N preset takes priority.
    shortcut_gem = shared_disc_shortcut_gem();
    if(isdefined(shortcut_gem) && scramble == 0)
    {
        aligned = maps\mp\zm_tomb_quest_crypt::chamber_disc_get_gem_position(shortcut_gem); // Vanilla: the position that lines a dial up with this gem.
        setting = get_cfg_int("last_disc");
        turns = setting - 1;
        if(setting == 0) turns = randomintrange(0, 4);
        dials[0].position = aligned;
        dials[1].position = aligned;
        dials[2].position = (aligned + turns) % 4;
        dials[3].position = aligned;
    }
    //MODIFIED END
    else
    {
        prev_disc_pos = 0;
        for(i = 1; i <= dials.size; i++)
        {
            turn = randomintrange(1, 3);
            if(scramble) turn = int(scramble / pow(10, 4 - i)) % 10;
            dials[i - 1].position = (prev_disc_pos + turn) % 4;
            prev_disc_pos = dials[i - 1].position;
        }
    }
    // The first scramble, and every one while a held start's setup runs, turns
    // the dials at once: each setup orb would otherwise wait for the 4 second
    // animation of the scramble before it.
    if(isdefined(level.shared_mound_discs_pending) && level.shared_mound_discs_pending)
    {
        level.shared_mound_discs_pending = false;
        shared_set_discs_silent(discs);
    }
    else if(isdefined(level.segment_setup_running))
        shared_set_discs_silent(discs);
    else
        maps\mp\zm_tomb_quest_crypt::chamber_discs_move_all_to_position(discs);
}

// Which crypt gem the opening shortcut lines the dials up with at this scramble,
// or undefined to scramble normally.
//   Ice:  the mound opening (scramble 1) -> blue.
//   Wind: the setup Ice orb (scramble 2) -> yellow, only for the Craft start.
//   Fire: the setup Wind orb (scramble 3) -> red, only for the Craft start.
//   Lightning: the setup Fire orb (scramble 4) -> purple, only for the Craft start.
//         Exit starts keep the normal scramble.
shared_disc_shortcut_gem()
{
    if(level.gamemode == "icestart" && level.n_disc_scrambles == 1)
        return "crypt_gem_ice";
    if(level.gamemode == "windstart" && level.n_disc_scrambles == 2 && get_cfg_int("wind_spawn") != 1)
        return "crypt_gem_air";
    if(level.gamemode == "firestart" && level.n_disc_scrambles == 3 && get_cfg_int("fire_spawn") != 1)
        return "crypt_gem_fire";
    if(level.gamemode == "lightningstart" && level.n_disc_scrambles == 4 && get_cfg_int("lightning_spawn") != 1)
        return "crypt_gem_elec";
    return undefined;
}

shared_set_discs_silent(discs)
{
    flag_set("disc_rotation_active");
    foreach(disc in discs)
        disc rotateto((disc.angles[0], disc.position * 90, disc.angles[2]), 0.05, 0, 0);
    wait 0.05;
    // The client redraws the lights on a bryce_cake change, and two toggles in
    // one frame leave the value (and the lights) unchanged. Like vanilla
    // chamber_disc_move_to_position, toggle again once the dials have settled,
    // so the lights cannot keep the colours from before the move.
    foreach(disc in discs)
        disc maps\mp\zm_tomb_quest_crypt::bryce_cake_light_update(0);
    wait 0.25;
    foreach(disc in discs)
        disc maps\mp\zm_tomb_quest_crypt::bryce_cake_light_update(0);
    flag_clear("disc_rotation_active");
}

/*##############################################################################
                              Round functions
##############################################################################*/
// Starts on target_round, as a fresh round or with remaining_zombies left in it.
shared_set_round(target_round, remaining_zombies)
{
    if(target_round < 1) target_round = 1;

    // Panzers and Templars planned before this round already happened; a fresh
    // round's own ones still come.
    first_live_round = target_round;
    if(isdefined(remaining_zombies)) first_live_round++;
    shared_schedule_catch_up(level.panzer_schedule, first_live_round);
    shared_schedule_catch_up(level.templar_schedule, first_live_round);

    practice_set_round(target_round, remaining_zombies);
}

/*##############################################################################
                              Crazy Place gem functions
##############################################################################*/
shared_unlock_gem(gem_array)
{
    foreach(staff_index in gem_array)
    {
        level thread shared_unlock_gem_staff(int(staff_index));
    }
}

shared_unlock_gem_staff(staff_index)
{
    shared_enable_chamber_exit(staff_index);

    // Wait crystal watcher to store plinth
    plinth = getent("crystal_plinth" + staff_index, "targetname");
    while(!isdefined(plinth) || !isdefined(plinth.v_staff))
    {
        wait 0.05;
        plinth = getent("crystal_plinth" + staff_index, "targetname");
    }
    wait 0.05;
    level notify("player_teleported", get_players()[0], staff_index);
}


/*##############################################################################
                              Player perks and challenge rewards
##############################################################################*/
shared_perks(perks)
{
    self endon("disconnect");
    level endon("end_game");
    foreach(perk in perks)
    {
        self maps\mp\zombies\_zm_perks::give_perk(perk);
        wait 0.05;
    }
}

shared_box_rewards(reward_name, consumed)
{
    self endon("disconnect");
    level endon("end_game");
    if(!isdefined(consumed)) consumed = false;
    while(!isdefined(self.characterindex) || !isdefined(level._challenges) || !isdefined(level._challenges.a_players[self.characterindex])) wait 0.05;

    if(reward_name == "zc_boxes_filled")
    {
        // Preserve the checkpoint's soul-box cleanup and gong delay.
        wait 10;
        foreach(box in getentarray("foot_box", "script_noteworthy"))
        {
            volume = getent(box.target, "targetname");
            if(isdefined(volume)) volume delete();
            box delete();
        }
        wait 7;
    }
    self shared_box_reward_state(reward_name, consumed);
    if(reward_name == "zc_headshots") self.headshots = 115;
}

shared_box_reward_state(name, consumed)
{
    stat = maps\mp\zombies\_zm_challenges::get_stat(name, self);
    self maps\mp\zombies\_zm_challenges::set_stat(name, stat.s_parent.n_goal);
    claimed = stat.b_reward_claimed;
    consume = consumed;
    if(stat.s_parent.b_team)
    {
        category = level._challenges.s_team;
        stat.a_b_player_rewarded[self.characterindex] = consume;
    }
    else
        category = level._challenges.a_players[self.characterindex];

    if(claimed && !consume) category.n_medals_held++;
    else if(!claimed && consume) category.n_medals_held--;
    stat.b_reward_claimed = consume;
    if(isdefined(stat.s_parent.cf_complete))
        self setclientfieldtoplayer(stat.s_parent.cf_complete, !consume);
}

/*##############################################################################
                              Hud timer
##############################################################################*/
// Splits run from start_split to Freedom; each case falls through to the next.
// Without clock_start the run clock (level.game_start_time) is already running.
// With it, the clock starts at the first split: clock_start sets
// level.game_start_time for the checkpoint, then the running row appears.
shared_segment_timer(start_split, clock_start)
{
    level endon("end_game");
    level.segment_names = array("^2NML ^7", "^4ICE ^7", "^3WIND ^7", "^1FIRE ^7", "^6LIGHTNING ^7", "^3FREEDOM ^7");
    level.segment_clock_start = clock_start;
    level.segment_next = start_split;
    // Rows line up across modes: Ice is row 0 and NML shifts nothing.
    level.segment_row = start_split - SPLIT_ICE;
    if(level.segment_row < 0) level.segment_row = 0;

    level.timer["segment"] = createServerFontString("default", 1.3);
    level.timer["segment"] setpoint("CENTER", "TOP", 0, 0);
    level.timer["segment"].sort = 2000;
    timer_segment_hud(level.timer["segment"]);
    level thread shared_segment_end();

    if(!isdefined(clock_start)) level thread shared_segment_running();

    switch(start_split)
    {
        case SPLIT_NML:
            flag_wait("activate_zone_nml");
            shared_segment_split(SPLIT_NML);
        case SPLIT_ICE:
            while(level.n_staffs_crafted < 1) wait 0.05;
            shared_segment_split(SPLIT_ICE);
        case SPLIT_WIND:
            while(level.n_staffs_crafted < 2) wait 0.05;
            shared_segment_split(SPLIT_WIND);
        case SPLIT_FIRE:
            while(level.n_staffs_crafted < 3) wait 0.05;
            shared_segment_split(SPLIT_FIRE);
        case SPLIT_LIGHTNING:
            while(level.n_staffs_crafted < 4) wait 0.05;
            shared_segment_split(SPLIT_LIGHTNING);
            // Ending segment is timed from the fire link.
            level.timer_segment_paused = true;
            timer_segment_refresh();
            flag_wait("fire_link_enabled");
            level.timer_segment_paused = undefined;
            timer_segment_refresh();
            level.segment_start_time = gettime();
            level.timer["segment"] settimerup(0);
    }
}

shared_segment_split(split)
{
    first = !isdefined(level.segment_running);
    if(first) [[ level.segment_clock_start ]]();

    // A hidden split (Timer menu) gets no row; see split_shown.
    if(split_shown(split))
    {
        hud = createServerFontString("default", 1.4);
        hud.sort = 2000;
        hud.hidewheninmenu = 0;
        hud setpoint("TOPLEFT", "TOPLEFT", -63, 75 + level.segment_row * 16);
        hud setTextUnlimited(level.segment_names[split] + game_time_string());
        timer_main_hud(hud);
        level.segment_row++;
    }
    level.segment_next = split + 1;

    // The segment timer only times staff to staff.
    if(split >= SPLIT_ICE && split <= SPLIT_LIGHTNING)
    {
        level.segment_start_time = gettime();
        level.timer["segment"] settimerup(0);
    }
    if(first) level thread shared_segment_running();
}

// Live time for the next split, one row below the last recorded split.
shared_segment_running()
{
    level endon("end_game");
    level.segment_running = createServerFontString("default", 1.4);
    level.segment_running.sort = 2000;
    level.segment_running.hidewheninmenu = 0;
    timer_main_hud(level.segment_running);
    while(true)
    {
        level.segment_running setpoint("TOPLEFT", "TOPLEFT", -63, 75 + level.segment_row * 16);
        level.segment_running setTextUnlimited(level.segment_names[split_next_shown(level.segment_next)] + game_time_string());
        wait 0.05;
    }
}

// Freezes the timers at game end; Freedom only counts if Samantha was released.
shared_segment_end()
{
    level waittill("end_game");
    if(!isdefined(level.segment_start_time)) return;
    segment = gettime() - level.segment_start_time;
    if(flag("ee_samantha_released"))
    {
        level.segment_running destroy();
        shared_segment_split(SPLIT_FREEDOM);
    }
    level.timer["segment"] setTextUnlimited(game_time_string(1, segment));
}

/*##############################################################################
                              Segment baseline (Ice and Wind Start)
##############################################################################*/
shared_cycle_tracker()
{
    // The menu toggle and a mode's start can both create it; keep one.
    if(isdefined(level.cycle_display)) level.cycle_display destroy();
    level.cycle_display = createServerFontString("default", 1.3);
	level.cycle_display setpoint("LEFT", "LEFT", 5, -232);
	level.cycle_display.alpha = 1;
	level.cycle_display setTextUnlimited(level.cycle_string);
}

shared_toggle_cycle_display()
{
    setting = "cycle_tracker";
    new_status = 1 - get_cfg_int(setting);
    level.mode_cfg[setting] = new_status;
    write_config(level.mode_cfg, level.mode_cfg_str);
    if(new_status) level thread shared_cycle_tracker();
    else if(isdefined(level.cycle_display)) level.cycle_display destroy();
    self refresh_menu();
}

shared_kill_plane()
{
    plane = getentarray( "air_crystal_biplane", "targetname" );
    while(plane.size < 2)
    {
        wait 1;
        plane = getentarray( "air_crystal_biplane", "targetname" );
    }

    plane[0] dodamage( 66666, plane[plane.size].origin, self);
    plane[0] ent_flag_set( "biplane_down" );
    level notify( "biplane_down" );
}

shared_generators()
{
    generators = getstructarray("s_generator", "targetname");
    foreach(gen in generators)
    {
        gen maps\mp\zm_tomb_capture_zones::set_player_controlled_area();
        gen.n_current_progress = 100;
        gen maps\mp\zm_tomb_capture_zones::generator_state_power_up();
        level setclientfield( gen.script_noteworthy, gen.n_current_progress / 100 );
    }

    //Prevent r10 gen start - gen6 skip not done
    while(level.round_number < 10) wait 0.05;
    flag_set("zone_capture_in_progress");
    while(level.round_number < 11) wait 0.05;
    flag_clear("zone_capture_in_progress");
}

shared_pointbased_drops()
{
	level waittill("start_of_round");
	wait 1;
	level.score_to_drop = 33000 + randomint(1000);
	p_score = int(level.score_to_drop / 10) * 10;
	self.score_total = p_score - 1000 - (randomint(200) * 10);
	level.zombie_vars["zombie_powerup_drop_increment"] = 5004.53758257;
	level.zombie_vars["zombie_drop_item"] = 0;
}

shared_wallbuy_outlines(show_ak)
{
    p1 = getPlayers()[0];
	goat = randomint(100) < 5;

    for( i = 0; i < level._spawned_wallbuys.size; i++)
    {
		wep = level._spawned_wallbuys[i].zombie_weapon_upgrade;
        if(wep == "mp40_zm" || wep == "claymore_zm")
            level._spawned_wallbuys[i].trigger_stub maps\mp\zombies\_zm_weapons::show_all_weapon_buys( p1, maps\mp\zombies\_zm_weapons::get_weapon_cost( wep ), maps\mp\zombies\_zm_weapons::get_ammo_cost( wep ), 0 );

		if(wep == "beretta93r_zm" && goat)
			level._spawned_wallbuys[i].trigger_stub maps\mp\zombies\_zm_weapons::show_all_weapon_buys( p1, maps\mp\zombies\_zm_weapons::get_weapon_cost( wep ), maps\mp\zombies\_zm_weapons::get_ammo_cost( wep ), 0 );
		if(wep == "ak74u_zm" && !goat && show_ak)
			level._spawned_wallbuys[i].trigger_stub maps\mp\zombies\_zm_weapons::show_all_weapon_buys( p1, maps\mp\zombies\_zm_weapons::get_weapon_cost( wep ), maps\mp\zombies\_zm_weapons::get_ammo_cost( wep ), 0 );
    }

}

shared_shovel()
{
    n_player = self getentitynumber() + 1;
    self.dig_vars["has_shovel"] = 1;
    level setclientfield( "shovel_player" + n_player, 1 );

    // Remove the lower spawn-room shovel and its pickup prompt together.
    foreach(stub in arraycopy(level._unitriggers.trigger_stubs))
    {
        if(!isDefined(stub) || !isDefined(stub.e_shovel)) continue;
        if(distance(stub.e_shovel.origin, (2486, 5286, -368)) > 128) continue;
        stub.e_shovel delete();
        maps\mp\zombies\_zm_unitrigger::unregister_unitrigger(stub);
    }
}

// The items every segment start has, plus the conditional ones its Items menu
// declares (Segment item declarations). Uncollected items are placed by
// shared_part_location. Crystals are handled by each mode's setup.
shared_get_parts()
{
    // Taking a crystal deletes its model; let the native plinth watcher store it first.
    plinth = getent("crystal_plinth4", "targetname");
    while(!isDefined(plinth.v_staff)) wait 0.05;

    icestart = level.gamemode == "icestart";

	self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "upper_staff");
	self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "middle_staff");
	self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_air", "lower_staff");

    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_water", "gem");
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_water", "upper_staff");
	self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_water", "middle_staff");
	self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_water", "lower_staff");

    // Panzer and Gen 6 parts; the middle one comes from the plane.
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_fire", "upper_staff");
	if(!icestart || get_cfg_int("plane_part"))
    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_fire", "middle_staff");
	self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_fire", "lower_staff");

    // R2L part. The mound and church parts are never collected by a segment start.
    if(!icestart || get_cfg_int("r2l"))
        self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("elemental_staff_lightning", "upper_staff");

    self maps\mp\zombies\_zm_craftables::player_get_craftable_piece("equip_dieseldrone_zm", "brain");
    self shared_give_collected_items();
    if(shared_drone_crafted()) self shared_craft_maxis_drone();
}

// Every disc, Maxis part and shield part whose location setting is "collected".
// Full Game gives them at the black screen; segment starts in shared_get_parts.
shared_give_collected_items()
{
    foreach(key in shared_item_keys())
    {
        if(!shared_item_collected(key)) continue;
        part = shared_part(key);
        self maps\mp\zombies\_zm_craftables::player_get_craftable_piece(part.craftable, part.piece);
    }
}

// Crafts the Maxis drone on the workbench in the tunnel behind Gen 4 (the open
// table nearest that generator) and gives it to the player, the way a native
// craft and pickup there would. Its three parts must be in the shared inventory.
shared_craft_maxis_drone()
{
    gen4 = level.zone_capture.zones["generator_nml_right"];
    table = undefined;
    foreach(stub in level.a_uts_craftables)
    {
        if(stub.equipname != "open_table") continue;
        if(!isDefined(table) || distancesquared(stub.origin, gen4.origin) < distancesquared(table.origin, gen4.origin))
            table = stub;
    }
    print("O-Prac: crafting the Maxis drone at " + table.origin + "\n");

    // Offer the drone on that table, as the native prompt does, and craft it.
    // player_craft moves the drone's craftable data onto the table.
    table.a_uts_open_craftables_available = array(maps\mp\zombies\_zm_craftables::find_craftable_stub("equip_dieseldrone_zm"));
    table.n_open_craftable_choice = 0;
    self maps\mp\zombies\_zm_craftables::player_craft(table.craftablespawn);

    // Native order: validation records the pickup table, the crafted callback
    // places the stand, then the purchase gives the drone.
    level.quadrotor_status.pickup_trig = table;
    table [[table.craftablestub.onfullycrafted]]();
    pickup = spawn("trigger_radius_use", table.origin, 0, 32, 64);
    pickup.stub = table;
    pickup setinvisibletoall();
    pickup maps\mp\zm_tomb_craftables::setup_quadrotor_purchase(self);
    pickup delete();
}

/*##############################################################################
                              Panzer and Templar schedule
##############################################################################*/
// Panzers come on round 8, then every 4-5 rounds; Templars on round 10, then
// every 3-5 rounds. The gaps to the 2nd and 3rd come from the Panzer 2/3 and
// Templar II/III settings, else random, and count from when the previous one
// actually came. Segment starts assume the route's skip (a generator capture in
// progress over the round change) pushed the first Templars to round 11.
//
// Each mode calls shared_schedules_init in its initialize and installs the two
// trackers below with replacefunc. shared_set_round marks everything planned
// before a later start round as already happened.

// Default for Full Game and every segment start: Templar II/III rounds random
// (0); Templars I at gens 1-3, II and III at gens 2-5.
shared_templar_defaults(settings_ar)
{
    settings_ar["temps_2_round"] = 0;
    settings_ar["temps_3_round"] = 0;
    for(i = 1; i < 7; i++)
    {
        settings_ar["temps_1_gen_" + i] = (i <= 3);
        settings_ar["temps_2_gen_" + i] = (i >= 2 && i <= 5);
        settings_ar["temps_3_gen_" + i] = (i >= 2 && i <= 5);
    }
    return settings_ar;
}

shared_schedules_init(first_templar_round)
{
    level.panzer_schedule = shared_schedule(8, array("panzer_2", "panzer_3"), 4, 5);
    level.templar_schedule = shared_schedule(first_templar_round, array("temps_2_round", "temps_3_round"), 3, 5);
}

shared_schedule(first_round, gap_settings, min_gap, max_gap)
{
    schedule = spawnstruct();
    schedule.next_round = first_round;
    schedule.count = 0; // Events so far.
    schedule.min_gap = min_gap;
    schedule.max_gap = max_gap;
    // Rolled now, so a late start's history and its future agree.
    schedule.gaps = [];
    foreach(setting in gap_settings)
    {
        gap = get_cfg_int(setting);
        if(gap < min_gap || gap > max_gap) gap = randomintrange(min_gap, max_gap + 1);
        schedule.gaps[schedule.gaps.size] = gap;
    }
    return schedule;
}

// Records an event on round; the next one follows after its gap.
shared_schedule_advance(schedule, round)
{
    gap = randomintrange(schedule.min_gap, schedule.max_gap + 1);
    if(schedule.count < schedule.gaps.size) gap = schedule.gaps[schedule.count];
    schedule.count++;
    schedule.last_round = round;
    schedule.next_round = round + gap;
}

// Late start: events planned before first_live_round already happened.
shared_schedule_catch_up(schedule, first_live_round)
{
    while(schedule.next_round < first_live_round) shared_schedule_advance(schedule, schedule.next_round);
}

// OVERRIDE: maps\mp\zombies\_zm_ai_mechz_ffotd::mechz_round_tracker_loop_start (empty in vanilla).
// The native tracker calls it at the top of every loop once round 8 is reached.
shared_mechz_round_tracker_loop_start()
{
    // Segment starts hold Panzers until the player is released.
    if(isdefined(level.shared_schedule_hold)) flag_wait(level.shared_schedule_hold);
    schedule = level.panzer_schedule;

    // Late start: hand the native tracker the waves that already happened, so
    // wave size and health keep counting from there.
    if(level.mechz_round_count < schedule.count)
    {
        level.mechz_round_count = schedule.count;
        level.num_mechz_spawned = shared_panzers_in_waves(schedule.count);
        level.mechz_last_spawn_round = schedule.last_round;
    }
    // Waves the native tracker spawned since its last loop.
    while(level.mechz_round_count > schedule.count) shared_schedule_advance(schedule, level.mechz_last_spawn_round);
    level.next_mechz_round = schedule.next_round;
}

/*##############################################################################
                              Panzer waiting at a spot (segment starts)
##############################################################################*/
// In a run, a Panzer due on the start round (Windstart: Panzer 2 a 4 rounder,
// round 12) came while the player was still above ground and waits outside when
// they come out of the Crazy Place: vanilla Panzers do not target a player in the
// Crazy Place (get_favorite_enemy skips is_player_in_chamber). The native tracker
// cannot reproduce that in a segment start: while the player is in the Crazy
// Place no above-ground zone is active, so level.zombie_mechz_locations is empty
// (zonemgr create_spawner_list) and mechz_spawning_logic waits, and mechz_spawn
// deletes a Panzer with no location. So the held setup spawns it itself at the
// mode's panzer_spot and books it as that round's wave, so the native tracker
// does not spawn another (user, 2026-10-20).

// Whether the mode's panzer_spot applies: its Panzer wave (panzer_spot_wave, e.g.
// 2 for Panzer 2) is due exactly on the start round. The gaps are rolled once at
// load from the Panzer 2/3 settings, or at random, and shared_set_round catches
// the schedule up, so this is decided once: a 4 rounder (set or rolled) puts
// Panzer 2 on round 12; a 5 rounder (round 13) leaves everything vanilla.
shared_panzer_due_at_spot()
{
    if(!isdefined(level.segment) || !isdefined(level.segment.panzer_spot)) return false;
    schedule = level.panzer_schedule;
    if(isdefined(level.segment.panzer_spot_wave) && schedule.count + 1 != level.segment.panzer_spot_wave) return false;
    return schedule.next_round == level.segment.round;
}

// Spawns the start round's Panzer at panzer_spot, as the native tracker and
// mechz_spawning_logic would (health, spawn, wave count, next Panzer round).
shared_prespawn_panzer()
{
    schedule = level.panzer_schedule;
    round = level.round_number;

    // The waves before this one, as the tracker's late-start sync would set them.
    level.mechz_round_count = schedule.count;
    level.num_mechz_spawned = shared_panzers_in_waves(schedule.count);
    level.mechz_last_spawn_round = schedule.last_round;
    maps\mp\zombies\_zm_ai_mechz::mechz_health_increases();

    spot = spawnstruct();
    spot.origin = level.segment.panzer_spot;
    spot.angles = (0, 0, 0);
    level.mechz_force_spawn_pos = spot; // vanilla mechz_spawn uses it over its own pick.
    // mechz_spawn deletes the Panzer when this is empty (the player is in the
    // Crazy Place); zonemgr rebuilds the list on its next update.
    if(level.zombie_mechz_locations.size < 1) level.zombie_mechz_locations = array(spot);
    ai = spawn_zombie(level.mechz_spawners[0]);
    if(!isdefined(ai))
    {
        level.mechz_force_spawn_pos = undefined;
        shared_setup_trace("Panzer pre-spawn failed");
        return;
    }
    ai thread maps\mp\zombies\_zm_ai_mechz::mechz_spawn();

    // This round's wave is done: the tracker's next loop sees it and moves on.
    shared_schedule_advance(schedule, round);
    level.mechz_round_count = schedule.count;
    level.num_mechz_spawned = shared_panzers_in_waves(schedule.count);
    level.mechz_last_spawn_round = round;
    level.next_mechz_round = schedule.next_round;
    level.mechz_should_drop_powerup = 1;
}

// A Panzer is alive and has finished landing: vanilla mechz_spawn starts
// mechz_jump_think, which sets closest_jump_point, right after the landing
// animation.
shared_panzer_landed()
{
    foreach(ai in getaispeciesarray(level.zombie_team, "all"))
        if(is_true(ai.is_mechz) && isalive(ai) && isdefined(ai.closest_jump_point))
            return true;
    return false;
}

// Native wave sizes: always 1 Panzer solo; otherwise 1 for each of the first
// two waves, then 2, then 3.
shared_panzers_in_waves(waves)
{
    total = 0;
    for(wave = 0; wave < waves; wave++)
    {
        if(is_true(level.is_forever_solo_game) || wave < 2) total += 1;
        else if(wave < 5) total += 2;
        else total += 3;
    }
    return total;
}

shared_recapture_round_tracker() // OVERRIDE: maps\mp\zm_tomb_capture_zones::recapture_round_tracker
{
    // A segment start's own round has no round change after release; check it then.
    if(isdefined(level.shared_schedule_hold))
    {
        flag_wait(level.shared_schedule_hold);
        shared_try_recapture();
    }
    while(true)
    {
        level waittill_any("between_round_over", "force_recapture_start");
        shared_try_recapture();
    }
}

shared_try_recapture()
{
    schedule = level.templar_schedule;
    if(level.round_number < schedule.next_round || flag("zone_capture_in_progress")) return;
    if(maps\mp\zm_tomb_capture_zones::get_captured_zone_count() < maps\mp\zm_tomb_capture_zones::get_player_controlled_zone_count_for_recapture()) return;

    shared_schedule_advance(schedule, level.round_number);
    // Which attack this is selects its Templars I/II/III generator settings.
    level.n_templar_rounds = schedule.count;
    level thread maps\mp\zm_tomb_capture_zones::recapture_round_start();
}

shared_get_recapture_zone(s_last_recapture_zone)
{
	a_s_player_zones = [];
	foreach ( str_key, s_zone in level.zone_capture.zones )
	{
		if(s_zone ent_flag("player_controlled"))
		{
			a_s_player_zones[str_key] = s_zone;
		}
	}
	s_recapture_zone = undefined;
	if(a_s_player_zones.size)
	{
		if(isDefined(s_last_recapture_zone))
		{
			n_distance_closest = undefined;
			foreach(s_zone in a_s_player_zones)
			{
				n_distance = distancesquared(s_zone.origin, s_last_recapture_zone.origin);
				if(!isDefined(n_distance_closest) || n_distance < n_distance_closest)
				{
					s_recapture_zone = s_zone;
					n_distance_closest = n_distance;
				}
			}
		}
		else if(level.n_templar_rounds < 4)
		{
			possible_gens = [];
			possible_gens[possible_gens.size] = "generator_start_bunker";
			possible_gens[possible_gens.size] = "generator_tank_trench";
			possible_gens[possible_gens.size] = "generator_mid_trench";
			possible_gens[possible_gens.size] = "generator_nml_right";
			possible_gens[possible_gens.size] = "generator_nml_left";
			possible_gens[possible_gens.size] = "generator_church";
			non_wanted_gens = [];
			for(i = 1; i < 7; i++)
			{
				gen_dvar = "temps_" + level.n_templar_rounds + "_gen_" + i;
				gen_enabled = get_cfg_int(gen_dvar);
				if(gen_enabled == 0)
				{
					non_wanted_gens[non_wanted_gens.size] = possible_gens[i - 1];
				}
			}
			invalid_gen = 1;
			timeout = 0;
			while(invalid_gen)
			{
				if(timeout == 30)
				{
					s_recapture_zone = random(a_s_player_zones);
					break;
				}
				invalid_gen = 0;
				s_recapture_zone = random(a_s_player_zones);
				foreach(loc in non_wanted_gens)
				{
					if(s_recapture_zone == level.zone_capture.zones[loc])
					{
						invalid_gen = 1;
					}
				}
				timeout++;
			}
		}
		else
		{
			s_recapture_zone = random(a_s_player_zones);
		}
	}
	return s_recapture_zone;
}

// Shared by Full Game and the segment modes. Layout follows vanilla; every
// change is fenced by //MODIFIED ... //MODIFIED END or tagged inline.
// Vanilla devgui (/# #/) blocks are omitted.
shared_robot_cycling() // OVERRIDE: maps\mp\zm_tomb_giant_robot::robot_cycling
{
    three_robot_round = 0;
    last_robot = -1;

    //MODIFIED: segment modes (level.delay_robot) skip the intro walk, hold the
    // robots until their start event, then resume at the reconstructed cycle.
    // three_robot_round carries a round 12 trio that happened before the craft.
    // Full Game keeps the vanilla intro walk.
    if ( is_true( level.delay_robot ) )
    {
        flag_wait( "start_robots" );
        level.robot_cycle = level.segment_next_robot_cycle - 1;
        three_robot_round = level.segment_three_robot_round;

        if ( level.segment_robot_wait > 0 )
            wait( level.segment_robot_wait );
    }
    else
    {
        level.robot_cycle = 0;
        level thread maps\mp\zm_tomb_giant_robot::giant_robot_intro_walk( 1 ); // vanilla
        level waittill( "giant_robot_intro_complete" );                      // vanilla
    }
    //MODIFIED END

    while ( true )
    {
        //MODIFIED: cycle index for cfg settings and the cycle tracker;
        // -1 means no setting chose the robot.
        level.robot_cycle++;
        random_number = -1;
        //MODIFIED END

        if ( !( level.round_number % 4 ) && three_robot_round != level.round_number )
            flag_set( "three_robot_round" );

        if ( flag( "ee_all_staffs_placed" ) && !flag( "ee_mech_zombie_hole_opened" ) )
            flag_set( "three_robot_round" );

        //MODIFIED: robot from the active mode's cfg. In a three robot round it
        // chooses which robot carries the hatch. ROBOT_RANDOM keeps the vanilla roll.
        if ( level.robot_cycle <= ROBOT_CYCLE_COUNT )
        {
            setting = get_cfg_int( "cycle_" + level.robot_cycle );

            if ( setting >= ROBOT_ODIN && setting <= ROBOT_FREYA )
                random_number = setting;
        }

        // Rain Fire: hatch robot for three robot rounds once all staffs are upgraded.
        if ( flag( "three_robot_round" ) && flag( "ee_all_staffs_upgraded" ) && !flag( "ee_mech_zombie_hole_opened" ) )
        {
            setting = get_cfg_int( "rain_robot" );

            if ( setting >= ROBOT_ODIN && setting <= ROBOT_FREYA )
                random_number = setting;
        }
        //MODIFIED END

        if ( flag( "three_robot_round" ) )
        {
            level.zombie_ai_limit = 22;

            if ( random_number < 0 ) //MODIFIED: vanilla always rolls
                random_number = randomint( 3 );

            shared_robot_cycle_string( 1, 3 ); //MODIFIED: cycle tracker

            if ( random_number == 2 )
                level thread shared_giant_robot_start_walk( 2 ); //MODIFIED: shared walk
            else
                level thread shared_giant_robot_start_walk( 2, 0 ); //MODIFIED: shared walk

            wait 5;

            if ( random_number == 0 )
                level thread shared_giant_robot_start_walk( 0 ); //MODIFIED: shared walk
            else
                level thread shared_giant_robot_start_walk( 0, 0 ); //MODIFIED: shared walk

            wait 5;

            if ( random_number == 1 )
                level thread shared_giant_robot_start_walk( 1 ); //MODIFIED: shared walk
            else
                level thread shared_giant_robot_start_walk( 1, 0 ); //MODIFIED: shared walk

            level waittill( "giant_robot_walk_cycle_complete" );
            level waittill( "giant_robot_walk_cycle_complete" );
            level waittill( "giant_robot_walk_cycle_complete" );
            shared_robot_cycle_string( 0, 3 ); //MODIFIED: cycle tracker
            wait 5;
            level.zombie_ai_limit = 24;
            three_robot_round = level.round_number;
            last_robot = -1;
            flag_clear( "three_robot_round" );
        }
        else
        {
            //MODIFIED: replaces the vanilla roll. Before No Man's Land only Odin
            // or Thor walks (a configured Freya is rerolled), as in vanilla. After
            // it, the robot cannot repeat the last one, but the reroll is Odin or
            // Thor only; vanilla rolls randomint( 3 ). The NML difference predates
            // this shared version (upstream O-Prac).
            if ( flag( "activate_zone_nml" ) )
            {
                while ( random_number == last_robot || random_number < 0 )
                    random_number = randomint( 2 );
            }
            else if ( random_number < 0 || random_number > 1 )
                random_number = randomint( 2 );
            //MODIFIED END

            last_robot = random_number;
            shared_robot_cycle_string( 1, random_number ); //MODIFIED: cycle tracker
            level thread shared_giant_robot_start_walk( random_number ); //MODIFIED: shared walk
            level waittill( "giant_robot_walk_cycle_complete" );
            shared_robot_cycle_string( 0, random_number ); //MODIFIED: cycle tracker
            wait 5;
        }
    }
}

#using_animtree("zm_tomb_giant_robot_hatch");
shared_giant_robot_start_walk( n_robot_id, b_has_hatch ) // COPY: maps\mp\zm_tomb_giant_robot::giant_robot_start_walk
{
    if ( !isdefined( b_has_hatch ) )
        b_has_hatch = 1;

    ai = getent( "giant_robot_walker_" + n_robot_id, "targetname" );
    level.gr_foot_hatch_closed[n_robot_id] = 1;
    ai.b_has_hatch = b_has_hatch;
    ai ent_flag_clear( "kill_trigger_active" );
    ai ent_flag_clear( "robot_head_entered" );

    if ( isdefined( ai.b_has_hatch ) && ai.b_has_hatch )
        m_sole = getent( "target_sole_" + n_robot_id, "targetname" );

    if ( isdefined( m_sole ) && ( isdefined( ai.b_has_hatch ) && ai.b_has_hatch ) )
    {
        m_sole setcandamage( 1 );
        m_sole.health = 99999;
        m_sole useanimtree( #animtree );
        m_sole unlink();
    }

    wait 10;

    if ( isdefined( m_sole ) )
    {
        if ( cointoss() )
            ai.hatch_foot = "left";
        else
            ai.hatch_foot = "right";

        //MODIFIED: hatch foot from the active mode's cfg: foot_<cycle>, then
        // rain_foot once all staffs are crafted. FOOT_RANDOM keeps the coin toss
        // above, which still runs so the random call order matches vanilla.
        foot = FOOT_RANDOM;

        if ( level.robot_cycle <= ROBOT_CYCLE_COUNT )
            foot = get_cfg_int( "foot_" + level.robot_cycle );

        if ( flag( "ee_all_staffs_crafted" ) )
        {
            rain_foot = get_cfg_int( "rain_foot" );

            if ( rain_foot == FOOT_LEFT || rain_foot == FOOT_RIGHT )
                foot = rain_foot;
        }

        if ( foot == FOOT_LEFT )
            ai.hatch_foot = "left";
        else if ( foot == FOOT_RIGHT )
            ai.hatch_foot = "right";
        //MODIFIED END

        if ( ai.hatch_foot == "left" )
        {
            n_sole_origin = ai gettagorigin( "TAG_ATTACH_HATCH_LE" );
            v_sole_angles = ai gettagangles( "TAG_ATTACH_HATCH_LE" );
            ai.hatch_foot = "left";
            str_sole_tag = "TAG_ATTACH_HATCH_LE";
            ai attach( "veh_t6_dlc_zm_robot_foot_hatch", "TAG_ATTACH_HATCH_RI" );
        }
        else if ( ai.hatch_foot == "right" )
        {
            n_sole_origin = ai gettagorigin( "TAG_ATTACH_HATCH_RI" );
            v_sole_angles = ai gettagangles( "TAG_ATTACH_HATCH_RI" );
            ai.hatch_foot = "right";
            str_sole_tag = "TAG_ATTACH_HATCH_RI";
            ai attach( "veh_t6_dlc_zm_robot_foot_hatch", "TAG_ATTACH_HATCH_LE" );
        }

        m_sole.origin = n_sole_origin;
        m_sole.angles = v_sole_angles;
        wait 0.1;
        m_sole linkto( ai, str_sole_tag, ( 0, 0, 0 ) );
        m_sole show();
        ai attach( "veh_t6_dlc_zm_robot_foot_hatch_lights", str_sole_tag );
    }

    if ( !( isdefined( ai.b_has_hatch ) && ai.b_has_hatch ) )
    {
        ai attach( "veh_t6_dlc_zm_robot_foot_hatch", "TAG_ATTACH_HATCH_RI" );
        ai attach( "veh_t6_dlc_zm_robot_foot_hatch", "TAG_ATTACH_HATCH_LE" );
    }

    wait 0.05;
    ai thread maps\mp\zm_tomb_giant_robot::giant_robot_think( ai.trig_stomp_kill_right, ai.trig_stomp_kill_left, ai.clip_foot_right, ai.clip_foot_left, m_sole, n_robot_id );
}

shared_robot_cycle_string(starting, robot, decimals = 0)
{
    robots = array("odin", "thor", "freya", "trios");
    level.cycle_string = game_time_string(get_cfg_int("cycle_tracker_ms"));
    level.cycle_string = level.cycle_string + " | cycle " + level.robot_cycle + bool_compare_string(starting, " start", " end");
    level.cycle_string = level.cycle_string + " | " + robots[robot];
    if(isDefined(level.cycle_display))  level.cycle_display setTextUnlimited(level.cycle_string);
    print(level.cycle_string);
}

shared_dig_spots_respawn( a_dig_spots )
{
	while(!isDefined(level.a_dig_spots)) wait 0.05;
	o_dig_spots = level.a_dig_spots;

    while ( true )
    {
        level waittill( "end_of_round" );

        wait 2;
        a_dig_spots = array_randomize( level.a_dig_spots );
        n_respawned = 0;
        n_respawned_max = 3;

        if ( level.weather_snow > 0 )
            n_respawned_max = 0;
        else if ( level.weather_rain > 0 )
            n_respawned_max = 5;

        if ( level.weather_snow == 0 )
            n_respawned_max += randomint( get_players().size );

		override_dig_spots = array(16, 18, 19, 20);
		if(isDefined(override_dig_spots))
		{
			for ( i = 0; i < override_dig_spots.size; i++ )
			{
				dig_index = override_dig_spots[i];
				if ( isDefined( o_dig_spots[dig_index].dug ) && o_dig_spots[dig_index].dug && n_respawned < n_respawned_max && level.n_dig_spots_cur <= level.n_dig_spots_max )
				{
					o_dig_spots[dig_index].dug = undefined;
					o_dig_spots[dig_index] thread maps\mp\zm_tomb_dig::dig_spot_spawn();
					wait_network_frame();
					n_respawned++;
				}
			}
		}

        for ( i = 0; i < a_dig_spots.size; i++ )
        {
            if ( isDefined( a_dig_spots[i].dug ) && a_dig_spots[i].dug && n_respawned < n_respawned_max && level.n_dig_spots_cur <= level.n_dig_spots_max )
            {
                a_dig_spots[i].dug = undefined;
                a_dig_spots[i] thread maps\mp\zm_tomb_dig::dig_spot_spawn();
                wait_network_frame();
                n_respawned++;
            }
        }

        if ( level.weather_snow > 0 && level.ice_staff_pieces.size > 0 )
        {
            foreach ( s_staff in level.ice_staff_pieces )
            {
                a_staff_spots = [];
                n_active_mounds = 0;

                foreach ( s_dig_spot in level.a_dig_spots )
                {
                    if ( isDefined( s_dig_spot.str_zone ) && issubstr( s_dig_spot.str_zone, s_staff.zone_substr ) )
                    {
                        if ( !( isDefined( s_dig_spot.dug ) && s_dig_spot.dug ) )
                        {
                            n_active_mounds++;
                            continue;
                        }

                        a_staff_spots[a_staff_spots.size] = s_dig_spot;
                    }
                }

                if ( n_active_mounds < 2 && a_staff_spots.size > 0 && level.n_dig_spots_cur <= level.n_dig_spots_max )
                {
                    n_index = randomint( a_staff_spots.size );
                    a_staff_spots[n_index].dug = undefined;
                    a_staff_spots[n_index] thread maps\mp\zm_tomb_dig::dig_spot_spawn();
                    arrayremoveindex( a_staff_spots, n_index );
                    n_active_mounds++;
                    wait_network_frame();
                }
            }
        }
    }
}

shared_waittill_dug(s_dig_spot)
{
	while(true)
	{
		self waittill("trigger", player);
		if(isDefined(player.dig_vars["has_shovel"]) && player.dig_vars["has_shovel"])
		{
			player playsound("evt_dig");
			s_dig_spot.dug = 1;
			level.n_dig_spots_cur--;
			playfx(level._effect["digging"], self.origin);
			player setclientfieldtoplayer("player_rumble_and_shake", 1);
			player maps\mp\zombies\_zm_stats::increment_client_stat("tomb_dig", 0);
			player maps\mp\zombies\_zm_stats::increment_player_stat("tomb_dig");
			n_good_chance = 50;

			if(player.dig_vars["n_losing_streak"] == 3)
			{
				player.dig_vars["n_losing_streak"] = 0;
				n_good_chance = 100;
			}

			if(player.dig_vars["has_upgraded_shovel"])
			{
				if(!player.dig_vars["has_helmet"])
				{
					if(randomint(100) >= 95)
					{
						player.dig_vars["has_helmet"] = 1;
						n_player = player getentitynumber() + 1;
						level setclientfield("helmet_player" + n_player, 1);
						player playsoundtoplayer("zmb_squest_golden_anything", player);
						player maps\mp\zombies\_zm_stats::increment_client_stat("tomb_golden_hard_hat", 0);
						player maps\mp\zombies\_zm_stats::increment_player_stat("tomb_golden_hard_hat");
						return;
					}
				}
				n_good_chance = 70;
			}
			if(flag("ee_mech_zombie_hole_opened") && !level.dig_n_zombie_bloods_spawned)
			{
				powerup = spawn( "script_model", self.origin );
				powerup endon( "powerup_grabbed" );
				powerup endon( "powerup_timedout" );

				level.dig_n_zombie_bloods_spawned++;
				level.dig_n_powerups_spawned++;
				level.dig_last_prize_rare = 0;
				player maps\mp\zm_tomb_dig::dig_reward_dialog( "dig_powerup" );

				powerup maps\mp\zombies\_zm_powerups::powerup_setup( "zombie_blood" );
				powerup movez( 40, 0.6 );

				powerup waittill( "movedone" );

				powerup thread maps\mp\zombies\_zm_powerups::powerup_timeout();
				powerup thread maps\mp\zombies\_zm_powerups::powerup_wobble();
				powerup thread maps\mp\zombies\_zm_powerups::powerup_grab();
			}
			else if ( player.dig_vars["n_losing_streak"] == 3 )
			{
				player.dig_vars["n_losing_streak"] = 0;
				n_good_chance = 100;
			}
			else if(randomint(100) > n_good_chance)
			{
				if(cointoss())
				{
					player maps\mp\zm_tomb_dig::dig_reward_dialog("dig_grenade");
					self thread maps\mp\zm_tomb_dig::dig_up_grenade(player);
				}
				else
				{
					player maps\mp\zm_tomb_dig::dig_reward_dialog("dig_zombie");
					self thread maps\mp\zm_tomb_dig::dig_up_zombie(player, s_dig_spot);
				}
				player.dig_vars["n_losing_streak"]++;
			}
			else if(cointoss())
			{
				self thread maps\mp\zm_tomb_dig::dig_up_powerup(player);
			}
			else
			{
				player maps\mp\zm_tomb_dig::dig_reward_dialog("dig_gun");
				self thread maps\mp\zm_tomb_dig::dig_up_weapon(player);
			}
			if(!player.dig_vars["has_upgraded_shovel"])
			{
				player.dig_vars["n_spots_dug"]++;
				if(player.dig_vars["n_spots_dug"] >= 30)
				{
					player.dig_vars["has_upgraded_shovel"] = 1;
					player thread maps\mp\zm_tomb_dig::ee_zombie_blood_dig();
					n_player = player getentitynumber() + 1;
					level setclientfield("shovel_player" + n_player, 2);
					player playsoundtoplayer("zmb_squest_golden_anything", player);
					player maps\mp\zombies\_zm_stats::increment_client_stat("tomb_golden_shovel", 0);
					player maps\mp\zombies\_zm_stats::increment_player_stat("tomb_golden_shovel");
				}
			}
			return;
		}
	}
}

// OVERRIDE: maps\mp\zm_tomb_distance_tracking::zombie_tracking_init, segment
// starts only (Full Game and the other modes run vanilla). Vanilla Origins
// despawning (zombie_tracking_dist 1520, zombie_tracking_high 1000, the tunnel
// stairs) on a real run's timing; the changes are marked //MODIFIED.
shared_segment_zombie_tracking_init()
{
    level.zombie_respawned_health = [];

    //MODIFIED: vanilla Origins values (zm_tomb_distance_tracking); this copy had the
    // generic 1500 / 600 and no tunnel marking
    if ( !isdefined( level.zombie_tracking_dist ) )
        level.zombie_tracking_dist = 1520;

    if ( !isdefined( level.zombie_tracking_high ) )
        level.zombie_tracking_high = 1000;
    //MODIFIED END

    if ( !isdefined( level.zombie_tracking_wait ) )
        level.zombie_tracking_wait = 10;

    //MODIFIED: real-run timing from the start's clock (core practice_check_phasing)
    practice_checks_hold();
    aligned = false;
    //MODIFIED END

    while ( true )
    {
        //MODIFIED: vanilla Origins marks players on the staff tunnel stairs, where
        // delete_zombie_noone_looking counts zombies as close from 1.5x as far
        a_players = get_players();

        foreach ( player in a_players )
        {
            if ( player maps\mp\zombies\_zm_zonemgr::player_in_zone( "zone_air_stairs" ) || player maps\mp\zombies\_zm_zonemgr::player_in_zone( "zone_bolt_stairs" ) || player maps\mp\zombies\_zm_zonemgr::player_in_zone( "zone_fire_stairs" ) || player maps\mp\zombies\_zm_zonemgr::player_in_zone( "zone_ice_stairs" ) )
            {
                player.b_in_tunnels = 1;
                continue;
            }

            player.b_in_tunnels = 0;
        }
        //MODIFIED END

        zombies = get_round_enemy_array();

        if ( !isdefined( zombies ) || isdefined( level.ignore_distance_tracking ) && level.ignore_distance_tracking )
        {
            aligned = practice_despawn_wait(aligned); //MODIFIED: real-run timing (core)
            continue;
        }
        else
        {
            for ( i = 0; i < zombies.size; i++ )
            {
                if ( isdefined( zombies[i] ) && !( isdefined( zombies[i].ignore_distance_tracking ) && zombies[i].ignore_distance_tracking ) )
                    zombies[i] thread  maps\mp\zm_tomb_distance_tracking::delete_zombie_noone_looking( level.zombie_tracking_dist, level.zombie_tracking_high );
            }

        }

        aligned = practice_despawn_wait(aligned); //MODIFIED: real-run timing (core)
    }
}

/*##############################################################################
                              Craftable rigging
##############################################################################*/
// Full Game and every segment start install this.
shared_randomize_craftable_spawns() //OVERRIDE: maps\mp\zm_tomb_craftables::randomize_craftable_spawns
{
	//MODIFIED: the vinyls come from the shared table
	foreach(key in shared_vinyl_keys())
	{
		str_craftable = "gramophone_" + key;
	//MODIFIED END
		s_original_pos = getstruct(str_craftable, "targetname");
		a_alt_locations = getstructarray(str_craftable + "_alt", "targetname");
		//MODIFIED: a location setting picks the index; alt.size keeps the original spot
		n_loc_index = shared_part_location(key);
		if(n_loc_index > a_alt_locations.size)
		{
			print("O-Prac: " + key + " has no location " + n_loc_index + " (" + (a_alt_locations.size + 1) + " locations), using random");
			n_loc_index = PART_RANDOM;
		}
		if(n_loc_index < 0)
			n_loc_index = randomintrange(0, a_alt_locations.size + 1);
		//MODIFIED END

		if(n_loc_index == a_alt_locations.size) continue;
		s_original_pos.origin = a_alt_locations[n_loc_index].origin;
		s_original_pos.angles = a_alt_locations[n_loc_index].angles;
	}
}

// Full Game and every segment start install this.
shared_generate_zombie_craftable_piece(craftablename, piecename, modelname, radius, height, drop_offset, hud_icon, onpickup, ondrop, oncrafted, use_spawn_num, tag_name, can_reuse, client_field_value, is_shared, vox_id, b_one_time_vo) //OVERRIDE: maps\mp\zombies\_zm_craftables::generate_zombie_craftable_piece
{
	if(!isDefined(is_shared))
	{
		is_shared = 0;
	}
	if(!isDefined(b_one_time_vo))
	{
		b_one_time_vo = 0;
	}
	precachemodel(modelname);
	if(isDefined(hud_icon))
	{
		precacheshader(hud_icon);
	}
	piecestub = spawnstruct();
	craftable_pieces = [];
	piece_alias = "";
	if(!isDefined(piecename))
	{
		piecename = modelname;
	}
	craftable_pieces_structs = getstructarray(craftablename + "_" + piecename, "targetname");
	foreach(index, struct in craftable_pieces_structs)
	{
		craftable_pieces[index] = struct;
		craftable_pieces[index].hasspawned = 0;
	}
	//MODIFIED: a part location setting leaves only its chosen spawn
	piecestub.spawns = shared_part_spawns(craftablename, piecename, craftable_pieces);
	//MODIFIED END
	piecestub.craftablename = craftablename;
	piecestub.piecename = piecename;
	piecestub.modelname = modelname;
	piecestub.hud_icon = hud_icon;
	piecestub.radius = radius;
	piecestub.height = height;
	piecestub.tag_name = tag_name;
	piecestub.can_reuse = can_reuse;
	piecestub.drop_offset = drop_offset;
	piecestub.max_instances = 256;
	piecestub.onpickup = onpickup;
	piecestub.ondrop = ondrop;
	piecestub.oncrafted = oncrafted;
	piecestub.use_spawn_num = use_spawn_num;
	piecestub.is_shared = is_shared;
	piecestub.vox_id = vox_id;
	if(isDefined(b_one_time_vo) && b_one_time_vo)
	{
		piecestub.b_one_time_vo = b_one_time_vo;
	}
	// Vanilla nesting of the common _zm_craftables script (every map runs it; the
	// Origins dump is decompiled incompletely, so this follows the complete dump in
	// the Mob of the Dead folder). The upstream copy hung the else on the outer if,
	// so crystals (unshared pieces) lost their top-left HUD state.
	if(isDefined(client_field_value))
	{
		if(isDefined(is_shared) && is_shared)
		{
			piecestub.client_field_id = client_field_value;
		}
		else
		{
			piecestub.client_field_state = client_field_value;
		}
	}
	return piecestub;
}

/*##############################################################################
                              Part locations
##############################################################################*/
// The Maxis drone parts, shield parts and gramophone vinyls each have a location
// setting, shared by Full Game and the segment starts: PART_RANDOM (oprac.gsh), a
// spot, or collected. A spot is the vanilla index, so it is used as is:
//   parts   shared_part_spawns keeps only spawn struct [setting]
//   vinyls  shared_randomize_craftable_spawns moves the record to _alt struct
//           [setting]; the last location (setting == alt count) is the original
// Collected is the value after the last spot (part.locations.size): the item
// spawns at random and shared_give_collected_items hands it over. Each mode's
// defaults hold its route (segment starts: discs and Maxis parts collected), and
// the player may change any of them, even where the route never would.
//
// Dev: the dvar oprac_force_spawn (set by tools\part_spawns.gsc) puts every part
// and vinyl at that index, for walking the map to check the location names.

shared_part_keys()
{
	return array("maxis_body", "maxis_engine", "shield_gen2", "shield_gen3", "shield_nml");
}

shared_shield_keys()
{
	return array("shield_gen2", "shield_gen3", "shield_nml");
}

// The keys are also the gramophone piece names.
shared_vinyl_keys()
{
	return array("vinyl_player", "vinyl_master", "vinyl_ice", "vinyl_air", "vinyl_fire", "vinyl_elec");
}

shared_item_keys()
{
	return combinearrays(shared_part_keys(), shared_vinyl_keys());
}

shared_part_location(key)
{
	forced = getDvar("oprac_force_spawn");
	if(forced != "") return int(forced);

	// A collected item is picked up at setup, wherever it spawned.
	value = get_cfg_int(key);
	if(value >= shared_part(key).locations.size) return PART_RANDOM;
	return value;
}

shared_part_collected_value(key)
{
	return shared_part(key).locations.size;
}

// A crafted drone has its body and engine whatever their settings say.
shared_item_collected(key)
{
	if(shared_drone_crafted() && (key == "maxis_body" || key == "maxis_engine")) return true;
	return get_cfg_int(key) == shared_part_collected_value(key);
}

/*##############################################################################
                              Segment item declarations
##############################################################################*/
// What each segment start can still be missing at its craft (the user's route
// facts). Location defaults (shared_segment_item_defaults) collect every disc and
// Maxis part; the player sets one to a spot to leave it out.
//   Icestart        Purple Disc, plane, R2L part, Maxis Body, Maxis Engine
//   Windstart       Maxis Body, Maxis Engine, Maxis Drone crafted
//   Firestart       Maxis Body, Maxis Engine, Maxis Drone crafted
//   Lightningstart  Maxis Engine, Maxis Drone crafted
// Shield parts are optional in every start. A crafted drone has all its parts.

shared_drone_option()
{
    switch(level.gamemode)
    {
        case "windstart":
        case "firestart":
        case "lightningstart":
            return true;
        default:
            return false;
    }
}

shared_drone_crafted()
{
    return shared_drone_option() && get_cfg_int("maxis_drone_crafted");
}

// .locations names the locations in index order.
// All checked in game with oprac_force_spawn on 2026-10-11 (each item seen at two
// indexes, the third by elimination).
shared_part(key)
{
	part = spawnstruct();
	switch(key)
	{
		case "maxis_body":
			part.label = "Maxis Body";
			part.craftable = "equip_dieseldrone_zm";
			part.piece = "body";
			part.locations = array("ice tunnel", "gen 5 path", "gen 4 path");
			break;
		case "maxis_engine":
			part.label = "Maxis Engine";
			part.craftable = "equip_dieseldrone_zm";
			part.piece = "engine";
			part.locations = array("pack-a-punch", "gram", "scaffolding");
			break;
		case "shield_gen2":
			part.label = "Shield Gen2";
			part.craftable = "tomb_shield_zm";
			part.piece = "bracket";
			part.locations = array("claymore", "wheelbarrow", "footprint");
			break;
		case "shield_gen3":
			part.label = "Shield Gen3";
			part.craftable = "tomb_shield_zm";
			part.piece = "top";
			part.locations = array("fire tunnel", "wheelbarrow", "ak74u");
			break;
		case "shield_nml":
			part.label = "Shield NML";
			part.craftable = "tomb_shield_zm";
			part.piece = "door";
			part.locations = array("gen 4 box", "gen 4 side", "gen 5 side");
			break;
		case "vinyl_player":
			part.label = "Gramophone";
			part.locations = array("far", "close");
			break;
		case "vinyl_master":
			part.label = "Master Disc";
			part.locations = array("wheelbarrow", "stairs", "backside");
			break;
		case "vinyl_ice":
			part.label = "Ice Disc";
			part.locations = array("relay", "mystery box", "table");
			break;
		case "vinyl_air":
			part.label = "Wind Disc";
			part.locations = array("lightning tunnel", "boxes", "stamina up");
			break;
		case "vinyl_fire":
			part.label = "Fire Disc";
			part.locations = array("church", "generator", "tank");
			break;
		case "vinyl_elec":
			part.label = "Lightning Disc";
			part.locations = array("fizz", "wind tunnel", "chariot");
			break;
	}
	if(!isDefined(part.craftable))
	{
		part.craftable = "gramophone";
		part.piece = key;
	}
	return part;
}

shared_part_defaults(settings_ar)
{
	foreach(key in shared_item_keys())
		settings_ar[key] = PART_RANDOM;
	return settings_ar;
}

// Segment starts, after shared_part_defaults: the route has every disc and Maxis
// part collected; shield parts stay on the map. Icestart adds its own items
// (plane, R2L).
shared_segment_item_defaults(settings_ar)
{
	foreach(key in combinearrays(shared_vinyl_keys(), array("maxis_body", "maxis_engine")))
		settings_ar[key] = shared_part_collected_value(key);
	settings_ar["maxis_drone_crafted"] = 0;      // Windstart on: 1 crafts and gives the drone
	return settings_ar;
}

// Not a switch: gsc-tool stores case -1 as 16777215 (24 bits), which may never
// match.
shared_part_location_text(part, value)
{
	if(value == PART_RANDOM) return "random";
	if(value >= part.locations.size) return "^2collected";
	return part.locations[value];
}

// The spawn structs a piece may use: all of them (random), or only the one its
// setting indexes. An index past the last struct falls back to random.
shared_part_spawns(craftablename, piecename, spawns)
{
	foreach(key in shared_part_keys())
	{
		part = shared_part(key);
		if(part.craftable != craftablename || part.piece != piecename) continue;

		value = shared_part_location(key);
		if(value < 0) return spawns;
		if(!isDefined(spawns[value]))
		{
			print("O-Prac: " + key + " has no spawn " + value + " (" + spawns.size + " spawns), using random");
			return spawns;
		}
		return array(spawns[value]);
	}
	return spawns;
}

shared_zone_capture_powerup()
{
	return 0;
}

/*##############################################################################
                              Segment menus
##############################################################################*/
// Menus for every segment start (Ice, Wind, Fire, Lightning).
shared_build_segment_menus(root)
{
    settings = add_submenu(root, "mapsettings", level.mode.label + " Settings", level.mode.label);
        disc_turns = array("random", "0 turn", "1 turn", "2 turn", "3 turn");
        if(level.gamemode == "icestart")
        {
            self shared_craft_time_menu(settings);
            add_cfg_choice(settings, "Start Location", "start_loc", array("random", "floor", "mule"));
            add_cfg_choice(settings, "Ice Disc Turn", "last_disc", disc_turns);
            add_cfg_toggle(settings, "R2L Route", "r2l", "^2Yes", "^1No");
            add_cfg_toggle(settings, "Early Gram", "early_gram", "^2yes", "^1no");
            add_cfg_toggle(settings, "MP40 Tile Clue", "mp40_tile_clue", "^2Yes", "^1No");
            // Cycle 1 Foot picks the second bunker door; only R2L has a choice.
            if(get_cfg_int("r2l")) add_cfg_choice(settings, "Cycle 1 Foot", "trench_path", array("random", "gen2", "gen3"));
            add_cfg_toggle(settings, "Auto round end", "auto_round_end");
            create_option(settings, "Auto round end delay: ^3" + get_cfg_int("auto_round_end_delay") + "s", ::cfg_increment_int, "auto_round_end_delay", array(1, 10));
            add_cfg_toggle(settings, "Peek Code", "peek_code", "^2Yes", "^1No");
        }
        else
        {
            self shared_craft_time_menu(settings);
            // Start Location sits right under Custom Craft.
            switch(level.gamemode)
            {
                case "windstart":      add_cfg_choice(settings, "Start Location", "wind_spawn", array("Craft", "Exit")); break;
                case "firestart":      add_cfg_choice(settings, "Start Location", "fire_spawn", array("Craft", "Exit")); break;
                case "lightningstart": add_cfg_choice(settings, "Start Location", "lightning_spawn", array("Craft", "Exit")); break;
            }
            // Trio skip: Firestart and Lightningstart only; Windstart always uses the round 12 trio.
            if(level.gamemode != "windstart") add_cfg_toggle(settings, "Trio skip", "trioskip", "^2Yes", "^1No");
            // Disc Turn is for the Craft start only: the Exit start keeps the normal disc scramble.
            switch(level.gamemode)
            {
                case "windstart":
                    add_cfg_choice(settings, "STG acquired", "stg_start", array("no", "yes", "papped"));
                    if(get_cfg_int("wind_spawn") != 1) add_cfg_choice(settings, "Wind Disc Turn", "last_disc", disc_turns);
                    create_option(settings, "Start Round: ^3" + get_cfg_int("wind_start_round"), ::cfg_increment_int, "wind_start_round", array(11, 12));
                    create_option(settings, "Ice prefills: ^3" + get_cfg_int("ice_souls"), ::cfg_increment_int, "ice_souls", array(0, 10));
                    break;
                case "firestart":
                    add_cfg_choice(settings, "STG acquired", "stg_start", array("no", "yes", "papped"));
                    create_option(settings, "Ice prefills: ^3" + get_cfg_int("ice_souls"), ::cfg_increment_int, "ice_souls", array(0, 10));
                    if(get_cfg_int("fire_spawn") != 1) add_cfg_choice(settings, "Fire Disc Turn", "last_disc", disc_turns);
                    break;
                case "lightningstart":
                    add_cfg_choice(settings, "STG acquired", "stg_start", array("no", "yes", "papped"));
                    if(get_cfg_int("lightning_spawn") != 1) add_cfg_choice(settings, "Lightning Disc Turn", "last_disc", disc_turns);
                    create_option(settings, "Zombies left: ^3" + shared_zombies_left_text("lightning_zombies"), ::cfg_increment_int, "lightning_zombies", array(0, 24));
                    break;
            }
        }

    // Items with no location setting (shared_get_parts). Discs, Maxis and shield
    // parts are collected through Part Locations and Vinyl Locations.
    items = add_submenu(root, "items", "Items settings", "Items");
        if(level.gamemode == "icestart")
        {
            add_cfg_toggle(items, "Plane Shot", "kill_plane");
            create_option(items, "Plane Part: " + cfgint_compare("plane_part", "^2collected", "^1disperse"), ::shared_plane_part_toggle);
        }
        if(shared_drone_option()) add_cfg_toggle(items, "Maxis Drone", "maxis_drone_crafted", "^2crafted", "^3not crafted");
        if(level.gamemode == "icestart") add_cfg_toggle(items, "Fizz DT", "dt_start");
        add_cfg_toggle(items, "115 Reward", "headshot_reward");

    self shared_build_parts_menu(root);
    self shared_build_vinyls_menu(root);
    self shared_build_disc_menu(root);

    relays = add_submenu(root, "relays", "Electric Relays", "Relays");
        shared_add_relay_row(relays, "Spawn", "relay_start");
        shared_add_relay_row(relays, "Gen2", "relay_tank");
        shared_add_relay_row(relays, "Gen4", "relay_air");
        shared_add_relay_row(relays, "Gen5", "relay_elec");
        shared_add_relay_row(relays, "Middle", "relay_ruins");
        shared_add_relay_row(relays, "Bot Church", "relay_ice");
        shared_add_relay_row(relays, "Top Church", "relay_village");

    self shared_build_templar_menu(root);
    self shared_build_panzer_menu(root);
    self shared_build_robot_menus(root, ::shared_segment_all_random_cycles, shared_robot_earliest_cycle());
    self puzzle_rng_build_root_menu(root);
}

shared_plane_part_toggle()
{
	setting = "plane_part";
	value = 1 - get_cfg_int(setting);
	level.mode_cfg[setting] = value;
	if(value) level.mode_cfg["kill_plane"] = 1;
	write_config(level.mode_cfg, level.mode_cfg_str);
	self refresh_menu();
}

// Unlike fullgame_all_random_cycles, leaves the Rain fire robot unchanged.
shared_segment_all_random_cycles()
{
    for(cycle = 1; cycle <= ROBOT_CYCLE_COUNT; cycle++)
        level.mode_cfg["cycle_" + cycle] = ROBOT_RANDOM;
    write_config(level.mode_cfg, level.mode_cfg_str);
    self refresh_menu();
}

/*##############################################################################
                              Craft time
##############################################################################*/
// Each start mode begins when a staff is crafted. The player picks what the run
// clock should read at that moment, either from a list of presets or as a
// custom minutes:seconds time.
//
// A mode describes its presets once, in its initialize function, BEFORE its cfg
// is loaded:
//
//     shared_craft_time_setup("12:30", "14:30", 5, "13:30");
//
// Read it as: "presets from 12:30 to 14:30, every 5 seconds, 13:30 by default".
// Everything else comes from those four values:
//
//     shared_craft_time_defaults()     default cfg settings
//     shared_craft_time_menu()         "Craft Time" option and Custom Craft menu
//     shared_craft_time_start_clock()  run clock, robots, OOPA and despawn checks
//
// The saved "craft_time" setting is a preset number, not a time: 0 is the first
// preset (12:30), 1 the next (12:35), and so on.
//
// Custom Craft minutes stay within custom_min_minutes..custom_max_minutes. The
// earliest possible craft also decides the first robot cycle the menus offer.

shared_craft_time_setup(first_time, last_time, step_seconds, default_time, custom_min_minutes = 0, custom_max_minutes = 59)
{
    first_seconds = shared_time_text_to_seconds(first_time);
    last_seconds = shared_time_text_to_seconds(last_time);

    level.craft_time = spawnstruct();
    level.craft_time.first_seconds = first_seconds;
    level.craft_time.step_seconds = step_seconds;
    level.craft_time.preset_count = int((last_seconds - first_seconds) / step_seconds) + 1;
    level.craft_time.default_seconds = shared_time_text_to_seconds(default_time);
    level.craft_time.custom_min_minutes = custom_min_minutes;
    level.craft_time.custom_max_minutes = custom_max_minutes;
}

// The earliest craft time any preset or Custom Craft setting allows, in seconds.
shared_craft_time_earliest_seconds()
{
    custom_seconds = level.craft_time.custom_min_minutes * 60;
    if(custom_seconds < level.craft_time.first_seconds) return custom_seconds;
    return level.craft_time.first_seconds;
}

// Adds the craft time settings to a mode's default cfg.
shared_craft_time_defaults(settings_ar)
{
    default_seconds = level.craft_time.default_seconds;
    default_preset = int((default_seconds - level.craft_time.first_seconds) / level.craft_time.step_seconds);

    settings_ar["craft_time"] = default_preset;
    settings_ar["custom_craft"] = 0;
    settings_ar["custom_craft_minutes"] = shared_craft_time_custom_default_minutes();
    settings_ar["custom_craft_seconds"] = default_seconds % 60;
    return settings_ar;
}

// The default craft time's minutes, moved into the Custom Craft range.
shared_craft_time_custom_default_minutes()
{
    minutes = int(level.craft_time.default_seconds / 60);
    if(minutes < level.craft_time.custom_min_minutes) return level.craft_time.custom_min_minutes;
    if(minutes > level.craft_time.custom_max_minutes) return level.craft_time.custom_max_minutes;
    return minutes;
}

// The craft time the player picked, in seconds (13:20 is 800).
shared_craft_time_seconds()
{
    default_seconds = level.craft_time.default_seconds;

    if(get_cfg_int("custom_craft"))
    {
        minutes = get_cfg_int("custom_craft_minutes");
        seconds = get_cfg_int("custom_craft_seconds");
        if(minutes < level.craft_time.custom_min_minutes || minutes > level.craft_time.custom_max_minutes) minutes = shared_craft_time_custom_default_minutes();
        if(seconds < 0 || seconds > 59) seconds = default_seconds % 60;
        return minutes * 60 + seconds;
    }

    preset = get_cfg_int("craft_time");
    if(preset < 0 || preset >= level.craft_time.preset_count) return default_seconds; // Hand-edited cfg.
    return level.craft_time.first_seconds + preset * level.craft_time.step_seconds;
}

// Adds "Craft Time" and the Custom Craft submenu to a mode's settings menu.
shared_craft_time_menu(menu)
{
    craft_text = shared_seconds_to_time_text(shared_craft_time_seconds());
    create_option(menu, "Craft Time: ^3 " + craft_text, ::shared_craft_time_next_preset);

    custom = add_submenu(menu, "custom_craft", "Custom craft time", "Custom Craft");
        add_cfg_toggle(custom, "Enabled", "custom_craft");
        create_option(custom, "Minutes: ^3" + get_cfg_int("custom_craft_minutes"), ::cfg_increment_int, "custom_craft_minutes", array(level.craft_time.custom_min_minutes, level.craft_time.custom_max_minutes));
        create_option(custom, "Seconds: ^3" + get_cfg_int("custom_craft_seconds"), ::cfg_increment_int, "custom_craft_seconds", array(0, 59));
}

// Menu action for "Craft Time": turns Custom Craft off and moves to the next
// preset. After the last preset it goes back to the first.
shared_craft_time_next_preset()
{
    level.mode_cfg["custom_craft"] = 0;
    self cfg_increment_int("craft_time", array(0, level.craft_time.preset_count - 1));
}

// Call when the staff is crafted. Sets the run clock to the picked craft time and
// lines the robots and the OOPA and despawn checks up with it.
// Robot timing follows the "Trio round 12" column of Robot Intervals.xlsx (the
// standard). The "Trio skip" setting switches to the non-standard "No trios"
// column; modes without that setting always use the standard.
shared_craft_time_start_clock()
{
    // Read the settings once, so every timing thread uses the same values.
    craft_seconds = shared_craft_time_seconds();
    round12_trio = !get_cfg_int("trioskip");
    level.segment_craft_seconds = craft_seconds;
    shared_robot_schedule(craft_seconds, round12_trio);
    level.game_start_time = getTime() - craft_seconds * 1000;
    flag_set("start_robots");
}

// "13:20" -> 800
shared_time_text_to_seconds(time_text)
{
    parts = strtok(time_text, ":");
    return int(parts[0]) * 60 + int(parts[1]);
}

// 800 -> "13:20". Seconds below 10 get a leading zero: 785 -> "13:05".
shared_seconds_to_time_text(total_seconds)
{
    minutes = int(total_seconds / 60);
    seconds = total_seconds % 60;
    if(seconds < 10) return minutes + ":0" + seconds;
    return minutes + ":" + seconds;
}

/*##############################################################################
                              Robot schedule
##############################################################################*/
// Robot Intervals.xlsx: cycle n starts at 0:37.00 + (n - 1) * 2:01.85 run time
// (a robot walks 1:56.85, then the loop waits 5 s). Standard ("Trio round 12"
// column): round 12 has a three robot cycle at cycle ROUND12_TRIO_CYCLE; it ends
// 9.90 s later and delays every later cycle. Non-standard ("No trios" column,
// trioskip on): round12_trio is false and no cycle is delayed.
// Milliseconds keep the 0.05 s steps exact.
shared_robot_cycle_start_ms(cycle, round12_trio)
{
    start_ms = 37000 + (cycle - 1) * 121850;
    if(round12_trio && cycle > ROUND12_TRIO_CYCLE) start_ms += 9900;
    return start_ms;
}

// The first cycle that starts at or after the craft.
shared_robot_first_cycle(craft_seconds, round12_trio)
{
    craft_ms = int(craft_seconds * 1000);
    cycle = 1;
    while(shared_robot_cycle_start_ms(cycle, round12_trio) < craft_ms) cycle++;
    return cycle;
}

// The first cycle any craft time setting can reach. The round 12 trio only
// delays later cycles, so the standard schedule gives the earliest.
shared_robot_earliest_cycle()
{
    return shared_robot_first_cycle(shared_craft_time_earliest_seconds(), true);
}

// Holds the robots until the first cycle that starts at or after the craft.
shared_robot_schedule(craft_seconds, round12_trio)
{
    craft_ms = int(craft_seconds * 1000);
    cycle = shared_robot_first_cycle(craft_seconds, round12_trio);
    level.segment_next_robot_cycle = cycle;
    level.segment_robot_wait = (shared_robot_cycle_start_ms(cycle, round12_trio) - craft_ms) / 1000.0;

    // A trio that started before the craft used up round 12's three robot cycle.
    level.segment_three_robot_round = 0;
    if(round12_trio && shared_robot_cycle_start_ms(ROUND12_TRIO_CYCLE, round12_trio) < craft_ms)
        level.segment_three_robot_round = 12;

    if(cycle > 1) level thread shared_robot_projected_cycle(cycle - 1, round12_trio, craft_ms);
}

// Cycle tracker for the cycle the schedule puts before the craft, so the display
// shows its timing instead of waiting for the first real cycle: "start" while
// its walk would still be going, then "end" when the walk would finish. Display
// only: no robot walks for it, and only "single" or "trios" is known.
shared_robot_projected_cycle(cycle, round12_trio, craft_ms)
{
    level endon("end_game");

    start_ms = shared_robot_cycle_start_ms(cycle, round12_trio);
    end_ms = shared_robot_cycle_start_ms(cycle + 1, round12_trio) - 5000; // The loop waits 5 s after each cycle.
    robot = "single";
    if(round12_trio && cycle == ROUND12_TRIO_CYCLE) robot = "trios";

    if(craft_ms < end_ms)
    {
        shared_robot_projected_cycle_string(cycle, "start", start_ms, robot);
        wait (end_ms - craft_ms) / 1000.0;
    }
    shared_robot_projected_cycle_string(cycle, "end", end_ms, robot);
}

shared_robot_projected_cycle_string(cycle, state, time_ms, robot)
{
    level.cycle_string = game_time_string(get_cfg_int("cycle_tracker_ms"), time_ms) + " | cycle " + cycle + " " + state + " | " + robot;
    if(isDefined(level.cycle_display)) level.cycle_display setTextUnlimited(level.cycle_string);
}

shared_starting_weapons()
{
    // Called before the player spawns, and vanilla's spawn loadout would replace
    // the MP40: wait until the player is in the game with the starting pistol.
    self endon("disconnect");
    while(self.sessionstate != "playing" || !self hasweapon("c96_zm")) wait 0.05;

    // A held start has the Mauser upgraded from the start, not at the release.
    if(is_true(level.segment.upgrade_mauser))
    {
        self takeweapon("c96_zm");
        self maps\mp\zombies\_zm_weapons::weapon_give("c96_upgraded_zm", 1);
    }

    // "STG acquired" (Windstart on): the STG-44, plain or upgraded, instead.
    switch(get_cfg_int("stg_start"))
    {
        case STG_YES:    weapon = "mp44_zm"; break;
        case STG_PAPPED: weapon = "mp44_upgraded_zm"; break;
        default:         weapon = "mp40_zm"; break;
    }
    if(weapon == "mp44_upgraded_zm")
        self giveWeapon(weapon, 0, self maps\mp\zombies\_zm_weapons::get_pack_a_punch_weapon_options(weapon));
    else
        self giveWeapon(weapon);
    self maps\mp\zombies\_zm_weap_claymore::claymore_setup();
    wait 0.05;
    self switchToWeapon(weapon);
}

// Creates an element's Crazy Place exit, as entering through its portal does.
shared_enable_chamber_exit(staff_index)
{
    entrance = undefined;
    foreach(pad in getstructarray("trigger_teleport_pad", "targetname"))
        if(pad.script_int == staff_index) entrance = pad;

    while(!isdefined(level.a_portal_exit_frames) || !isdefined(level.a_portal_exit_frames[staff_index])) wait 0.05;
    if(!isdefined(entrance.exit_enabled) || !entrance.exit_enabled)
    {
        entrance.exit_enabled = 1;
        level thread maps\mp\zm_tomb_teleporter::run_chamber_exit(staff_index);
    }
}

/*##############################################################################
                              Start spots
##############################################################################*/
// A segment start's two spots (origin and view angles): Craft on the excavation
// floor and Exit at a Crazy Place exit. Each mode defines its own and passes them
// at load.
shared_start_spots(craft_origin, craft_angles, exit_origin, exit_angles)
{
    spots = spawnstruct();
    spots.craft_origin = craft_origin;
    spots.craft_angles = craft_angles;
    spots.exit_origin = exit_origin;
    spots.exit_angles = exit_angles;
    return spots;
}

// Puts the player on the start's Exit spot, or its Craft spot.
shared_teleport_to_start(spots, use_exit)
{
    if(use_exit)
    {
        self setorigin(spots.exit_origin);
        self setplayerangles(spots.exit_angles);
    }
    else
    {
        self setorigin(spots.craft_origin);
        self setplayerangles(spots.craft_angles);
    }
}

/*##############################################################################
                              Segment runner
##############################################################################*/
// Every segment start (Icestart, Windstart, Firestart, Lightningstart) has the
// same shape. Its file builds a segment description (<mode>_segment) and calls:
//     initialize:  shared_segment_install(<mode>_segment())
//     run:         level shared_run_segment(level.segment)
// The description holds what differs as data (gems, perks, doors...) plus the
// mode's own steps: setup (the map setup), start (setup, start spot, release
// and run clock) and on_spawn (what happens as the player spawns). Starts that
// hold the player while setup runs use shared_held_start; Icestart has its own
// start because of Peek Code.

// Game seconds (timescale 10: a tenth of that in real time) before a held start
// whose setup has not finished releases the player anyway.
#define SEGMENT_SETUP_TIMEOUT  300

// A segment description with the values most starts share. The mode overrides
// what differs and sets split, gems and setup.
shared_segment()
{
    segment = spawnstruct();
    segment.staffs = [];                    // staffs the setup completes (shared_staff_install)
    segment.tank_trips = 2;                 // shared_tank_setup_trips
    segment.excluded_doors = undefined;     // doors left closed (shared_open_doors)
    segment.leave_gramophone = false;       // shared_open_mound
    segment.wallbuy_ak = false;             // shared_wallbuy_outlines
    segment.points_spent_claimed = true;    // "points spent" box reward already claimed
    segment.perks = array("specialty_longersprint", "specialty_armorvest", "specialty_additionalprimaryweapon", "specialty_rof");
    segment.kill_plane = true;
    segment.panzer_spot = undefined;        // shared_prespawn_panzer
    segment.panzer_spot_wave = undefined;   // which Panzer (1 = first) panzer_spot is for
    segment.solved_relays = undefined;      // relay_* keys always solved (shared_relay_solved)
    segment.tablet = ::shared_tablet_cleaned;
    segment.early_teleport = false;         // true: move to the start spot at spawn (a Panzer waits for them in the Crazy Place)
    segment.on_spawn = ::shared_hold_at_start;
    segment.start = ::shared_held_start;
    return segment;
}

// Load-time hooks, flags and state every segment start needs.
shared_segment_install(segment)
{
    level.segment = segment;
    level.shared_tank_setup_trips = segment.tank_trips; // Tank trips are read at runtime.
    flag_init("shared_tank_setup_done"); // Set when the setup trips are done.
    shared_schedules_init(11); // The route's skip pushes the first Templars to round 11.
    shared_segment_replacefuncs();
    replacefunc( maps\mp\zm_tomb_main_quest::run_gramophone_door, ::shared_fast_mound_unlock );
    replacefunc( maps\mp\zm_tomb_quest_crypt::chamber_discs_randomize, ::shared_chamber_discs_randomize);
    if(segment.staffs.size) shared_staff_install(segment.staffs);

    flag_init("start_robots");
    flag_clear("start_robots");
    level.delay_robot = true;
    level.zombie_round_start_delay = 0;
    level.n_disc_scrambles = 0; // Mound opening -> 1; each setup orb -> the next.
    level.cycle_string = "awating robot cycle";
    level.start_timing["time_sting"] = "";
    level.start_timing["ms"] = 0;
    level.start_timing["cycle"] = 0;
}

// The shared startup: map state, rewards, loadout and the always-on threads,
// then the mode's start.
shared_run_segment(segment)
{
    setDvar("timescale", 10);
    flag_wait("initial_players_connected");
    attaining27 = get_players()[0];
    level.segment_player = attaining27;
    if(isdefined(segment.on_spawn)) attaining27 thread [[ segment.on_spawn ]]();

    //Map state
    level thread shared_open_doors(segment.excluded_doors);
    level thread shared_open_mound(segment.leave_gramophone);
    level thread shared_relays();
    level thread shared_wallbuy_outlines(segment.wallbuy_ak);
    level thread shared_unlock_gem(segment.gems);

    //Box rewards
    if(get_cfg_int("headshot_reward"))
        attaining27 thread shared_box_rewards("zc_headshots");
    attaining27 thread shared_box_rewards("zc_boxes_filled", true);
    attaining27 thread shared_box_rewards("zc_points_spent", segment.points_spent_claimed);
    attaining27 thread shared_box_rewards("zc_zone_captures");
    attaining27 thread maps\mp\zombies\_zm_weap_one_inch_punch::one_inch_punch_melee_attack();

    //Perks and guns
    attaining27 thread shared_perks(segment.perks);
    attaining27 thread shared_starting_weapons();

    flag_wait("initial_blackscreen_passed");
    shared_setup_trace("blackscreen passed");
    flag_set("menu_active");
    level thread shared_generators();
    if(segment.kill_plane) attaining27 thread shared_kill_plane();
    attaining27 thread shared_shovel();
    attaining27 thread [[ segment.tablet ]]();
    attaining27 thread shared_pointbased_drops();

    attaining27 [[ segment.start ]]();
}

/*##############################################################################
                              Held start
##############################################################################*/
// Windstart, Firestart and Lightningstart: the player waits frozen on the start
// spot while setup runs at timescale 10 and is released on the segment round.
// The mode's description sets spots (shared_start_spots), use_exit, round and
// round_zombies (shared_set_round).

// Load-time part of the held start; call after shared_segment_install.
shared_held_start_install()
{
    level.shared_schedule_hold = "segment_ready"; // Panzers and Templars wait for release.
    flag_init("segment_ready"); // Set when the player is released.
    flag_clear("segment_ready");
    practice_check_phasing("segment_ready", "start_robots"); // Checks wait for release too.
    flag_init("segment_round_ready");
    flag_clear("segment_round_ready");
    flag_init("segment_setup_done");
    flag_clear("segment_setup_done");
    flag_init("segment_panzer_ready");
    flag_clear("segment_panzer_ready");
    flag_init("segment_portals_open"); // The setup's portals have finished opening.
    flag_clear("segment_portals_open");
    flag_init("segment_exit_open"); // A Crazy Place exit has finished opening (shared_run_chamber_exit).
    flag_clear("segment_exit_open");
    level.segment_setup_running = true; // Cleared at the release.
    level.segment.upgrade_mauser = true; // shared_starting_weapons upgrades the starting Mauser.
    level thread shared_held_start_round();
}

shared_held_start_round()
{
    shared_set_round(level.segment.round, level.segment.round_zombies);
    // Spawning resumes when the player is released; release waits for this so
    // the clear cannot land after spawning was turned back on.
    flag_clear("spawn_zombies");
    shared_setup_trace("round ready");
    flag_set("segment_round_ready");
}

// on_spawn: keeps the player frozen where they spawned until release, then the
// held start moves them once. A start with a Panzer waiting in the Crazy Place
// (segment.early_teleport) moves them at spawn instead: the Panzer ignores a
// player in the Crazy Place, so it stays where it landed. Freezing every frame
// also covers the vanilla intro fade, which unfreezes players.
shared_hold_at_start()
{
    self endon("disconnect");
    self.ignoreme = 1;
    self enableinvulnerability();

    while(self.sessionstate != "playing") wait 0.05;
    if(level.segment.early_teleport) self shared_teleport_to_start(level.segment.spots, level.segment.use_exit);

    while(!flag("segment_ready"))
    {
        self freezecontrols(1);
        wait 0.05;
    }
}

// start: runs the mode's setup, then releases the player.
shared_held_start()
{
    // Failsafe: a setup step that never finishes must not keep the player frozen
    // at timescale 10. Release anyway after SEGMENT_SETUP_TIMEOUT game seconds.
    shared_setup_trace("setup start");
    self thread shared_run_setup(level.segment.setup);
    setup_start = gettime();
    self thread shared_panzer_flow(setup_start);
    // The tank's setup trips (vanilla speed) must also be done, so it is parked.
    while(!(flag("segment_setup_done") && flag("shared_tank_setup_done")) && gettime() - setup_start < SEGMENT_SETUP_TIMEOUT * 1000) wait 0.05;
    if(!flag("segment_setup_done") || !flag("shared_tank_setup_done"))
    {
        shared_setup_trace("setup timed out, releasing anyway");
        iprintln("^1O-Prac: setup did not finish, releasing anyway");
    }
    shared_setup_trace("setup done, waiting segment_round_ready");
    flag_wait("segment_round_ready");
    flag_wait("segment_panzer_ready");
    shared_setup_trace("released");

    // The player's one move, still frozen at timescale 10 so the zones settle
    // during the half second below.
    if(!level.segment.early_teleport)
        self shared_teleport_to_start(level.segment.spots, level.segment.use_exit);
    setDvar("timescale", 1);
    wait 0.5; // Normal speed for 500 ms before anything is released.

    self.score = 6500;

    flag_set("spawn_zombies");
    level thread shared_segment_timer(level.segment.split, ::shared_craft_time_start_clock);
    level.segment_setup_running = undefined; // An open Crazy Place exit starts its 20 seconds.
    flag_set("segment_ready");
    if(get_cfg_int("cycle_tracker")) level thread shared_cycle_tracker();

    self disableinvulnerability();
    self.ignoreme = 0;
    self freezecontrols(0);
}

// A Panzer due on the start round is spawned at the mode's spot as soon as the
// round is ready and lands while the rest of the setup runs, so it is already
// waiting there at release (shared_prespawn_panzer).
shared_panzer_flow(setup_start)
{
    flag_wait("segment_round_ready");
    if(shared_panzer_due_at_spot())
    {
        shared_setup_trace("Panzer pre-spawn");
        shared_prespawn_panzer();
        while(!shared_panzer_landed() && gettime() - setup_start < SEGMENT_SETUP_TIMEOUT * 1000) wait 0.05;
        shared_setup_trace("Panzer landed");
    }
    flag_set("segment_panzer_ready");
}

shared_run_setup(setup)
{
    self [[ setup ]]();
    shared_refresh_staff_icons();
    flag_set("segment_setup_done");
}

// tablet: cleaned at the church and returned; G-Strikes reward claimed.
shared_tablet_cleaned()
{
    while(!isDefined(level.n_tablets_remaining) || !isDefined(self.sq_one_inch_punch_stage)) wait 0.05;
    number = level.n_tablets_remaining;
    table = getent("trigger_oneinchpunch_bunker_table", "targetname");
    self.sq_one_inch_punch_tablet_num = number;
    getent("tablet_bunker_" + number, "targetname") delete();
    level.n_tablets_remaining--;
    self thread maps\mp\zm_tomb_ee_side::sq_one_inch_punch_disconnect_watch();
    self thread maps\mp\zm_tomb_ee_side::sq_one_inch_punch_death_watch();
    // Native stage 4 returns it clean.
    self.sq_one_inch_punch_stage = 4;
    while(self.sq_one_inch_punch_stage == 4)
    {
        table notify("trigger", self);
        wait 0.1;
    }
    // Second punch stage completed; native reward spawn and claim.
    self.sq_one_inch_punch_kills = 20;
    self.sq_one_inch_punch_stage = 6;
    self maps\mp\zm_tomb_ee_side::bunker_spawn_reward();
    while(self.sq_one_inch_punch_stage == 6)
    {
        table notify("trigger", self);
        wait 0.1;
    }
}

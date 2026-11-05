#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;

#include scripts\zm\utility_core\menu_base;
#include scripts\zm\utility_core\menu_utility;
#include scripts\zm\utility_core\saveslots;
#include scripts\zm\utility_core\splits;

/*##############################################################################
                              Map descriptor and start-up
##############################################################################*/
// The core never names map code. Each map's entry script (zm_tomb\o-prac-menu.gsc,
// zm_prison\m-prac-menu.gsc) describes its map with this struct, fills in the hooks it
// needs, registers its modes and calls practice_main and practice_init.
// Every hook is optional:
//   initialize()               while the map loads, after the base cfg and before
//                              the mode's initialize: map-wide replacefuncs
//   build_hud_top(menu)        HUD rows right after the Speedometer
//   build_hud(menu)            HUD rows after the core rows
//   build_cheats(menu)         Cheats rows after the core rows
//   build_map_menu(root)       the map's own root menus, in every mode (Victis)
//   base_cfg_defaults(cfg)     returns cfg plus the map's basegame.cfg settings
//   say_command(message)       chat words the core does not know (self = player)
//   open_doors()               replaces the core Open Doors
//   open_doors_extra()         extra step inside the core Open Doors (self = player)
//   oopa_tick()                each out-of-playable-area check (self = player)
//   oopa_hud_spot()            where the OOPA Countdown shows, e.g. a trick (self = player)
//   oopa_hud_spot_label        name of its "only" choice in the HUD menu, like "R2L only"
//   hud_left_shift()           x offset for the left HUD (zone, HP) (self = player)
//   run()                      map-wide threads, started with the core HUDs
practice_map(menu_title, tool_name, cfg_dir, mode_dvar)
{
    map = spawnstruct();
    map.menu_title = menu_title;     // Menu header
    map.tool_name = tool_name;       // Start-up message
    map.cfg_dir = cfg_dir;           // Folder of every cfg file, like "O_PRAC/"
    map.mode_dvar = mode_dvar;       // Dvar holding the selected mode
    map.accent_color = (0.54, 0.17, 0.89);
    map.cursor_color = (0.74, 0.56, 1);      // Lighter than the accent, so the bar stands out from the panel.
    map.header_text_color = (1, 1, 1);       // Black on a light accent.
    return map;
}

// Call from the entry's main(), after registering the modes. The first
// registered mode is the default.
practice_main(map, version)
{
    level.practice_map = map;
    level.practice_version = version;
    // The B2EE timer's init skips itself when this is set (every map and mode).
    level.oprac_version = version;

    flag_init("menu_active");
    set_dvar_if_unset(map.mode_dvar, level.modes[0].name);
    level.mode = get_mode(getDvar(map.mode_dvar));
    level.gamemode = level.mode.name;

    basegame_initialize();
    [[ level.mode.initialize ]]();

    flag_wait("initial_blackscreen_passed");
    // A map may have started the run clock earlier (Mob: its afterlife intro).
    if(!isDefined(level.game_start_time)) level.game_start_time = getTime();
}

// Call from the entry's init().
practice_init()
{
    level thread [[ level.mode.run ]]();
    level thread basegame_run();
    level thread on_player_connect_menu();
    if(isDefined(level.practice_map.menu_icon)) precacheshader(level.practice_map.menu_icon);
    // A release shows its version at start-up only, a dev build keeps it in the title.
    level.menu_title = level.practice_map.menu_title;
    if(level.practice_version == "DEV BUILD") level.menu_title += " " + level.practice_version;
}

on_player_connect_menu()
{
	while(true)
	{
		level waittill("connecting", player);
		player thread on_player_spawned_menu();
	}
}

on_player_spawned_menu()
{
	self endon("disconnect");
	level endon("game_ended");

	while(true)
	{
		self waittill("spawned_player");
        self thread basegame_health_damage_monitor();

		if(!isDefined(self.has_menu))
		{
			self.has_menu = true;
			self thread initialize_menu();
		}

		flag_wait("initial_blackscreen_passed");

		if(self isHost())
		{
			if(get_cfg_int("hud_speed"))
				self thread basegame_speedometer();
		}
		else
		{
			speeddvar = self.name + "_speedometer";
			set_dvar_float_if_unset( speeddvar, "1" );
			if(int(getdvar(speeddvar)))
				self thread basegame_speedometer();
		}
	}
}

basegame_initialize()
{
    basegame_cfg_init();
    basegame_overrides();
    basegame_apply_show_identifier();
    if(isDefined(level.practice_map.initialize)) [[ level.practice_map.initialize ]]();
}

basegame_run()
{
    level thread say_command_monitor();
    flag_wait("initial_blackscreen_passed");
    iPrintLn( "^7" + level.practice_map.tool_name + " ^3" + level.practice_version );
    if(menu_equipment_chord()) iPrintLn( "^7Press [^6[{+melee}]^7] + [^6[{+actionslot " + menu_chord_slot() + "}]^7] ^7to open" );
    else iPrintLn( "^7Press [^6[{+melee}]^7] + [^6[{+smoke}]^7] ^7to open" );
    wait 1.8;

    level thread basegame_unitrigger_hud_monitor();
    level thread basegame_optional_hud_monitor();
    level thread basegame_zone_hud_monitor();
    level thread basegame_oopa_hud_monitor();
    if(isDefined(level.practice_map.run)) level thread [[ level.practice_map.run ]]();
    level thread basegame_points_hud_monitor();
    level thread basegame_active_zones_hud_monitor();
}

basegame_cfg_init()
{
    level.base_cfg_str = level.practice_map.cfg_dir + "basegame.cfg";
    level.base_cfg = cfg_load(level.base_cfg_str, basegame_default_cfg());
}

basegame_default_cfg()
{
    settings_ar = [];

    settings_ar["hud_points"] = 0;
    settings_ar["oopa"] = 1;
    settings_ar["hud_remaning"] = 0;
    settings_ar["hud_spawned"] = 0;
    settings_ar["hud_health"] = 0;
    settings_ar["hud_zone"] = 0;
    settings_ar["hud_speed"] = 1;
    settings_ar["hud_unitrigger"] = 0;
    settings_ar["hud_active_zones"] = 0;
    settings_ar["hud_oopa"] = 1; // OOPA Countdown: 0 off, 1 on, 2 the map's spot only (Origins: R2L)
    settings_ar["show_identifier"] = 1; // Plutonium's session identifier and script hashes (user, 2026-11-02).
    settings_ar["menu_key"] = 0; // The key that opens the menu with melee: 0 special grenade (user, 2026-11-02), 1 dpad slot 1 (the shield).

    if(isDefined(level.practice_map.base_cfg_defaults))
        settings_ar = [[ level.practice_map.base_cfg_defaults ]](settings_ar);
    return settings_ar;
}

// Plutonium's on-screen session identifier (cg_drawIdentifier) and the script
// hashes it flashes at the start of a game (cg_flashScriptHashes). Solo, the
// host's dvars are the player's own.
basegame_apply_show_identifier()
{
    show = get_cfg_int("show_identifier");
    setdvar("cg_flashScriptHashes", show);
    setdvar("cg_drawIdentifier", show);
}

// Menu action for "Show Identifier/Hashes".
basegame_toggle_show_identifier()
{
    self cfg_toggle_binary("show_identifier");
    basegame_apply_show_identifier();
}

basegame_overrides()
{
    replacefunc( maps\mp\zombies\_zm::player_out_of_playable_area_monitor, ::basegame_player_out_of_playable_area_monitor);
    replacefunc( maps\mp\zombies\_zm_powerups::watch_for_drop, ::basegame_watch_for_drop );
}

//funcs

give_drop( drop )
{
    powerup = level maps\mp\zombies\_zm_powerups::specific_powerup_drop( drop, self.origin );
    powerup thread maps\mp\zombies\_zm_powerups::powerup_timeout();
}

//HUD ELEMS

// Point based HUD (hud_points: 0 off, 1 relative, 2 absolute). The monitor builds
// the HUD when the setting is on and destroys it when it is off, so the menu
// switches it without a restart. level.score_to_drop exists once the vanilla
// drop watcher has started.
basegame_points_hud_monitor()
{
    level endon("end_game");
    text = "";
    while(true)
    {
        mode = get_cfg_int("hud_points");
        if(mode == 0 || !isDefined(level.score_to_drop))
        {
            if(isDefined(level.point_based_hud)) level.point_based_hud destroy();
            level.point_based_hud = undefined;
            text = "";
            wait 0.25;
            continue;
        }

        if(!isDefined(level.point_based_hud))
        {
            level.point_based_hud = createServerFontString("default", 1.4);
            level.point_based_hud.alignx = "left";
            level.point_based_hud.aligny = "middle";
            level.point_based_hud.horzalign = "right";
            level.point_based_hud.vertalign = "bottom";
            level.point_based_hud.x = -170;
            level.point_based_hud.y = 8;
            level.point_based_hud.alpha = 0.8;
            level.point_based_hud.hidewheninmenu = 0;
            text = "";
        }

        players = get_players();
        point_req = int(level.score_to_drop + 0.99);
        if(mode == 1)
        {
            // This player's points since the last drop.
            point_req -= players[0].score_total - players[0].score;
            point_cur = players[0].score;
        }
        else
        {
            point_cur = 0;
            foreach(player in players)
                if(isDefined(player.score_total)) point_cur += player.score_total;
        }

        new_text = point_cur + "/" + point_req;
        if(new_text != text)
        {
            level.point_based_hud setTextUnlimited(new_text);
            text = new_text;
        }

        if(level.zombie_vars["zombie_drop_item"])
            level.point_based_hud.color = (0.54, 0.17, 0.89);
        else
            level.point_based_hud.color = (1, 1, 1);

        wait 0.05;
    }
}

// Active zones HUD (hud_active_zones): every zone the zone manager keeps active,
// one per line. Built and destroyed by the setting, like the other optional HUDs.
// setTextUnlimited, as the text keeps changing (settext fills the configstrings).
basegame_active_zones_hud_monitor()
{
    level endon("end_game");
    hud = undefined;
    text = "";
    while(true)
    {
        if(!get_cfg_int("hud_active_zones") || !isDefined(level.zones))
        {
            if(isDefined(hud)) hud destroy();
            hud = undefined;
            text = "";
        }
        else
        {
            if(!isDefined(hud))
            {
                hud = createServerFontString("default", 1.2);
                hud.alignx = "left";
                hud.aligny = "top";
                hud.horzalign = "left";
                hud.vertalign = "middle";
                // Moved right and down from (-62, -65) so it clears the timers
                // (user, 2026-10-29, from a screenshot at 720p).
                hud.x = 100;
                hud.y = 30;
                hud.hidewheninmenu = 1;
            }
            new_text = "active zones:";
            zones = maps\mp\zombies\_zm_zonemgr::get_active_zone_names();
            if(isDefined(zones))
                foreach(zone in zones)
                    new_text = new_text + "\n" + basegame_plain_zone_name(zone);
            if(new_text != text)
            {
                hud setTextUnlimited(new_text);
                text = new_text;
            }
        }
        wait 0.25;
    }
}

// "zone_bunker_tank_b" -> "bunker tank b".
basegame_plain_zone_name(zone)
{
    if(zone.size >= 5 && getsubstr(zone, 0, 5) == "zone_")
        zone = getsubstr(zone, 5, zone.size);
    name = "";
    foreach(token in strtok(zone, "_"))
    {
        if(name != "") name += " ";
        name += token;
    }
    return name;
}





//OOOOOOOOOOOOOOOOVERUDDDDDDES

basegame_watch_for_drop()
{
    flag_wait( "start_zombie_round_logic" );
    flag_wait( "begin_spawning" );
    players = get_players();
    level.score_to_drop = players.size * level.zombie_vars["zombie_score_start_" + players.size + "p"] + level.zombie_vars["zombie_powerup_drop_increment"];

    while ( true )
    {
        flag_wait( "zombie_drop_powerups" );
        players = get_players();
        curr_total_score = 0;

        for ( i = 0; i < players.size; i++ )
        {
            if ( isdefined( players[i].score_total ) )
                curr_total_score += players[i].score_total;
        }

        if ( curr_total_score > level.score_to_drop )
        {
            level.zombie_vars["zombie_powerup_drop_increment"] *= 1.14;
            level.score_to_drop = curr_total_score + level.zombie_vars["zombie_powerup_drop_increment"];
            level.zombie_vars["zombie_drop_item"] = 1;
        }

        wait 0.5;
    }
}

/*##############################################################################
                              Real-run check timing
##############################################################################*/
// Vanilla's periodic checks tick on a fixed rhythm from the map start. Measured
// with tools\timing_probe.gsc (2026-10-26, map restarts on Origins, Mob and
// Buried), in run time (the T6 EE Timer's clock, zero when the black screen
// ends; level.game_start_time):
//   out of playable area   every 3 s at 2.2 s + 0.15 s x character index
//   zombie despawn         every 10 s at 3.2 s
#define PRACTICE_OOPA_PHASE_MS     2200
#define PRACTICE_OOPA_INDEX_MS      150
#define PRACTICE_DESPAWN_PHASE_MS  3200

// A mode that starts mid-run (Origins segment starts, Mob plane starts) calls
// this in its initialize, so those checks behave as in a real run from where it
// starts:
//   hold_flag    no checks until it is set (the start's release); undefined: the
//                black screen
//   clock_flag   set when the run clock starts at the start's time
// Between the two the checks keep their normal period; when the clock starts,
// each one's next tick waits for the real run's rhythm. Without this, vanilla.
// The mode initializes both flags (flag_init).
practice_check_phasing(hold_flag, clock_flag)
{
    level.practice_phasing = spawnstruct();
    level.practice_phasing.hold = hold_flag;
    level.practice_phasing.clock = clock_flag;
}

// The first check of a phased mode waits here.
practice_checks_hold()
{
    flag_wait("initial_blackscreen_passed");
    if(isdefined(level.practice_phasing.hold)) flag_wait(level.practice_phasing.hold);
}

// The wait between two ticks of a check with this period (seconds) that ticks
// at run time reference_ms in a real run. Before the clock starts: the period,
// cut short when it starts; then the first tick waits for the real rhythm and
// the rest the period. Returns whether the ticks are on that rhythm yet.
practice_phased_wait(aligned, period, reference_ms)
{
    if(aligned)
    {
        wait period;
        return true;
    }
    clock = level.practice_phasing.clock;
    if(!flag(clock)) level waittill_any_timeout(period, clock);
    if(!flag(clock)) return false;
    wait practice_check_delay(reference_ms, int(period * 1000));
    return true;
}

// Seconds from now until a check that ticks at run time reference_ms every
// period_ms ticks next.
practice_check_delay(reference_ms, period_ms)
{
    delay_ms = (reference_ms - (gettime() - level.game_start_time)) % period_ms;
    if(delay_ms < 0) delay_ms += period_ms;
    return delay_ms / 1000.0;
}

// The wait between out-of-playable-area checks (core monitor, self = player).
basegame_oopa_wait(aligned)
{
    period = maps\mp\zombies\_zm::get_player_out_of_playable_area_monitor_wait_time();
    if(!isdefined(level.practice_phasing))
    {
        wait period;
        return true;
    }
    return practice_phased_wait(aligned, period, PRACTICE_OOPA_PHASE_MS + PRACTICE_OOPA_INDEX_MS * self.characterindex);
}

// The wait between despawn checks, for a map's zombie_tracking_init override.
// Its first check waits in practice_checks_hold when phased.
practice_despawn_wait(aligned)
{
    if(!isdefined(level.practice_phasing))
    {
        wait level.zombie_tracking_wait;
        return true;
    }
    return practice_phased_wait(aligned, level.zombie_tracking_wait, PRACTICE_DESPAWN_PHASE_MS);
}

// Vanilla player_out_of_playable_area_monitor's condition: outside every life
// brush, and in a kill brush or outside the enabled playable area.
basegame_out_of_playable_area()
{
	return !self maps\mp\zombies\_zm::in_life_brush() && (self maps\mp\zombies\_zm::in_kill_brush() || !self maps\mp\zombies\_zm::in_enabled_playable_area());
}

// OOPA Countdown (hud_oopa): a bar filling from each out-of-playable-area check
// to the next, framed red once a check caught the player out. 1 on: while the
// player is out of the playable area, or at the map's spot. 2: only at the
// map's spot (practice_map oopa_hud_spot, self = player; Origins: the R2L trick
// until trig_zone_bunker_6 fires). No bar before the first check (segment
// starts hold it until their clock starts).
basegame_oopa_hud_monitor()
{
	level endon("end_game");
	while(true)
	{
		setting = get_cfg_int("hud_oopa");
		foreach(player in get_players())
		{
			show = false;
			if(setting && isdefined(player.practice_oopa_tick))
			{
				spot = isdefined(level.practice_map.oopa_hud_spot) && player [[ level.practice_map.oopa_hud_spot ]]();
				if(setting == 2) show = spot;
				else show = spot || player basegame_out_of_playable_area();
			}
			if(show)
			{
				if(!isdefined(player.practice_oopa_bar))
				{
					player.practice_oopa_bar = player createbar((1, 1, 1), 24, 2);
					player.practice_oopa_bar setpoint("CENTER", "CENTER", 0, 12);
				}
				elapsed = (gettime() - player.practice_oopa_tick) / (maps\mp\zombies\_zm::get_player_out_of_playable_area_monitor_wait_time() * 1000);
				if(elapsed > 1) elapsed = 1;
				player.practice_oopa_bar updatebar(elapsed);
				if(is_true(player.practice_oopa_failing)) player.practice_oopa_bar.color = (1, 0, 0);
				else player.practice_oopa_bar.color = (0, 0, 0);
			}
			else if(isdefined(player.practice_oopa_bar))
			{
				player.practice_oopa_bar destroyelem();
				player.practice_oopa_bar = undefined;
			}
		}
		wait 0.05;
	}
}

basegame_player_out_of_playable_area_monitor()
{
	self notify("stop_player_out_of_playable_area_monitor");
	self endon("stop_player_out_of_playable_area_monitor");
	self endon("disconnect");
	level endon("end_game");
	while(!isdefined(self.characterindex))
	{
		wait 0.05;
	}
	//MODIFIED: a mode that starts mid-run holds the checks until its release, then
	// puts them on a real run's timing (practice_check_phasing)
	aligned = !isdefined(level.practice_phasing);
	if(aligned) wait 0.15 * self.characterindex;
	else practice_checks_hold();
	//MODIFIED END
	while(true)
	{
		//MODIFIED: the OOPA Countdown times from each check and shows its result
		self.practice_oopa_tick = gettime();
		self.practice_oopa_failing = self basegame_out_of_playable_area();
		if(isdefined(level.practice_map.oopa_tick)) self [[ level.practice_map.oopa_tick ]]();
		//MODIFIED END
		if(self.sessionstate == "spectator")
		{
			aligned = self basegame_oopa_wait(aligned); //MODIFIED: real-run timing when phased
			continue;
		}
		if(is_true(level.hostmigration_occured))
		{
			aligned = self basegame_oopa_wait(aligned); //MODIFIED: real-run timing when phased
			continue;
		}
		//MODIFIED: vanilla's condition, shared with the OOPA Countdown
		if(self basegame_out_of_playable_area())
		//MODIFIED END
		{
			if(!isdefined(level.player_out_of_playable_area_monitor_callback) || self [[level.player_out_of_playable_area_monitor_callback]]())
			{
				self maps\mp\zombies\_zm_stats::increment_map_cheat_stat("cheat_out_of_playable");
				self maps\mp\zombies\_zm_stats::increment_client_stat("cheat_out_of_playable", 0);
				self maps\mp\zombies\_zm_stats::increment_client_stat("cheat_total", 0);
				if(get_cfg_int("oopa") == 1) self playlocalsound(level.zmb_laugh_alias);
				wait 0.5;
                if(get_cfg_int("oopa"))
                {
                    if(get_players().size == 1 && flag("solo_game") && (isdefined(self.waiting_to_revive) && self.waiting_to_revive))
                    {
                        level notify("end_game");
                    }
                    else
                    {
                        self disableinvulnerability();
                        self.lives = 0;
                        self dodamage(self.health + 1000, self.origin);
                        self.bleedout_time = 0;
                    }
                }
			}
		}
        else
        {
        }
		aligned = self basegame_oopa_wait(aligned); //MODIFIED: real-run timing when phased
	}
}

basegame_speedometer()
{
    self endon("kill_speedometer");

    self.speedometer = createfontstring("default", 1.4);
    self.speedometer.alpha = 0.8;
    self.speedometer.hidewheninmenu = 1;
    self.speedometer setpoint("CENTER", "CENTER", 0, 190);

    while (true)
    {
        self set_speedometer_color();
        wait 0.05;
    }
}

set_speedometer_color()
{
    velocity = int(length(self getvelocity() * (1, 1, 0))); //ignore vertical velocity
    self.speedometer setValue(velocity);

    if(isdefined( self.afterlife ) && self.afterlife )
    {
        self.speedometer.color = (0.6, 1.0, 1.0);      //pale cyan
        self.speedometer.glowcolor = (0.3, 0.8, 1.0);  //cyan glow
        return;
    }

    //Speed range for color gradient
    if(self hasperk("specialty_longersprint"))
    {
        min_speed = 310.0;
        max_speed = 390.0;
    }
    else
    {
        min_speed = 260.0;
        max_speed = 350.0;
    }

    //clamp value 0-1
    ratio = (velocity - min_speed) / (max_speed - min_speed);
    ratio = max(0, min(1, ratio));

    if (ratio < 0.5)
    {
        rt = ratio / 0.5;
        self.speedometer.color = (0.6 + 0.4 * rt, 1.0, 0.6); // green -> yellow
        self.speedometer.glowcolor = (0.4 + 0.3 * rt, 0.7, 0.4);
    }
    else
    {
        rt = (ratio - 0.5) / 0.5;
        self.speedometer.color = (1.0, 1.0 - 0.8 * rt, 0.6 - 0.6 * rt); // yellow -> red
        self.speedometer.glowcolor = (0.7, 0.7 - 0.6 * rt, 0.4 - 0.4 * rt);
	}
}

say_command_monitor()
{
	while(true)
	{
		level waittill("say", message, player);
		// Before the lowercasing below: slot names keep their case.
		if(player saveslot_say_command(message)) continue;
		if(player practice_time_say_command(tolower(message))) continue;
		switch(tolower(message))
		{
			case "help":
				player basegame_say_help();
				break;

			case "restart":
				player set_gamemode(level.gamemode);
				break;

			case "max":
				player give_drop("full_ammo");
				break;

			case "insta":
				player give_drop("insta_kill");
				break;

			case "nuke":
				player give_drop("nuke");
				break;

			case "double":
				player give_drop("double_points");
				break;

			case "points":
				player set_points(1000000);
				break;

			case "demi":
				player toggle_demigod();
				break;
			case "pap":
				player upgrade_weapon();
				break;
            case "doors":
                player thread open_all_doors();
                break;
            default:
                if(isdefined(level.practice_map.say_command))
                    player thread [[ level.practice_map.say_command ]](tolower(message));
                break;
		}
	}
}

basegame_say_help()
{
	self iprintln("^3restart^7, ^3time^7, ^3save^7, ^3load^7, ^3slot");
	line = "^3max^7, ^3insta^7, ^3nuke^7, ^3double^7, ^3points^7, ^3demi^7, ^3pap^7, ^3doors";
	if(isDefined(level.practice_map.say_help)) line += level.practice_map.say_help;
	self iprintln(line);
}

// Unitrigger HUD functions
basegame_toggle_unitrigger_hud()
{
    level.base_cfg["hud_unitrigger"] = 1 - get_cfg_int("hud_unitrigger");
    write_config(level.base_cfg, level.base_cfg_str);
    if(!get_cfg_int("hud_unitrigger")) basegame_unitrigger_hud_destroy_all();
    self refresh_menu();
}

basegame_unitrigger_hud_destroy_all()
{
    if(!isDefined(level.unitrigger_debug_huds)) return;
    foreach(record in level.unitrigger_debug_huds)
        if(isDefined(record) && isDefined(record.hud)) record.hud destroy();
    level.unitrigger_debug_huds = [];
}

basegame_unitrigger_hud_monitor()
{
    level notify("stop_unitrigger_debug");
    level endon("stop_unitrigger_debug");
    basegame_unitrigger_hud_destroy_all();
    level.unitrigger_debug_huds = [];
    level thread basegame_unitrigger_hud_game_end();
    while(true)
    {
        if(!get_cfg_int("hud_unitrigger"))
            basegame_unitrigger_hud_destroy_all();
        else
        {
            present = [];
            foreach(player in get_players())
            {
                if(!isDefined(player)) continue;
                index = player getentitynumber();
                present[index] = true;
                record = level.unitrigger_debug_huds[index];
                if(isDefined(record) && record.player != player)
                {
                    if(isDefined(record.hud)) record.hud destroy();
                    record = undefined;
                }
                if(!isDefined(record))
                {
                    record = spawnstruct();
                    record.player = player;
                    record.hud = player createFontString("default", 1.1);
                    record.hud setpoint("RIGHT", "TOP", -12, 110); // Left of centre, clear of the menu panel.
                    record.text = "";
                    level.unitrigger_debug_huds[index] = record;
                }
                text = player basegame_unitrigger_debug_text();
                if(text != record.text)
                {
                    record.hud setTextUnlimited(text);
                    record.text = text;
                }
            }
            // Keep HUD ownership outside the player entity so disconnect cleanup works.
            foreach(index, record in level.unitrigger_debug_huds)
            {
                if(isDefined(record) && !isDefined(present[index]))
                {
                    if(isDefined(record.hud)) record.hud destroy();
                    level.unitrigger_debug_huds[index] = undefined;
                }
            }
        }
        wait 0.1;
    }
}

basegame_unitrigger_hud_game_end()
{
    level notify("replace_unitrigger_debug_cleanup");
    level endon("replace_unitrigger_debug_cleanup");
    level waittill("game_ended");
    level notify("stop_unitrigger_debug");
    basegame_unitrigger_hud_destroy_all();
}

basegame_unitrigger_debug_text()
{
    trigger = level._unitriggers.trigger_pool[self getentitynumber()];
    if(!isDefined(trigger)) return "^3Unit trigger: ^7none";
    status = "^7selected (inactive)";
    if(isDefined(trigger.thread_running) && trigger.thread_running) status = "^2active";
    name = "unnamed";
    type = "unitrigger";
    if(isDefined(trigger.stub))
    {
        if(isDefined(trigger.stub.targetname) && trigger.stub.targetname != "") name = trigger.stub.targetname;
        else if(isDefined(trigger.stub.equipname)) name = trigger.stub.equipname;
        else if(isDefined(trigger.stub.script_noteworthy)) name = trigger.stub.script_noteworthy;
        if(isDefined(trigger.stub.script_unitrigger_type)) type = trigger.stub.script_unitrigger_type;
    }
    return "^3Unit trigger: " + status + " ^7#" + trigger getentitynumber() + " " + name + " (" + type + ")";
}

// One owner creates, updates and destroys optional HUDs during gameplay.
basegame_optional_hud_monitor()
{
    level thread basegame_watch_game_over();
    while(true)
    {
        spawned = get_round_enemy_array().size;
        if(get_cfg_int("hud_remaning"))
        {
            if(!isdefined(level.zombie_counter_hud))
            {
                level.zombie_counter_hud = createServerFontString("default", 1.3);
                level.zombie_counter_hud setpoint("LEFT", "CENTER", 60, 185);
                level.zombie_counter_hud.label = &"remaining: ^1";
            }
            level.zombie_counter_hud setvalue(spawned + level.zombie_total);
        }
        else if(isdefined(level.zombie_counter_hud))
        {
            level.zombie_counter_hud destroy();
            level.zombie_counter_hud = undefined;
        }
        if(get_cfg_int("hud_spawned"))
        {
            if(!isdefined(level.zombie_spawned_hud))
            {
                level.zombie_spawned_hud = createServerFontString("default", 1.3);
                level.zombie_spawned_hud setpoint("LEFT", "CENTER", 60, 200);
                level.zombie_spawned_hud.label = &"spawned: ^1";
            }
            level.zombie_spawned_hud setvalue(spawned);
        }
        else if(isdefined(level.zombie_spawned_hud))
        {
            level.zombie_spawned_hud destroy();
            level.zombie_spawned_hud = undefined;
        }
        foreach(player in get_players())
            player basegame_update_health_bar();
        wait 0.05;
    }
}

basegame_update_health_bar()
{
    if(!get_cfg_int("hud_health"))
    {
        if(isdefined(self.practice_health_bg)) self.practice_health_bg destroy();
        if(isdefined(self.practice_health_fill)) self.practice_health_fill destroy();
        if(isdefined(self.practice_health_value)) self.practice_health_value destroy();
        if(isdefined(self.practice_regen_bg)) self.practice_regen_bg destroy();
        if(isdefined(self.practice_regen_fill)) self.practice_regen_fill destroy();
        self.practice_regen_bg = undefined;
        self.practice_regen_fill = undefined;
        self.practice_health_value = undefined;
        self.practice_health_bg = undefined;
        self.practice_health_fill = undefined;
        return;
    }
    if(!isdefined(self.practice_health_bg))
    {
        self.practice_health_bg = newclienthudelem(self);
        self.practice_health_bg.horzalign = "left";
        self.practice_health_bg.vertalign = "bottom";
        self.practice_health_bg.alignx = "left";
        self.practice_health_bg.aligny = "top";
        self.practice_health_bg.x = -10;
        self.practice_health_bg.y = -42;
        self.practice_health_bg.color = (0.1, 0.1, 0.1);
        self.practice_health_bg.alpha = 0.8;
        self.practice_health_bg.sort = 1999;
        self.practice_health_bg setshader("white", 70, 8);
        self.practice_health_fill = newclienthudelem(self);
        self.practice_health_fill.horzalign = "left";
        self.practice_health_fill.vertalign = "bottom";
        self.practice_health_fill.alignx = "left";
        self.practice_health_fill.aligny = "top";
        self.practice_health_fill.x = -9;
        self.practice_health_fill.y = -41;
        self.practice_health_fill.sort = 2000;
    }
    if(!isdefined(self.practice_health_value))
    {
        self.practice_health_value = createfontstring("default", 1.4);
        self.practice_health_value.horzalign = "left";
        self.practice_health_value.vertalign = "bottom";
        self.practice_health_value.alignx = "left";
        self.practice_health_value.aligny = "middle";
        self.practice_health_value.x = -30;
        self.practice_health_value.y = -36;
        self.practice_health_value.sort = 2000;
        self.practice_health_value.color = (1, 1, 1);
    }
    shift = self basegame_hud_left_shift();
    self.practice_health_bg.x = hud_edge_x("left", -10) + shift;
    self.practice_health_fill.x = hud_edge_x("left", -9) + shift;
    self.practice_health_value.x = hud_edge_x("left", -30) + shift;
    self.practice_hud_shift = shift;

    // Downed and game-over players keep 100 health; show them as dead.
    alive = self basegame_hud_alive();
    health = 0;
    if(alive) health = self.health;
    self.practice_health_value setvalue(health);
    fraction = 0;
    if(alive && isdefined(self.maxhealth) && self.maxhealth > 0)
        fraction = self.health / self.maxhealth;
    if(fraction < 0) fraction = 0;
    if(fraction > 1) fraction = 1;
    width = int(68 * fraction);
    if(width < 1) width = 1;
    self.practice_health_fill setshader("white", width, 6);
    self.practice_health_fill.alpha = 0.9;
    if(fraction <= 0) self.practice_health_fill.alpha = 0;
    self.practice_health_fill.color = (1, 1, 1);
    self basegame_update_regen_bar();
}


basegame_zone_hud_monitor()
{
    level endon("end_game");
    while(true)
    {
        foreach(player in get_players())
            player basegame_update_zone_hud();
        wait 0.25;
    }
}

basegame_update_zone_hud()
{
    if(!get_cfg_int("hud_zone"))
    {
        if(isdefined(self.practice_zone_hud)) self.practice_zone_hud destroy();
        self.practice_zone_hud = undefined;
        self.practice_zone_text = undefined;
        return;
    }
    if(!isdefined(self.practice_zone_hud))
    {
        self.practice_zone_hud = createfontstring("default", 1.3);
        self.practice_zone_hud.horzalign = "left";
        self.practice_zone_hud.vertalign = "bottom";
        self.practice_zone_hud.alignx = "left";
        self.practice_zone_hud.aligny = "middle";
        self.practice_zone_hud.x = -30;
        self.practice_zone_hud.y = -55;
        self.practice_zone_hud.sort = 2000;
        self.practice_zone_hud.hidewheninmenu = 1;
    }
    self.practice_zone_hud.x = hud_edge_x("left", -30) + self basegame_hud_left_shift();
    zone = undefined;
    if(isdefined(level.zones)) zone = self maps\mp\zombies\_zm_zonemgr::get_player_zone();
    if(!isdefined(zone)) zone = "unknown";
    if(zone.size >= 5 && getsubstr(zone, zone.size - 5, zone.size) == "_zone")
        zone = getsubstr(zone, 0, zone.size - 5);
    zone = basegame_plain_zone_name(zone); // Same names as the Active Zones HUD.
    if(!isdefined(self.practice_zone_text) || self.practice_zone_text != zone)
    {
        self.practice_zone_hud setTextUnlimited("zone: " + zone);
        self.practice_zone_text = zone;
    }
}


// Observe damage notifications, including grenade self-damage.
basegame_health_damage_monitor()
{
    self notify("practice_health_damage_monitor");
    self endon("practice_health_damage_monitor");
    self endon("disconnect");
    self endon("death");
    level endon("end_game");
    self.practice_hurt_time = undefined;
    self.practice_severe_hurt = false;
    while(true)
    {
        self waittill("damage", amount, attacker);
        if(isdefined(attacker) && attacker != self && isplayer(attacker) && attacker.team == self.team) continue;
        self.practice_hurt_time = gettime();
    }
}

basegame_update_regen_bar()
{
    if(!isdefined(self.practice_regen_bg))
    {
        self.practice_regen_bg = newclienthudelem(self);
        self.practice_regen_bg.horzalign = "left";
        self.practice_regen_bg.vertalign = "bottom";
        self.practice_regen_bg.alignx = "left";
        self.practice_regen_bg.aligny = "top";
        self.practice_regen_bg.x = -10;
        self.practice_regen_bg.y = -32;
        self.practice_regen_bg.color = (0.1, 0.1, 0.1);
        self.practice_regen_bg.sort = 1999;
        self.practice_regen_bg setshader("white", 70, 5);
        self.practice_regen_fill = newclienthudelem(self);
        self.practice_regen_fill.horzalign = "left";
        self.practice_regen_fill.vertalign = "bottom";
        self.practice_regen_fill.alignx = "left";
        self.practice_regen_fill.aligny = "top";
        self.practice_regen_fill.x = -9;
        self.practice_regen_fill.y = -31;
        self.practice_regen_fill.color = (0.65, 0.65, 0.65);
        self.practice_regen_fill.sort = 2000;
    }
    self.practice_regen_bg.x = hud_edge_x("left", -10) + self.practice_hud_shift;
    self.practice_regen_fill.x = hud_edge_x("left", -9) + self.practice_hud_shift;
    self.practice_regen_bg.alpha = 0;
    self.practice_regen_fill.alpha = 0;
    if(!self basegame_hud_alive() || !isdefined(self.maxhealth) || self.health >= self.maxhealth)
    {
        self.practice_hurt_time = undefined;
        self.practice_severe_hurt = false;
        return;
    }
    if(!isdefined(self.practice_hurt_time)) return;
    if(self.health / self.maxhealth <= level.healthoverlaycutoff)
        self.practice_severe_hurt = true;
    delay = level.playerhealth_regularregendelay;
    self.practice_regen_fill.color = (1, 1, 1);
    if(self.practice_severe_hurt)
    {
        delay = level.longregentime;
        self.practice_regen_fill.color = (1, 0, 0);
    }
    if(delay <= 0) return;
    fraction = (gettime() - self.practice_hurt_time) / delay;
    if(fraction < 0) fraction = 0;
    if(fraction > 1) fraction = 1;
    width = int(68 * fraction);
    if(width < 1) width = 1;
    self.practice_regen_bg.alpha = 0.8;
    self.practice_regen_fill setshader("white", width, 3);
    if(fraction > 0) self.practice_regen_fill.alpha = 0.9;
}


basegame_hud_alive()
{
    // A solo bleed-out ends the game with the player still playing at full health.
    if(is_true(level.practice_game_over)) return false;
    if(!isalive(self) || self.sessionstate != "playing") return false;
    return !self maps\mp\zombies\_zm_laststand::player_is_in_laststand();
}

basegame_watch_game_over()
{
    level waittill("end_game");
    level.practice_game_over = true;
}

// x offset for the left-side HUD (zone, HP and regen); the map can move it
// around its own HUD icons.
basegame_hud_left_shift()
{
    if(isdefined(level.practice_map.hud_left_shift)) return self [[ level.practice_map.hud_left_shift ]]();
    return 0;
}



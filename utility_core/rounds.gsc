#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

/*##############################################################################
                              Round skip
##############################################################################*/
// Moved from O-Prac's shared_set_round (origins_menu\segmentutil.gsc) so every
// map can use it. Map-specific schedules (Origins Panzers and Templars, Mob's
// Brutus) are caught up by the caller before it calls this.

// Starts on target_round, as a fresh round or with remaining_zombies left in it.
// Waits for the next round to begin, then plays it out as an empty round with
// the health of the round before target_round, so the round after it is
// target_round. Call it before that round begins (thread it to keep going).
practice_set_round(target_round, remaining_zombies)
{
    if(target_round < 1) target_round = 1;

    level waittill("start_of_round");
    spawning_enabled = flag("spawn_zombies");
    flag_clear("spawn_zombies");
    level.zombie_total = 0;
    maps\mp\zombies\_zm::ai_calculate_health(target_round - 1);
    level.round_number = target_round - 1;
    level thread practice_clear_round_zombies();
    // The skipped round's break is one frame instead of vanilla's
    // zombie_between_round_time (10 s, round_over), so target_round begins about
    // 3.5 s after this one (round_wait's 1 s checks, the 2.5 s round change).
    between_round_time = level.zombie_vars["zombie_between_round_time"];
    level.zombie_vars["zombie_between_round_time"] = 0.05;
    level waittill("start_of_round");
    level.zombie_vars["zombie_between_round_time"] = between_round_time;
    round_max = practice_round_zombie_count(target_round);
    if(!isdefined(remaining_zombies)) remaining_zombies = round_max;
    if(remaining_zombies < 0) remaining_zombies = 0;
    if(remaining_zombies > round_max) remaining_zombies = round_max;
    level.zombie_total = remaining_zombies;

    delay = 2;
    for(i = 1; i <= target_round; i++) delay *= 0.95;
    level.zombie_vars["zombie_spawn_delay"] = delay;
    if(spawning_enabled) flag_set("spawn_zombies");
}

// Zombies in a round: the formula in maps\mp\zombies\_zm::round_spawning.
practice_round_zombie_count(target_round)
{
    max = level.zombie_vars["zombie_max_ai"];
    multiplier = target_round / 5;
    if(multiplier < 1) multiplier = 1;
    if(target_round >= 10) multiplier *= target_round * 0.15;
    player_count = get_players().size;
    if(player_count == 1)
        max += int(0.5 * level.zombie_vars["zombie_ai_per_player"] * multiplier);
    else
        max += int((player_count - 1) * level.zombie_vars["zombie_ai_per_player"] * multiplier);

    if(target_round < 2) return int(max * 0.25);
    if(target_round < 3) return int(max * 0.3);
    if(target_round < 4) return int(max * 0.5);
    if(target_round < 5) return int(max * 0.7);
    if(target_round < 6) return int(max * 0.9);
    return max;
}

// Kills every zombie of the skipped round as it spawns, until the round ends.
practice_clear_round_zombies()
{
    level endon("end_of_round");
    level endon("game_ended");
    while(true)
    {
        foreach(zombie in get_round_enemy_array())
            if(isdefined(zombie) && isalive(zombie))
                zombie dodamage(zombie.health + 666, zombie.origin);
        wait 0.05;
    }
}

#include maps\_utility;
#include common_scripts\utility;
#include maps\_playervehicle;

/*
	M1A1 ABRAMS - PLAYER COMMANDED TANK

	The tank is driven by the vehicle code itself ( useby, like the tank levels of CoD2 ): WASD drive
	the hull and the turret follows the view. On top of that this script adds a third person camera,
	a gunner sight, a loaded / reloading 120mm main gun, the coaxial machine gun on the ads button and
	the tank HUD.

	LEVEL SCRIPT
		main()
		{
			maps\_m1a1::main( "vehicle_m1a1_abrams" );
			maps\_playervehicle_abrams::main();					// before maps\_load::main()
			maps\_load::main();
			tank = maps\_playervehicle_abrams::setup( getent( "abrams_player", "targetname" ) );
		}

	RADIANT
		- a script_vehicle "vehicle_m1a1_abrams", vehicletype "m1a1", targetname "abrams_player".
		  Without a targetname the first M1A1 with the USABLE spawnflag ( then any M1A1 ) is used.

	NOTIFIES
		level "pv_abrams_boarded" ( tank ), level "pv_abrams_exited" ( tank ), tank "pv_main_gun_fired"
*/

main()
{
	pv_precache();

	level.pv_abrams_reload_time = 4.0;
	level.pv_abrams_shells = 40;
	level.pv_abrams_mg_ammo = 2400;
	level.pv_abrams_chase_distance = 400;
	level.pv_abrams_chase_height = 110;
	level.pv_abrams_gunner_offset = ( 52, -38, -6 );
	level.pv_abrams_default_view = "chase";

	level.pv_abrams_health[ "easy" ] = 5500;
	level.pv_abrams_health[ "medium" ] = 4000;
	level.pv_abrams_health[ "hard" ] = 3000;
	level.pv_abrams_health[ "fu" ] = 2200;

	precacheItem( "m1a1_turret_pv" );
	precacheTurret( "m1a1_coaxial_mg" );
	precacheModel( "vehicle_m1a1_abrams_PKT_Coaxial_MG" );
	precacheModel( "vehicle_m1a1_abrams_dmg" );

	precacheShader( "gfx/reticle/mg42_cross.tga" );
	precacheShader( "reticle_center_cross" );
	precacheShader( "tank_shell" );
	// reload fill frames: tank_shell with only the bottom k/16 visible ( main\images\tankfillNN.iwi )
	for ( i = 1; i < 16; i++ )
		precacheShader( abrams_fill_shader( i ) );
	precacheShader( "overlay_low_health" );

	precacheString( &"PLAYERVEHICLE_HINT_BOARD_ABRAMS" );
	precacheString( &"PLAYERVEHICLE_HINT_STOP_TO_EXIT" );
	precacheString( &"PLAYERVEHICLE_ABRAMS_TITLE" );
	precacheString( &"PLAYERVEHICLE_HELP_ABRAMS_DRIVE" );
	precacheString( &"PLAYERVEHICLE_HELP_ABRAMS_TURN" );
	precacheString( &"PLAYERVEHICLE_HELP_ABRAMS_MOUSE" );
	precacheString( &"PLAYERVEHICLE_HELP_ABRAMS_FIRE" );
	precacheString( &"PLAYERVEHICLE_HELP_ABRAMS_MG_TOGGLE" );
	precacheString( &"PLAYERVEHICLE_HELP_ABRAMS_MG_HOLD" );
	precacheString( &"PLAYERVEHICLE_HELP_ABRAMS_ZOOM" );
	precacheString( &"PLAYERVEHICLE_HELP_ABRAMS_VIEW" );
	precacheString( &"PLAYERVEHICLE_HELP_ABRAMS_EXIT" );
	precacheString( &"PLAYERVEHICLE_HUD_TANK_SABOT" );
	precacheString( &"PLAYERVEHICLE_HUD_TANK_COAX" );
	precacheString( &"PLAYERVEHICLE_HUD_TANK_READY" );
	precacheString( &"PLAYERVEHICLE_HUD_TANK_LOADING" );
	precacheString( &"PLAYERVEHICLE_HUD_TANK_RANGE" );
	precacheString( &"PLAYERVEHICLE_HUD_TANK_ARMOR" );
	precacheString( &"PLAYERVEHICLE_HUD_TANK_SPEED" );
	precacheString( &"PLAYERVEHICLE_HUD_TANK_DAMAGE" );
	precacheString( &"PLAYERVEHICLE_HUD_TANK_NO_AMMO" );

	level._effect[ "pv_abrams_smoke" ] = loadfx( "smoke/damaged_vehicle_smoke" );
	level._effect[ "pv_abrams_fire" ] = loadfx( "fire/tank_fire_engine" );
	level._effect[ "pv_abrams_turret_fire" ] = loadfx( "fire/tank_fire_turret_abrams" );
	level._effect[ "pv_abrams_explosion" ] = loadfx( "explosions/large_vehicle_explosion" );
	level._effect[ "pv_abrams_ammo_breach" ] = loadfx( "explosions/tank_ammo_breach" );

	precacheRumble( "artillery_rumble" );
	precacheRumble( "defaultweapon_fire" );
}

/*
=============
///ScriptDocBegin
"Name: setup( <tank> )"
"Summary: Turns an M1A1 from the map into the player tank. Call after maps\_load::main()."
"Module: PlayerVehicle"
"OptionalArg: <tank>: the script_vehicle, found automatically when omitted"
"Example: tank = maps\_playervehicle_abrams::setup( getent( "abrams_player", "targetname" ) );"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
setup( tank )
{
	pv_init();

	// let the vehicle system finish with the map vehicles first
	waittillframeend;

	if ( !isdefined( tank ) )
		tank = abrams_find_tank();
	assertEx( isdefined( tank ), "maps\\_playervehicle_abrams::setup() - no M1A1 in the map" );

	tank abrams_setup_vehicle();
	level.pv_abrams = tank;
	return tank;
}

abrams_find_tank()
{
	tank = getent( "abrams_player", "targetname" );
	if ( isdefined( tank ) )
		return tank;

	vehicles = getentarray( "script_vehicle", "classname" );
	for ( i = 0; i < vehicles.size; i++ )
	{
		if ( isdefined( vehicles[ i ].vehicletype ) && vehicles[ i ].vehicletype == "m1a1" && isdefined( vehicles[ i ].spawnflags ) && ( vehicles[ i ].spawnflags & 1 ) )
			return vehicles[ i ];
	}
	for ( i = 0; i < vehicles.size; i++ )
	{
		if ( isdefined( vehicles[ i ].vehicletype ) && vehicles[ i ].vehicletype == "m1a1" )
			return vehicles[ i ];
	}
	return undefined;
}

abrams_setup_vehicle()
{
	// the player tank handles its own health, death, main gun and coax
	self notify( "stop_vehicle_wait" );
	self notify( "stop_friendlyfire_shield" );
	self notify( "nodeath_thread" );
	self makevehicleunusable();
	self.health = 100000;

	// _vehicle::vehicle_shoot_shock() would shellshock / black out the player on every shot
	self.shock_distance = 0;
	self.black_distance = 0;

	// keep _vehicle's automatic coax gunner off
	self.script_turretmg = 0;

	self.pv = spawnstruct();
	self.pv.hp_max = abrams_difficulty_health();
	self.pv.hp = self.pv.hp_max;
	self.pv.shells = level.pv_abrams_shells;
	self.pv.mg_ammo = level.pv_abrams_mg_ammo;
	self.pv.loaded = true;
	self.pv.reloading = false;
	self.pv.view = level.pv_abrams_default_view;
	self.pv.piloted = false;
	self.pv.dead = false;
	self.pv.exit_allowed = true;
	self.pv.damage_state = 0;
	self.pv.help_shown = false;
	self.pv.velocity = ( 0, 0, 0 );
	self.pv.next_dry_fire = 0;
	self.pv_damage_func = ::abrams_damage;

	self abrams_coax_create();
	self thread abrams_damage_monitor();

	pv_register_vehicle( self, &"PLAYERVEHICLE_HINT_BOARD_ABRAMS", ::abrams_enter, 260, "tag_turret" );
}

abrams_difficulty_health()
{
	skill = getdifficulty();
	if ( isdefined( level.pv_abrams_health[ skill ] ) )
		return level.pv_abrams_health[ skill ];
	return level.pv_abrams_health[ "medium" ];
}

// the coax that _vehicle::mginit() spawned fires in bursts on its own, so it is replaced by
// a manual turret driven by the ads button
abrams_coax_create()
{
	if ( isdefined( self.mgturret ) )
	{
		for ( i = 0; i < self.mgturret.size; i++ )
		{
			if ( isdefined( self.mgturret[ i ] ) )
				self.mgturret[ i ] delete();
		}
	}

	turret = spawnTurret( "misc_turret", self gettagorigin( "tag_coax_mg" ), "m1a1_coaxial_mg" );
	turret setmodel( "vehicle_m1a1_abrams_PKT_Coaxial_MG" );
	turret.angles = self gettagangles( "tag_coax_mg" );
	turret linkto( self, "tag_coax_mg", ( 0, 0, 0 ), ( 0, 0, 0 ) );
	turret maketurretunusable();
	turret setmode( "manual" );
	turret setturretteam( "allies" );
	turret setleftarc( 25 );
	turret setrightarc( 25 );
	turret settoparc( 25 );
	turret setbottomarc( 25 );
	turret setshadowhint( "never" );
	turret.isvehicleattached = true;
	turret.pv_credit_player = true;

	self.pv.coax = turret;
	self.pv.coax_target = spawn( "script_origin", self.origin );
	turret settargetentity( self.pv.coax_target );


	self.mgturret = [];
	self.mgturret[ 0 ] = turret;
}

/******************************************************/
/*                     PUBLIC API                     */
/******************************************************/

player_enter( tank )
{
	if ( !isdefined( tank ) )
		tank = level.pv_abrams;
	tank abrams_enter();
}

set_exit_allowed( tank, allowed )
{
	tank.pv.exit_allowed = allowed;
}

set_boarding_enabled( tank, enabled )
{
	pv_set_boardable( tank, enabled );
}

/******************************************************/
/*                    ENTER / EXIT                    */
/******************************************************/

abrams_enter()
{
	if ( isdefined( level.pv_active ) || self.pv.dead )
		return;

	self notify( "pv_boarded" );
	pv_player_enter( self );
	pv_fade_out( 0.25 );

	self playsound( "tank_hatch" );
	self useby( level.player );
	self.pv.piloted = true;

	// we own the main gun: _vehicle::turret_shoot() fires on every "turret_fire"
	self notify( "stop_turret_shoot" );
	self setvehweapon( "m1a1_turret_pv" );

	self abrams_hud_create();
	self abrams_set_view( self.pv.view );

	self thread abrams_camera_think();
	self thread abrams_aim_think();
	self thread abrams_main_gun_think();
	self thread abrams_coax_think();
	self thread abrams_input_think();
	self thread abrams_hud_think();
	self thread abrams_player_death_cleanup();

	level notify( "pv_abrams_boarded", self );

	pv_fade_in( 0.35 );
	level.pv_transition = undefined;

	if ( !self.pv.help_shown )
	{
		self.pv.help_shown = true;
		thread pv_show_help( &"PLAYERVEHICLE_ABRAMS_TITLE", abrams_help_lines(), 12 );
	}
}

abrams_help_lines()
{
	lines = [];
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ABRAMS_DRIVE";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ABRAMS_TURN";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ABRAMS_MOUSE";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ABRAMS_FIRE";
	if ( pv_ads_is_toggle() )
		lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ABRAMS_MG_TOGGLE";
	else
		lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ABRAMS_MG_HOLD";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ABRAMS_ZOOM";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ABRAMS_VIEW";
	if ( self.pv.exit_allowed )
		lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ABRAMS_EXIT";
	return lines;
}

abrams_try_exit()
{
	if ( !self.pv.exit_allowed || isdefined( level.pv_transition ) )
		return;

	if ( self getspeedmph() > 2 )
	{
		self abrams_hud_message( &"PLAYERVEHICLE_HINT_STOP_TO_EXIT" );
		return;
	}

	self thread abrams_exit();
}

abrams_exit()
{
	level.pv_transition = true;
	pv_fade_out( 0.25 );

	self notify( "pv_exit" );
	self abrams_shutdown();

	// back out through the hatch ( the vehicle code puts the player on tag_detach )
	self useby( level.player );
	self playsound( "tank_hatch" );

	pv_player_exit();
	level notify( "pv_abrams_exited", self );

	pv_fade_in( 0.35 );
	level.pv_transition = undefined;
}

abrams_shutdown()
{
	pv_help_destroy();

	if ( isdefined( self.pv.coax ) )
		self.pv.coax stopfiring();

	level.player unlink();
	if ( isdefined( self.pv.cam ) )
		self.pv.cam delete();

	pv_hud_destroy_all();
	self.pv.hud = undefined;
	self.pv.piloted = false;
}

abrams_player_death_cleanup()
{
	self endon( "pv_exit" );
	self endon( "death" );

	level.player waittill( "death" );
	setsaveddvar( "cg_fov", "65" );
	if ( isdefined( self.pv.coax ) )
		self.pv.coax stopfiring();
}

/******************************************************/
/*                       CAMERA                       */
/******************************************************/

abrams_set_view( view )
{
	self.pv.view = view;
	angles = level.player getplayerangles();

	level.player unlink();
	if ( isdefined( self.pv.cam ) )
		self.pv.cam delete();

	if ( view == "gunner" )
	{
		// sight on the turret roof next to the gun
		self.pv.cam = pv_camera_rig( self, "tag_turret", level.pv_abrams_gunner_offset, ( 0, 0, 0 ) );
		level.player playerlinkto( self.pv.cam, "tag_origin", 0, 180, 180, 25, 25 );
	}
	else
	{
		self.pv.cam_hull_yaw = self.angles[ 1 ];
		self.pv.cam_rel_yaw = pv_angle_diff( angles[ 1 ], self.angles[ 1 ] );
		self.pv.cam_offset = self abrams_chase_offset();
		self.pv.cam = pv_camera_rig( self, "tag_origin", self.pv.cam_offset, ( 0, 0, 0 ) );
		level.player playerlinkto( self.pv.cam, "tag_origin", 0, 180, 180, 75, 75 );
	}

	level.player setplayerangles( angles );
	self abrams_apply_fov();
	self.pv.view_changed = true;
}

abrams_apply_fov()
{
	zoom = pv_button_held( "down" );
	if ( self.pv.view == "gunner" )
	{
		if ( zoom )
			pv_set_fov( 15 );
		else
			pv_set_fov( 45 );
	}
	else
	{
		if ( zoom )
			pv_set_fov( 30 );
		else
			pv_set_fov( 70 );
	}
}

// Orbit of the chase camera round the turret, following the view ( the turret then traverses after the
// view ), pulled in front of walls, as a link offset in hull space.
//  - Scripts run before the vehicles move in a server frame, so the offset is worked out for the heading
//    the hull will have at the end of the frame: otherwise the camera swings round with the hull for a
//    frame on every turn.
//  - The vehicle code turns the player's view along with the hull, in uneven steps of one to six degrees
//    per server frame. The orbit therefore follows the view relative to the hull, with those steps smoothed
//    out, while a real turn of the mouse is followed straight away.
abrams_chase_offset()
{
	view = level.player getplayerangles();
	hull_turn = pv_angle_diff( self.angles[ 1 ], self.pv.cam_hull_yaw );
	self.pv.cam_hull_yaw = self.angles[ 1 ];

	gap = pv_angle_diff( pv_angle_diff( view[ 1 ], self.angles[ 1 ] ), self.pv.cam_rel_yaw );
	if ( abs( gap ) > 4 )
		self.pv.cam_rel_yaw += gap * 0.85;
	else
		self.pv.cam_rel_yaw += gap * 0.4;
	self.pv.cam_rel_yaw = pv_angle_diff( self.pv.cam_rel_yaw, 0 );

	hull = ( self.angles[ 0 ], self.angles[ 1 ] + hull_turn, self.angles[ 2 ] );
	pitch = pv_clamp( view[ 0 ], -8, 45 ) * 0.6;
	yaw = hull[ 1 ] + self.pv.cam_rel_yaw;

	// the turret ring, carried round with the hull
	ring = self gettagorigin( "tag_turret" ) - self.origin;
	c = cos( hull_turn );
	s = sin( hull_turn );
	ring = ( ring[ 0 ] * c - ring[ 1 ] * s, ring[ 0 ] * s + ring[ 1 ] * c, ring[ 2 ] );

	pivot = self.origin + ring + ( 0, 0, level.pv_abrams_chase_height );
	eye = pivot - vectorScale( anglestoforward( ( pitch, yaw, 0 ) ), level.pv_abrams_chase_distance );

	// keep the camera out of walls and the ground
	trace = bullettrace( pivot, eye, false, self );
	if ( trace[ "fraction" ] < 1 )
		eye = pivot + vectorScale( eye - pivot, pv_max( 0.12, trace[ "fraction" ] - 0.08 ) );

	// the player's eye sits 60 units above the link point
	rig = eye - ( 0, 0, 60 ) - self.origin;
	return ( vectordot( rig, anglestoforward( hull ) ), -1 * vectordot( rig, anglestoright( hull ) ), vectordot( rig, anglestoup( hull ) ) );
}

abrams_camera_think()
{
	self endon( "death" );
	self endon( "pv_exit" );

	last_origin = self.origin;
	for ( ;; )
	{
		wait 0.05;

		self.pv.velocity = vectorScale( self.origin - last_origin, 20 );
		last_origin = self.origin;

		if ( self.pv.view != "chase" || !isdefined( self.pv.cam ) )
			continue;

		// the rig stays linked to the hull ( so it never trails behind a moving tank ) and only its
		// offset follows the view; moveto() every frame stutters, the mover is updated after the scripts
		offset = self abrams_chase_offset();
		if ( distancesquared( offset, self.pv.cam_offset ) < 0.25 )
			continue;
		self.pv.cam_offset = offset;
		self.pv.cam unlink();
		self.pv.cam linkto( self, "tag_origin", offset, ( 0, 0, 0 ) );
	}
}

/******************************************************/
/*                      WEAPONS                       */
/******************************************************/

abrams_aim_think()
{
	self endon( "death" );
	self endon( "pv_exit" );

	for ( ;; )
	{
		flash = self gettagorigin( "tag_flash" );
		dir = anglestoforward( self gettagangles( "tag_barrel" ) );
		trace = bullettrace( flash, flash + vectorScale( dir, 30000 ), true, self );
		self.pv.gun_point = trace[ "position" ];
		self.pv.gun_range = distance( flash, self.pv.gun_point );
		self.pv.coax_target.origin = self.pv.gun_point;
		wait 0.05;
	}
}

abrams_main_gun_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	for ( ;; )
	{
		// sent by the vehicle code while the fire button is down
		self waittill( "turret_fire" );

		if ( !self.pv.loaded )
			continue;

		if ( self.pv.shells <= 0 && getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
		{
			if ( gettime() > self.pv.next_dry_fire )
			{
				self.pv.next_dry_fire = gettime() + 1000;
				level.player playlocalsound( "weap_dryfire_smg_plr" );
				self abrams_hud_message( &"PLAYERVEHICLE_HUD_TANK_NO_AMMO" );
			}
			continue;
		}

		self setvehweapon( "m1a1_turret_pv" );
		self fireweapon();
		self notify( "pv_main_gun_fired" );

		if ( getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
			self.pv.shells--;
		self.pv.loaded = false;
		self.pv.ammo_changed = true;

		earthquake( 0.4, 0.8, level.player.origin, 600 );
		level.player playrumbleonentity( "artillery_rumble" );

		self thread abrams_reload();
	}
}

// the loader rams a new round: the shell icon dims on the shot and fills back up
abrams_reload()
{
	self endon( "death" );

	self.pv.reloading = true;
	self.pv.reload_start = gettime();
	self thread abrams_hud_reload_fill();

	wait level.pv_abrams_reload_time * 0.4;
	if ( self.pv.piloted )
		self playsound( "tank_reload" );
	wait level.pv_abrams_reload_time * 0.6;

	self.pv.reloading = false;
	if ( self.pv.shells > 0 || getdvar( "cobrapilot_unlimited_ammo" ) == "1" )
	{
		self.pv.loaded = true;
		if ( self.pv.piloted )
			level.player playlocalsound( "weap_raise_plr" );
	}
	self abrams_hud_reload_done();
}

abrams_coax_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	turret = self.pv.coax;
	for ( ;; )
	{
		while ( !pv_button_held( "ads" ) )
			wait 0.05;

		if ( self.pv.mg_ammo <= 0 && getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
		{
			level.player playlocalsound( "weap_dryfire_smg_plr" );
			while ( pv_button_held( "ads" ) )
				wait 0.05;
			continue;
		}

		turret startfiring();
		while ( pv_button_held( "ads" ) )
		{
			if ( self.pv.mg_ammo <= 0 && getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
				break;
			turret shootturret();
			if ( getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
				self.pv.mg_ammo--;
			self.pv.ammo_changed = true;
			wait 0.08;
		}
		turret stopfiring();
	}
}

/******************************************************/
/*                       INPUT                        */
/******************************************************/

abrams_input_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	for ( ;; )
	{
		level waittill( "pv_input", cmd );

		switch ( cmd )
		{
			case "view":
				if ( self.pv.view == "chase" )
					self abrams_set_view( "gunner" );
				else
					self abrams_set_view( "chase" );
				level.player playlocalsound( "ui_camera_whoosh_in" );
				break;
			case "use":
				self abrams_try_exit();
				break;
			case "down_on":
			case "down_off":
				self abrams_apply_fov();
				break;
		}
	}
}

/******************************************************/
/*                   DAMAGE / DEATH                   */
/******************************************************/

abrams_damage_monitor()
{
	self endon( "death" );

	for ( ;; )
	{
		self waittill( "damage", amount, attacker, direction, point, type );
		self.health = 100000;
		self thread abrams_damage( amount, attacker, direction, point, type );
	}
}

abrams_damage( amount, attacker, direction, point, type )
{
	if ( self.pv.dead )
		return;
	if ( pv_is_friendly( attacker, self ) )
		return;

	scale = 1.0;
	if ( isdefined( type ) )
	{
		switch ( type )
		{
			// small arms do nothing to an Abrams
			case "MOD_PISTOL_BULLET":
			case "MOD_RIFLE_BULLET":
			case "MOD_MELEE":
				return;
			case "MOD_GRENADE":
			case "MOD_GRENADE_SPLASH":
				scale = 0.4;
				break;
		}
	}

	// the frontal armor stops most of it ( build_frontarmor() in _m1a1 ), the rear is weak
	if ( isdefined( attacker ) && isdefined( attacker.origin ) )
	{
		to_attacker = vectornormalize( ( attacker.origin[ 0 ] - self.origin[ 0 ], attacker.origin[ 1 ] - self.origin[ 1 ], 0 ) );
		facing = vectordot( to_attacker, anglestoforward( ( 0, self.angles[ 1 ], 0 ) ) );
		if ( facing > 0.7 )
			scale = scale * 0.4;
		else if ( facing < -0.6 )
			scale = scale * 1.5;
	}

	damage = int( pv_min( amount * scale, self.pv.hp_max * 0.4 ) );
	if ( damage <= 0 )
		return;

	self.pv.hp -= damage;

	if ( self.pv.piloted )
	{
		self.pv.hud_damage_flash = true;
		level.player playrumbleonentity( "damage_heavy" );
		earthquake( 0.3, 0.5, level.player.origin, 400 );
	}

	self abrams_damage_state();

	if ( self.pv.hp <= 0 )
		self thread abrams_destroyed();
}

abrams_damage_state()
{
	frac = self.pv.hp / self.pv.hp_max;
	state = 0;
	if ( frac < 0.55 )
		state = 1;
	if ( frac < 0.25 )
		state = 2;

	if ( state <= self.pv.damage_state )
		return;
	self.pv.damage_state = state;

	if ( state == 1 )
		self thread abrams_damage_fx( "pv_abrams_smoke", "tag_engine_exhaust", 0.4 );
	if ( state == 2 )
		self thread abrams_damage_fx( "pv_abrams_fire", "tag_engine_left", 0.3 );
}

abrams_damage_fx( fx, tag, rate )
{
	self endon( "death" );
	for ( ;; )
	{
		playfxontag( level._effect[ fx ], self, tag );
		wait rate;
	}
}

abrams_destroyed()
{
	if ( self.pv.dead )
		return;
	self.pv.dead = true;
	self notify( "pv_crash" );
	pv_set_boardable( self, false );

	origin = self.origin;
	playfx( level._effect[ "pv_abrams_explosion" ], origin );
	playfxontag( level._effect[ "pv_abrams_ammo_breach" ], self, "tag_turret" );
	self playsound( "pv_tank_explode" );
	earthquake( 0.6, 1.5, origin, 2500 );

	if ( isdefined( self.pv.coax ) )
	{
		self.pv.coax stopfiring();
		self.pv.coax delete();
	}

	if ( self.pv.piloted )
		pv_kill_player( "@PLAYERVEHICLE_DEADQUOTE_ABRAMS" );

	self setmodel( "vehicle_m1a1_abrams_dmg" );
	radiusdamage( origin + ( 0, 0, 64 ), 300, 200, 30 );
	self thread abrams_damage_fx( "pv_abrams_turret_fire", "tag_turret", 0.3 );
}

/******************************************************/
/*                         HUD                        */
/******************************************************/

abrams_hud_create()
{
	level.pv_hud_elems = [];
	hud = spawnstruct();
	self.pv.hud = hud;

	// The stationary MG crosshair, fixed in the middle of the screen like on the MG42: the turret lays the
	// gun on whatever is under it. A HUD element that tracked the gun from script would trail the view at
	// 20 updates a second ( and 3D waypoints only take effect materials ).
	hud.cross = pv_hud_icon( "gfx/reticle/mg42_cross.tga", 40, 40, 0, 0, "center", "middle", "center", "middle" );
	hud.cross.alpha = 0.9;

	// where the gun really points while the turret is still traversing
	hud.gun_mark = pv_hud_icon( "reticle_center_cross", 20, 20, 0, 0, "center", "middle", "center", "middle" );
	hud.gun_mark.alpha = 0;

	// range to the impact point, under the middle of the screen
	hud.range = pv_hud_text( "objective", 1.1, 0, 30, "center", "top", "center", "middle" );
	hud.range.label = &"PLAYERVEHICLE_HUD_TANK_RANGE";

	// main gun ( bottom right, where the weapon info normally is )
	hud.shell_back = pv_hud_icon( "tank_shell", 44, 44, -14, -14, "right", "bottom", "right", "bottom" );
	hud.shell_back.alpha = 0.35;
	hud.shell = pv_hud_icon( "tank_shell", 44, 44, -14, -14, "right", "bottom", "right", "bottom" );

	hud.gun_name = pv_hud_text( "objective", 1.25, -60, -48, "right", "middle", "right", "bottom" );
	hud.gun_name settext( &"PLAYERVEHICLE_HUD_TANK_SABOT" );
	hud.gun_count = pv_hud_text( "objective", 1.9, -60, -28, "right", "middle", "right", "bottom" );
	hud.gun_count setvalue( self.pv.shells );
	hud.gun_status = pv_hud_text( "objective", 1.1, -14, -64, "right", "middle", "right", "bottom" );

	hud.mg_name = pv_hud_text( "objective", 1.1, -60, -84, "right", "middle", "right", "bottom" );
	hud.mg_name settext( &"PLAYERVEHICLE_HUD_TANK_COAX" );
	hud.mg_count = pv_hud_text( "objective", 1.1, -14, -84, "right", "middle", "right", "bottom" );
	hud.mg_count setvalue( self.pv.mg_ammo );

	// hull status next to the code drawn tank icon ( hud.menu "tankstatus" )
	hud.armor = pv_hud_text( "objective", 1.1, 148, -36, "left", "middle", "left", "bottom" );
	hud.armor.label = &"PLAYERVEHICLE_HUD_TANK_ARMOR";
	hud.speed = pv_hud_text( "objective", 1.1, 148, -22, "left", "middle", "left", "bottom" );
	hud.speed.label = &"PLAYERVEHICLE_HUD_TANK_SPEED";

	hud.warning = pv_hud_text( "objective", 1.8, 0, -96, "center", "middle", "center", "middle" );
	hud.warning settext( &"PLAYERVEHICLE_HUD_TANK_DAMAGE" );
	hud.warning.color = ( 1, 0.2, 0.15 );
	hud.warning.alpha = 0;

	hud.message = pv_hud_text( "default", 1.4, 0, 70, "center", "middle", "center", "middle" );
	hud.message.alpha = 0;

	hud.damage_overlay = pv_hud_icon( "overlay_low_health", 640, 480, 0, 0, "left", "top", "fullscreen", "fullscreen" );
	hud.damage_overlay.alpha = 0;
	hud.damage_overlay.foreground = false;
	hud.damage_overlay.sort = -2;

	// stock HUD look: white, slightly transparent
	text = [];
	text[ text.size ] = hud.range;
	text[ text.size ] = hud.gun_name;
	text[ text.size ] = hud.gun_count;
	text[ text.size ] = hud.gun_status;
	text[ text.size ] = hud.mg_name;
	text[ text.size ] = hud.mg_count;
	text[ text.size ] = hud.armor;
	text[ text.size ] = hud.speed;
	for ( i = 0; i < text.size; i++ )
		text[ i ].alpha = 0.8;

	self.pv.ammo_changed = true;

	// back in during a reload: continue the fill where it is
	if ( self.pv.reloading )
		self abrams_hud_reload_frame();
	else if ( !self.pv.loaded )
		hud.shell.alpha = 0;
}

// the dim shell icon fills up from the bottom over the reload
abrams_hud_reload_fill()
{
	self endon( "death" );

	while ( self.pv.reloading )
	{
		self abrams_hud_reload_frame();
		wait 0.05;
	}
}

abrams_hud_reload_frame()
{
	hud = self.pv.hud;
	if ( !isdefined( hud ) )
		return;

	elapsed = ( gettime() - self.pv.reload_start ) / 1000;
	step = int( pv_clamp( 16 * elapsed / level.pv_abrams_reload_time, 0, 15 ) );
	if ( step < 1 )
	{
		hud.shell.alpha = 0;
		return;
	}

	hud.shell setshader( abrams_fill_shader( step ), 44, 44 );
	hud.shell.alpha = 1;
}

abrams_fill_shader( step )
{
	if ( step < 10 )
		return "tankfill0" + step;
	return "tankfill" + step;
}

abrams_hud_reload_done()
{
	hud = self.pv.hud;
	if ( !isdefined( hud ) )
		return;

	hud.shell setshader( "tank_shell", 44, 44 );
	if ( self.pv.loaded )
	{
		hud.shell.alpha = 1;
		hud.shell.color = ( 1, 1, 0.6 );
		hud.shell fadeOverTime( 0.4 );
		hud.shell.color = ( 1, 1, 1 );
	}
	else
	{
		hud.shell.alpha = 0;
	}
}

abrams_hud_message( text )
{
	if ( !isdefined( self.pv.hud ) )
		return;

	hud = self.pv.hud;
	hud.message settext( text );
	hud.message.alpha = 1;
	hud.message fadeOverTime( 2.5 );
	hud.message.alpha = 0;
}

abrams_hud_think()
{
	self endon( "death" );
	self endon( "pv_exit" );

	for ( ;; )
	{
		wait 0.05;
		hud = self.pv.hud;
		if ( !isdefined( hud ) || !isdefined( self.pv.gun_point ) )
			continue;

		hud.range setvalue( int( self.pv.gun_range / 39.37 ) );

		// the gun's aim while it is off the crosshair ( turret traversing, gun at its elevation limit )
		pos = pv_world_to_screen( self.pv.gun_point, level.player geteye(), level.player getplayerangles(), level.pv_fov );
		if ( isdefined( pos ) && ( abs( pos[ 0 ] ) > 16 || abs( pos[ 1 ] ) > 16 ) && abs( pos[ 0 ] ) < 420 && abs( pos[ 1 ] ) < 235 )
		{
			if ( hud.gun_mark.alpha == 0 )
			{
				hud.gun_mark.x = pos[ 0 ];
				hud.gun_mark.y = pos[ 1 ];
			}
			hud.gun_mark moveOverTime( 0.1 );
			hud.gun_mark.x = pos[ 0 ];
			hud.gun_mark.y = pos[ 1 ];
			hud.gun_mark.alpha = 0.6;
		}
		else
			hud.gun_mark.alpha = 0;

		if ( self.pv.loaded )
		{
			hud.gun_status settext( &"PLAYERVEHICLE_HUD_TANK_READY" );
			hud.gun_status.alpha = 0.8;
		}
		else
		{
			hud.gun_status settext( &"PLAYERVEHICLE_HUD_TANK_LOADING" );
			if ( pv_blink_on( 600 ) )
				hud.gun_status.alpha = 0.8;
			else
				hud.gun_status.alpha = 0.25;
		}

		if ( self.pv.ammo_changed )
		{
			self.pv.ammo_changed = false;
			hud.gun_count setvalue( self.pv.shells );
			hud.mg_count setvalue( self.pv.mg_ammo );
		}

		hud.armor setvalue( int( pv_max( 0, self.pv.hp ) * 100 / self.pv.hp_max ) );
		hud.speed setvalue( int( self getspeedmph() ) );

		if ( self.pv.damage_state >= 1 )
			hud.armor.color = ( 1, 0.6, 0.2 );
		if ( self.pv.damage_state >= 2 )
		{
			hud.armor.color = ( 1, 0.25, 0.2 );
			hud.warning.alpha = 0.8 * pv_blink_on( 1000 );
		}

		if ( isdefined( self.pv.hud_damage_flash ) )
		{
			self.pv.hud_damage_flash = undefined;
			hud.damage_overlay.alpha = 0.5;
			hud.damage_overlay fadeOverTime( 0.6 );
			hud.damage_overlay.alpha = 0;
		}
	}
}

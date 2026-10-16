#include maps\_utility;
#include common_scripts\utility;
#include maps\_playervehicle;

/*
	AH-1W SUPERCOBRA - PLAYER PILOTED GUNSHIP

	Rebuilt from the cut "cobrapilot" alpha ( maps\_cobrapilot.gsc ) for the PC: the alpha drove the
	helicopter through the console-only flight model, so here the Cobra is flown through the vehicle
	AI goal system ( same calls the AI helicopters use ) with the player's input, which gives the same
	tilting / inertia but works with mouse and keyboard.

	LEVEL SCRIPT
		main()
		{
			maps\_playervehicle_cobra::main();					// before maps\_load::main()
			maps\_load::main();
			cobra = maps\_playervehicle_cobra::setup( getent( "cobra_player", "targetname" ) );
		}

	RADIANT
		- a script_vehicle with model "vehicle_cobra_helicopter_fly" and targetname "cobra_player".
		  Any helicopter vehicletype works ( cobra / cobra_player ), it is swapped for the
		  "cobra_pv" vehicle info at runtime. The USABLE spawnflag is not needed.
		- optional rearm / repair pads: trigger_multiple or trigger_radius with targetname "ammo_reload"
		  ( same as the alpha ) or "cobra_rearm".
		- optional mission area: trigger_multiple "border_outer" / "border_inner" ( same as the alpha ).

	ZONE FILE
		see the lines in zone_source\cobra_pilot.csv between the "player vehicles" comments.

	DVARS ( same names as the alpha )
		cobrapilot_unlimited_ammo	0 / 1
		cobrapilot_gunner_enabled	1 / 0	front seat gunner works the 20mm while you use missiles

	NOTIFIES
		level "pv_cobra_boarded" ( cobra ), level "pv_cobra_exited" ( cobra ), cobra "pv_landed", cobra "pv_takeoff"
*/

main( model )
{
	if ( !isdefined( model ) )
		model = "vehicle_cobra_helicopter_fly";
	level.pv_cobra_model = model;

	pv_precache();

	// player Cobra vehicle info ( vehicles/cobra_pv ): faster nose turret with more depression, higher top speed
	maps\_cobra::main( model, "cobra_pv" );

	// cobra_pv is never placed in the map ( setup() spawns it ), so its init thread is kept out of the
	// vehicle script's table until then: the developer check in _vehicle::generate_colmaps_vehicles()
	// asserts on registered vehicle types that have no script_vehicle in the map
	level.pv_cobra_init_thread = level.vehicleInitThread[ "cobra_pv" ][ model ];
	level.vehicleInitThread[ "cobra_pv" ] = undefined;

	// rotor wash: the stock tread table ( _treadfx.gsc ) only knows "cobra", any other type gets the
	// small tank tread puff
	maps\_treadfx::setallvehiclefx( "cobra_pv", "treadfx/heli_dust_default" );
	maps\_treadfx::setvehiclefx( "cobra_pv", "water", "treadfx/heli_water" );

	// The alpha's surface-to-air sites ( _vehicle_missile.gsc: SLAMRAAM, SA-6, ZPU with script_turret 1 )
	// wait for the difficulty that _cobrapilot.gsc used to ask for in its menu
	setdvar( "cobrapilot_difficulty", cobra_alpha_difficulty() );

	if ( getdvar( "cobrapilot_unlimited_ammo" ) == "" )
		setdvar( "cobrapilot_unlimited_ammo", "0" );
	if ( getdvar( "cobrapilot_gunner_enabled" ) == "" )
		setdvar( "cobrapilot_gunner_enabled", "1" );

	// flight model ( mph, mph per second, degrees per second )
	level.pv_cobra_speed_fwd = 115;
	level.pv_cobra_speed_back = 35;
	level.pv_cobra_speed_side = 45;
	level.pv_cobra_speed_climb = 30;
	level.pv_cobra_speed_descend = 26;
	level.pv_cobra_accel = 34;
	level.pv_cobra_decel = 30;
	level.pv_cobra_yaw_speed = 110;
	level.pv_cobra_ceiling_height = 6000;	// above the take off point

	// cameras: player link offsets in helicopter space ( the eye ends up 60 units higher )
	level.pv_cobra_chase_offset = ( -860, 0, 70 );
	level.pv_cobra_tads_offset = ( 250, 0, -205 );
	level.pv_cobra_default_view = "cockpit";

	level.pv_cobra_flares = 30;
	level.pv_cobra_health[ "easy" ] = 6000;
	level.pv_cobra_health[ "medium" ] = 4500;
	level.pv_cobra_health[ "hard" ] = 3200;
	level.pv_cobra_health[ "fu" ] = 2400;

	precacheModel( "cobra_interior_viewmodel" );
	precacheModel( "vehicle_cobra_helicopter_d" );
	precacheModel( "projectile_hellfire_missile" );
	precacheModel( "projectile_sidewinder_missile" );
	precacheModel( "body_complete_sp_cobra_pilot_desert_zack" );

	precacheShader( "reticle_center_cross" );
	precacheShader( "veh_centercircle" );
	precacheShader( "veh_movingcircle" );
	precacheShader( "veh_hud_hellfire" );
	precacheShader( "veh_hud_sidewinder" );
	precacheShader( "veh_hud_target" );
	precacheShader( "veh_hud_target_offscreen" );
	precacheShader( "veh_hud_target_lock" );
	precacheShader( "veh_hud_target_locking" );
	precacheShader( "veh_hud_target_invalid" );
	precacheShader( "veh_hud_target_invalid_offscreen" );
	precacheShader( "veh_hud_missile" );
	precacheShader( "veh_hud_missile_flash" );
	precacheShader( "veh_hud_missile_offscreen" );
	precacheShader( "veh_hud_missile_arrow_left" );
	precacheShader( "veh_hud_missile_arrow_right" );
	precacheShader( "veh_hud_missile_arrow_forward" );
	precacheShader( "veh_hud_missile_arrow_back" );
	precacheShader( "cobra_health" );
	precacheShader( "compass_waypoint_farp" );
	precacheShader( "overlay_low_health" );
	precacheShader( "ac130_overlay_25mm" );
	precacheShader( "ac130_overlay_grain" );

	precacheString( &"PLAYERVEHICLE_HINT_BOARD_COBRA" );
	precacheString( &"PLAYERVEHICLE_HINT_LAND_TO_EXIT" );
	precacheString( &"PLAYERVEHICLE_HINT_NO_ROOM_TO_EXIT" );
	precacheString( &"PLAYERVEHICLE_COBRA_TITLE" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_CYCLIC" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_STRAFE" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_COLLECTIVE" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_MOUSE" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_FIRE" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_WEAPON" );
	precacheString( &"PLAYERVEHICLE_HELP_ZOOM_TOGGLE" );
	precacheString( &"PLAYERVEHICLE_HELP_ZOOM_HOLD" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_FLARES" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_VIEW" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_THERMAL" );
	precacheString( &"PLAYERVEHICLE_HELP_COBRA_EXIT" );
	precacheString( &"PLAYERVEHICLE_HUD_KTS" );
	precacheString( &"PLAYERVEHICLE_HUD_FT" );
	precacheString( &"PLAYERVEHICLE_HUD_FLARES" );
	precacheString( &"PLAYERVEHICLE_HUD_LOCKING" );
	precacheString( &"PLAYERVEHICLE_HUD_LOCKED" );
	precacheString( &"PLAYERVEHICLE_HUD_PULL_UP" );
	precacheString( &"PLAYERVEHICLE_HUD_MISSILE" );
	precacheString( &"PLAYERVEHICLE_HUD_DAMAGE" );
	precacheString( &"PLAYERVEHICLE_HUD_REARMING" );
	precacheString( &"PLAYERVEHICLE_HUD_NO_FLARES" );
	precacheString( &"PLAYERVEHICLE_HUD_TADS" );
	precacheString( &"PLAYERVEHICLE_HUD_WHOT" );
	precacheString( &"PLAYERVEHICLE_HUD_BHOT" );
	precacheString( &"PLAYERVEHICLE_HUD_WFOV" );
	precacheString( &"PLAYERVEHICLE_HUD_NFOV" );
	precacheString( &"PLAYERVEHICLE_HUD_RANGE" );
	precacheString( &"PLAYERVEHICLE_HUD_GUNNER" );
	precacheString( &"COBRAPILOT_NO_AMMO" );
	precacheString( &"COBRAPILOT_EDGE_OF_WORLD_WARNING" );

	level._effect[ "pv_cobra_flares" ] = loadfx( "misc/flares_cobra" );
	level._effect[ "pv_cobra_smoke_light" ] = loadfx( "smoke/heli_engine_smolder" );
	level._effect[ "pv_cobra_smoke_heavy" ] = loadfx( "smoke/smoke_trail_black_heli" );
	level._effect[ "pv_cobra_fire" ] = loadfx( "fire/fire_smoke_trail_l" );
	level._effect[ "pv_cobra_explosion" ] = loadfx( "explosions/helicopter_explosion_cobra" );
	level._effect[ "pv_cobra_crash" ] = loadfx( "explosions/cobrapilot_vehicle_explosion" );

	precacheRumble( "defaultweapon_fire" );
	precacheRumble( "artillery_rumble" );

	// weapon loadout. The names / tags follow the alpha ( level.cobra_weapon_tags ).
	level.pv_cobra_weapon_defs = [];

	tags = [];
	tags[ 0 ] = "tag_flash";
	def = cobra_weapon_def( "cobra_20mm_pv", &"COBRAPILOT_20MM", "gun", 750, 0.065, tags );
	def.ammo_increment = 50;

	tags = [];
	tags[ 0 ] = "tag_store_r_2";
	tags[ 1 ] = "tag_store_l_2_a";
	def = cobra_weapon_def( "cobra_ffar_pv", &"COBRAPILOT_FFAR", "rocket", 38, 0.14, tags );
	def.ammo_increment = 4;

	tags = [];
	tags[ 0 ] = "tag_store_l_1_a";
	tags[ 1 ] = "tag_store_r_1_a";
	tags[ 2 ] = "tag_store_l_1_b";
	tags[ 3 ] = "tag_store_r_1_b";
	tags[ 4 ] = "tag_store_l_1_c";
	tags[ 5 ] = "tag_store_r_1_c";
	tags[ 6 ] = "tag_store_l_1_d";
	tags[ 7 ] = "tag_store_r_1_d";
	def = cobra_weapon_def( "cobra_hellfire_pv", &"COBRAPILOT_HELLFIRE", "ground", 8, 0.5, tags );
	def.single_shot = true;
	def.model = "projectile_hellfire_missile";
	def.lock_time = 1.5;
	def.lock_shader = "veh_hud_hellfire";
	def.lock_size = 180;

	tags = [];
	tags[ 0 ] = "tag_store_l_wing";
	tags[ 1 ] = "tag_store_r_wing";
	def = cobra_weapon_def( "cobra_sidewinder_pv", &"COBRAPILOT_SIDEWINDER", "air", 2, 1.0, tags );
	def.single_shot = true;
	def.model = "projectile_sidewinder_missile";
	def.lock_time = 2.5;
	def.lock_shader = "veh_hud_sidewinder";
	def.lock_size = 180;

	for ( i = 0; i < level.pv_cobra_weapon_defs.size; i++ )
	{
		precacheItem( level.pv_cobra_weapon_defs[ i ].weapon );
		precacheString( level.pv_cobra_weapon_defs[ i ].string );
	}
}

// the game difficulty in the alpha's terms ( easy / medium / hard / insane )
cobra_alpha_difficulty()
{
	switch ( getdifficulty() )
	{
		case "easy":
			return "easy";
		case "hard":
			return "hard";
		case "fu":
			return "insane";
		default:
			return "medium";
	}
}

cobra_weapon_def( weapon, string, type, max_ammo, interval, tags )
{
	def = spawnstruct();
	def.weapon = weapon;
	def.string = string;
	def.type = type;
	def.max_ammo = max_ammo;
	def.interval = interval;
	def.tags = tags;
	def.single_shot = false;
	def.ammo_increment = 1;
	def.lock_time = 0;
	def.lock_size = 0;
	def.index = level.pv_cobra_weapon_defs.size;
	level.pv_cobra_weapon_defs[ def.index ] = def;
	return def;
}

/*
=============
///ScriptDocBegin
"Name: setup( <vehicle> )"
"Summary: Turns a Cobra from the map into the player Cobra and returns it ( it may be a new entity ). Call after maps\_load::main()."
"Module: PlayerVehicle"
"MandatoryArg: <vehicle>: script_vehicle with a Cobra model"
"Example: cobra = maps\_playervehicle_cobra::setup( getent( "cobra_player", "targetname" ) );"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
setup( vehicle )
{
	pv_init();

	// let the vehicle system finish with the map vehicles first
	waittillframeend;

	if ( !isdefined( vehicle ) )
		vehicle = getent( "cobra_player", "targetname" );
	assertEx( isdefined( vehicle ), "maps\\_playervehicle_cobra::setup() - no Cobra ( script_vehicle targetname cobra_player )" );

	cobra = cobra_replace_vehicle( vehicle );
	cobra cobra_setup_vehicle();
	level.pv_cobra = cobra;
	return cobra;
}

// Swaps a map Cobra for one using the "cobra_pv" vehicle info, the same way the vehicle spawners
// in _vehicle.gsc spawn their vehicles.
cobra_replace_vehicle( old )
{
	if ( old.vehicletype == "cobra_pv" )
		return old;

	origin = old.origin;
	angles = old.angles;
	model = old.model;
	targetname = old.targetname;
	if ( !isdefined( targetname ) )
		targetname = "cobra_player";

	old notify( "stop_vehicle_wait" );
	old notify( "nodeath_thread" );
	if ( isdefined( old.script_team ) && isdefined( level.vehicles[ old.script_team ] ) )
		level.vehicles[ old.script_team ] = array_remove( level.vehicles[ old.script_team ], old );
	if ( isdefined( old.targetname ) && isdefined( level.vehicle_target ) && isdefined( level.vehicle_target[ old.targetname ] ) )
		level.vehicle_target[ old.targetname ] = array_remove( level.vehicle_target[ old.targetname ], old );
	old delete();

	level.helicopter_list[ "cobra_pv" ] = true;
	if ( !isdefined( level.vehicleInitThread[ "cobra_pv" ] ) )
		level.vehicleInitThread[ "cobra_pv" ] = [];
	level.vehicleInitThread[ "cobra_pv" ][ model ] = level.pv_cobra_init_thread;

	cobra = spawnVehicle( model, targetname, "cobra_pv", origin, angles );
	cobra.vehicletype = "cobra_pv";
	cobra.script_team = "allies";
	maps\_vehicle::vehicle_init( cobra );
	return cobra;
}

cobra_setup_vehicle()
{
	// the player Cobra handles its own health, death and turret
	self notify( "stop_vehicle_wait" );
	self notify( "stop_friendlyfire_shield" );
	self notify( "nodeath_thread" );
	self makevehicleunusable();
	self.health = 100000;
	self.incomming_Missiles = [];

	self.pv = spawnstruct();
	self.pv.hp_max = cobra_difficulty_health();
	self.pv.hp = self.pv.hp_max;
	self.pv.view = level.pv_cobra_default_view;
	self.pv.weapon = 0;
	self.pv.ammo = [];
	self.pv.next_tag = [];
	for ( i = 0; i < level.pv_cobra_weapon_defs.size; i++ )
	{
		self.pv.ammo[ i ] = level.pv_cobra_weapon_defs[ i ].max_ammo;
		self.pv.next_tag[ i ] = 0;
	}
	self.pv.flares = level.pv_cobra_flares;
	self.pv.piloted = false;
	self.pv.landed = false;
	self.pv.hovering = false;
	self.pv.dead = false;
	self.pv.exit_allowed = true;
	self.pv.thermal_inverted = false;
	self.pv.velocity = ( 0, 0, 0 );
	self.pv.agl = 0;
	skids = self gettagorigin( "tag_ground" );
	self.pv.ground_offset = self.origin[ 2 ] - skids[ 2 ];
	self.pv.next_bump_time = 0;
	self.pv.goal_speed = -1;
	self.pv.goal_stop = false;
	self.pv.ceiling = self.origin[ 2 ] + level.pv_cobra_ceiling_height;
	self.pv.target_yaw = self.angles[ 1 ];
	self.pv.next_fire_time = 0;
	self.pv.last_gun_shot = 0;
	self.pv.gun_sound_on = false;
	self.pv.next_flare_time = 0;
	self.pv.damage_state = 0;
	self.pv.help_shown = false;
	self.pv.gunner_has_turret = false;
	self.pv.targets = [];
	self.pv_damage_func = ::cobra_damage;
	self.pv_credit_player = true;

	self cobra_crew_spawn();
	self cobra_refresh_stores();
	self thread maps\_vehicle::lights_on( "running" );
	self thread cobra_damage_monitor();
	self thread cobra_incoming_missile_monitor();
	self thread cobra_gunner_think();
	self thread cobra_parked();

	pv_register_vehicle( self, &"PLAYERVEHICLE_HINT_BOARD_COBRA", ::cobra_enter, 210, "tag_player" );
}

cobra_difficulty_health()
{
	skill = getdifficulty();
	if ( isdefined( level.pv_cobra_health[ skill ] ) )
		return level.pv_cobra_health[ skill ];
	return level.pv_cobra_health[ "medium" ];
}

/******************************************************/
/*                     PUBLIC API                     */
/******************************************************/

// put the player straight into the pilot seat ( mission starts in the air etc. )
player_enter( cobra )
{
	if ( !isdefined( cobra ) )
		cobra = level.pv_cobra;
	cobra cobra_enter();
}

set_exit_allowed( cobra, allowed )
{
	cobra.pv.exit_allowed = allowed;
}

set_boarding_enabled( cobra, enabled )
{
	pv_set_boardable( cobra, enabled );
}

// custom lock-on target ( SAM site, building ... ): <type> "ground" or "air"
add_target( ent, type, offset )
{
	if ( !isdefined( level.pv_cobra_custom_targets ) )
		level.pv_cobra_custom_targets = [];
	if ( !isdefined( offset ) )
		offset = ( 0, 0, 0 );
	ent.pv_target_type = type;
	ent.pv_target_offset = offset;
	level.pv_cobra_custom_targets = array_add( level.pv_cobra_custom_targets, ent );
}

remove_target( ent )
{
	if ( isdefined( level.pv_cobra_custom_targets ) )
		level.pv_cobra_custom_targets = array_remove( level.pv_cobra_custom_targets, ent );
}

// tell the Cobra a missile is homing on it ( same as cobra notify( "incomming_missile", missile ) )
incoming_missile( cobra, missile )
{
	cobra notify( "incomming_missile", missile );
}

/******************************************************/
/*                    ENTER / EXIT                    */
/******************************************************/

cobra_enter()
{
	if ( isdefined( level.pv_active ) || self.pv.dead )
		return;

	self notify( "pv_boarded" );
	pv_player_enter( self );
	pv_fade_out( 0.25 );

	self.pv.piloted = true;
	self.pv.weapon_changed = true;
	self cobra_hud_create();
	self cobra_set_view( self.pv.view );

	self thread cobra_flight_think();
	self thread cobra_camera_think();
	self thread cobra_aim_think();
	self thread cobra_weapons_think();
	self thread cobra_input_think();
	self thread cobra_targets_think();
	self thread cobra_warnings_think();
	self thread cobra_hud_think();
	self thread cobra_rearm_think();
	self thread cobra_edge_of_world();
	self thread cobra_player_death_cleanup();

	level.player playlocalsound( "ui_screen_trans_in" );
	level notify( "pv_cobra_boarded", self );

	pv_fade_in( 0.35 );
	level.pv_transition = undefined;

	if ( !self.pv.help_shown )
	{
		self.pv.help_shown = true;
		thread pv_show_help( &"PLAYERVEHICLE_COBRA_TITLE", cobra_help_lines(), 12 );
	}
}

cobra_help_lines()
{
	lines = [];
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_CYCLIC";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_STRAFE";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_COLLECTIVE";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_MOUSE";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_FIRE";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_WEAPON";
	if ( pv_ads_is_toggle() )
		lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ZOOM_TOGGLE";
	else
		lines[ lines.size ] = &"PLAYERVEHICLE_HELP_ZOOM_HOLD";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_FLARES";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_VIEW";
	lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_THERMAL";
	if ( self.pv.exit_allowed )
		lines[ lines.size ] = &"PLAYERVEHICLE_HELP_COBRA_EXIT";
	return lines;
}

cobra_try_exit()
{
	if ( !self.pv.exit_allowed || isdefined( level.pv_transition ) )
		return;

	if ( !self.pv.landed )
	{
		if ( self.pv.agl > 40 || length( self.pv.velocity ) > 120 )
		{
			self cobra_hud_message( &"PLAYERVEHICLE_HINT_LAND_TO_EXIT" );
			return;
		}
	}

	pos = self cobra_exit_position();
	if ( !isdefined( pos ) )
	{
		self cobra_hud_message( &"PLAYERVEHICLE_HINT_NO_ROOM_TO_EXIT" );
		return;
	}

	self thread cobra_exit( pos );
}

cobra_exit( pos )
{
	level.pv_transition = true;
	pv_fade_out( 0.25 );

	self notify( "pv_exit" );
	self cobra_shutdown_cockpit();

	level.player setorigin( pos );
	level.player setplayerangles( ( 0, vectortoangles( self gettagorigin( "tag_player" ) - pos )[ 1 ], 0 ) );

	pv_player_exit();
	level notify( "pv_cobra_exited", self );
	self thread cobra_parked();

	pv_fade_in( 0.35 );
	level.pv_transition = undefined;
}

// everything that has to go when the pilot leaves ( exit, death of the player )
cobra_shutdown_cockpit()
{
	pv_help_destroy();
	self cobra_targets_clear();
	self cobra_missile_warnings_clear();

	level.player unlink();
	if ( isdefined( self.pv.cam ) )
		self.pv.cam delete();
	if ( isdefined( self.pv.aim_ent ) )
		self.pv.aim_ent delete();

	self cobra_set_thermal( false );
	pv_hud_destroy_all();
	self.pv.hud = undefined;

	level.player stoploopsound();
	self.pv.piloted = false;

	if ( !self.pv.dead )
	{
		self setmodel( level.pv_cobra_model );
		self cobra_relink_crew();
		self cobra_refresh_stores();
		self clearturrettarget();
	}
}

// standing spot next to the cockpit with ground close under the skids ( undefined when there is none )
cobra_exit_position()
{
	right = anglestoright( ( 0, self.angles[ 1 ], 0 ) );
	forward = anglestoforward( ( 0, self.angles[ 1 ], 0 ) );
	cockpit = self gettagorigin( "tag_player" );
	skids = self.origin[ 2 ] - self.pv.ground_offset;

	// left side first ( pilot door side ), then right, then further out, then in front of the nose
	sides = [];
	sides[ 0 ] = vectorScale( right, -150 );
	sides[ 1 ] = vectorScale( right, 150 );
	sides[ 2 ] = vectorScale( right, -240 );
	sides[ 3 ] = vectorScale( right, 240 );
	sides[ 4 ] = vectorScale( forward, 400 );

	for ( i = 0; i < sides.size; i++ )
	{
		spot = cockpit + sides[ i ];
		if ( !bullettracepassed( cockpit, spot, false, self ) )
			continue;
		ground = pv_ground_z( spot + ( 0, 0, 64 ), self );
		if ( !isdefined( ground ) || abs( ground - skids ) > 80 )
			continue;
		top = ( spot[ 0 ], spot[ 1 ], ground + 64 );
		pos = playerphysicstrace( top, ( spot[ 0 ], spot[ 1 ], ground - 16 ) );
		if ( distancesquared( pos, top ) < 1 )
			continue;	// stuck in something
		return pos;
	}
	return undefined;
}

cobra_player_death_cleanup()
{
	self endon( "pv_exit" );
	self endon( "death" );

	level.player waittill( "death" );
	setsaveddvar( "cg_fov", "65" );
	self cobra_set_thermal( false );
}

/******************************************************/
/*                       VIEWS                        */
/******************************************************/

cobra_cycle_view()
{
	switch ( self.pv.view )
	{
		case "cockpit":
			self cobra_set_view( "chase" );
			break;
		case "chase":
			self cobra_set_view( "gunner" );
			break;
		default:
			self cobra_set_view( "cockpit" );
			break;
	}
	level.player playlocalsound( "ui_camera_whoosh_in" );
}

cobra_set_view( view )
{
	self.pv.view = view;

	level.player unlink();
	if ( isdefined( self.pv.cam ) )
		self.pv.cam delete();

	// the interior model shares the skeleton of the flying model, so the swap is seamless
	if ( view == "cockpit" )
		self setmodel( "cobra_interior_viewmodel" );
	else
		self setmodel( level.pv_cobra_model );

	// tags are looked up again after a model swap
	self cobra_relink_crew();
	self cobra_refresh_stores();

	switch ( view )
	{
		case "cockpit":
			self.pv.cam_offset = self cobra_cockpit_offset();
			self.pv.cam = pv_camera_rig( self, "tag_player", self.pv.cam_offset, ( 0, 0, 0 ) );
			level.player playerlinkto( self.pv.cam, "tag_origin", 0, 135, 135, 55, 65 );
			break;
		case "chase":
			self.pv.cam_offset = self cobra_camera_offset( view, 1 );
			self.pv.cam = pv_camera_rig( self, "tag_origin", self.pv.cam_offset, ( 0, 0, 0 ) );
			level.player playerlinkto( self.pv.cam, "tag_origin", 0, 180, 180, 70, 75 );
			break;
		default:
			self.pv.cam_offset = self cobra_camera_offset( view, 1 );
			self.pv.cam = pv_camera_rig( self, "tag_origin", self.pv.cam_offset, ( 0, 0, 0 ) );
			level.player playerlinkto( self.pv.cam, "tag_origin", 0, 110, 110, 20, 75 );
			break;
	}
	if ( view != "cockpit" )
		self.pv.cam_fraction = self.pv.cam_fraction_wanted;

	if ( view == "gunner" )
		level.player setplayerangles( ( 12, self.angles[ 1 ], 0 ) );
	else
		level.player setplayerangles( ( 4, self.angles[ 1 ], 0 ) );
	self.pv.target_yaw = self.angles[ 1 ];

	self cobra_set_thermal( view == "gunner" );
	self cobra_apply_fov();
	self cobra_hud_set_view();
}

// Link offset of the outside cameras, in helicopter space. The chase camera stays level behind the
// helicopter ( linked rigidly, the airframe's pitch would swing it 250 units up and down ), and both
// cameras are pulled in towards the helicopter when something is in the way. <fraction> is how much of
// the way out the camera may go.
cobra_camera_offset( view, fraction )
{
	if ( view == "chase" )
	{
		heading = ( 0, self.angles[ 1 ], 0 );
		offset = level.pv_cobra_chase_offset;
		world = vectorScale( anglestoforward( heading ), offset[ 0 ] ) - vectorScale( anglestoright( heading ), offset[ 1 ] ) + ( 0, 0, offset[ 2 ] );
	}
	else
	{
		// the sensor turret under the nose moves with the airframe
		offset = level.pv_cobra_tads_offset;
		world = vectorScale( anglestoforward( self.angles ), offset[ 0 ] ) - vectorScale( anglestoright( self.angles ), offset[ 1 ] ) + vectorScale( anglestoup( self.angles ), offset[ 2 ] );
	}

	// the player's eye sits 60 units above the link point
	pivot = self.origin + ( 0, 0, 100 );
	eye = self.origin + world + ( 0, 0, 60 );
	delta = eye - pivot;
	dist = length( delta );
	if ( dist > 1 )
	{
		dir = vectorScale( delta, 1 / dist );
		trace = self cobra_trace_hit( pivot, dir, dist + 32 );
		if ( isdefined( trace ) )
			fraction = pv_min( fraction, pv_max( 0.1, ( distance( pivot, trace[ "position" ] ) - 32 ) / dist ) );
		eye = pivot + vectorScale( delta, fraction );
	}
	self.pv.cam_fraction_wanted = fraction;

	rig = eye - ( 0, 0, 60 ) - self.origin;
	return ( vectordot( rig, anglestoforward( self.angles ) ), -1 * vectordot( rig, anglestoright( self.angles ) ), vectordot( rig, anglestoup( self.angles ) ) );
}

// The player's eye sits 60 units above the link point along the world up axis, while the seat tilts with
// the airframe: the link point is moved so the eye stays 60 units up the seat's own axis ( otherwise the
// bank of a sideslip puts the pilot's head through the canopy )
cobra_cockpit_offset()
{
	angles = self gettagangles( "tag_player" );
	up = ( 0, 0, 1 );
	return ( -60 * vectordot( up, anglestoforward( angles ) ), 60 * vectordot( up, anglestoright( angles ) ), 60 - 60 * vectordot( up, anglestoup( angles ) ) );
}

// keeps the cameras where they belong while the helicopter pitches and rolls: the pilot's head on his
// seat, the outside cameras level and out of walls ( relinks the camera rig when its offset changes )
cobra_camera_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	for ( ;; )
	{
		wait 0.05;
		if ( !isdefined( self.pv.cam ) )
			continue;

		if ( self.pv.view == "cockpit" )
		{
			offset = self cobra_cockpit_offset();
			tag = "tag_player";
		}
		else
		{
			// snap in at once when something gets in the way, ease back out afterwards
			offset = self cobra_camera_offset( self.pv.view, 1 );
			wanted = self.pv.cam_fraction_wanted;
			if ( wanted > self.pv.cam_fraction + 0.04 )
				offset = self cobra_camera_offset( self.pv.view, self.pv.cam_fraction + 0.04 );
			self.pv.cam_fraction = self.pv.cam_fraction_wanted;
			tag = "tag_origin";
		}

		if ( distancesquared( offset, self.pv.cam_offset ) < 0.25 )
			continue;
		self.pv.cam_offset = offset;
		self.pv.cam unlink();
		self.pv.cam linkto( self, tag, offset, ( 0, 0, 0 ) );
	}
}

cobra_apply_fov()
{
	zoom = pv_button_held( "ads" );
	switch ( self.pv.view )
	{
		case "cockpit":
			if ( zoom )
				pv_set_fov( 35 );
			else
				pv_set_fov( 72 );
			break;
		case "chase":
			if ( zoom )
				pv_set_fov( 40 );
			else
				pv_set_fov( 70 );
			break;
		default:
			if ( zoom )
				pv_set_fov( 12 );
			else
				pv_set_fov( 42 );
			break;
	}
}

cobra_set_thermal( enable )
{
	if ( enable )
	{
		if ( self.pv.thermal_inverted )
			visionSetNaked( "ac130_inverted", 0.25 );
		else
			visionSetNaked( "ac130", 0.25 );
		self.pv.thermal = true;
		return;
	}

	if ( isdefined( self.pv.thermal ) && self.pv.thermal )
	{
		if ( isdefined( level.lvl_visionset ) )
			visionSetNaked( level.lvl_visionset, 0.25 );
		else
			visionSetNaked( "default", 0.25 );
	}
	self.pv.thermal = false;
}

cobra_toggle_thermal()
{
	if ( self.pv.view != "gunner" )
		return;

	self.pv.thermal_inverted = !self.pv.thermal_inverted;
	self cobra_set_thermal( true );

	if ( self.pv.thermal_inverted )
		level.player playlocalsound( "item_nightvision_on" );
	else
		level.player playlocalsound( "item_nightvision_off" );
	self cobra_hud_set_view();
}

/******************************************************/
/*                       FLIGHT                       */
/******************************************************/

cobra_parked()
{
	self endon( "death" );
	self endon( "pv_boarded" );

	waittillframeend;
	if ( self.pv.dead )
		return;

	self setspeed( 20, 15, 15 );
	ground = self cobra_ground_z();
	if ( isdefined( ground ) && ( self.origin[ 2 ] - self.pv.ground_offset - ground ) < 120 )
		self cobra_land( ground );
	else
		self setvehgoalpos( self.origin, 1 );
}

cobra_land( ground )
{
	self.pv.landed = true;
	self.pv.hovering = true;
	self setmaxpitchroll( 0, 0 );
	self setjitterparams( ( 0, 0, 0 ), 1, 1 );
	self sethoverparams( 0, 0, 0 );
	self setspeed( 12, 10, 10 );
	self.pv.target_yaw = self.angles[ 1 ];
	self settargetyaw( self.pv.target_yaw );
	self setgoalyaw( self.pv.target_yaw );
	self setvehgoalpos( ( self.origin[ 0 ], self.origin[ 1 ], ground + self.pv.ground_offset ), 1 );
	self notify( "pv_landed" );
}

cobra_takeoff()
{
	self.pv.landed = false;
	self.pv.hovering = false;
	self setmaxpitchroll( 18, 32 );
	self setjitterparams( ( 3, 3, 3 ), 0.5, 1.5 );
	self notify( "pv_takeoff" );
}

cobra_flight_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	self setyawspeed( level.pv_cobra_yaw_speed, level.pv_cobra_yaw_speed * 2, level.pv_cobra_yaw_speed * 2 );
	if ( !self.pv.landed )
	{
		self setmaxpitchroll( 18, 32 );
		self setjitterparams( ( 3, 3, 3 ), 0.5, 1.5 );
	}

	self.pv.target_yaw = self.angles[ 1 ];
	self settargetyaw( self.pv.target_yaw );
	self setgoalyaw( self.pv.target_yaw );

	last_origin = self.origin;
	self.pv.goal_speed = -1;
	self.pv.goal = undefined;
	self.pv.goal_stop = false;
	ground = self cobra_ground_z();
	if ( !isdefined( ground ) )
		ground = self.origin[ 2 ] - self.pv.ground_offset - 500;

	// boarded in the air ( parked on its goal, frozen ): settle on a fresh hover goal so the nose turns
	if ( !self.pv.landed )
		self cobra_hover( ground );

	for ( ;; )
	{
		wait 0.05;

		self.pv.velocity = vectorScale( self.origin - last_origin, 20 );
		last_origin = self.origin;

		new_ground = self cobra_ground_z();
		if ( isdefined( new_ground ) )
			ground = new_ground;
		self.pv.ground = ground;
		self.pv.agl = self.origin[ 2 ] - self.pv.ground_offset - ground;

		// pedals: the nose follows the view ( gunner camera only turns the helicopter at the gimbal limit ),
		// except on the ground. The vehicle code only turns a helicopter towards its target yaw while it
		// travels; sitting on its goal it turns to the goal yaw, so both are kept the same.
		if ( !self.pv.landed )
		{
			yaw = self cobra_desired_yaw();
			if ( abs( pv_angle_diff( yaw, self.pv.target_yaw ) ) > 0.25 )
			{
				self.pv.target_yaw = yaw;
				self settargetyaw( yaw );
				self setgoalyaw( yaw );
			}
		}

		move = level.player getnormalizedmovement();
		climb = 0;
		if ( pv_button_held( "up" ) )
			climb += 1;
		if ( pv_button_held( "down" ) )
			climb -= 1;

		if ( self.pv.landed )
		{
			if ( climb <= 0 )
				continue;
			self cobra_takeoff();
			self.pv.goal_speed = -1;
		}

		// cyclic / collective -> desired velocity in mph
		if ( move[ 0 ] >= 0 )
			speed_fwd = move[ 0 ] * level.pv_cobra_speed_fwd;
		else
			speed_fwd = move[ 0 ] * level.pv_cobra_speed_back;
		speed_side = move[ 1 ] * level.pv_cobra_speed_side;

		if ( climb > 0 )
			speed_vert = level.pv_cobra_speed_climb;
		else if ( climb < 0 )
			speed_vert = -1 * level.pv_cobra_speed_descend;
		else
			speed_vert = 0;

		// the descent ends on a stop goal at skid height ( cobra_fly ), then the helicopter settles
		if ( speed_vert < 0 && self.pv.agl < 10 && length( ( speed_fwd, speed_side, 0 ) ) < 1 )
		{
			self cobra_land( ground );
			self.pv.goal_speed = -1;
			continue;
		}

		heading = ( 0, self.angles[ 1 ], 0 );
		horizontal = vectorScale( anglestoforward( heading ), speed_fwd ) + vectorScale( anglestoright( heading ), speed_side );
		self cobra_fly( horizontal, speed_vert, ground );
	}
}

// Turns the stick into a goal for the vehicle code. Lowering the speed only brakes at <new speed> mph
// per second, but a goal with the stop flag is always reached exactly ( the vehicle code brakes as hard
// as it has to ), so walls, the sky box and overhangs are handled with stop goals placed in front of them.
// Ground that rises ahead is climbed over instead ( cobra_terrain_follow ).
cobra_fly( horizontal, speed_vert, ground )
{
	velocity = self.pv.velocity;
	min_z = ground + self.pv.ground_offset + 2;

	// never coast into something, whatever the stick says ( drifting after a turn, a ridge taken too fast );
	// the stick takes over again once the helicopter can stop in time on its own
	emergency = self cobra_emergency_stop( velocity );
	if ( isdefined( emergency ) )
	{
		if ( !isdefined( self.pv.goal ) || !self.pv.goal_stop || distancesquared( emergency, self.pv.goal ) > 36 )
			self cobra_goal( emergency, pv_max( 10, length( velocity ) / 17.6 ), true, min_z );
		return;
	}

	stop = false;
	h_goal = ( 0, 0, 0 );
	h_speed = length( horizontal );
	if ( h_speed > 0.5 )
	{
		dir = vectorScale( horizontal, 1 / h_speed );
		need = cobra_stop_distance( pv_max( h_speed * 17.6, vectordot( velocity, dir ) ) ) + 80;
		room = self cobra_room( dir, need, false );
		if ( room <= 4 )
		{
			horizontal = ( 0, 0, 0 );
		}
		else if ( room <= need )
		{
			stop = true;
			h_goal = vectorScale( dir, room );
		}
		else
		{
			h_goal = vectorScale( dir, cobra_stop_distance( h_speed * 17.6 ) + h_speed * 17.6 );
		}
	}

	v_goal = 0;
	if ( speed_vert > 0 )
	{
		need = cobra_stop_distance( pv_max( speed_vert * 17.6, velocity[ 2 ] ) ) + 40;
		room = self cobra_room_up( need );
		if ( room <= 4 )
		{
			speed_vert = 0;
		}
		else if ( room <= need )
		{
			stop = true;
			v_goal = room;
		}
		else
		{
			v_goal = cobra_stop_distance( speed_vert * 17.6 ) + speed_vert * 17.6;
		}
	}
	else if ( speed_vert < 0 )
	{
		// close to the ground the descent becomes a stop goal at skid height: the flare
		sink = pv_max( speed_vert * -17.6, -1 * velocity[ 2 ] );
		drop = self.origin[ 2 ] - min_z;
		if ( drop <= cobra_stop_distance( sink ) + 60 )
		{
			stop = true;
			v_goal = -1 * pv_max( drop, 0 );
		}
		else
		{
			v_goal = -1 * ( cobra_stop_distance( speed_vert * -17.6 ) + speed_vert * -17.6 );
		}
	}

	desired = horizontal + ( 0, 0, speed_vert );
	speed = length( desired );

	if ( stop )
	{
		self cobra_goal( self.origin + h_goal + ( 0, 0, v_goal ), pv_max( 10, pv_max( speed, length( velocity ) / 17.6 ) ), true, min_z );
		return;
	}

	if ( speed > 1 )
	{
		goal = self.origin + vectorScale( vectornormalize( desired ), 1500 );
		goal = self cobra_terrain_follow( goal, horizontal, velocity );
		self cobra_goal( goal, speed, false, min_z );
		return;
	}

	if ( !self.pv.hovering )
		self cobra_hover( ground );
}

cobra_goal( goal, speed, stop, min_z )
{
	if ( goal[ 2 ] < min_z )
		goal = ( goal[ 0 ], goal[ 1 ], min_z );
	if ( goal[ 2 ] > self.pv.ceiling )
		goal = ( goal[ 0 ], goal[ 1 ], pv_max( self.pv.ceiling, self.origin[ 2 ] ) );
	if ( stop )
		goal = self cobra_safe_stop_goal( goal );

	if ( abs( speed - self.pv.goal_speed ) > 0.5 )
	{
		self cobra_set_speed( speed );
		self.pv.goal_speed = speed;
	}

	// a stop goal that has not moved is left alone so the vehicle code keeps its braking curve
	if ( stop && isdefined( self.pv.goal ) && self.pv.goal_stop && distancesquared( goal, self.pv.goal ) < 36 )
		return;

	self setvehgoalpos( goal, stop );
	self.pv.goal = goal;
	self.pv.goal_stop = stop;
	self.pv.hovering = false;
}

// brake to a hover at the natural stopping point ( or in front of whatever is in the way ). Never
// re-issued while hovering, otherwise the vehicle code freezes the helicopter ( including its yaw ) on its goal
cobra_hover( ground )
{
	self.pv.hovering = true;

	velocity = self.pv.velocity;
	speed = length( velocity );
	goal = self.origin;
	if ( speed > 20 )
	{
		dist = cobra_stop_distance( speed );
		dir = vectorScale( velocity, 1 / speed );

		// sinking is stopped by the ground clamp below, so only the level part is checked then
		check = dir;
		if ( check[ 2 ] < 0 )
			check = ( check[ 0 ], check[ 1 ], 0 );
		check_len = length( check );
		if ( check_len > 0.2 )
		{
			room = self cobra_room( vectorScale( check, 1 / check_len ), dist * check_len, true );
			if ( room < dist * check_len )
				dist = pv_max( room, 4 ) / check_len;
		}
		goal = self.origin + vectorScale( dir, dist );
	}

	min_z = ground + self.pv.ground_offset + 2;
	if ( goal[ 2 ] < min_z )
		goal = ( goal[ 0 ], goal[ 1 ], min_z );
	if ( goal[ 2 ] > self.pv.ceiling )
		goal = ( goal[ 0 ], goal[ 1 ], pv_max( self.pv.ceiling, self.origin[ 2 ] ) );
	goal = self cobra_safe_stop_goal( goal );

	self.pv.goal_speed = pv_max( 10, speed / 17.6 );
	self cobra_set_speed( self.pv.goal_speed );

	// re-issuing a goal the helicopter already sits on would freeze it
	if ( isdefined( self.pv.goal ) && self.pv.goal_stop && distancesquared( goal, self.pv.goal ) < 1 )
		return;
	self setvehgoalpos( goal, 1 );
	self.pv.goal = goal;
	self.pv.goal_stop = true;
}

// A stop goal right on top of the helicopter freezes it in the vehicle code, yaw included. Keep the
// current stop goal when the helicopter is settling on it anyway, otherwise settle a few units on.
cobra_safe_stop_goal( goal )
{
	if ( distancesquared( goal, self.origin ) >= 16 )
		return goal;
	if ( isdefined( self.pv.goal ) && self.pv.goal_stop && distancesquared( self.pv.goal, self.origin ) < 4096 )
		return self.pv.goal;

	dir = ( 0, 0, 1 );
	if ( lengthsquared( self.pv.velocity ) > 1 )
		dir = vectornormalize( self.pv.velocity );
	return self.origin + vectorScale( dir, 8 );
}

cobra_desired_yaw()
{
	view = level.player getplayerangles();
	view_yaw = view[ 1 ];

	if ( self.pv.view != "gunner" )
		return view_yaw;

	// gunner camera: the nose only follows when the sensor reaches the gimbal limit
	limit = 50;
	rel = pv_angle_diff( view_yaw, self.angles[ 1 ] );
	if ( rel > limit )
		return view_yaw - limit;
	if ( rel < -1 * limit )
		return view_yaw + limit;
	return self.pv.target_yaw;
}

// distance needed to stop from <speed> ( units per second ) at the normal deceleration
cobra_stop_distance( speed )
{
	return ( speed * speed ) / ( 2 * level.pv_cobra_decel * 17.6 );
}

// How far the airframe reaches out from its origin in direction <dir>, plus a safety margin: the main
// rotor disc ( radius 290 ) and the fuselage from the nose ( 330 ) to the tail rotor ( 520 )
cobra_clearance( dir )
{
	f = vectordot( dir, anglestoforward( self.angles ) );
	u = vectordot( dir, anglestoup( self.angles ) );

	if ( f > 0 )
		reach = pv_max( 290, f * 330 );
	else
		reach = pv_max( 290, f * -520 );
	reach = reach * sqrt( pv_max( 0, 1 - u * u ) );
	if ( u > 0 )
		reach += u * 100;
	else
		reach += u * -1 * self.pv.ground_offset;
	return reach + 100;
}

// How far the helicopter can still move along <dir> before its safety margin touches something; a big
// number when nothing is within <need>. Ground below the skids never counts ( landing ), ground rising
// above them only counts when <terrain_blocks> is set: the stick direction leaves it to the terrain
// following, the emergency check does not.
cobra_room( dir, need, terrain_blocks )
{
	clearance = self cobra_clearance( dir );
	look = need + clearance + 200;
	center = self.origin + ( 0, 0, 40 );

	side = ( dir[ 1 ], -1 * dir[ 0 ], 0 );
	if ( lengthsquared( side ) < 0.01 )
		side = anglestoright( self.angles );
	side = vectorScale( vectornormalize( side ), 240 );

	// the outer rays run past the rotor tips, which only reach 160 units ahead of them
	starts = [];
	reach = [];
	starts[ 0 ] = center;
	reach[ 0 ] = clearance;
	starts[ 1 ] = self cobra_trace_start( center, center + side );
	reach[ 1 ] = 260;
	starts[ 2 ] = self cobra_trace_start( center, center - side );
	reach[ 2 ] = 260;
	starts[ 3 ] = self cobra_trace_start( center, self.origin - ( 0, 0, self.pv.ground_offset * 0.7 ) );
	reach[ 3 ] = clearance;

	skids = self.origin[ 2 ] - self.pv.ground_offset;
	room = look;
	for ( i = 0; i < starts.size; i++ )
	{
		trace = self cobra_trace_hit( starts[ i ], dir, look );
		if ( !isdefined( trace ) )
			continue;
		if ( trace[ "normal" ][ 2 ] > 0.7 && ( !terrain_blocks || trace[ "position" ][ 2 ] < skids + 24 ) )
			continue;
		room = pv_min( room, distance( starts[ i ], trace[ "position" ] ) - reach[ i ] );
	}
	return room;
}

// room to climb: overhangs above the rotor and the mission ceiling
cobra_room_up( need )
{
	clearance = 130;
	look = need + clearance + 200;
	center = self.origin + ( 0, 0, 40 );
	side = vectorScale( anglestoright( ( 0, self.angles[ 1 ], 0 ) ), 220 );

	starts = [];
	starts[ 0 ] = center;
	starts[ 1 ] = self cobra_trace_start( center, center + side );
	starts[ 2 ] = self cobra_trace_start( center, center - side );

	room = look;
	for ( i = 0; i < starts.size; i++ )
	{
		hit = self cobra_trace_past_self( starts[ i ], ( 0, 0, 1 ), look );
		if ( hit[ 2 ] - starts[ i ][ 2 ] < look )
			room = pv_min( room, hit[ 2 ] - starts[ i ][ 2 ] - clearance );
	}
	return pv_min( room, self.pv.ceiling - self.origin[ 2 ] );
}

// stopping point when the helicopter would not stop in time on its own; undefined while the way is clear
cobra_emergency_stop( velocity )
{
	// sinking onto the ground is the landing code's business
	if ( velocity[ 2 ] < 0 )
		velocity = ( velocity[ 0 ], velocity[ 1 ], 0 );

	speed = length( velocity );
	if ( speed < 90 )
		return undefined;

	dir = vectorScale( velocity, 1 / speed );
	need = cobra_stop_distance( speed ) + speed * 0.1;
	room = self cobra_room( dir, need, true );
	if ( room > need )
		return undefined;

	// already braking for a stop goal on this path, short of it: keep that one, the vehicle code always
	// stops on those ( a goal off to the side would still let the momentum carry it on )
	if ( isdefined( self.pv.goal ) && self.pv.goal_stop )
	{
		to_goal = self.pv.goal - self.origin;
		ahead = vectordot( to_goal, dir );
		if ( ahead > -1 && ahead <= room + 1 && lengthsquared( to_goal ) - ahead * ahead < 1024 )
			return self.pv.goal;
	}

	if ( speed > 300 )
		self.pv.collision_warning_time = gettime() + 1200;

	// a stop this hard is the rotor finding the wall
	if ( room < need * 0.4 && speed > 900 && gettime() > self.pv.next_bump_time )
	{
		self.pv.next_bump_time = gettime() + 1500;
		self thread cobra_damage( int( speed * 0.4 ), undefined, dir, self.origin, "MOD_CRUSH" );
		self joltbody( self.origin + vectorScale( dir, 200 ), 0.6 );
		earthquake( 0.5, 0.6, self.origin, 1000 );
	}
	// a stop goal much closer than the speed allows makes the vehicle code bounce back off it, so the
	// stop may eat into the safety margin rather than brake at more than three times the normal rate
	dist = pv_max( 4, pv_clamp( cobra_stop_distance( speed ) / 3, room, room + 80 ) );
	return self.origin + vectorScale( dir, dist );
}

// rising ground ahead: aim high enough that the straight line to the goal clears it
cobra_terrain_follow( goal, horizontal, velocity )
{
	// only while the stick asks for horizontal movement ( drifting is covered by cobra_emergency_stop )
	if ( lengthsquared( horizontal ) < 0.25 )
		return goal;
	dir = vectornormalize( horizontal );
	flat_velocity = ( velocity[ 0 ], velocity[ 1 ], 0 );

	speed = pv_max( length( flat_velocity ), length( horizontal ) * 17.6 );
	reach = 500 + speed * 1.6;

	// only look as far as the next wall ( past the edge of the sky box there is no ground to find )
	center = self.origin + ( 0, 0, 40 );
	wall = self cobra_trace_hit( center, dir, reach );
	if ( isdefined( wall ) && wall[ "normal" ][ 2 ] <= 0.7 )
		reach = distance( center, wall[ "position" ] ) - 60;

	// the ground probes start below whatever is overhead
	top = self cobra_trace_past_self( center, ( 0, 0, 1 ), 700 );
	start_z = top[ 2 ] - 20;

	// the first probe sits beyond the nose ( or the tail ), the helicopter is not ground
	nearest = self cobra_clearance( dir );
	if ( reach < nearest + 100 )
		return goal;

	clearance = self.pv.ground_offset + 90;
	slope = 0;
	for ( i = 0; i < 5; i++ )
	{
		d = nearest + ( reach - nearest ) * i / 4;
		point = self.origin + vectorScale( dir, d );
		ground = pv_ground_z( ( point[ 0 ], point[ 1 ], start_z ), self );
		if ( !isdefined( ground ) )
			continue;
		rise = ground + clearance - self.origin[ 2 ];
		if ( rise > 0 && rise / d > slope )
			slope = rise / d;
	}
	if ( slope <= 0 )
		return goal;

	flat = length( ( goal[ 0 ] - self.origin[ 0 ], goal[ 1 ] - self.origin[ 1 ], 0 ) );
	z = self.origin[ 2 ] + slope * flat;
	if ( z > goal[ 2 ] )
		goal = ( goal[ 0 ], goal[ 1 ], z );
	return goal;
}

/******************************************************/
/*                    AIM / WEAPONS                   */
/******************************************************/

cobra_aim_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	self.pv.aim_ent = spawn( "script_origin", self.origin );
	self.pv.next_bump_time = 0;

	for ( ;; )
	{
		eye = level.player geteye();
		dir = anglestoforward( level.player getplayerangles() );
		self.pv.aim_point = self cobra_trace_past_self( eye, dir, 30000 );
		self.pv.aim_range = distance( self gettagorigin( "tag_flash" ), self.pv.aim_point );
		self.pv.aim_ent.origin = self.pv.aim_point;

		if ( !self.pv.gunner_has_turret )
			self setturrettargetvec( self.pv.aim_point );

		wait 0.05;
	}
}

// Aim / obstacle traces. They never hit characters ( the ray starts at the player's own eye, inside
// his hitbox ) and any hit that falls inside the helicopter's own bounds is stepped over.
cobra_point_on_self( point )
{
	delta = point - self.origin;
	f = vectordot( delta, anglestoforward( self.angles ) );
	if ( f < -480 || f > 300 )
		return false;
	r = vectordot( delta, anglestoright( self.angles ) );
	if ( r < -175 || r > 175 )
		return false;
	u = vectordot( delta, anglestoup( self.angles ) );
	return ( u > -170 && u < 70 );
}

// first hit along the ray that is not part of this helicopter ( undefined when the ray is clear )
cobra_trace_hit( start, dir, length )
{
	end = start + vectorScale( dir, length );
	point = start;
	for ( i = 0; i < 6; i++ )
	{
		trace = bullettrace( point, end, false, self );
		if ( trace[ "fraction" ] >= 1 )
			return undefined;
		if ( !self cobra_point_on_self( trace[ "position" ] ) )
			return trace;
		point = trace[ "position" ] + vectorScale( dir, 8 );
	}
	return undefined;
}

// first point along the ray that is not part of this helicopter ( or the end of the ray )
cobra_trace_past_self( start, dir, length )
{
	trace = self cobra_trace_hit( start, dir, length );
	if ( !isdefined( trace ) )
		return start + vectorScale( dir, length );
	return trace[ "position" ];
}

// <to>, or the last free point on the way there from <from> ( trace starts must not be inside a wall )
cobra_trace_start( from, to )
{
	delta = to - from;
	dist = length( delta );
	if ( dist < 1 )
		return to;
	dir = vectorScale( delta, 1 / dist );
	trace = self cobra_trace_hit( from, dir, dist );
	if ( !isdefined( trace ) )
		return to;
	return trace[ "position" ] - vectorScale( dir, 8 );
}

// ground height under the helicopter, not counting the helicopter itself
cobra_ground_z()
{
	return pv_ground_z( self.origin, self );
}

// line of sight that ignores the helicopter's own collision ( targets themselves count as visible )
cobra_sight( from, to )
{
	dist = distance( from, to );
	if ( dist < 1 )
		return true;
	hit = self cobra_trace_past_self( from, vectornormalize( to - from ), dist );
	return ( distance( hit, to ) < 250 );
}

cobra_set_speed( speed )
{
	// the vehicle code clamps ( and warns about ) accelerations above the speed itself
	speed = pv_max( 1, speed );
	self setspeed( speed, pv_min( level.pv_cobra_accel, speed ), pv_min( level.pv_cobra_decel, speed ) );
}

cobra_weapons_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	latch = false;
	for ( ;; )
	{
		wait 0.05;

		if ( !level.player attackbuttonpressed() )
		{
			latch = false;
			continue;
		}

		def = level.pv_cobra_weapon_defs[ self.pv.weapon ];
		if ( def.single_shot && latch )
			continue;
		if ( gettime() < self.pv.next_fire_time )
			continue;

		latch = true;

		if ( self.pv.ammo[ def.index ] <= 0 && getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
		{
			self cobra_no_ammo();
			self.pv.next_fire_time = gettime() + 600;
			continue;
		}

		switch ( def.type )
		{
			case "gun":
				self cobra_fire_gun( def );
				break;
			case "rocket":
				self cobra_fire_rocket( def );
				break;
			default:
				self cobra_fire_missile( def );
				break;
		}

		if ( getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
			self.pv.ammo[ def.index ]--;
		self.pv.ammo_changed = true;

		// keep the real rate of fire across the 50 ms script frames, without a catch-up volley after a pause
		interval = int( def.interval * 1000 );
		if ( self.pv.next_fire_time < gettime() - interval )
			self.pv.next_fire_time = gettime();
		self.pv.next_fire_time += interval;
	}
}

cobra_fire_gun( def )
{
	self setvehweapon( def.weapon );
	self fireweapon( "tag_flash" );
	self cobra_gun_sound();
	level.player playrumbleonentity( "defaultweapon_fire" );
}

// The M197 is heard as a firing loop at its rate of fire while rounds go out ( a sound per round would
// stutter with the 20 Hz script frames ), then the echo of the last rounds when the burst ends
cobra_gun_sound()
{
	self.pv.last_gun_shot = gettime();
	if ( self.pv.gun_sound_on )
		return;
	self.pv.gun_sound_on = true;
	self thread cobra_gun_sound_burst();
}

cobra_gun_sound_burst()
{
	snd = spawn( "script_origin", self gettagorigin( "tag_flash" ) );
	snd linkto( self, "tag_flash", ( 0, 0, 0 ), ( 0, 0, 0 ) );
	snd playloopsound( "pv_cobra_20mm_loop" );

	while ( isdefined( self ) && gettime() - self.pv.last_gun_shot < 110 )
		wait 0.05;

	snd stoploopsound();
	snd playsound( "pv_cobra_20mm_tail" );
	if ( isdefined( self ) )
		self.pv.gun_sound_on = false;

	wait 3;
	snd delete();
}

cobra_fire_rocket( def )
{
	tag = def.tags[ self.pv.next_tag[ def.index ] ];
	self.pv.next_tag[ def.index ] = ( self.pv.next_tag[ def.index ] + 1 ) % def.tags.size;

	// aimed like the alpha's AI rockets: guided at the reticle point for a moment, then ballistic
	spread = self.pv.aim_range * 0.012;
	aim = spawn( "script_origin", self.pv.aim_point + ( randomfloatrange( -1 * spread, spread ), randomfloatrange( -1 * spread, spread ), randomfloatrange( -0.5 * spread, 0.5 * spread ) ) );

	self setvehweapon( def.weapon );
	missile = self fireweapon( tag, aim, ( 0, 0, 0 ) );
	if ( isdefined( missile ) )
		missile thread cobra_missile_lose_target( 0.15 );
	aim thread pv_delete_after( 0.3 );

	level.player playrumbleonentity( "artillery_rumble" );
	earthquake( 0.12, 0.25, level.player.origin, 300 );
}

cobra_missile_lose_target( delay )
{
	self endon( "death" );
	wait delay;
	self missile_settarget( undefined );
}

cobra_fire_missile( def )
{
	tag_index = def.max_ammo - self.pv.ammo[ def.index ];
	if ( tag_index < 0 || tag_index >= def.tags.size )
		tag_index = 0;
	tag = def.tags[ tag_index ];

	target = undefined;
	offset = ( 0, 0, 0 );
	if ( isdefined( self.pv.lock ) && self.pv.lock.locked && isdefined( self.pv.lock.ent ) )
	{
		target = self.pv.lock.ent;
		offset = self.pv.lock.offset;
	}
	else if ( def.type == "ground" )
	{
		// no lock: laser designate the reticle point
		target = spawn( "script_origin", self.pv.aim_point );
		target thread pv_delete_after( 12 );
	}

	self setvehweapon( def.weapon );
	if ( isdefined( target ) )
	{
		missile = self fireweapon( tag, target, offset );
		if ( isdefined( missile ) )
			target notify( "incomming_missile", missile );
	}
	else
	{
		self fireweapon( tag );
	}

	if ( isdefined( def.model ) && getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
		self cobra_detach_store( def.model, tag );

	level.player playrumbleonentity( "artillery_rumble" );
	earthquake( 0.18, 0.4, level.player.origin, 300 );
}

cobra_no_ammo()
{
	level.player playlocalsound( "weap_dryfire_smg_plr" );
	self cobra_hud_message( &"COBRAPILOT_NO_AMMO" );
}

cobra_select_weapon( dir )
{
	count = level.pv_cobra_weapon_defs.size;
	self.pv.weapon = ( self.pv.weapon + dir + count ) % count;
	self.pv.weapon_changed = true;
	self cobra_lock_clear();
	level.player playlocalsound( "ui_text_type" );
	self notify( "pv_weapon_changed" );
}

// hellfire / sidewinder models on the pylons, like the alpha's attachMissiles()
cobra_refresh_stores()
{
	self detachall();

	if ( isdefined( self.pv ) && self.pv.piloted && self.pv.view == "cockpit" )
		return;
	if ( isdefined( self.pv ) && self.pv.dead )
		return;

	for ( i = 0; i < level.pv_cobra_weapon_defs.size; i++ )
	{
		def = level.pv_cobra_weapon_defs[ i ];
		if ( !isdefined( def.model ) )
			continue;

		ammo = def.max_ammo;
		if ( isdefined( self.pv ) )
			ammo = self.pv.ammo[ i ];

		// fired from the first tag onwards, so the remaining ones are the last tags
		for ( t = def.max_ammo - ammo; t < def.tags.size; t++ )
		{
			if ( t < 0 )
				continue;
			self attach( def.model, def.tags[ t ] );
		}
	}
}

cobra_detach_store( model, tag )
{
	count = self getattachsize();
	for ( i = 0; i < count; i++ )
	{
		if ( self getattachmodelname( i ) != model )
			continue;
		if ( tolower( self getattachtagname( i ) ) != tolower( tag ) )
			continue;
		self detach( model, tag );
		return;
	}
}

/******************************************************/
/*                   TARGETS / LOCKS                  */
/******************************************************/

cobra_targets_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	self.pv.lock = undefined;
	next_refresh = 0;

	for ( ;; )
	{
		// no target markers without the HUD ( mission failed screen )
		if ( !isdefined( self.pv.hud ) )
		{
			self cobra_targets_clear();
			wait 0.1;
			continue;
		}

		if ( gettime() >= next_refresh )
		{
			self cobra_targets_refresh();
			next_refresh = gettime() + 500;
		}
		self cobra_lock_update();
		wait 0.1;
	}
}

cobra_targets_refresh()
{
	candidates = [];
	if ( isdefined( level.vehicles ) && isdefined( level.vehicles[ "axis" ] ) )
		candidates = level.vehicles[ "axis" ];
	if ( isdefined( level.pv_cobra_custom_targets ) )
		candidates = array_combine( candidates, level.pv_cobra_custom_targets );

	// drop dead / removed targets
	keep = [];
	for ( i = 0; i < self.pv.targets.size; i++ )
	{
		t = self.pv.targets[ i ];
		if ( isdefined( t.ent ) && cobra_target_alive( t.ent ) && is_in_array( candidates, t.ent ) )
		{
			keep[ keep.size ] = t;
			continue;
		}
		if ( isdefined( t.ent ) && target_istarget( t.ent ) )
			target_remove( t.ent );
		if ( isdefined( self.pv.lock ) && self.pv.lock == t )
			self cobra_lock_clear();
	}
	self.pv.targets = keep;

	// new targets
	for ( i = 0; i < candidates.size; i++ )
	{
		ent = candidates[ i ];
		if ( !isdefined( ent ) || !cobra_target_alive( ent ) || ent == self )
			continue;
		if ( isdefined( ent.pv_target_registered ) && target_istarget( ent ) )
			continue;

		t = spawnstruct();
		t.ent = ent;
		t.type = cobra_target_type( ent );
		t.offset = cobra_target_offset( ent );
		t.locked = false;
		target_set( ent, t.offset );
		ent.pv_target_registered = true;
		self.pv.targets[ self.pv.targets.size ] = t;
		self cobra_target_shader( t, "target" );
	}
}

cobra_target_alive( ent )
{
	if ( isai( ent ) )
		return isalive( ent );
	if ( isdefined( ent.health ) && ent.classname == "script_vehicle" )
		return ent.health > 0;
	return true;
}

cobra_target_type( ent )
{
	if ( isdefined( ent.pv_target_type ) )
		return ent.pv_target_type;
	if ( isdefined( ent.script_targettype ) )
		return ent.script_targettype;
	if ( !isdefined( ent.vehicletype ) )
		return "ground";
	if ( ent maps\_vehicle::isHelicopter() )
		return "air";
	if ( isdefined( ent.vehicletype ) && ent.vehicletype == "mig29" )
		return "air";
	return "ground";
}

cobra_target_offset( ent )
{
	if ( isdefined( ent.pv_target_offset ) )
		return ent.pv_target_offset;
	if ( isdefined( ent.script_targetoffset_z ) )
		return ( 0, 0, ent.script_targetoffset_z );
	if ( cobra_target_type( ent ) == "air" )
		return ( 0, 0, -100 );
	return ( 0, 0, 48 );
}

cobra_target_shader( t, state )
{
	if ( !isdefined( t.ent ) || !target_istarget( t.ent ) )
		return;

	switch ( state )
	{
		case "lock":
			target_setshader( t.ent, "veh_hud_target_lock" );
			target_setoffscreenshader( t.ent, "veh_hud_target_offscreen" );
			break;
		case "locking":
			target_setshader( t.ent, "veh_hud_target_locking" );
			target_setoffscreenshader( t.ent, "veh_hud_target_offscreen" );
			break;
		case "invalid":
			target_setshader( t.ent, "veh_hud_target_invalid" );
			target_setoffscreenshader( t.ent, "veh_hud_target_invalid_offscreen" );
			break;
		default:
			target_setshader( t.ent, "veh_hud_target" );
			target_setoffscreenshader( t.ent, "veh_hud_target_offscreen" );
			break;
	}
}

cobra_targets_clear()
{
	self cobra_lock_clear();
	if ( !isdefined( self.pv.targets ) )
		return;

	for ( i = 0; i < self.pv.targets.size; i++ )
	{
		ent = self.pv.targets[ i ].ent;
		if ( isdefined( ent ) )
		{
			if ( target_istarget( ent ) )
				target_remove( ent );
			ent.pv_target_registered = undefined;
		}
	}
	self.pv.targets = [];
}

cobra_lock_update()
{
	def = level.pv_cobra_weapon_defs[ self.pv.weapon ];

	if ( def.type != "ground" && def.type != "air" )
	{
		// guns and rockets can engage anything
		for ( i = 0; i < self.pv.targets.size; i++ )
			self cobra_target_shader( self.pv.targets[ i ], "target" );
		self cobra_lock_clear();
		return;
	}

	half = ( def.lock_size * 0.5 ) - 22;
	eye = level.player geteye();
	candidate = undefined;
	best_dist = 999999999;

	for ( i = 0; i < self.pv.targets.size; i++ )
	{
		t = self.pv.targets[ i ];
		if ( !isdefined( t.ent ) )
			continue;

		if ( t.type != def.type )
		{
			self cobra_target_shader( t, "invalid" );
			continue;
		}

		if ( def.type == "ground" )
			inside = target_isinrect( t.ent, level.player, level.pv_fov, half, half );
		else
			inside = target_isincircle( t.ent, level.player, level.pv_fov, half );

		if ( inside && self cobra_sight( eye, t.ent.origin + t.offset ) )
		{
			dist = distancesquared( eye, t.ent.origin );
			if ( dist < best_dist )
			{
				candidate = t;
				best_dist = dist;
			}
		}

		if ( !isdefined( self.pv.lock ) || self.pv.lock != t )
			self cobra_target_shader( t, "target" );
	}

	if ( !isdefined( candidate ) )
	{
		self cobra_lock_clear();
		return;
	}

	if ( !isdefined( self.pv.lock ) || self.pv.lock != candidate )
	{
		self cobra_lock_clear();
		self.pv.lock = candidate;
		candidate.locked = false;
		candidate.lock_start = gettime();
		target_startreticlelockon( candidate.ent, def.lock_time );
	}

	if ( candidate.locked )
		return;

	if ( gettime() - candidate.lock_start >= def.lock_time * 1000 )
	{
		candidate.locked = true;
		self cobra_target_shader( candidate, "lock" );
		level.player playlocalsound( "javelin_clu_lock" );
		candidate.ent notify( "missile_lock", self );
		return;
	}

	// blink while the seeker works, ticking like the alpha's hellfire seeker
	if ( pv_blink_on( 400 ) )
		self cobra_target_shader( candidate, "locking" );
	else
		self cobra_target_shader( candidate, "target" );

	if ( !isdefined( candidate.next_tick ) || gettime() >= candidate.next_tick )
	{
		candidate.next_tick = gettime() + 400;
		level.player playlocalsound( "javelin_clu_aquiring_lock" );
	}
}

cobra_lock_clear()
{
	if ( !isdefined( self.pv.lock ) )
		return;

	t = self.pv.lock;
	self.pv.lock = undefined;
	t.locked = false;
	target_clearreticlelockon();
	if ( isdefined( t.ent ) )
	{
		t.ent notify( "missile_lock_ended", self );
		self cobra_target_shader( t, "target" );
	}
}

/******************************************************/
/*                    CREW / GUNNER                   */
/******************************************************/

cobra_crew_spawn()
{
	// same seats and idles the AI crews use in _cobra.gsc ( tag_pilot / tag_gunner )
	self.pv.gunner = spawn( "script_model", self gettagorigin( "tag_gunner" ) );
	self.pv.gunner setmodel( "body_complete_sp_cobra_pilot_desert_zack" );
	self.pv.gunner cobra_gunner_anim();

	self.pv.pilot = spawn( "script_model", self gettagorigin( "tag_pilot" ) );
	self.pv.pilot setmodel( "body_complete_sp_cobra_pilot_desert_zack" );
	self.pv.pilot cobra_pilot_anim();
	self.pv.pilot hide();

	self cobra_relink_crew();
}

cobra_relink_crew()
{
	if ( isdefined( self.pv.gunner ) )
	{
		self.pv.gunner unlink();
		self.pv.gunner.origin = self gettagorigin( "tag_gunner" );
		self.pv.gunner.angles = self gettagangles( "tag_gunner" );
		self.pv.gunner linkto( self, "tag_gunner", ( 0, 0, 0 ), ( 0, 0, 0 ) );
	}

	if ( isdefined( self.pv.pilot ) )
	{
		self.pv.pilot unlink();
		self.pv.pilot.origin = self gettagorigin( "tag_pilot" );
		self.pv.pilot.angles = self gettagangles( "tag_pilot" );
		self.pv.pilot linkto( self, "tag_pilot", ( 0, 0, 0 ), ( 0, 0, 0 ) );

		// the player is the pilot: only visible from outside
		if ( self.pv.piloted && self.pv.view != "cockpit" )
			self.pv.pilot show();
		else
			self.pv.pilot hide();
	}
}

cobra_crew_delete()
{
	if ( isdefined( self.pv.gunner ) )
		self.pv.gunner delete();
	if ( isdefined( self.pv.pilot ) )
		self.pv.pilot delete();
}

// front seat gunner from the alpha: works the 20mm on his own while the pilot shoots missiles
cobra_gunner_think()
{
	self endon( "death" );
	self endon( "pv_crash" );

	for ( ;; )
	{
		wait 0.25;
		self.pv.gunner_firing = false;

		if ( !self.pv.piloted || getdvar( "cobrapilot_gunner_enabled" ) != "1" )
		{
			self.pv.gunner_has_turret = false;
			continue;
		}
		if ( level.pv_cobra_weapon_defs[ self.pv.weapon ].type == "gun" )
		{
			self.pv.gunner_has_turret = false;
			continue;
		}

		target = self cobra_gunner_get_target();
		if ( !isdefined( target ) )
		{
			self.pv.gunner_has_turret = false;
			continue;
		}

		self.pv.gunner_has_turret = true;
		offset = ( 0, 0, 40 );
		if ( !isai( target ) )
			offset = cobra_target_offset( target );
		self setturrettargetent( target, offset );
		wait 0.35;

		self.pv.gunner_firing = true;
		shots = randomintrange( 10, 24 );
		for ( i = 0; i < shots; i++ )
		{
			if ( !isdefined( target ) || !cobra_target_alive( target ) )
				break;
			if ( !self.pv.piloted || level.pv_cobra_weapon_defs[ self.pv.weapon ].type == "gun" )
				break;
			self setvehweapon( "cobra_20mm_pv" );
			self fireweapon( "tag_flash" );
			self cobra_gun_sound();
			wait 0.07;
		}
		self.pv.gunner_firing = false;
		wait randomfloatrange( 0.5, 1.2 );
	}
}

cobra_gunner_get_target()
{
	origin = self gettagorigin( "tag_flash" );
	forward = anglestoforward( ( 0, self.angles[ 1 ], 0 ) );
	max_dist = 7000 * 7000;

	possible = getaiarray( "axis" );
	if ( isdefined( level.vehicles[ "axis" ] ) )
		possible = array_combine( possible, level.vehicles[ "axis" ] );

	best = undefined;
	best_dist = max_dist;
	for ( i = 0; i < possible.size; i++ )
	{
		ent = possible[ i ];
		if ( !isdefined( ent ) || !cobra_target_alive( ent ) )
			continue;

		dist = distancesquared( origin, ent.origin );
		if ( dist > best_dist )
			continue;

		if ( vectordot( forward, vectornormalize( ent.origin - origin ) ) < 0.2 )
			continue;

		if ( !self cobra_sight( origin, ent.origin + ( 0, 0, 40 ) ) )
			continue;

		best = ent;
		best_dist = dist;
	}
	return best;
}

/******************************************************/
/*              FLARES / INCOMING MISSILES            */
/******************************************************/

cobra_flares()
{
	if ( gettime() < self.pv.next_flare_time )
		return;

	if ( self.pv.flares <= 0 && getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
	{
		level.player playlocalsound( "weap_dryfire_smg_plr" );
		self cobra_hud_message( &"PLAYERVEHICLE_HUD_NO_FLARES" );
		return;
	}

	self.pv.next_flare_time = gettime() + 1200;
	if ( getdvar( "cobrapilot_unlimited_ammo" ) != "1" )
		self.pv.flares--;
	self.pv.ammo_changed = true;

	self playsound( "pv_flare_burst" );
	for ( i = 0; i < 4; i++ )
	{
		playfx( level._effect[ "pv_cobra_flares" ], self gettagorigin( "tag_flare" ) );
		self thread cobra_flare_decoy();
		wait 0.12;
	}
}

cobra_flare_decoy()
{
	velocity = vectorScale( self.pv.velocity, 0.5 ) + ( randomfloatrange( -250, 250 ), randomfloatrange( -250, 250 ), randomfloatrange( -150, 50 ) );
	flare = spawn( "script_origin", self gettagorigin( "tag_flare" ) );
	flare movegravity( velocity, 5 );

	// spoof everything that is homing on us
	missiles = self.incomming_Missiles;
	for ( i = 0; i < missiles.size; i++ )
	{
		if ( isdefined( missiles[ i ] ) )
			missiles[ i ] missile_settarget( flare );
	}
	self.incomming_Missiles = [];

	wait 5.5;
	flare delete();
}

cobra_incoming_missile_monitor()
{
	self endon( "death" );

	for ( ;; )
	{
		self waittill( "incomming_missile", missile );
		if ( !isdefined( missile ) )
			continue;

		self.incomming_Missiles = array_add( self.incomming_Missiles, missile );
		self thread cobra_missile_warning( missile );
	}
}

// red missile marker + direction arrows from the alpha's missileIndicator()
cobra_missile_warning( missile )
{
	self endon( "death" );
	missile endon( "death" );

	while ( !self.pv.piloted )
		wait 0.1;

	if ( !isdefined( self.pv.warn_missiles ) )
		self.pv.warn_missiles = [];
	self.pv.warn_missiles = array_add( self.pv.warn_missiles, missile );

	target_set( missile );
	target_setshader( missile, "veh_hud_missile" );
	target_setoffscreenshader( missile, "veh_hud_missile_offscreen" );

	self thread cobra_missile_warning_end( missile );

	next_sound = 0;
	for ( ;; )
	{
		if ( !self.pv.piloted )
			break;

		if ( gettime() >= next_sound )
		{
			level.player playlocalsound( "pv_alarm_missile" );
			next_sound = gettime() + 700;
		}

		if ( pv_blink_on( 300 ) )
		{
			target_setshader( missile, "veh_hud_missile" );
			target_setoffscreenshader( missile, "veh_hud_missile_offscreen" );
		}
		else
		{
			target_setshader( missile, "veh_hud_missile_flash" );
			target_setoffscreenshader( missile, "veh_hud_missile_flash" );
		}

		wait 0.1;
	}

	if ( target_istarget( missile ) )
		target_remove( missile );
}

cobra_missile_warning_end( missile )
{
	self endon( "death" );
	missile waittill( "death" );
	if ( isdefined( self.pv.warn_missiles ) )
	{
		self.pv.warn_missiles = array_remove( self.pv.warn_missiles, missile );
		self.pv.warn_missiles = remove_undefined_from_array( self.pv.warn_missiles );
	}
	self.incomming_Missiles = remove_undefined_from_array( self.incomming_Missiles );
}

cobra_missile_warnings_clear()
{
	if ( !isdefined( self.pv.warn_missiles ) )
		return;
	for ( i = 0; i < self.pv.warn_missiles.size; i++ )
	{
		missile = self.pv.warn_missiles[ i ];
		if ( isdefined( missile ) && target_istarget( missile ) )
			target_remove( missile );
	}
	self.pv.warn_missiles = [];
}

/******************************************************/
/*                  WARNINGS / BORDERS                */
/******************************************************/

cobra_warnings_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	next_alarm = 0;
	for ( ;; )
	{
		wait 0.1;
		if ( !isdefined( self.pv.hud ) )
			continue;

		// ground proximity: sinking faster than a normal descent with less than ~1.6 seconds to impact,
		// or the flight control had to brake hard in front of something
		sink = -1 * self.pv.velocity[ 2 ];
		pull_up = ( !self.pv.landed && sink > level.pv_cobra_speed_descend * 17.6 * 1.25 && self.pv.agl < 600 && ( self.pv.agl / sink ) < 1.6 );
		if ( isdefined( self.pv.collision_warning_time ) && gettime() < self.pv.collision_warning_time )
			pull_up = true;
		self.pv.warning_pull_up = pull_up;

		if ( pull_up && gettime() >= next_alarm )
		{
			level.player playlocalsound( "pv_alarm_altitude" );
			next_alarm = gettime() + 900;
		}
	}
}

// the alpha's edge_Of_World(): leave through "border_outer", come back through "border_inner"
cobra_edge_of_world()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	outer = getentarray( "border_outer", "targetname" );
	inner = getentarray( "border_inner", "targetname" );
	if ( !outer.size )
		return;

	for ( ;; )
	{
		wait 0.25;
		out = false;
		for ( i = 0; i < outer.size; i++ )
		{
			if ( self istouching( outer[ i ] ) )
				out = true;
		}
		if ( !out )
			continue;

		self.pv.out_of_bounds_time = gettime();
		while ( isdefined( self.pv.out_of_bounds_time ) )
		{
			wait 0.25;
			back = false;
			for ( i = 0; i < inner.size; i++ )
			{
				if ( self istouching( inner[ i ] ) )
					back = true;
			}
			if ( back )
			{
				self.pv.out_of_bounds_time = undefined;
				break;
			}
			if ( gettime() - self.pv.out_of_bounds_time > 15000 )
			{
				setdvar( "ui_deadquote", "@COBRAPILOT_EDGE_OF_WORLD_FAIL" );
				maps\_utility::missionFailedWrapper();
				return;
			}
		}
	}
}

/******************************************************/
/*                   DAMAGE / DEATH                   */
/******************************************************/

cobra_damage_monitor()
{
	self endon( "death" );

	for ( ;; )
	{
		self waittill( "damage", amount, attacker, direction, point, type );
		self.health = 100000;
		self thread cobra_damage( amount, attacker, direction, point, type );
	}
}

cobra_damage( amount, attacker, direction, point, type )
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
			case "MOD_PISTOL_BULLET":
			case "MOD_RIFLE_BULLET":
				scale = 0.35;
				break;
			case "MOD_PROJECTILE":
			case "MOD_PROJECTILE_SPLASH":
				scale = 1.8;
				break;
			case "MOD_MELEE":
				scale = 0;
				break;
		}
	}

	damage = int( amount * scale );
	if ( damage <= 0 )
		return;

	self.pv.hp -= damage;

	if ( self.pv.piloted )
	{
		self.pv.hud_damage_flash = true;
		if ( damage > 200 )
		{
			level.player playrumbleonentity( "damage_heavy" );
			earthquake( 0.35, 0.5, level.player.origin, 300 );
		}
		else
		{
			level.player playrumbleonentity( "damage_light" );
		}
	}

	self cobra_damage_state();

	if ( self.pv.hp <= 0 )
		self thread cobra_destroyed();
}

cobra_damage_state()
{
	frac = self.pv.hp / self.pv.hp_max;
	state = 0;
	if ( frac < 0.6 )
		state = 1;
	if ( frac < 0.3 )
		state = 2;

	if ( state <= self.pv.damage_state )
		return;
	self.pv.damage_state = state;

	if ( state == 1 )
		self thread cobra_damage_fx( "pv_cobra_smoke_light", "tag_engine_left", 0.3 );

	if ( state == 2 )
	{
		self thread cobra_damage_fx( "pv_cobra_smoke_heavy", "tag_engine_right", 0.25 );
		self thread cobra_damage_fx( "pv_cobra_fire", "tag_engine_left", 0.2 );
		self thread cobra_damage_sound();
	}
}

cobra_damage_fx( fx, tag, rate )
{
	self endon( "death" );
	self endon( "pv_repaired" );
	for ( ;; )
	{
		playfxontag( level._effect[ fx ], self, tag );
		wait rate;
	}
}

cobra_damage_sound()
{
	self endon( "death" );
	self endon( "pv_repaired" );
	for ( ;; )
	{
		self playsound( "pv_heli_damaged" );
		wait randomfloatrange( 2.5, 4 );
	}
}

cobra_destroyed()
{
	if ( self.pv.dead )
		return;
	self.pv.dead = true;
	self notify( "pv_crash" );
	pv_set_boardable( self, false );

	if ( !self.pv.piloted )
	{
		self cobra_explode();
		return;
	}

	// spin out of control, then blow up
	self playsound( "pv_heli_spindown" );
	self thread cobra_damage_fx( "pv_cobra_smoke_heavy", "tag_engine_left", 0.1 );
	self thread cobra_damage_fx( "pv_cobra_fire", "tag_engine_right", 0.1 );
	self setmaxpitchroll( 25, 40 );
	self setyawspeed( 360, 360, 360 );
	self setspeed( 45, 30, 30 );

	yaw = self.angles[ 1 ];
	start = gettime();
	while ( gettime() - start < 3000 )
	{
		ground = self cobra_ground_z();
		if ( isdefined( ground ) && self.origin[ 2 ] - self.pv.ground_offset - ground < 40 )
			break;
		yaw += 30;
		self settargetyaw( yaw );
		self setgoalyaw( yaw );
		self setvehgoalpos( self.origin + vectorScale( anglestoforward( ( 0, yaw, 0 ) ), 300 ) - ( 0, 0, 600 ), 0 );
		wait 0.05;
	}

	pv_kill_player( "@PLAYERVEHICLE_DEADQUOTE_COBRA" );
	self cobra_explode();
}

cobra_explode()
{
	origin = self.origin;
	playfx( level._effect[ "pv_cobra_explosion" ], origin );
	playfx( level._effect[ "pv_cobra_crash" ], origin );
	self playsound( "helicopter_crash" );
	earthquake( 0.6, 1.5, origin, 3000 );
	radiusdamage( origin + ( 0, 0, -100 ), 350, 250, 40 );

	self cobra_crew_delete();
	self detachall();
	self notify( "pv_repaired" );

	ground = pv_ground_z( origin, self );
	if ( isdefined( ground ) && origin[ 2 ] - self.pv.ground_offset - ground < 200 )
	{
		// burning wreck on the ground
		self setmodel( "vehicle_cobra_helicopter_d" );
		self setvehgoalpos( ( origin[ 0 ], origin[ 1 ], ground + self.pv.ground_offset ), 1 );
		self thread cobra_damage_fx( "pv_cobra_smoke_heavy", "tag_engine_left", 0.3 );
		return;
	}

	wait 0.05;
	if ( isdefined( self ) )
	{
		self notify( "death" );
		self delete();
	}
}

/******************************************************/
/*                       REARM                        */
/******************************************************/

// hover low over / land on an "ammo_reload" ( alpha ) or "cobra_rearm" trigger to rearm and repair
cobra_rearm_think()
{
	self endon( "death" );
	self endon( "pv_exit" );
	self endon( "pv_crash" );

	pads = array_combine( getentarray( "ammo_reload", "targetname" ), getentarray( "cobra_rearm", "targetname" ) );
	if ( !pads.size )
		return;

	// world space markers like the alpha's ammo_Reload_Station_Notify()
	for ( i = 0; i < pads.size; i++ )
	{
		farp = newHudElem();
		farp setshader( "compass_waypoint_farp", 8, 8 );
		farp.x = pads[ i ].origin[ 0 ];
		farp.y = pads[ i ].origin[ 1 ];
		farp.z = pads[ i ].origin[ 2 ];
		farp.alpha = 0.75;
		farp setwaypoint( true );
		level.pv_hud_elems[ level.pv_hud_elems.size ] = farp;
	}

	for ( ;; )
	{
		wait 0.5;
		self.pv.rearming = false;

		on_pad = false;
		for ( i = 0; i < pads.size; i++ )
		{
			if ( self istouching( pads[ i ] ) )
				on_pad = true;
		}
		if ( !on_pad || self.pv.agl > 350 || length( self.pv.velocity ) > 200 )
			continue;

		self.pv.rearming = true;
		changed = false;

		for ( i = 0; i < level.pv_cobra_weapon_defs.size; i++ )
		{
			def = level.pv_cobra_weapon_defs[ i ];
			if ( self.pv.ammo[ i ] >= def.max_ammo )
				continue;
			self.pv.ammo[ i ] = int( pv_min( def.max_ammo, self.pv.ammo[ i ] + def.ammo_increment ) );
			changed = true;
		}
		if ( self.pv.flares < level.pv_cobra_flares )
		{
			self.pv.flares++;
			changed = true;
		}
		if ( self.pv.hp < self.pv.hp_max )
		{
			self.pv.hp = int( pv_min( self.pv.hp_max, self.pv.hp + self.pv.hp_max / 12 ) );
			changed = true;
			if ( self.pv.hp >= self.pv.hp_max * 0.6 && self.pv.damage_state > 0 )
			{
				self.pv.damage_state = 0;
				self notify( "pv_repaired" );
			}
		}

		if ( changed )
		{
			self.pv.ammo_changed = true;
			self cobra_refresh_stores();
			level.player playlocalsound( "weap_ammo_pickup" );
		}
	}
}

/******************************************************/
/*                       INPUT                        */
/******************************************************/

cobra_input_think()
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
				self cobra_cycle_view();
				break;
			case "weapnext":
				self cobra_select_weapon( 1 );
				break;
			case "weapprev":
				self cobra_select_weapon( -1 );
				break;
			case "frag":
				self thread cobra_flares();
				break;
			case "reload":
				self cobra_toggle_thermal();
				break;
			case "use":
				self cobra_try_exit();
				break;
			case "ads_on":
			case "ads_off":
				self cobra_apply_fov();
				break;
		}
	}
}

/******************************************************/
/*                         HUD                        */
/******************************************************/

cobra_hud_create()
{
	level.pv_hud_elems = [];
	hud = spawnstruct();
	self.pv.hud = hud;
	green = ( 0.4, 1, 0.4 );

	// --- pilot symbology ---
	hud.center = pv_hud_icon( "reticle_center_cross", 32, 32, 0, 0, "center", "middle", "center", "middle" );
	hud.rocket = pv_hud_icon( "veh_centercircle", 24, 24, 0, 0, "center", "middle", "center", "middle" );
	hud.pipper = pv_hud_icon( "veh_movingcircle", 48, 48, 0, 0, "center", "middle", "center", "middle" );
	hud.lockbox = pv_hud_icon( "veh_hud_hellfire", 180, 180, 0, 0, "center", "middle", "center", "middle" );
	hud.lockcircle = pv_hud_icon( "veh_hud_sidewinder", 180, 180, 0, 0, "center", "middle", "center", "middle" );

	hud.lock_text = pv_hud_text( "objective", 1.3, 0, 104, "center", "middle", "center", "middle" );
	hud.lock_text.alpha = 0;

	hud.speed = pv_hud_text( "objective", 1.5, -150, 0, "right", "middle", "center", "middle" );
	hud.speed.label = &"PLAYERVEHICLE_HUD_KTS";
	hud.speed setvalue( 0 );

	hud.alt = pv_hud_text( "objective", 1.5, 150, 0, "left", "middle", "center", "middle" );
	hud.alt.label = &"PLAYERVEHICLE_HUD_FT";
	hud.alt setvalue( 0 );

	hud.gunner = pv_hud_text( "objective", 1.1, 0, 128, "center", "middle", "center", "middle" );
	hud.gunner settext( &"PLAYERVEHICLE_HUD_GUNNER" );
	hud.gunner.alpha = 0;

	// --- weapons, health ( bottom right, where the infantry weapon info sits ) ---
	hud.weapon_names = [];
	hud.weapon_ammo = [];
	base_y = -40 - ( level.pv_cobra_weapon_defs.size * 16 );
	hud.select_bar = pv_hud_icon( "white", 300, 15, -12, base_y, "right", "middle", "right", "bottom" );
	hud.select_bar.alpha = 0.18;
	hud.select_bar.sort = 0;

	for ( i = 0; i < level.pv_cobra_weapon_defs.size; i++ )
	{
		y = base_y + ( i * 16 );
		name = pv_hud_text( "objective", 1.2, -78, y, "right", "middle", "right", "bottom" );
		name settext( level.pv_cobra_weapon_defs[ i ].string );
		hud.weapon_names[ i ] = name;

		ammo = pv_hud_text( "objective", 1.2, -20, y, "right", "middle", "right", "bottom" );
		ammo setvalue( self.pv.ammo[ i ] );
		hud.weapon_ammo[ i ] = ammo;
	}

	hud.flares = pv_hud_text( "objective", 1.2, -20, -26, "right", "middle", "right", "bottom" );
	hud.flares.label = &"PLAYERVEHICLE_HUD_FLARES";
	hud.flares setvalue( self.pv.flares );

	hud.health = pv_hud_icon( "cobra_health", 96, 48, -16, base_y - 16, "right", "bottom", "right", "bottom" );

	// --- warnings ---
	hud.warning = pv_hud_text( "objective", 2.0, 0, -96, "center", "middle", "center", "middle" );
	hud.warning.color = ( 1, 0.2, 0.15 );
	hud.warning.alpha = 0;

	hud.message = pv_hud_text( "default", 1.4, 0, 70, "center", "middle", "center", "middle" );
	hud.message.alpha = 0;

	hud.damage_overlay = pv_hud_icon( "overlay_low_health", 640, 480, 0, 0, "left", "top", "fullscreen", "fullscreen" );
	hud.damage_overlay.alpha = 0;
	hud.damage_overlay.foreground = false;
	hud.damage_overlay.sort = -2;

	// --- gunner camera ( TADS ) ---
	hud.tads_grain = pv_hud_icon( "ac130_overlay_grain", 640, 480, 0, 0, "left", "top", "fullscreen", "fullscreen" );
	hud.tads_grain.foreground = false;
	hud.tads_grain.sort = -3;
	hud.tads_overlay = pv_hud_icon( "ac130_overlay_25mm", 640, 480, 0, 0, "center", "middle", "center", "middle" );
	hud.tads_overlay.foreground = false;
	hud.tads_overlay.sort = -2;

	hud.tads_title = pv_hud_text( "default", 1.8, 24, 20, "left", "top", "left", "top" );
	hud.tads_title settext( &"PLAYERVEHICLE_HUD_TADS" );
	hud.tads_thermal = pv_hud_text( "default", 1.8, -24, 20, "right", "top", "right", "top" );
	hud.tads_fov = pv_hud_text( "default", 1.8, -24, 42, "right", "top", "right", "top" );
	hud.tads_range = pv_hud_text( "default", 1.8, 0, -86, "center", "bottom", "center", "bottom" );
	hud.tads_range.label = &"PLAYERVEHICLE_HUD_RANGE";

	hud.pilot_elems = [];
	hud.pilot_elems[ hud.pilot_elems.size ] = hud.speed;
	hud.pilot_elems[ hud.pilot_elems.size ] = hud.alt;
	hud.tads_elems = [];
	hud.tads_elems[ hud.tads_elems.size ] = hud.tads_grain;
	hud.tads_elems[ hud.tads_elems.size ] = hud.tads_overlay;
	hud.tads_elems[ hud.tads_elems.size ] = hud.tads_title;
	hud.tads_elems[ hud.tads_elems.size ] = hud.tads_thermal;
	hud.tads_elems[ hud.tads_elems.size ] = hud.tads_fov;
	hud.tads_elems[ hud.tads_elems.size ] = hud.tads_range;

	green_elems = [];
	green_elems[ green_elems.size ] = hud.center;
	green_elems[ green_elems.size ] = hud.rocket;
	green_elems[ green_elems.size ] = hud.pipper;
	green_elems[ green_elems.size ] = hud.lock_text;
	green_elems[ green_elems.size ] = hud.speed;
	green_elems[ green_elems.size ] = hud.alt;
	green_elems[ green_elems.size ] = hud.gunner;
	green_elems[ green_elems.size ] = hud.select_bar;
	green_elems[ green_elems.size ] = hud.flares;
	green_elems = array_combine( green_elems, hud.weapon_names );
	green_elems = array_combine( green_elems, hud.weapon_ammo );
	pv_hud_set_color( green_elems, green );

	for ( i = 0; i < green_elems.size; i++ )
	{
		if ( isdefined( green_elems[ i ].fontScale ) )
		{
			green_elems[ i ].glowColor = ( 0.1, 0.45, 0.1 );
			green_elems[ i ].glowAlpha = 0.35;
		}
	}

	self.pv.weapon_changed = true;
	self.pv.ammo_changed = true;
}

cobra_hud_set_view()
{
	hud = self.pv.hud;
	if ( !isdefined( hud ) )
		return;

	tads = ( self.pv.view == "gunner" );

	for ( i = 0; i < hud.tads_elems.size; i++ )
	{
		if ( tads )
			hud.tads_elems[ i ].alpha = 1;
		else
			hud.tads_elems[ i ].alpha = 0;
	}
	if ( tads )
		hud.tads_grain.alpha = 0.35;

	for ( i = 0; i < hud.pilot_elems.size; i++ )
	{
		if ( tads )
			hud.pilot_elems[ i ].alpha = 0;
		else
			hud.pilot_elems[ i ].alpha = 1;
	}

	if ( self.pv.thermal_inverted )
		hud.tads_thermal settext( &"PLAYERVEHICLE_HUD_BHOT" );
	else
		hud.tads_thermal settext( &"PLAYERVEHICLE_HUD_WHOT" );

	self.pv.weapon_changed = true;
	self.pv.fov_label = undefined;
}

cobra_hud_message( text )
{
	if ( !isdefined( self.pv.hud ) )
		return;

	hud = self.pv.hud;
	hud.message settext( text );
	hud.message.alpha = 1;
	hud.message fadeOverTime( 2.5 );
	hud.message.alpha = 0;
}

cobra_hud_think()
{
	self endon( "death" );
	self endon( "pv_exit" );

	for ( ;; )
	{
		wait 0.05;
		hud = self.pv.hud;
		if ( !isdefined( hud ) )
			continue;

		def = level.pv_cobra_weapon_defs[ self.pv.weapon ];
		tads = ( self.pv.view == "gunner" );
		eye = level.player geteye();
		angles = level.player getplayerangles();

		// flight data
		if ( !tads )
		{
			hud.speed setvalue( int( length( ( self.pv.velocity[ 0 ], self.pv.velocity[ 1 ], 0 ) ) / 20.25 ) );
			hud.alt setvalue( int( pv_max( 0, self.pv.agl ) / 12 ) );
		}

		// reticles for the selected weapon
		if ( self.pv.weapon_changed )
		{
			self.pv.weapon_changed = false;

			hud.center.alpha = 0;
			hud.rocket.alpha = 0;
			hud.lockbox.alpha = 0;
			hud.lockcircle.alpha = 0;

			if ( !tads )
			{
				switch ( def.type )
				{
					case "gun":
						hud.center.alpha = 1;
						break;
					case "rocket":
						hud.rocket.alpha = 1;
						break;
					case "ground":
						hud.lockbox.alpha = 0.85;
						hud.center.alpha = 0.6;
						break;
					case "air":
						hud.lockcircle.alpha = 0.85;
						hud.center.alpha = 0.6;
						break;
				}
			}

			for ( i = 0; i < hud.weapon_names.size; i++ )
			{
				if ( i == self.pv.weapon )
				{
					hud.weapon_names[ i ].alpha = 1;
					hud.weapon_ammo[ i ].alpha = 1;
				}
				else
				{
					hud.weapon_names[ i ].alpha = 0.4;
					hud.weapon_ammo[ i ].alpha = 0.4;
				}
			}
			hud.select_bar moveOverTime( 0.1 );
			hud.select_bar.y = hud.weapon_names[ self.pv.weapon ].y;
		}

		if ( self.pv.ammo_changed )
		{
			self.pv.ammo_changed = false;
			for ( i = 0; i < hud.weapon_ammo.size; i++ )
				hud.weapon_ammo[ i ] setvalue( self.pv.ammo[ i ] );
			hud.flares setvalue( self.pv.flares );
		}

		// where the M197 is actually pointing ( it slews after the reticle )
		show_pipper = ( def.type == "gun" || self.pv.gunner_has_turret ) && !tads;
		if ( show_pipper )
		{
			flash = self gettagorigin( "tag_flash" );
			dir = anglestoforward( self gettagangles( "tag_barrel" ) );
			hit = self cobra_trace_past_self( flash, dir, 20000 );
			pv_hud_move( hud.pipper, pv_world_to_screen( hit, eye, angles, level.pv_fov ), 0.85 );
		}
		else
		{
			hud.pipper.alpha = 0;
		}

		if ( self.pv.gunner_firing && !tads )
			hud.gunner.alpha = 0.8;
		else
			hud.gunner.alpha = 0;

		// lock status
		if ( isdefined( self.pv.lock ) )
		{
			if ( self.pv.lock.locked )
			{
				hud.lock_text settext( &"PLAYERVEHICLE_HUD_LOCKED" );
				hud.lock_text.alpha = 1;
			}
			else
			{
				hud.lock_text settext( &"PLAYERVEHICLE_HUD_LOCKING" );
				if ( pv_blink_on( 400 ) )
					hud.lock_text.alpha = 1;
				else
					hud.lock_text.alpha = 0.2;
			}
		}
		else
		{
			hud.lock_text.alpha = 0;
		}

		// health icon goes green -> orange -> red like the alpha's health_indicator_getColor()
		frac = pv_clamp( self.pv.hp / self.pv.hp_max, 0, 1 );
		if ( frac > 0.5 )
			hud.health.color = ( 2 - ( 2 * frac ), frac, 0 );
		else
			hud.health.color = ( 1, frac, 0 );
		if ( self.pv.damage_state >= 2 && !pv_blink_on( 500 ) )
			hud.health.alpha = 0.3;
		else
			hud.health.alpha = 0.9;

		if ( isdefined( self.pv.hud_damage_flash ) )
		{
			self.pv.hud_damage_flash = undefined;
			hud.damage_overlay.alpha = 0.6;
			hud.damage_overlay fadeOverTime( 0.6 );
			hud.damage_overlay.alpha = 0;
		}

		// warnings: missile launch > pull up > damage
		if ( isdefined( self.pv.warn_missiles ) && self.pv.warn_missiles.size > 0 )
		{
			hud.warning settext( &"PLAYERVEHICLE_HUD_MISSILE" );
			hud.warning.alpha = pv_blink_on( 300 );
		}
		else if ( isdefined( self.pv.warning_pull_up ) && self.pv.warning_pull_up )
		{
			hud.warning settext( &"PLAYERVEHICLE_HUD_PULL_UP" );
			hud.warning.alpha = pv_blink_on( 400 );
		}
		else if ( isdefined( self.pv.rearming ) && self.pv.rearming )
		{
			hud.warning settext( &"PLAYERVEHICLE_HUD_REARMING" );
			hud.warning.alpha = 0.8;
		}
		else if ( self.pv.damage_state >= 2 )
		{
			hud.warning settext( &"PLAYERVEHICLE_HUD_DAMAGE" );
			hud.warning.alpha = 0.8 * pv_blink_on( 1000 );
		}
		else if ( isdefined( self.pv.out_of_bounds_time ) )
		{
			hud.warning settext( &"COBRAPILOT_EDGE_OF_WORLD_WARNING" );
			hud.warning.alpha = pv_blink_on( 800 );
		}
		else
		{
			hud.warning.alpha = 0;
		}

		// gunner camera readouts
		if ( tads )
		{
			hud.tads_range setvalue( int( self.pv.aim_range / 39.37 ) );
			wide = !pv_button_held( "ads" );
			if ( !isdefined( self.pv.fov_label ) || self.pv.fov_label != wide )
			{
				self.pv.fov_label = wide;
				if ( wide )
					hud.tads_fov settext( &"PLAYERVEHICLE_HUD_WFOV" );
				else
					hud.tads_fov settext( &"PLAYERVEHICLE_HUD_NFOV" );
			}
		}
	}
}

#using_animtree( "generic_human" );
cobra_pilot_anim()
{
	self useanimtree( #animtree );
	self setanim( %helicopter_pilot1_idle, 1, 0 );
}

cobra_gunner_anim()
{
	self useanimtree( #animtree );
	self setanim( %helicopter_pilot2_idle, 1, 0 );
}

#include maps\_utility;
#include common_scripts\utility;

/*
	PLAYER VEHICLE FRAMEWORK

	Shared code for the player piloted AH-1W SuperCobra ( maps\_playervehicle_cobra ) and the
	player commanded M1A1 Abrams ( maps\_playervehicle_abrams ).

	Handles:
		- input ( notifyOnCommand based, independent of the player's key bindings )
		- boarding hints and the use button
		- player state while inside a vehicle ( weapons, stance, HUD dvars, fov )
		- damage routing from the player to the vehicle he is driving
		- kill credit: damage done by the vehicle weapons counts as the player's for the friendly fire
		  and participation rules of maps\_friendlyfire
		- camera rigs, fades and world -> HUD projection for floating reticles
		- HUD element helpers and the controls help panel

	You never call this file directly from a level, the vehicle scripts do.
*/

/*
=============
///ScriptDocBegin
"Name: pv_precache()"
"Summary: Precaches everything the shared player vehicle code needs. Called from the vehicle mains."
"Module: PlayerVehicle"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
pv_precache()
{
	if ( isdefined( level.pv_precached ) )
		return;
	level.pv_precached = true;

	precacheModel( "tag_origin" );
	precacheShader( "black" );
	precacheShader( "white" );

	precacheRumble( "damage_light" );
	precacheRumble( "damage_heavy" );

	if ( !isdefined( level.pv_vehicles ) )
		level.pv_vehicles = [];
}

/*
=============
///ScriptDocBegin
"Name: pv_init()"
"Summary: Starts the shared systems ( input, boarding ). Must run after maps\_load::main(). Safe to call more than once."
"Module: PlayerVehicle"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
pv_init()
{
	if ( isdefined( level.pv_initialized ) )
		return;
	level.pv_initialized = true;

	assertEx( isdefined( level.player ), "maps\\_playervehicle::pv_init() has to be called after maps\\_load::main()" );

	if ( !isdefined( level.pv_vehicles ) )
		level.pv_vehicles = [];
	level.pv_hud_elems = [];
	level.pv_fov = 65;

	pv_input_init();

	thread pv_boarding_monitor();
	thread pv_boarding_use_monitor();
	thread pv_damage_credit_monitor();
	thread pv_hud_hide_on_fail();
}

/******************************************************/
/*                       INPUT                        */
/******************************************************/

// Everything goes through notifyOnCommand so the controls follow whatever keys the player
// has bound ( same approach the AC-130 level uses ). Hold style commands report "+" and "-".
pv_input_init()
{
	level.pv_held = [];

	pv_input_watch_hold( "ads", "+toggleads_throw", "-toggleads_throw" );
	pv_input_watch_hold( "ads", "+speed_throw", "-speed_throw" );
	pv_input_watch_hold( "up", "+gostand", "-gostand" );
	pv_input_watch_hold( "up", "+moveup", "-moveup" );
	pv_input_watch_hold( "down", "+breath_sprint", "-breath_sprint" );
	pv_input_watch_hold( "down", "+sprint", "-sprint" );
	pv_input_watch_hold( "down", "+movedown", "-movedown" );

	pv_input_watch_press( "use", "+activate" );
	pv_input_watch_press( "use", "+usereload" );
	pv_input_watch_press( "view", "+melee" );
	pv_input_watch_press( "view", "+melee_breath" );
	pv_input_watch_press( "weapnext", "weapnext" );
	pv_input_watch_press( "weapprev", "weapprev" );
	pv_input_watch_press( "frag", "+frag" );
	pv_input_watch_press( "smoke", "+smoke" );
	pv_input_watch_press( "reload", "+reload" );
}

pv_input_watch_hold( name, on_cmd, off_cmd )
{
	if ( !isdefined( level.pv_held[ name ] ) )
	{
		level.pv_held[ name ] = false;
		thread pv_input_hold_thread( name, true );
		thread pv_input_hold_thread( name, false );
	}

	level.player notifyOnCommand( "pv_cmd_" + name + "_on", on_cmd );
	level.player notifyOnCommand( "pv_cmd_" + name + "_off", off_cmd );
}

pv_input_hold_thread( name, state )
{
	if ( state )
		msg = "pv_cmd_" + name + "_on";
	else
		msg = "pv_cmd_" + name + "_off";

	for ( ;; )
	{
		level.player waittill( msg );
		level.pv_held[ name ] = state;
		if ( state )
			level notify( "pv_input", name + "_on" );
		else
			level notify( "pv_input", name + "_off" );
	}
}

pv_input_watch_press( name, cmd )
{
	if ( !isdefined( level.pv_press_watched ) )
		level.pv_press_watched = [];

	if ( !isdefined( level.pv_press_watched[ name ] ) )
	{
		level.pv_press_watched[ name ] = true;
		thread pv_input_press_thread( name );
	}

	level.player notifyOnCommand( "pv_cmd_" + name, cmd );
}

pv_input_press_thread( name )
{
	msg = "pv_cmd_" + name;
	for ( ;; )
	{
		level.player waittill( msg );
		level notify( "pv_input", name );
	}
}

/*
=============
///ScriptDocBegin
"Name: pv_button_held( <name> )"
"Summary: True while the player holds a tracked command: "ads" ( zoom / right mouse ), "up" ( jump ), "down" ( sprint key )."
"Module: PlayerVehicle"
"MandatoryArg: <name>: tracked command group"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
pv_button_held( name )
{
	if ( !isdefined( level.pv_held ) || !isdefined( level.pv_held[ name ] ) )
		return false;
	return level.pv_held[ name ];
}

// "+ads"-binding the player actually uses, so the help text shows the right key
pv_ads_is_toggle()
{
	binding = getKeyBinding( "+toggleads_throw" );
	return ( binding[ "count" ] > 0 );
}

/******************************************************/
/*                      BOARDING                      */
/******************************************************/

/*
=============
///ScriptDocBegin
"Name: pv_register_vehicle( <vehicle>, <hint>, <enter_func>, <radius>, <tag> )"
"Summary: Makes a vehicle boardable: a use hint appears near <tag> and <enter_func> runs on the vehicle when the player presses use."
"Module: PlayerVehicle"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
pv_register_vehicle( vehicle, hint, enter_func, radius, tag )
{
	vehicle.pv_hint = hint;
	vehicle.pv_enter_func = enter_func;
	vehicle.pv_board_radius = radius;
	vehicle.pv_board_tag = tag;
	vehicle.pv_boardable = true;

	if ( !is_in_array( level.pv_vehicles, vehicle ) )
		level.pv_vehicles[ level.pv_vehicles.size ] = vehicle;

	vehicle thread pv_unregister_on_death();
}

pv_unregister_on_death()
{
	self waittill( "death" );
	level.pv_vehicles = array_remove( level.pv_vehicles, self );
	level.pv_vehicles = remove_undefined_from_array( level.pv_vehicles );
}

pv_set_boardable( vehicle, boardable )
{
	vehicle.pv_boardable = boardable;
}

pv_boarding_monitor()
{
	level.player endon( "death" );

	hint = undefined;
	hint_vehicle = undefined;
	level.pv_hint_vehicle = undefined;

	for ( ;; )
	{
		wait 0.05;

		vehicle = undefined;
		if ( !isdefined( level.pv_active ) && !isdefined( level.pv_transition ) )
			vehicle = pv_get_boardable_vehicle();

		level.pv_hint_vehicle = vehicle;

		if ( !isdefined( vehicle ) )
		{
			if ( isdefined( hint ) )
				hint destroy();
			hint = undefined;
			hint_vehicle = undefined;
			continue;
		}

		if ( !isdefined( hint ) )
		{
			// same spot and size as the code driven use hint ( hud.menu "Cursorhints" )
			hint = newHudElem();
			hint.x = 0;
			hint.y = 70;
			hint.alignX = "center";
			hint.alignY = "middle";
			hint.horzAlign = "center";
			hint.vertAlign = "middle";
			hint.font = "default";
			hint.fontScale = 1.4;
			hint.foreground = true;
			hint.hidewheninmenu = true;
			hint_vehicle = undefined;
		}

		if ( !isdefined( hint_vehicle ) || hint_vehicle != vehicle )
		{
			hint settext( vehicle.pv_hint );
			hint_vehicle = vehicle;
		}
	}
}

pv_get_boardable_vehicle()
{
	if ( !isalive( level.player ) )
		return undefined;

	eye = level.player geteye();
	forward = anglestoforward( level.player getplayerangles() );

	best = undefined;
	best_score = -100;

	for ( i = 0; i < level.pv_vehicles.size; i++ )
	{
		vehicle = level.pv_vehicles[ i ];
		if ( !isdefined( vehicle ) )
			continue;
		if ( !isdefined( vehicle.pv_boardable ) || !vehicle.pv_boardable )
			continue;

		org = vehicle gettagorigin( vehicle.pv_board_tag );
		dist = distance( eye, org );
		if ( dist > vehicle.pv_board_radius )
			continue;

		dot = vectordot( forward, vectornormalize( org - eye ) );
		if ( dot < 0.3 && dist > 100 )
			continue;

		score = dot + ( 1 - ( dist / vehicle.pv_board_radius ) );
		if ( score > best_score )
		{
			best = vehicle;
			best_score = score;
		}
	}

	return best;
}

pv_boarding_use_monitor()
{
	level.player endon( "death" );

	for ( ;; )
	{
		level waittill( "pv_input", cmd );
		if ( cmd != "use" )
			continue;
		if ( isdefined( level.pv_active ) || isdefined( level.pv_transition ) )
			continue;

		vehicle = level.pv_hint_vehicle;
		if ( !isdefined( vehicle ) )
			continue;

		vehicle thread [[ vehicle.pv_enter_func ]]();
	}
}

/******************************************************/
/*                    PLAYER STATE                    */
/******************************************************/

/*
=============
///ScriptDocBegin
"Name: pv_player_enter( <vehicle> )"
"Summary: Puts the player into "vehicle mode": weapons away, no stance changes, invulnerable ( the vehicle takes the hits ), weapon HUD hidden."
"Module: PlayerVehicle"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
pv_player_enter( vehicle )
{
	level.pv_active = vehicle;
	level.pv_transition = true;

	saved = spawnstruct();
	saved.fov = getdvar( "cg_fov" );
	saved.ammo_hide = getdvar( "ammoCounterHide" );
	saved.show_stance = getdvar( "hud_showStance" );
	level.pv_saved = saved;

	level.player disableweapons();
	level.player allowcrouch( false );
	level.player allowprone( false );
	level.player allowjump( false );
	level.player allowsprint( false );
	level.player allowmelee( false );
	level.player setstance( "stand" );
	level.player EnableInvulnerability();

	setsaveddvar( "ammoCounterHide", "1" );
	setsaveddvar( "hud_showStance", "0" );

	level.player thread pv_player_damage_redirect( vehicle );
	level notify( "pv_player_entered", vehicle );
}

pv_player_exit()
{
	level.player notify( "pv_stop_damage_redirect" );

	saved = level.pv_saved;

	level.player DisableInvulnerability();
	level.player allowcrouch( true );
	level.player allowprone( true );
	level.player allowjump( true );
	level.player allowsprint( true );
	level.player allowmelee( true );
	level.player enableweapons();

	if ( isdefined( saved ) )
	{
		setsaveddvar( "cg_fov", saved.fov );
		setsaveddvar( "ammoCounterHide", saved.ammo_hide );
		setsaveddvar( "hud_showStance", saved.show_stance );
	}
	level.pv_fov = 65;

	vehicle = level.pv_active;
	level.pv_active = undefined;
	level notify( "pv_player_exited", vehicle );
}

// enemies keep shooting at the player, wherever the camera is - the vehicle soaks it up
pv_player_damage_redirect( vehicle )
{
	self endon( "pv_stop_damage_redirect" );
	self endon( "death" );
	vehicle endon( "death" );

	for ( ;; )
	{
		self waittill( "damage", amount, attacker, direction, point, type );
		if ( isdefined( vehicle.pv_damage_func ) )
			vehicle thread [[ vehicle.pv_damage_func ]]( amount, attacker, direction, point, type );
	}
}

pv_set_fov( fov )
{
	level.pv_fov = fov;
	setsaveddvar( "cg_fov", fov );
}

/*
=============
///ScriptDocBegin
"Name: pv_kill_player( <deadquote> )"
"Summary: Kills the player because his vehicle was destroyed and shows <deadquote> ( "@STRING_REF" ) on the death screen."
"Module: PlayerVehicle"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
pv_kill_player( deadquote )
{
	if ( !isalive( level.player ) )
		return;

	level notify( "new_quote_string" );
	setdvar( "ui_deadquote", deadquote );

	level.player notify( "pv_stop_damage_redirect" );
	level.player DisableInvulnerability();
	level.player EnableHealthShield( false );
	level.player dodamage( level.player.health + 100000, level.player.origin );
}

/******************************************************/
/*                   CAMERA / SCREEN                  */
/******************************************************/

// The player's eye sits 60 units above whatever he is linked to ( standing view height ).
pv_camera_rig( parent, tag, offset, angles )
{
	rig = spawn( "script_model", parent gettagorigin( tag ) );
	rig setmodel( "tag_origin" );
	rig linkto( parent, tag, offset, angles );
	return rig;
}

pv_fade_out( time )
{
	if ( !isdefined( level.pv_fade_elem ) )
	{
		elem = newHudElem();
		elem.x = 0;
		elem.y = 0;
		elem.alignX = "left";
		elem.alignY = "top";
		elem.horzAlign = "fullscreen";
		elem.vertAlign = "fullscreen";
		elem.foreground = true;
		elem.sort = 100;
		elem.alpha = 0;
		elem setshader( "black", 640, 480 );
		level.pv_fade_elem = elem;
	}

	level.pv_fade_elem fadeOverTime( time );
	level.pv_fade_elem.alpha = 1;
	wait time;
}

pv_fade_in( time )
{
	if ( !isdefined( level.pv_fade_elem ) )
		return;
	level.pv_fade_elem fadeOverTime( time );
	level.pv_fade_elem.alpha = 0;
}

/*
=============
///ScriptDocBegin
"Name: pv_world_to_screen( <point>, <eye>, <angles>, <fov> )"
"Summary: Projects a world position into HUD space ( center / middle aligned 640x480 units ). Returns undefined if the point is behind the view."
"Module: PlayerVehicle"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
pv_world_to_screen( point, eye, angles, fov )
{
	delta = point - eye;
	forward = vectordot( delta, anglestoforward( angles ) );
	if ( forward < 8 )
		return undefined;

	// cg_fov is the horizontal fov of a 4:3 view; the vertical fov is the same on every aspect
	half = fov * 0.5;
	tan_half_vertical = ( sin( half ) / cos( half ) ) * 0.75;
	scale = 240 / ( forward * tan_half_vertical );

	x = vectordot( delta, anglestoright( angles ) ) * scale;
	y = -1 * vectordot( delta, anglestoup( angles ) ) * scale;
	return ( x, y, 0 );
}

/******************************************************/
/*                        HUD                         */
/******************************************************/

pv_hud_text( font, scale, x, y, align_x, align_y, horz_align, vert_align )
{
	elem = newHudElem();
	elem.font = font;
	elem.fontScale = scale;
	elem.x = x;
	elem.y = y;
	elem.alignX = align_x;
	elem.alignY = align_y;
	elem.horzAlign = horz_align;
	elem.vertAlign = vert_align;
	elem.foreground = true;
	elem.hidewheninmenu = true;
	elem.sort = 2;
	elem.alpha = 1;
	level.pv_hud_elems[ level.pv_hud_elems.size ] = elem;
	return elem;
}

pv_hud_icon( shader, width, height, x, y, align_x, align_y, horz_align, vert_align )
{
	elem = newHudElem();
	elem.x = x;
	elem.y = y;
	elem.alignX = align_x;
	elem.alignY = align_y;
	elem.horzAlign = horz_align;
	elem.vertAlign = vert_align;
	elem.foreground = true;
	elem.hidewheninmenu = true;
	elem.sort = 1;
	elem.alpha = 1;
	elem setshader( shader, width, height );
	level.pv_hud_elems[ level.pv_hud_elems.size ] = elem;
	return elem;
}

// the vehicle HUD fades out under the mission failed / death screen, like the stock HUD
pv_hud_hide_on_fail()
{
	thread pv_hud_hide_on_death();
	flag_wait( "missionfailed" );
	pv_hud_hide();
}

pv_hud_hide_on_death()
{
	level.player waittill( "death" );
	pv_hud_hide();
}

pv_hud_hide()
{
	if ( isdefined( level.pv_hud_hidden ) )
		return;
	level.pv_hud_hidden = true;

	// the vehicle HUD loops leave the elements alone once the vehicle has no HUD
	if ( isdefined( level.pv_active ) && isdefined( level.pv_active.pv ) )
		level.pv_active.pv.hud = undefined;
	pv_help_destroy();

	for ( i = 0; i < level.pv_hud_elems.size; i++ )
	{
		if ( !isdefined( level.pv_hud_elems[ i ] ) )
			continue;
		level.pv_hud_elems[ i ] fadeOverTime( 0.5 );
		level.pv_hud_elems[ i ].alpha = 0;
	}
}

pv_hud_destroy_all()
{
	if ( !isdefined( level.pv_hud_elems ) )
		return;

	for ( i = 0; i < level.pv_hud_elems.size; i++ )
	{
		if ( isdefined( level.pv_hud_elems[ i ] ) )
			level.pv_hud_elems[ i ] destroy();
	}
	level.pv_hud_elems = [];
}

pv_hud_set_color( elems, color )
{
	for ( i = 0; i < elems.size; i++ )
		elems[ i ].color = color;
}

// smooth reticle movement between server frames
pv_hud_move( elem, pos, visible_alpha )
{
	if ( !isdefined( pos ) || abs( pos[ 0 ] ) > 420 || abs( pos[ 1 ] ) > 235 )
	{
		elem.alpha = 0;
		return;
	}

	elem moveOverTime( 0.05 );
	elem.x = pos[ 0 ];
	elem.y = pos[ 1 ];
	elem.alpha = visible_alpha;
}

// time based blink used by the per frame HUD loops: true during the "on" part of the period
pv_blink_on( period_ms )
{
	return ( ( gettime() % period_ms ) < ( period_ms * 0.5 ) );
}

/*
=============
///ScriptDocBegin
"Name: pv_show_help( <title>, <lines>, <duration> )"
"Summary: Shows a controls panel on the left side of the screen for <duration> seconds."
"Module: PlayerVehicle"
"SPMP: singleplayer"
///ScriptDocEnd
=============
*/
pv_show_help( title, lines, duration )
{
	pv_help_destroy();
	level endon( "pv_help_destroy" );

	level.pv_help_elems = [];
	y = -40 - ( lines.size * 7 );

	elem = pv_help_text( "objective", 1.6, y );
	elem settext( title );
	y = y + 22;

	for ( i = 0; i < lines.size; i++ )
	{
		elem = pv_help_text( "default", 1.25, y );
		elem settext( lines[ i ] );
		y = y + 15;
	}

	for ( i = 0; i < level.pv_help_elems.size; i++ )
	{
		level.pv_help_elems[ i ] fadeOverTime( 0.6 );
		level.pv_help_elems[ i ].alpha = 0.9;
	}

	wait duration;

	for ( i = 0; i < level.pv_help_elems.size; i++ )
	{
		level.pv_help_elems[ i ] fadeOverTime( 1.5 );
		level.pv_help_elems[ i ].alpha = 0;
	}

	wait 1.5;
	pv_help_destroy();
}

pv_help_text( font, scale, y )
{
	elem = newHudElem();
	elem.font = font;
	elem.fontScale = scale;
	elem.x = 20;
	elem.y = y;
	elem.alignX = "left";
	elem.alignY = "middle";
	elem.horzAlign = "left";
	elem.vertAlign = "middle";
	elem.foreground = true;
	elem.hidewheninmenu = true;
	elem.sort = 3;
	elem.alpha = 0;
	elem.glowColor = ( 0.3, 0.6, 0.3 );
	elem.glowAlpha = 0;
	level.pv_help_elems[ level.pv_help_elems.size ] = elem;
	return elem;
}

pv_help_destroy()
{
	// destroy first: the notify ends the help thread if it is the one calling us
	if ( isdefined( level.pv_help_elems ) )
	{
		for ( i = 0; i < level.pv_help_elems.size; i++ )
		{
			if ( isdefined( level.pv_help_elems[ i ] ) )
				level.pv_help_elems[ i ] destroy();
		}
	}
	level.pv_help_elems = [];

	level notify( "pv_help_destroy" );
}

/******************************************************/
/*                        MATH                        */
/******************************************************/

// signed difference a - b wrapped to -180..180
pv_angle_diff( a, b )
{
	diff = a - b;
	while ( diff > 180 )
		diff -= 360;
	while ( diff < -180 )
		diff += 360;
	return diff;
}

pv_clamp( value, low, high )
{
	if ( value < low )
		return low;
	if ( value > high )
		return high;
	return value;
}

pv_max( a, b )
{
	if ( a > b )
		return a;
	return b;
}

pv_min( a, b )
{
	if ( a < b )
		return a;
	return b;
}

// ground height straight below a point, ignoring <ignore_ent>. undefined if nothing is hit.
pv_ground_z( origin, ignore_ent )
{
	trace = bullettrace( origin, origin - ( 0, 0, 30000 ), false, ignore_ent );
	if ( trace[ "fraction" ] >= 1 )
		return undefined;
	return trace[ "position" ][ 2 ];
}

/******************************************************/
/*                    KILL CREDIT                     */
/******************************************************/

// Weapons the vehicle code does not tie to the player ( the script flown Cobra has no vehicle owner,
// the tank's coax is a turret of its own ) are marked with pv_credit_player. While the player is in a
// vehicle their damage on AI is passed on to maps\_friendlyfire as his own, like the stock tank gun:
// shooting friendlies fails the mission, enemy kills earn participation points.
pv_damage_credit_monitor()
{
	for ( ;; )
	{
		wait 0.5;
		if ( !isdefined( level.pv_active ) )
			continue;

		ai = getaiarray();
		for ( i = 0; i < ai.size; i++ )
		{
			if ( isdefined( ai[ i ].pv_credit_watch ) )
				continue;
			ai[ i ].pv_credit_watch = true;
			ai[ i ] thread pv_damage_credit_watch();
		}
	}
}

pv_damage_credit_watch()
{
	self thread pv_kill_credit_watch();
	self endon( "death" );

	for ( ;; )
	{
		self waittill( "damage", damage, attacker, direction, point, method );
		if ( self.health > 0 && pv_credited_attacker( attacker ) )
			self notify( "friendlyfire_notify", damage, level.player, direction, point, method );
	}
}

// kills are booked here directly: by the time a notify could reach maps\_friendlyfire its watcher on the
// dead AI has already given up
pv_kill_credit_watch()
{
	team = self.team;
	self waittill( "death", attacker );
	if ( !pv_credited_attacker( attacker ) || !isdefined( team ) || !isdefined( level.friendlyfire ) )
		return;

	if ( team != level.player.team )
	{
		level.player.participation += level.friendlyfire[ "enemy_kill_points" ];
		maps\_friendlyfire::participation_point_cap();
		return;
	}

	if ( isdefined( self ) && ( isdefined( self.no_friendly_fire_penalty ) || ( isdefined( self.NoFriendlyfire ) && self.NoFriendlyfire ) ) )
		return;
	level.player.participation += level.friendlyfire[ "friend_kill_points" ];
	maps\_friendlyfire::participation_point_cap();
	maps\_friendlyfire::friendly_fire_checkPoints();
}

pv_credited_attacker( attacker )
{
	return ( isdefined( level.pv_active ) && isdefined( attacker ) && isdefined( attacker.pv_credit_player ) );
}

pv_is_friendly( attacker, vehicle )
{
	if ( !isdefined( attacker ) )
		return false;
	if ( attacker == level.player || attacker == vehicle )
		return true;
	if ( isdefined( attacker.team ) && attacker.team == "allies" )
		return true;
	if ( isdefined( attacker.script_team ) && attacker.script_team == "allies" )
		return true;
	return false;
}

pv_delete_after( time )
{
	self endon( "death" );
	wait time;
	self delete();
}

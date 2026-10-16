#include maps\_anim;
#include maps\_utility;
#include common_scripts\utility;
#include maps\_utility_code;
#include maps\_debug;
#include maps\_vehicle;
#include maps\_hud_util;

main()
{
	// vehicles placed in the map ( one line per vehicletype + model )
	maps\_cobra::main( "vehicle_cobra_helicopter_fly" );
	maps\_blackhawk::main( "vehicle_blackhawk_hero" );
	maps\_m1a1::main( "vehicle_m1a1_abrams" );
	maps\_t72::main( "vehicle_t72_tank" );
	maps\_bmp::main( "vehicle_bmp_desert" );
	maps\_slamraam::main( "vehicle_slamraam" );
	
	// player vehicles: precache, has to run before maps\_load::main()
	maps\_playervehicle_cobra::main();
	maps\_playervehicle_abrams::main();

	// The stock T-72 and SLAMRAAM scripts default to the allied team ( build_team( "allies" ) ), so without
	// a "script_team" key in Radiant they are friendlies: no lock-on, and the friendly fire shield of
	// _vehicle.gsc throws away all damage from the player. Enemy armour placed here without the key is
	// made axis; a script_team set in Radiant always wins.
	vehicles = getentarray( "script_vehicle", "classname" );
	for ( i = 0; i < vehicles.size; i++ )
	{
		if ( isdefined( vehicles[ i ].script_team ) || !isdefined( vehicles[ i ].vehicletype ) )
			continue;
		switch ( tolower( vehicles[ i ].vehicletype ) )
		{
			case "t72":
			case "bmp":
			case "slamraam":
				vehicles[ i ].script_team = "axis";
				break;
		}
	}

	maps\_load::main();

	// boarding is handled by the player vehicle scripts ( press use next to the vehicle )
	vehseat = getent( "vehseat", "targetname" );
	if ( isdefined( vehseat ) )
		vehseat delete();

	level.cobra = maps\_playervehicle_cobra::setup( getent( "cobra_player", "targetname" ) );
	level.abrams = maps\_playervehicle_abrams::setup();

	// the Black Hawk is flagged usable in the map, but the stock helicopter driving has no altitude or
	// yaw control on the PC, so it stays a static prop until it gets a player script of its own
	vehicles = getentarray( "script_vehicle", "classname" );
	for ( i = 0; i < vehicles.size; i++ )
	{
		if ( vehicles[ i ].vehicletype == "blackhawk" )
			vehicles[ i ] makevehicleunusable();
	}
}

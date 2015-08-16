/*
	Author: IT07

	Description:
	init for a3_epoch_garage
*/

diag_log "///////////////////////////////////////////";
diag_log "[EPOCH VGS] Starting server-side code...";
diag_log "\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\";

"EPOCH_vgsPV" addPublicVariableEventHandler
{
	_packet = [_this, 1, [], [[]]] call BIS_fnc_param;
	if (count _packet isEqualTo 0) exitWith {};
	if (count _packet > 2) exitWith {};
	_data = [_packet, 1, [],[[]]] call BIS_fnc_param;
	if (count _data isEqualTo 0) exitWith {};
	switch (_this select 1 select 0) do
	{
		case "Request":
		{
			if (count _data isEqualTo 2) then
			{
				Private ["_player","_exitLog"];
				_player = [_data, 0, objNull, [objNull]] call BIS_fnc_param; // Put sent value into var
				if isNull _player exitWith {};
				_key = [_data, 1, "", [""]] call BIS_fnc_param;
				if not([_player, _key] in (uiNamespace getVariable "EPOCH_vgsKeys")) exitWith {};
				// Data is valid let's get the cars from db and send it to client
				_playerUID = getPlayerUID _player;
				_response = [format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID] call EPOCH_server_hiveGET;
				if isNil"_response" then { _response = [1,[]] };
				if ((_response select 0) isEqualTo 1) then
				{
					if (typeName (_response select 1) isEqualTo "ARRAY") then
					{
						_vehs = _response select 1;
						if (count _vehs isEqualTo 0) then
						{
							_slots = "maxGarageSlots" call VGS_fnc_vgsGetServerSetting;
							for "_s" from 1 to _slots do
							{
								_vehs pushBack [];
							};
							// Save the array with empty slots into DB
							[format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID, _vehs] call EPOCH_server_hiveSET;
						};
						EPOCH_myVehs = _vehs;
						(owner _player) publicVariableClient "EPOCH_myVehs";
						diag_log format["[EPOCH VGS] Client %1 requested his/her vehicles. Result: %2", name _player, EPOCH_myVehs];
						EPOCH_myVehs = nil;
					};
				};
			};
		};

		case "Write":
		{
			if (count _data isEqualTo 5) then
			{
				_playerObj = [_data, 3, objNull, [objNull]] call BIS_fnc_param;
				if isNull _playerObj exitWith {};
				_key = [_data, 4, "", [""]] call BIS_fnc_param;
				if not([_playerObj, _key] in (uiNamespace getVariable "EPOCH_vgsKeys")) exitWith {};
				private ["_vehs"];
				// Get the given slot selected
				_slot = [_data, 0, -1, [0]] call BIS_fnc_param;
				_slots = "maxGarageSlots" call VGS_fnc_vgsGetServerSetting;
				if (_slot < 0) exitWith {};
	 			if (_slot > (_slots -1)) exitWith {};
				// Get the vehicle
				_vehObj = [_data, 1, objNull, [objNull]] call BIS_fnc_param;
				if isNull _vehObj exitWith {};
				if isPlayer _vehObj exitWith {};
				// do additional checks
				if not(owner _vehObj isEqualTo (owner _playerObj)) exitWith {};
				_blacklist = "vehBlacklist" call VGS_fnc_vgsGetServerSetting;
				if (typeOf _vehObj in _blacklist) exitWith {};
				_maxDist = "maxWriteDistance" call VGS_fnc_vgsGetServerSetting;
				if not(((position _playerObj) distance (position _vehObj)) < _maxDist) exitWith {};
				// Get the given vehicle name
				_name = [_data, 2, "", [""]] call BIS_fnc_param;
				if (_name isEqualTo "") exitWith {};
				// Get the player
				diag_log format["[EPOCH VGS] EPOCH_vgsWrite: _data = %1", _data];
				// Define player's UID
				_playerUID = getPlayerUID _playerObj;
				// Define the classname of _veh
				_typeOf = typeOf _vehObj;
				// Get the storage usage
				_gear = "W.I.P.";
				// Get the fuel level of _veh
				_fuel = fuel _vehObj;
				// Get the hitPoint(s) damage of given vehicle
				_hitPoints = [configFile >> "CfgVehicles" >> _typeOf >> "HitPoints",0] call BIS_fnc_returnChildren;
				_maxDamage = count _hitPoints;
				_overallDamage = 0;
				_damagedParts = [];
				{
					if (_vehObj getHitPointDamage (configName _x) > 0) then
					{
						_partDamage = _vehObj getHitPointDamage (configName _x);
						_overallDamage = _overallDamage + _partDamage;
						_damagedParts pushBack [configName _x, _partDamage];
					};
				} forEach _hitPoints;
				_damage = (_overallDamage/_maxDamage)*100;
				// Get existing vehicles
				_response = [format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID] call EPOCH_server_hiveGET;
				if ((_response select 0) isEqualTo 1) then
				{
					if (typeName (_response select 1) isEqualTo "ARRAY") then
					{
						_vehs = _response select 1;
						if not(count (_vehs select _slot) isEqualTo 0) then
						{ // If there is already a vehicle, clear it
							_vehs set [_slot, []];
						};
						{
							(_vehs select _slot) pushBack _x
						} forEach [_name, _typeOf, _damage, _gear, _fuel, _damagedParts];
						[format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID, _vehs] call EPOCH_server_hiveSET;
						{
							moveOut _x;
						} forEach (crew _vehObj);
						_vehObj setDamage 1;
						deleteVehicle _vehObj;
						EPOCH_myVehs = _vehs;
						(owner _playerObj) publicVariableClient "EPOCH_myVehs";
						diag_log format["[EPOCH VGS] Client (%1) put his/her %2 in garage", name _playerObj, _typeOf];
						EPOCH_myVehs = nil;
					};
				};
			};
		};

		case "Read":
		{
			if (count _data isEqualto 3) then
			{
				_playerObj = [_data, 1, objNull, [objNull]] call BIS_fnc_param;
				if isNull _playerObj exitWith {};
				_key = [_data, 2, "", [""]] call BIS_fnc_param;
				if not([_playerObj, _key] in (uiNamespace getVariable "EPOCH_vgsKeys")) exitWith {};
				private ["_vehs"];
				_requested = [_data, 0, -1, [0]] call BIS_fnc_param;
				if (_requested < 0) exitWith {};
				_playerUID = getPlayerUID _playerObj;
				_response = [format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID] call EPOCH_server_hiveGET;
				if ((_response select 0) isEqualTo 1) then
				{
					if (typeName (_response select 1) isEqualTo "ARRAY") then
					{
						_vehs = _response select 1;
						if (_requested > (count _vehs)-1) exitWith {};
	 					if (_requested < 0) exitWith {};
						_toSpawn = _vehs select _requested;
						if (count _toSpawn isEqualto 0) exitWith { diag_log"[EPOCH VGS] Attempt to spawn vehicle from empty slot"; };
						_vehs set [_requested, []];
						[format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID, _vehs] call EPOCH_server_hiveSET;
						_fuel = _toSpawn select 4;
						_hitPoints = _toSpawn select 5;
						_pos = [position _playerObj, 2, 20, 1, 0, 5, 0] call bis_fnc_findSafePos;
						_veh = createVehicle [_toSpawn select 1, _pos, [], 0, "NONE"];
						_veh call EPOCH_server_setVToken;
						if (count _hitPoints > 0) then
						{
							{
								_veh setHitPointDamage [_x select 0, _x select 1];
							} forEach _hitPoints;
	 					};
						_veh setFuel _fuel;
						_veh setVehicleLock "LOCKEDPLAYER";
						if (_veh isKindOf "Car") then
						{
							_veh engineOn true;
						};
						_veh setOwner (owner _playerObj);
						// Refetch the vehicles from db and send it to Client
						_response = [format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID] call EPOCH_server_hiveGET;
						if ((_response select 0) isEqualTo 1) then
						{
							if (typeName (_response select 1) isEqualTo "ARRAY") then
							{
								EPOCH_myVehs = _response select 1;
								(owner _playerObj) publicVariableClient "EPOCH_myVehs";
								diag_log format["[EPOCH VGS] Client %1 took his/her %2 from garage", name _playerObj, _toSpawn select 1];
								EPOCH_myVehs = nil;
							};
						};
					};
				};
			};
		};
		case "Repair":
		{
			if (count _data isEqualTo 3) then
			{
				_player = [_data, 1, objNull, [objNull]] call BIS_fnc_param;
				if isNull _player exitWith {};
				_key = [_data, 2, "", [""]] call BIS_fnc_param;
				if not([_player, _key] in (uiNamespace getVariable "EPOCH_vgsKeys")) exitWith {};
				_slot = [_data, 0, -1, [0]] call BIS_fnc_param;
				if (_slot < 0) exitWith {};
				if (_slot > (("maxGarageSlots" call VGS_fnc_vgsGetServerSetting)+1)) exitWith {};
				_playerUID = getPlayerUID _player;
				_response = [format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID] call EPOCH_server_hiveGET;
				if ((_response select 0) isEqualTo 1) then
				{
					if (typeName (_response select 1) isEqualTo "ARRAY") then
					{
						_vehs = _response select 1;
						(_vehs select _slot) set [2, 0];
						(_vehs select _slot) set [5, []];
						[format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID, _vehs] call EPOCH_server_hiveSET;
						EPOCH_myVehs = _vehs;
						(owner _player) publicVariableClient "EPOCH_myVehs";
						diag_log format["[EPOCH VGS] Client %1 repaired his/her %2", name _player, (_vehs select _slot) select 1];
						EPOCH_myVehs = nil;
					};
				};
			};
		};
		case "Trash":
		{
			if (count _data isEqualTo 3) then
			{
				_player = [_data, 1, objNull, [objNull]] call BIS_fnc_param;
				if isNull _player exitWith {};
				_key = [_data, 2, "", [""]] call BIS_fnc_param;
				if not([_player, _key] in (uiNamespace getVariable "EPOCH_vgsKeys")) exitWith {};
				_slot = [_data, 0, -1, [0]] call BIS_fnc_param;
				if (_slot < 0) exitWith {};
				if (_slot > (("maxGarageSlots" call VGS_fnc_vgsGetServerSetting)+1)) exitWith {};
				_playerUID = getPlayerUID _player;
				_response = [format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID] call EPOCH_server_hiveGET;
				if ((_response select 0) isEqualTo 1) then
				{
					if (typeName (_response select 1) isEqualTo "ARRAY") then
					{
						_vehs = _response select 1;
						_vehs set [_slot, []];
						[format["EPOCH_vgsOwnedVehs_%1", _playerUID], _playerUID, _vehs] call EPOCH_server_hiveSET;
						EPOCH_myVehs = _vehs;
						(owner _player) publicVariableClient "EPOCH_myVehs";
						EPOCH_myVehs = nil;
					};
				};
			};
		};
		default {};
	};
};

[] spawn
{ // My cute little secure and unbreakable key generator/sender :)
	_givenTo = [];
	uiNamespace setVariable ["EPOCH_vgsKeys", []];
	while {true} do
	{
		if not(count _givenTo isEqualTo 0) then
		{ // If _givenTo array isn't empty, loop through it to see if there are any non-existent units in it
			private ["_rem"];
			_rem = [];
			{
				if isNull _x then
				{
					_rem pushBack _x;
				};
			} forEach _givenTo;
			if not(count _rem isEqualTo 0) then
			{
				{
					_index = _givenTo find _x;
					_givenTo deleteAt _index;
				} forEach _rem;
			};
		};

		if not(count playableUnits isEqualTo 0) then
		{
			_keys = uiNamespace getVariable "EPOCH_vgsKeys";
			{
				if not(_x in _givenTo) then
				{
					if (side _x isEqualTo EAST) then
					{
						_key = call VGS_fnc_vgsGenKey;
						_keys pushBack [_x, _key];
						EPOCH_vgsMyKey = _key;
						(owner _x) publicVariableClient "EPOCH_vgsMyKey";
						EPOCH_vgsMyKey = nil;
						_givenTo pushBack _x;
					};
				};
			} forEach playableUnits;
		};
		uiSleep 1;
	};
};
diag_log "[EPOCH VGS] all Code loaded!";

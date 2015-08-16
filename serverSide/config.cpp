/*
	Author: IT07

	Description:
	config.cpp of the VGS server-side pbo.
*/

class cfgVGS
{
	maxGarageSlots = 4; // Self-explenatory, right?
	maxWriteDistance = 10; // Maximum distance the vehicle can be away from the player when put into garage
	vehBlacklist[] = {"O_Truck_Big_cock_F"}; // Put classnames of disallowed vehicles in here
};

class CfgPatches
{
	class a3_epoch_virtualGarage
	{
		units[] = {};
		weapons[] = {};
		requiredAddons[] = {};
		fileName = "a3_epoch_virtualGarage.pbo";
		author[]= {"IT07"};
		version = "CLOSED_ALPHA";
	};
};
class cfgFunctions
{
	class VirtualGarageSystem
	{
		tag = "VGS";
		class fnc
		{
			file = "\a3_epoch_virtualGarage\functions_VGS";
			class vgsGetServerSetting {};
			class vgsGenKey {};
			class vgsInitServer { postInit = 1; };
		};
	};
};

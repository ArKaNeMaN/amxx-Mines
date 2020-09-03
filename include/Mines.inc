#define _awmines_included

#if !defined _reapi_included
	#include <reapi>
#endif

new const MINE_CLASSNAME[] = "mine";
new const MINE_BLOW_CLASSNAME[] = "mineBlow";

#define var_MineOwner var_owner

#define Mines_FindMine(%1) rg_find_ent_by_class(%1,MINE_CLASSNAME)
#define Mines_FindUserMine(%1,%2) rg_find_ent_by_owner(%1,%2)
#define Mines_GetMineOwner(%1) get_entvar(%1,var_MineOwner)

#define MINES_FWD_STOP 1
#define MINES_FWD_CONT 0

forward Mines_PlantPre(const Mine, Float:Origin[3]);
forward Mines_PlantPost(const Mine);
forward Mines_BlowPre(const Mine);
forward Mines_BlowPost(const Mine);
forward Mines_RemovePre(const Mine);
forward Mines_RemovePost(const Mine);

/**
* Sets the mine at the specified coordinates
*
* @param UserId		ID of the player
* @param Origin		Coords of mine
*
* @return		Number of mines set by the player
*/
native Mines_SetMine(const UserId, const Float:Origin[3]);

/**
* Blow mine
*
* @param Mine		ID of mine
*
* @noreturn
*/
native Mines_BlowMine(const Mine);

/**
* Remove mine
*
* @param Mine		ID of mine
*
* @noreturn
*/
native Mines_RemoveMine(const Mine);

/**
* Remove all user's mines
*
* @param UserId		ID of player
*
* @noreturn
*/
native Mines_RemoveAllUserMines(const UserId);

/**
* Remove all mines
*
* @noreturn
*/
native Mines_RemoveAllMines();

/**
* @param ent	ID of entity
*
* @return		true if entity is mine, else false
*/
stock bool:Mines_IsMine(ent){
	static classname[32]; get_entvar(ent, var_classname, classname, charsmax(classname));
	return bool:equal(classname, MINE_CLASSNAME);
}
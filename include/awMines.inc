#define _awmines_included

#if !defined _reapi_included
	#include <reapi>
#endif

new const MINE_CLASSNAME[] = "aw_mine";
new const MINE_BLOW_CLASSNAME[] = "aw_mineBlow";

#define MINE_OWNER_VAR var_iuser1

#define awMines_findMineEnts(%1) rg_find_ent_by_class(%1,MINE_CLASSNAME)
#define awMines_getMineOwner(%1) get_entvar(%1,MINE_OWNER_VAR)

#define MINES_FWD_STOP 1
#define MINES_FWD_CONT 0

forward awMines_fwdPantPre(mine, Float:origin[3]);
forward awMines_fwdPantPost(mine);
forward awMines_fwdBlowPre(mine);
forward awMines_fwdBlowPost(mine);
forward awMines_fwdRemovePre(mine);
forward awMines_fwdRemovePost(mine);

/**
* @param id		ID of the player
*
* @return		Number of mines set by the player
*/
native awMines_getUserMinesCount(id);

/**
* Sets the mine at the specified coordinates
*
* @param owner		ID of the player
* @param origin		Coords of mine
*
* @return		Number of mines set by the player
*/
native awMines_setMine(owner, Float:origin[3]);

/**
* Blow mine
*
* @param mine		ID of mine
*
* @noreturn
*/
native awMines_blowMine(mine);

/**
* Remove mine
*
* @param mine		ID of mine
*
* @noreturn
*/
native awMines_removeMine(mine);

/**
* Remove all user's mines
*
* @param id		ID of player
*
* @noreturn
*/
native awMines_removeAllUserMines(id);

/**
* Remove all mines
*
* @noreturn
*/
native awMines_removeAllMines();

/**
* @param ent	ID of entity
*
* @return		true if entity is mine, else false
*/
stock bool:awMines_isMine(ent){
	static classname[32]; get_entvar(ent, var_classname, classname, charsmax(classname));
	return bool:equal(classname, MINE_CLASSNAME);
}
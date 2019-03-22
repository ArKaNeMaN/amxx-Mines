#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <reapi>

#define MINE_CLASSNAME "aw_mine"
#define MINE_BLOW_CLASSNAME "aw_mineBlow"
#define MINE_MODEL "models/awMines/mine.mdl"
#define MINE_BLOW_SOUND "weapons/hegrenade-1.wav"
#define MINE_PLANT_SOUND "weapons/c4_disarmed.wav"
#define MINE_BLOW_SPRITE "sprites/awMines/blow.spr"
#define USER_MAX_MINES 5
#define MINE_OWNER_VAR var_iuser1
#define MINE_DAMAGE 80.0
#define MINE_RADIUS 100.0

#define isUser(%1) (%1>0&&%1<=MAX_PLAYERS)

new Array:uMines[MAX_PLAYERS+1];

#define PLUG_NAME "Mines"
#define PLUG_VER "0.1"

public plugin_init(){
	register_plugin(PLUG_NAME, PLUG_VER, "ArKaNeMaN");
	
	register_clcmd("set_mine", "cmdSetMine");
	
	RegisterHookChain(RG_RoundEnd, "roundEnd");
	
	server_print("[%s v%s] loaded.", PLUG_NAME, PLUG_VER);
}

public plugin_end(){
	for(new i = 0; i <= MAX_PLAYERS; i++) ArrayDestroy(uMines[i]);
}

public plugin_precache(){
	precache_model(MINE_MODEL);
	
	precache_model(MINE_BLOW_SPRITE);
	
	precache_sound(MINE_BLOW_SOUND);
	precache_sound(MINE_PLANT_SOUND);
}

public client_putinserver(id){
	uMines[id] = ArrayCreate();
}

public client_disconnected(id){
	removeAllUserMines(id);
	ArrayDestroy(uMines[id]);
}

public cmdSetMine(id){
	if(!is_user_alive(id)) return PLUGIN_CONTINUE;
	
	static Float:fOrigin[3]; fm_get_aim_origin(id, fOrigin);
	static minesCount; minesCount = ArraySize(uMines[id]);
	
	if(minesCount < USER_MAX_MINES) setMine(id, fOrigin);
	else client_print(id, print_center, "Исчерпан лимит мин (%d/%d)", minesCount, USER_MAX_MINES);
	
	return PLUGIN_CONTINUE;
}

public mineTouch(mine, id){
	if(!isUser(id)) return;
	blowMine(mine);
}

public roundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay){
	removeAllMines();
}

setMine(owner, Float:origin[3]){
	if(!isUser(owner)) return 0;
	
	static mine; mine = rg_create_entity("info_target");
	
	set_entvar(mine, var_classname, MINE_CLASSNAME);
	set_entvar(mine, var_origin, origin);
	//set_entvar(mine, var_model, MINE_MODEL);
	engfunc(EngFunc_SetModel, mine, MINE_MODEL);
	set_entvar(mine, MINE_OWNER_VAR, owner);
	
	set_entvar(mine, var_movetype, MOVETYPE_NONE);
	set_entvar(mine, var_fixangle, 1);
	set_entvar(mine, var_flags, get_entvar(mine, var_flags)|FL_ONGROUND);
	set_entvar(mine, var_solid, SOLID_TRIGGER);
	engfunc(EngFunc_SetSize, mine, Float:{-15.0, -15.0, -1.0}, Float:{15.0, 15.0, 5.0});
	engfunc(EngFunc_DropToFloor, mine);
	
	SetTouch(mine, "mineTouch");
	
	rh_emit_sound2(mine, 0, CHAN_ITEM, MINE_PLANT_SOUND);
	
	ArrayPushCell(uMines[owner], mine);
	return mine;
}

blowMine(mine){
	static Float:origin[3]; get_entvar(mine, var_origin, origin);
	static owner; owner = get_entvar(mine, MINE_OWNER_VAR);
	
	rg_dmg_radius(origin, mine, owner, MINE_DAMAGE, MINE_RADIUS, 0, DMG_BLAST);
	blowAnim(origin);
	rh_emit_sound2(mine, 0, CHAN_WEAPON, MINE_BLOW_SOUND);
	
	removeMine(mine);
}

blowAnim(Float:origin[3]){
	static blow; blow = rg_create_entity("env_sprite");
	
	set_entvar(blow, var_classname, MINE_BLOW_CLASSNAME);
	set_entvar(blow, var_model, MINE_BLOW_SPRITE);
	set_entvar(blow, var_origin, origin);
	
	set_entvar(blow, var_effects, EF_BRIGHTLIGHT);
	set_entvar(blow, var_rendermode, kRenderTransAdd);
	set_entvar(blow, var_renderamt, 200.0);
	set_entvar(blow, var_framerate, 20.0);
	set_entvar(blow, var_scale, 2.0);
	set_entvar(blow, var_spawnflags, SF_SPRITE_STARTON);
	
	//set_entvar(blow, var_ltime, 2.0);
	set_task(1.3, "rmBlowSpr", blow);
	
	dllfunc(DLLFunc_Spawn, blow);
	
	set_entvar(blow, var_movetype, MOVETYPE_NONE);
}

public rmBlowSpr(id){
	set_entvar(id, var_flags, FL_KILLME);
}

removeMine(mine){
	static owner; owner = get_entvar(mine, MINE_OWNER_VAR);
	static item; item = ArrayFindValue(uMines[owner], mine);
	if(item > -1) ArrayDeleteItem(uMines[owner], item);
	set_entvar(mine, var_flags, FL_KILLME);
}

removeAllMines(){
	new mine = 1;
	while((mine = rg_find_ent_by_class(mine, MINE_CLASSNAME)) > 0){
		log_amx("[Ent: %d]", mine);
		removeMine(mine);
	}
}

removeAllUserMines(id){
	for(new i = 0; i < ArraySize(uMines[id]); i++) removeMine(i);
}
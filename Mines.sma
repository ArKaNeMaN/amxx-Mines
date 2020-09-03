#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <reapi>
#include <Mines>

new const MINE_MODEL[] = "models/Mines/Mine.mdl";
new const MINE_BLOW_SPRITE[] = "sprites/Mines/Blow.spr";
new const MINE_BLOW_SOUND[] = "Mines/Blow.wav";
new const MINE_PLANT_SOUND[] = "Mines/Plant.wav";
#define DETECT_ONLY_PLAYERS // Срабатывание только на игроков
#define MINE_DAMAGE 80.0
#define MINE_RADIUS 100.0
#define SET_MINE_CMD "set_mine" // Закомментировать, чтобы отключить команду (По сути без этого плагин становится просто инстументом для работы с минами)
#if defined SET_MINE_CMD
	//#define ADD_MINES_INVENTORY // Инвентарь мин
	//#define SHOW_MINES_REST // При установке показывает остаток мин
#endif

#define isUser(%1) (%1>0&&%1<=MAX_PLAYERS)

enum e_Fwds{
	Fwd_PlantPre,
	Fwd_PlantPost,
	Fwd_BlowPre,
	Fwd_BlowPost,
	Fwd_RemovePre,
	Fwd_RemovePost,
}

new Fwds[e_Fwds];

new Array:uMines[MAX_PLAYERS+1];

new const PLUG_NAME[] = "Mines";
new const PLUG_VER[] = "0.2";

public plugin_init(){
	register_plugin(PLUG_NAME, PLUG_VER, "ArKaNeMaN");
	
	RegisterHookChain(RG_RoundEnd, "roundEnd");
	
	Fwds[fwd_plantPre] = CreateMultiForward("awMines_fwdPantPre", ET_CONTINUE, FP_CELL, FP_ARRAY);
	Fwds[fwd_plantPost] = CreateMultiForward("awMines_fwdPantPost", ET_CONTINUE, FP_CELL);
	Fwds[fwd_blowPre] = CreateMultiForward("awMines_fwdBlowPre", ET_CONTINUE, FP_CELL);
	Fwds[fwd_blowPost] = CreateMultiForward("awMines_fwdBlowPost", ET_CONTINUE, FP_CELL);
	Fwds[fwd_removePre] = CreateMultiForward("awMines_fwdRemovePre", ET_CONTINUE, FP_CELL);
	Fwds[fwd_removePost] = CreateMultiForward("awMines_fwdRemovePost", ET_CONTINUE, FP_CELL);
	
	server_print("[%s v%s] loaded.", PLUG_NAME, PLUG_VER);
}

public plugin_end(){
	for(new i = 0; i <= MAX_PLAYERS; i++)
		if(uMines[i])
			ArrayDestroy(uMines[i]);
}

public plugin_precache(){
	precache_model(MINE_MODEL);
	
	precache_model(MINE_BLOW_SPRITE);
	
	precache_sound(MINE_BLOW_SOUND);
	precache_sound(MINE_PLANT_SOUND);
}

public client_putinserver(id){
	uMines[id] = ArrayCreate();
	#if defined ADD_MINES_INVENTORY
	uMinesInv[id] = 0;
	#endif
}

public client_disconnected(id){
	removeAllUserMines(id);
	ArrayDestroy(uMines[id]);
	#if defined ADD_MINES_INVENTORY
	uMinesInv[id] = 0;
	#endif
}

public mineTouch(mine, id){
	#if defined DETECT_ONLY_PLAYERS
	if(!isUser(id)) return;
	#endif
	blowMine(mine);
}

public roundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay){
	removeAllMines();
}

setMine(owner, Float:origin[3]){
	if(!isUser(owner)) return 0;
	
	new ret = MINES_FWD_CONT;
	ExecuteForward(Fwds[fwd_plantPre], ret, owner, origin);
	
	if(ret == MINES_FWD_STOP) return 0;
	
	static mine; mine = rg_create_entity("info_target");
	
	set_entvar(mine, var_classname, MINE_CLASSNAME);
	set_entvar(mine, var_origin, origin);
	engfunc(EngFunc_SetModel, mine, MINE_MODEL);
	set_entvar(mine, MINE_OWNER_VAR, owner);
	
	set_entvar(mine, var_movetype, MOVETYPE_NONE);
	set_entvar(mine, var_fixangle, 1);
	set_entvar(mine, var_flags, get_entvar(mine, var_flags)|FL_ONGROUND);
	set_entvar(mine, var_solid, SOLID_TRIGGER);
	engfunc(EngFunc_SetSize, mine, Float:{-15.0, -15.0, -1.0}, Float:{15.0, 15.0, 5.0});
	engfunc(EngFunc_DropToFloor, mine);
	
	SetTouch(mine, "mineTouch");
	
	ExecuteForward(Fwds[fwd_plantPost], ret, mine);
	
	rh_emit_sound2(mine, 0, CHAN_ITEM, MINE_PLANT_SOUND);
	
	ArrayPushCell(uMines[owner], mine);
	return mine;
}

blowMine(mine){
	if(!awMines_isMine(mine)) return;
	
	new ret = MINES_FWD_CONT;
	ExecuteForward(Fwds[fwd_blowPre], ret, mine);
	if(ret == MINES_FWD_STOP) return;
	
	static Float:origin[3]; get_entvar(mine, var_origin, origin);
	static owner; owner = awMines_getMineOwner(mine);
	
	rg_dmg_radius(origin, mine, owner, MINE_DAMAGE, MINE_RADIUS, 0, DMG_BLAST);
	blowAnim(origin);
	rh_emit_sound2(mine, 0, CHAN_WEAPON, MINE_BLOW_SOUND);
	
	ExecuteForward(Fwds[fwd_blowPost], ret, mine);
	
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
	
	set_task(1.3, "rmBlowSpr", blow);
	
	dllfunc(DLLFunc_Spawn, blow);
	
	set_entvar(blow, var_movetype, MOVETYPE_NONE);
}

public rmBlowSpr(id){
	set_entvar(id, var_flags, FL_KILLME);
}

removeMine(mine){
	if(!awMines_isMine(mine)) return;
	
	new ret = MINES_FWD_CONT;
	ExecuteForward(Fwds[fwd_removePre], ret, mine);
	if(ret == MINES_FWD_STOP) return;
	
	static owner; owner = awMines_getMineOwner(mine);
	static item; item = ArrayFindValue(uMines[owner], mine);
	if(item > -1) ArrayDeleteItem(uMines[owner], item);
	set_entvar(mine, var_flags, FL_KILLME);
	
	ExecuteForward(Fwds[fwd_removePost], ret, mine);
}

removeAllMines(){
	static Mine = 1;
	while((mine = awMines_FindMine(Mine)) > 0)
		removeMine(mine);
}

removeAllUserMines(id){
	for(new i = 0; i < ArraySize(uMines[id]); i++)
		removeMine(i);
}


public plugin_natives(){
	register_native("awMines_getUserMinesCount", "_getUserMinesCount");
	register_native("awMines_setMine", "_setMine");
	register_native("awMines_blowMine", "_blowMine");
	register_native("awMines_removeMine", "_removeMine");
	register_native("awMines_removeAllMines", "_removeAllMines");
	register_native("awMines_removeAllUserMines", "_removeAllUserMines");
}

public _getUserMinesCount(){
	static id; id = get_param(1);
	if(!isUser(id) || !is_user_connected(id)) log_error(AMX_ERR_PARAMS, "Client %d not found", id);
	return ArraySize(uMines[id]);
}

public _setMine(){
	static Float:origin[3]; get_array_f(2, origin, 3);
	return setMine(get_param(1), origin);
}

public _blowMine(){
	static mine; mine = get_param(1);
	if(!awMines_isMine(mine)) log_error(AMX_ERR_PARAMS, "Entity %d isn't mine", mine);
	blowMine(mine);
}

public _removeMine(){
	static mine; mine = get_param(1);
	if(!awMines_isMine(mine)) log_error(AMX_ERR_PARAMS, "Entity %d isn't mine", mine);
	removeMine(mine);
}

public _removeAllMines(){
	removeAllMines();
}

public _removeAllUserMines(){
	removeAllUserMines(get_param(1));
}
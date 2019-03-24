#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <reapi>
#include <awMines>

new const MINE_MODEL[] = "models/awMines/mine.mdl";
new const MINE_BLOW_SPRITE[] = "sprites/awMines/blow.spr";
new const MINE_BLOW_SOUND[] = "awMines/blow.wav";
new const MINE_PLANT_SOUND[] = "awMines/plant.wav";
#define DETECT_ONLY_PLAYERS // Срабатывание только на игроков
#define MINE_DAMAGE 80.0
#define MINE_RADIUS 100.0
#define SET_MINE_CMD "set_mine" // Закомментировать, чтобы отключить команду (По сути без этого плагин становится просто инстументом для работы с минами)
#if defined SET_MINE_CMD
	//#define ADD_MINES_INVENTORY // Инвентарь мин
	//#define SHOW_MINES_REST // При установке показывает остаток мин
#endif

#define isUser(%1) (%1>0&&%1<=MAX_PLAYERS)

enum e_fwds{
	fwd_plantPre,
	fwd_plantPost,
	fwd_blowPre,
	fwd_blowPost,
	fwd_removePre,
	fwd_removePost,
}

new fwds[e_fwds];

new Array:uMines[MAX_PLAYERS+1];
#if defined ADD_MINES_INVENTORY
new uMinesInv[MAX_PLAYERS+1];
#endif

#define PLUG_NAME "Mines"
#define PLUG_VER "0.2"

public plugin_init(){
	register_plugin(PLUG_NAME, PLUG_VER, "ArKaNeMaN");
	
	#if defined SET_MINE_CMD
	register_clcmd(SET_MINE_CMD, "cmdSetMine");
	#endif
	
	RegisterHookChain(RG_RoundEnd, "roundEnd");
	
	fwds[fwd_plantPre] = CreateMultiForward("awMines_fwdPantPre", ET_CONTINUE, FP_CELL, FP_ARRAY);
	fwds[fwd_plantPost] = CreateMultiForward("awMines_fwdPantPost", ET_CONTINUE, FP_CELL);
	fwds[fwd_blowPre] = CreateMultiForward("awMines_fwdBlowPre", ET_CONTINUE, FP_CELL);
	fwds[fwd_blowPost] = CreateMultiForward("awMines_fwdBlowPost", ET_CONTINUE, FP_CELL);
	fwds[fwd_removePre] = CreateMultiForward("awMines_fwdRemovePre", ET_CONTINUE, FP_CELL);
	fwds[fwd_removePost] = CreateMultiForward("awMines_fwdRemovePost", ET_CONTINUE, FP_CELL);
	
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

#if defined SET_MINE_CMD
public cmdSetMine(id){
	if(!is_user_alive(id)) return PLUGIN_CONTINUE;
	
	#if defined ADD_MINES_INVENTORY
	if(uMinesInv[id] > 0){
		#if defined SHOW_MINES_REST
		client_print(id, print_center, "У вас закончились мины");
		#endif
		return PLUGIN_CONTINUE;
	}
	#endif
	
	static Float:fOrigin[3]; fm_get_aim_origin(id, fOrigin);
	
	#if defined ADD_MINES_INVENTORY
	static mine; mine = setMine(id, fOrigin);
	if(mine){
		uMinesInv[id]--;
		#if defined SHOW_MINES_REST
		new temp = uMinesInv[id] % 10 == 1;
		client_print(id, print_center, "У вас остал%sсь %d мин%s",
			(temp == 1) ? "а" : "о",
			uMinesInv[id],
			(temp == 1) ? "а" : ((temp > 1 && temp < 5 && (uMinesInv[id] != 11 && uMinesInv[id] != 12)) ? "ы" : "")
		);
		#endif
	}
	#else
	setMine(id, fOrigin);
	#endif
	
	return PLUGIN_CONTINUE;
}
#endif

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
	ExecuteForward(fwds[fwd_plantPre], ret, owner, origin);
	
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
	
	ExecuteForward(fwds[fwd_plantPost], ret, mine);
	
	rh_emit_sound2(mine, 0, CHAN_ITEM, MINE_PLANT_SOUND);
	
	ArrayPushCell(uMines[owner], mine);
	return mine;
}

blowMine(mine){
	if(!awMines_isMine(mine)) return;
	
	new ret = MINES_FWD_CONT;
	ExecuteForward(fwds[fwd_blowPre], ret, mine);
	if(ret == MINES_FWD_STOP) return;
	
	static Float:origin[3]; get_entvar(mine, var_origin, origin);
	static owner; owner = awMines_getMineOwner(mine);
	
	rg_dmg_radius(origin, mine, owner, MINE_DAMAGE, MINE_RADIUS, 0, DMG_BLAST);
	blowAnim(origin);
	rh_emit_sound2(mine, 0, CHAN_WEAPON, MINE_BLOW_SOUND);
	
	ExecuteForward(fwds[fwd_blowPost], ret, mine);
	
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
	ExecuteForward(fwds[fwd_removePre], ret, mine);
	if(ret == MINES_FWD_STOP) return;
	
	static owner; owner = awMines_getMineOwner(mine);
	static item; item = ArrayFindValue(uMines[owner], mine);
	if(item > -1) ArrayDeleteItem(uMines[owner], item);
	set_entvar(mine, var_flags, FL_KILLME);
	
	ExecuteForward(fwds[fwd_removePost], ret, mine);
}

removeAllMines(){
	new mine = 1;
	while((mine = awMines_findMineEnts(mine)) > 0){
		removeMine(mine);
	}
}

removeAllUserMines(id){
	for(new i = 0; i < ArraySize(uMines[id]); i++) removeMine(i);
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
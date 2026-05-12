class_name BrainrotLore
extends RefCounted

const TEX_BRAINROT: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/monster_bear.png"),
	preload("res://assets/sprites/kenney/monster_gorilla.png"),
	preload("res://assets/sprites/kenney/monster_crocodile.png"),
	preload("res://assets/sprites/kenney/monster_sloth.png"),
	preload("res://assets/sprites/kenney/monster_rhino.png"),
	preload("res://assets/sprites/kenney/monster_parrot.png"),
]

const TEX_CHARS: Array[Texture2D] = [
	preload("res://assets/sprites/kenney/char_criminalMaleA.png"),
	preload("res://assets/sprites/kenney/char_cyborgFemaleA.png"),
	preload("res://assets/sprites/kenney/char_zombieMaleA.png"),
	preload("res://assets/sprites/kenney/char_humanFemaleA.png"),
	preload("res://assets/sprites/kenney/char_survivorFemaleA.png"),
	preload("res://assets/sprites/kenney/char_skaterMaleA.png"),
	preload("res://assets/sprites/kenney/char_humanMaleA.png"),
	preload("res://assets/sprites/kenney/char_zombieFemaleA.png"),
	preload("res://assets/sprites/kenney/char_survivorMaleB.png"),
	preload("res://assets/sprites/kenney/char_zombieA.png"),
	preload("res://assets/sprites/kenney/char_zombieC.png"),
]

const NAMES: Array[String] = [
	"ORSO\nBOMBARDIRO", "GORILLA\nCAPPUCCINO", "BOMBARDIRO\nCROCODILO",
	"BRADIPO\nASSASSINO", "RINOCERONTE\nBALLERINO", "PAPPAGALLO\nTRALALERO",
	"CRIMINALE\nAPPESSO", "CYBORG\nCAPPUCCINO", "ZOMBIE\nBALLERINO",
	"DONNA\nTRALALERO", "SOPRAVVISSUTA\nBOMBARDIRO", "SKATISTA\nASSASSINO",
	"UOMO\nCAPPUCCINO", "ZOMBESSA\nBALLERINA", "SOLDATO\nTRALALERO",
	"ZOMBIE\nCROCODILO", "MORTO\nCAPPUCCINO"
]

const COLS: Array[Color] = [
	Color(2.5, 0.3, 0.0), Color(2.5, 1.5, 0.0), Color(0.0, 2.5, 0.5),
	Color(0.5, 0.3, 2.5), Color(2.5, 0.0, 2.5), Color(0.0, 2.5, 2.5),
	Color(2.5, 2.0, 0.0), Color(0.0, 1.5, 2.5), Color(2.5, 0.5, 1.5),
]

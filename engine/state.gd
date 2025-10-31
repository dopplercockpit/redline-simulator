# res://engine/state.gd
extends Resource
const VERSION := "1.0.0"

# Cash & accruals
var cash: float = 0.0
var revenue_ytd: float = 0.0
var expense_ytd: float = 0.0

# Domain
var fleet := {}          # {"A320ceo": {"count":4, "lease_usd_mpm":220000, "hours_avail":10.5, "age_avg":8.2}}
var routes := {}         # {"LYS–BCN": {"weekly_freq":10, "price_usd":99, "capacity_seats":180, "demand_idx":0.76}}
var fuel := {"price_usd_per_ton": 830.0, "hedge_pct": 0.2, "hedge_price": 700.0}

# KPIs / rolling counters (reset on month close where noted)
var kpis := {}           # "ask", "rpk" rolling; plus derived CASK/RASK/LF
var meta := {}           # scenario metadata

func reset():
	cash = 0.0
	revenue_ytd = 0.0
	expense_ytd = 0.0
	fleet = {}
	routes = {}
	fuel = {"price_usd_per_ton": 830.0, "hedge_pct": 0.2, "hedge_price": 700.0}
	kpis = {}
	meta = {}

func load_config(cfg: Dictionary):
	for k in cfg.keys():
		self.set(k, cfg[k])

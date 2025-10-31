# res://engine/Telemetry.gd
extends Node

var _run_meta := {}

func init_run(meta: Dictionary) -> void:
	_run_meta = meta

func log_month(report: Dictionary) -> void:
	# Wire to Sheets/API later; MVP prints to console for visibility
	print("[Telemetry][Month ", report.get("month"), "] cash=$",
		round(report.get("cash", 0.0)), " cask=", "%.4f" % report.get("cask", 0.0),
		" rask=", "%.4f" % report.get("rask", 0.0),
		" lf=", "%.2f" % (report.get("lf", 0.0) * 100.0), "%")

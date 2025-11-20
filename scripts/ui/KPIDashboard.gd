func _on_state_updated(state):
    var pnl = state.get("financial_statements", {}).get("income_statement", {})
    var lines = pnl.get("lines", [])

    # Clear existing rows
    for child in $GridContainer.get_children():
        child.queue_free()

    # Render new rows
    for line in lines:
        var row = RowScene.instantiate()
        row.set_label(line["label"])
        row.set_value(line["value"])
        row.set_style(line["type"]) # Header, Subtotal, etc.
        row.set_tooltip(line["lever_hint"]) # "Affected by Fuel Hedging"
        $GridContainer.add_child(row)
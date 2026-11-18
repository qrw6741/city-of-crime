class_name ATMUI
extends MenuBase
## ATM / bank counter: deposit, withdraw and statement.

var is_bank := false
var body: VBoxContainer
var amount_edit: LineEdit

func _init(bank_branch: bool = false) -> void:
	super._init()
	is_bank = bank_branch

func build() -> void:
	var v := center_panel(Vector2(760, 0))
	v.add_child(UI.header("Meridian Bank" if is_bank else "Meridian ATM", "Keep your money safe - cash on hand can be lost, your bank balance can't."))
	body = UI.vbox(10)
	v.add_child(body)
	_refresh()

func _refresh() -> void:
	UI.clear(body)
	var h := UI.hbox(30)
	var c1 := UI.vbox(0)
	c1.add_child(UI.label("CASH", 14, UI.DIM))
	c1.add_child(UI.label(Catalog.fmt_money(Game.cash()), 32, UI.GREEN, true))
	h.add_child(c1)
	var c2 := UI.vbox(0)
	c2.add_child(UI.label("BANK BALANCE", 14, UI.DIM))
	c2.add_child(UI.label(Catalog.fmt_money(Game.bank()), 32, Color(0.7, 0.9, 1.0), true))
	h.add_child(c2)
	body.add_child(h)
	var row := UI.hbox()
	row.add_child(UI.button("Deposit all cash", func(): _dep(Game.cash()), 230))
	for a in [100, 1000, 10000]:
		var amt: int = a
		row.add_child(UI.button("Withdraw %s" % Catalog.fmt_money(amt), func(): _wd(amt), 160))
	body.add_child(row)
	var row2 := UI.hbox()
	amount_edit = LineEdit.new()
	amount_edit.placeholder_text = "Custom amount"
	amount_edit.custom_minimum_size = Vector2(230, 40)
	row2.add_child(amount_edit)
	row2.add_child(UI.button("Deposit", func(): _dep(_amt()), 160))
	row2.add_child(UI.button("Withdraw", func(): _wd(_amt()), 160))
	body.add_child(row2)
	body.add_child(UI.label("RECENT TRANSACTIONS", 14, UI.DIM))
	var sc := UI.scroll(Vector2(700, 260))
	var list := UI.vbox(2)
	sc.add_child(list)
	for t in Game.data["transactions"]:
		var r := UI.hbox()
		var l1 := UI.label(str(t["t"]).substr(5, 11), 14, UI.DIM)
		l1.custom_minimum_size.x = 120
		r.add_child(l1)
		var l2 := UI.label(str(t["r"]), 15)
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l2)
		var amount := int(t["a"])
		var tr := int(t.get("x", 0))
		var txt := Catalog.fmt_money(amount) if amount != 0 else ("transfer %s" % Catalog.fmt_money(tr))
		r.add_child(UI.label(("+" if amount > 0 else "") + txt, 15, UI.GREEN if amount > 0 else (UI.RED if amount < 0 else UI.DIM)))
		list.add_child(r)
	body.add_child(sc)
	body.add_child(UI.button("Close [Esc]", close, 700))

func _amt() -> int:
	return int(amount_edit.text.replace(",", "").replace("$", "").strip_edges())

func _dep(a: int) -> void:
	if Game.deposit(a):
		_refresh()
	else:
		Sfx.play("error")

func _wd(a: int) -> void:
	if Game.withdraw(a):
		_refresh()
	else:
		Sfx.play("error")

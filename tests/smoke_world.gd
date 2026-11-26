extends SceneTree
## Dünya etkileşimleri duman testi: kapı, koli, raf (elde koliyle), tank, eşya, müşteri soruları, kasa.
var f := 0
var m
var g
func _process(_d):
	f += 1
	if f == 2:
		g = root.get_node("Game")
		g.new_game()
		g.money = 99999
		m = load("res://scenes/main.tscn").instantiate()
		root.add_child(m)
	if f == 6:
		m.hud.close_panel()
		g.add_furniture("kasa", 4.5, 2.6, 0.0)
		var a: Dictionary = g.add_furniture("akvaryum_beyaz", -3.0, -4.4, 0.0)
		g.add_furniture("kavisli_raf", 6.7, -1.5, -90.0)
		g.add_furniture("saksi_agave", -6.2, 4.2, 0.0)
		g.tanks[int(a.tank)].fish.append(TankSim.new_fish("neon"))
		g.add_delivery("yem", 25)
	if f == 10:
		var p = m.player
		print("-- kapı"); m.shop.find_children("*", "Interactable", true, false)[0].interact(p)
		print("-- koli al"); m.shop._boxes_root.get_child(0).interact(p)
		print("-- rafa diz"); m.shop.shelves[0].interact(p)
		print("-- koli al 2"); m.shop._boxes_root.get_child(0).interact(p)
		print("-- depoya"); g.carry_to_depot()
		print("-- tank"); m.shop.aquariums[0].interact(p); m.hud.close_panel()
		print("-- kasa"); m.shop.counter.interact(p); m.hud.close_panel()
		print("-- saksı"); for n in m.shop.nodes.values():
			if n is FurnitureItem and n.type == "saksi_agave":
				n.interact(p)
		m.hud.close_panel()
		print("-- müşteri sorusu")
		var c = m.spawn_customer()
		c.question = Quiz.make(g.rng, ["neon"])
		c.interact(p)
		for b in m.hud._panel.find_children("*", "Button", true, false):
			if b.text != " ✕ ":
				b.pressed.emit()
				break
		print("-- şikâyet")
		var cm = m.spawn_customer()
		cm.make_complainer({"name": "Mert", "amount": 40, "species": "neon"})
		m.queue = [cm]
		cm.state = 5
		cm._path = []
		m.hud.open_register()
		for b in m.hud._panel.find_children("*", "Button", true, false):
			if b.text.begins_with("Parasını"):
				b.pressed.emit()
		print("-- satış + kepçe")
		if g.tanks[0].fish.is_empty():
			g.tanks[0].fish.append(TankSim.new_fish("neon"))
		var cs = m.spawn_customer()
		cs.basket = [{"type": "fish", "tank": 0, "uid": int(g.tanks[0].fish[0].uid), "species": "neon"}]
		m.queue = [cs]
		cs.state = 5
		cs._path = []
		m.hud.open_register()
		for b in m.hud._panel.find_children("*", "Button", true, false):
			if b.text.begins_with("Teklifini"):
				b.pressed.emit()
		var cg = m.hud._panel.find_children("*", "CatchGame", true, false)
		print("kepçe açıldı: ", cg.size())
		if cg.size() > 0:
			for sp in cg[0]._sprites:
				cg[0]._try_catch(sp.pos)
		print("tank balık: ", g.tanks[0].fish.size(), " para: ", g.money)
	if f == 20:
		print("BİTTİ")
		quit()
	return false

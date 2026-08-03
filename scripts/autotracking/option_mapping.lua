-- slot data key -> { tracker code, item type }
OPTION_MAPPING = {
    ["enable_act_1"] = {"act1on", "toggle"},
    ["enable_act_2"] = {"act2on", "toggle"},
    ["enable_act_3"] = {"act3on", "toggle"},
    ["act_unlocks"] = {"actunlocks", "progressive"},
    ["goal"] = {"goal", "progressive"},
    ["painting_checks_balancing"] = {"paintingbalance", "progressive"},
    ["randomize_nodes"] = {"randnodes", "toggle"},
    ["randomize_challenges"] = {"randchallenges", "progressive"},
    ["act2_randomize_bridge"] = {"act2bridge", "progressive"},
    ["epitaph_pieces_randomization"] = {"epitaphtype", "progressive"},
    ["randomize_hammer"] = {"randhammer", "progressive"},
    ["act3_overhaul"] = {"act3overhaul", "toggle"},
    ["randomize_shortcuts"] = {"randshortcuts", "progressive"},
    ["randomize_vessel_upgrades"] = {"randvessel", "progressive"},
    ["release_on_act_completion"] = {"releaseonact", "toggle"}
}

-- Values used when a slot data key is missing, matching the apworld defaults.
OPTION_DEFAULTS = {
    ["act1on"] = 1,
    ["act2on"] = 1,
    ["act3on"] = 1,
    ["actunlocks"] = 0,
    ["goal"] = 2,
    ["paintingbalance"] = 1,
    ["randnodes"] = 0,
    ["randchallenges"] = 0,
    ["act2bridge"] = 0,
    ["epitaphtype"] = 0,
    ["randhammer"] = 0,
    ["act3overhaul"] = 0,
    ["randshortcuts"] = 0,
    ["randvessel"] = 0,
    ["releaseonact"] = 0
}

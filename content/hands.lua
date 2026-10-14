-- Six additional hands and their native Planet consumables (Steamodded BETA-1224a).
-- Evaluators only read playing cards; no RNG, score coercion or gameplay mutations.
return function(T)
    local SUITS = {'Hearts', 'Diamonds', 'Clubs', 'Spades'}
    local SUIT_ORDER = {Hearts = 1, Diamonds = 2, Clubs = 3, Spades = 4}
    local ELEMENTS = {'fire', 'water', 'wood', 'metal', 'earth'}
    local definitions, catalogue, hand_keys = {}, {hands = {}, planets = {}}, {}

    local function no_rank(card)
        return SMODS.has_no_rank and SMODS.has_no_rank(card)
            or card.config.center.key == 'm_stone' or card.config.center.no_rank
    end
    local function rank(card)
        -- get_id() deliberately calls math.random for Stone in this engine.
        -- Read only the physical, native rank after excluding no-rank cards.
        if no_rank(card) then return nil end
        local id = card.base and card.base.id
        return type(id) == 'number' and id > 0 and id == id and id < math.huge and id or nil
    end
    local function suit_options(card)
        if SMODS.has_no_suit and SMODS.has_no_suit(card) then return {} end
        local center = card.config.center
        local wild = SMODS.has_any_suit and SMODS.has_any_suit(card)
            or center.key == 'm_wild' or center.any_suit
        if wild then
            local options = {}
            for _, suit in ipairs(SUITS) do
                -- bypass_debuff preserves hand formation; debuffs still suppress scoring.
                if card:is_suit(suit, true) then options[#options + 1] = suit end
            end
            return options
        end
        -- These hands use physical suits. Smeared does not replace a suit.
        local suit = card.base and card.base.suit
        return SUIT_ORDER[suit] and {suit} or {}
    end
    local function ordered(hand)
        local out = {}
        for _, card in ipairs(hand or {}) do
            out[#out + 1] = {card = card, rank = rank(card),
                suit = SUIT_ORDER[(card.base or {}).suit] or 5,
                seal = tostring(card.seal or ''), center = tostring(card.config.center.key or ''),
                edition = tostring((card.edition or {}).key or ''),
                -- sort_id is saved by Card:save; playing_card also persists.
                id = card.sort_id or card.playing_card or card.ID or 0}
        end
        table.sort(out, function(a, b)
            local ar, br = a.rank or 0, b.rank or 0
            if ar ~= br then return ar > br end
            if a.suit ~= b.suit then return a.suit < b.suit end
            if a.seal ~= b.seal then return a.seal < b.seal end
            if a.center ~= b.center then return a.center < b.center end
            if a.edition ~= b.edition then return a.edition < b.edition end
            if type(a.id) == 'number' and type(b.id) == 'number' then return a.id < b.id end
            return tostring(a.id) < tostring(b.id)
        end)
        return out
    end
    local function rank_groups(hand)
        local by_rank, ranks = {}, {}
        for _, info in ipairs(ordered(hand)) do
            if info.rank then
                if not by_rank[info.rank] then by_rank[info.rank] = {}; ranks[#ranks + 1] = info.rank end
                by_rank[info.rank][#by_rank[info.rank] + 1] = info.card
            end
        end
        -- ordered() already produced descending, distinct rank order.
        return by_rank, ranks
    end
    local function alternatives(group, kind)
        local by_token, tokens = {}, {}
        for _, card in ipairs(group) do
            local options = kind == 'suit' and suit_options(card) or (card.seal and {tostring(card.seal)} or {})
            for _, token in ipairs(options) do
                if not by_token[token] then by_token[token] = card; tokens[#tokens + 1] = token end
            end
        end
        table.sort(tokens, function(a, b)
            if kind == 'suit' then return SUIT_ORDER[a] < SUIT_ORDER[b] end
            return a < b
        end)
        local out = {}
        for _, token in ipairs(tokens) do out[#out + 1] = {token = token, card = by_token[token]} end
        return out
    end
    local function match_distinct(groups, kind)
        local choices, used, selected = {}, {}, {}
        for i, group in ipairs(groups) do
            choices[i] = alternatives(group, kind)
            if #choices[i] == 0 then return nil end
        end
        -- At most four suits / three seals. One physical card per distinct rank.
        local function visit(i)
            if i > #groups then return true end
            for _, choice in ipairs(choices[i]) do
                if not used[choice.token] then
                    used[choice.token] = true; selected[i] = choice.card
                    if visit(i + 1) then return true end
                    used[choice.token] = nil; selected[i] = nil
                end
            end
            return false
        end
        if visit(1) then return selected end
    end
    local function color_pair(group)
        local reds, blacks = {}, {}
        for _, card in ipairs(group) do
            local red, black = false, false
            for _, suit in ipairs(suit_options(card)) do
                if suit == 'Hearts' or suit == 'Diamonds' then red = true else black = true end
            end
            if red then reds[#reds + 1] = card end
            if black then blacks[#blacks + 1] = card end
        end
        for _, red in ipairs(reds) do
            for _, black in ipairs(blacks) do if red ~= black then return {red, black} end end
        end
    end
    local function sequence_groups(groups, start, length, step)
        local selected = {}
        for i = 0, length - 1 do
            local r = start + i*step
            if r == 1 then r = 14 end -- Ace low, without wrapping after a high Ace.
            if not groups[r] then return nil end
            selected[#selected + 1] = groups[r]
        end
        return selected
    end

    local evaluate = {}
    evaluate.elemental_cycle = function(parts, hand)
        local groups = rank_groups(hand)
        -- Prefer the highest complete run. Ace may be 1 or 14, never both in a run.
        for start = 11, 1, -1 do
            local run = sequence_groups(groups, start, 4, 1)
            local combo = run and match_distinct(run, 'suit')
            if combo then return {combo} end
        end
        return {}
    end
    evaluate.twin_dragons = function(parts, hand)
        local groups, ranks = rank_groups(hand)
        local pairs = {}
        for _, r in ipairs(ranks) do pairs[r] = color_pair(groups[r]) end
        for i = 1, #ranks - 1 do
            for j = i + 1, #ranks do
                local a, b = pairs[ranks[i]], pairs[ranks[j]]
                if a and b then return {{a[1], a[2], b[1], b[2]}} end
            end
        end
        return {}
    end
    evaluate.celestial_triad = function(parts, hand)
        local groups = rank_groups(hand)
        if not groups[3] or not groups[6] or not groups[9] then return {} end
        local combo = match_distinct({groups[3], groups[6], groups[9]}, 'suit')
        return combo and {combo} or {}
    end
    evaluate.dao_ladder = function(parts, hand)
        local groups = rank_groups(hand)
        for start = 6, 1, -1 do
            local run = sequence_groups(groups, start, 5, 2)
            if run then
                local combo = {}
                for _, group in ipairs(run) do combo[#combo + 1] = group[1] end
                return {combo}
            end
        end
        return {}
    end
    evaluate.inscription_matrix = function(parts, hand)
        local groups, ranks = rank_groups(hand)
        local sealed, candidate_ranks = {}, {}
        for _, r in ipairs(ranks) do
            local cards = {}
            for _, card in ipairs(groups[r]) do if card.seal then cards[#cards + 1] = card end end
            if #cards > 0 then sealed[r] = cards; candidate_ranks[#candidate_ranks + 1] = r end
        end
        for i = 1, #candidate_ranks - 2 do
            for j = i + 1, #candidate_ranks - 1 do
                for k = j + 1, #candidate_ranks do
                    local combo = match_distinct({sealed[candidate_ranks[i]], sealed[candidate_ranks[j]], sealed[candidate_ranks[k]]}, 'seal')
                    if combo then return {combo} end
                end
            end
        end
        return {}
    end
    evaluate.five_elements = function(parts, hand)
        local by_element = {}
        for _, info in ipairs(ordered(hand)) do
            local element = T.element(info.card)
            if not by_element[element] then by_element[element] = info.card end
        end
        local combo = {}
        for _, element in ipairs(ELEMENTS) do
            if not by_element[element] then return {} end
            combo[#combo + 1] = by_element[element]
        end
        return {combo}
    end

    local data = {
        {key = 'elemental_cycle', name = 'Ciclo Elemental', above = 'Straight', chips = 40, mult = 5, l_chips = 35, l_mult = 3,
            rule = 'Quatro valores consecutivos com quatro naipes distintos.',
            description = {'Quatro valores consecutivos, um de cada naipe.',
                'Ás baixo: A–2–3–4; alto: J–Q–K–A. Sem volta.',
                'Carta Naipe Curinga substitui naipes.',
                'Curinga Borrado, Quatro Dedos e Atalho', 'não alteram esta regra.'},
            example = {{'H_2', true}, {'D_3', true}, {'C_4', true}, {'S_5', true}},
            example_text = '2 de Copas, 3 de Ouros, 4 de Paus, 5 de Espadas.',
            planet = 'glory_star', planet_name = 'Estrela da Glória', art_index = 13,
            art_prompt = 'Original fantasy celestial card icon, golden star over a distant walled jade city, four separate elemental trails, dark navy sky, luminous gold border, no text, no letters, no logos.'},
        {key = 'twin_dragons', name = 'Dragões Gêmeos', above = 'Two Pair', chips = 30, mult = 3, l_chips = 25, l_mult = 2,
            rule = 'Dois pares de valores distintos; cada par contém uma carta vermelha e uma preta.',
            description = {'Dois pares de valores diferentes.', 'Cada par contém uma vermelha e uma preta.',
                'Carta Naipe Curinga pode assumir qualquer cor.', 'Curinga Borrado mantém o naipe físico.'},
            example = {{'H_4', true}, {'S_4', true}, {'D_9', true}, {'C_9', true}},
            example_text = '4 de Copas + 4 de Espadas; 9 de Ouros + 9 de Paus.',
            planet = 'twin_moon', planet_name = 'Lua Gêmea', art_index = 14,
            art_prompt = 'Original fantasy celestial card icon, two intertwined moons crimson and silver, paired dragon silhouettes circling them, dark navy sky, luminous gold border, no text, no letters, no logos.'},
        {key = 'celestial_triad', name = 'Tríade Celestial', above = 'Three of a Kind', chips = 40, mult = 4, l_chips = 30, l_mult = 3,
            rule = 'Um 3, um 6 e um 9, cada um com naipe diferente.',
            description = {'Um 3, um 6 e um 9, com três naipes diferentes.',
                'Carta Naipe Curinga substitui naipes.', 'Curinga Borrado mantém o naipe físico.',
                'Cartas extras não precisam pontuar.'},
            example = {{'H_3', true}, {'D_6', true}, {'S_9', true}},
            example_text = '3 de Copas, 6 de Ouros, 9 de Espadas.',
            planet = 'triple_heaven', planet_name = 'Céu Triplo', art_index = 15,
            art_prompt = 'Original fantasy celestial card icon, three celestial spheres arranged as a glowing triangle, jade cyan and violet light, dark navy sky, luminous gold border, no text, no letters, no logos.'},
        {key = 'dao_ladder', name = 'Escada do Dao', above = 'Flush', chips = 60, mult = 6, l_chips = 40, l_mult = 4,
            rule = 'Cinco valores distintos consecutivos com intervalo de dois.',
            description = {'Cinco valores em passos de dois: 2–4–6–8–10.',
                'Ás pode ser 1 ou 14; J=11, Q=12, K=13.', 'Não dá volta; naipes são livres.',
                'Quatro Dedos e Atalho não alteram a regra.'},
            example = {{'H_2', true}, {'D_4', true}, {'C_6', true}, {'S_8', true}, {'H_T', true}},
            example_text = '2, 4, 6, 8 e 10 de quaisquer naipes; também A–3–5–7–9.',
            planet = 'dao_world', planet_name = 'Mundo do Dao', art_index = 16,
            art_prompt = 'Original fantasy celestial card icon, jade planet encircled by an ascending orbital stair of five alternating platforms, flowing cosmic energy, dark navy sky, luminous gold border, no text, no letters, no logos.'},
        {key = 'inscription_matrix', name = 'Matriz das Inscrições', above = 'Full House', chips = 75, mult = 7, l_chips = 45, l_mult = 4,
            rule = 'Três cartas de valores distintos com três selos distintos.',
            description = {'Três valores diferentes e três selos diferentes.', 'Selos nativos e TDG são válidos.',
                'Pedra e cartas sem valor não são válidas.', 'As demais cartas não precisam pontuar.'},
            example = {{'H_2', true, seal = 'Red'}, {'C_7', true, seal = 'Blue'}, {'S_K', true, seal = 'Gold'}},
            example_text = '2 de Copas com Vermelho, 7 de Paus com Azul, Rei de Espadas com Dourado.',
            planet = 'inscription_domain', planet_name = 'Domínio das Inscrições', art_index = 17,
            art_prompt = 'Original fantasy celestial card icon, blue violet planet within three luminous rune rings and distinct engraved sigils, dark navy sky, luminous gold border, no readable text, no letters, no logos.'},
        {key = 'five_elements', name = 'Confluência dos Cinco Elementos', above = 'Straight Flush', chips = 140, mult = 12, l_chips = 65, l_mult = 5,
            rule = 'Cinco cartas: uma de cada afinidade fogo, água, madeira, metal e Terra.',
            description = {'Cinco cartas, uma de cada elemento:', 'Copas/Fogo, Espadas/Água, Paus/Madeira,',
                'Ouros/Metal e Terra (Pedra ou sem naipe).',
                'Carta Naipe Curinga mantém sua afinidade física.',
                'Curinga Borrado e Quatro Dedos não alteram a regra.'},
            example = {{'H_2', true}, {'S_4', true}, {'C_6', true}, {'D_8', true}, {'H_T', true, enhancement = 'm_stone'}},
            example_text = '2 de Copas, 4 de Espadas, 6 de Paus, 8 de Ouros e uma Pedra.',
            planet = 'spirit_realm', planet_name = 'Reino Espiritual', art_index = 18,
            art_prompt = 'Original fantasy celestial card icon, five spirit orbs of flame water green wood polished metal and stone orbit a radiant spiritual world, dark navy sky, luminous gold border, no text, no letters, no logos.'},
    }

    -- Register all hands first: Planets, Telescope, Blue Seal and Observatory read hand_type.
    for index, d in ipairs(data) do
        local full = 'tdg_' .. d.key
        hand_keys[#hand_keys + 1] = full
        definitions[full] = {key = full, chips = d.chips, mult = d.mult, s_chips = d.chips, s_mult = d.mult,
            l_chips = d.l_chips, l_mult = d.l_mult, level = 1, played = 0, played_this_round = 0,
            played_this_ante = 0, visible = true, example = d.example}
        SMODS.PokerHand {
            key = d.key, above_hand = d.above, chips = d.chips, mult = d.mult,
            l_chips = d.l_chips, l_mult = d.l_mult, visible = true,
            unlocked = true, discovered = true, example = d.example,
            loc_txt = {name = d.name, description = d.description}, evaluate = evaluate[d.key],
        }
        catalogue.hands[index] = {key = full, name = d.name, category = 'PokerHand', description = d.rule,
            above_hand = d.above, chips = d.chips, mult = d.mult, l_chips = d.l_chips, l_mult = d.l_mult,
            example = d.example, example_text = d.example_text, planet_key = 'c_tdg_' .. d.planet,
            art_index = d.art_index, art_prompt = d.art_prompt, localization = {name = d.name, description = d.description}}
    end

    local function deep_copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}; for k, v in pairs(value) do out[k] = deep_copy(v) end; return out
    end
    local score_fields = {chips = true, mult = true, s_chips = true, s_mult = true,
        l_chips = true, l_mult = true, level = true}
    -- Called by main BEFORE Game.start_run(args.savetext). Existing values stay intact.
    function T.ensure_hands_in_game(game)
        if type(game) ~= 'table' then return 0 end
        if type(game.hands) ~= 'table' then game.hands = {} end
        local added = 0
        for _, key in ipairs(hand_keys) do
            if type(game.hands[key]) ~= 'table' then game.hands[key] = {}; added = added + 1 end
            local saved = game.hands[key]
            for field, value in pairs(definitions[key]) do
                if saved[field] == nil then
                    if score_fields[field] and type(to_big) == 'function' then saved[field] = to_big(value)
                    else saved[field] = deep_copy(value) end
                end
            end
            local live = SMODS.PokerHands and SMODS.PokerHands[key]
            if live and live.order then saved.order = live.order end
        end
        return added
    end
    function T.ensure_hands_in_save(savetext)
        if type(savetext) ~= 'table' or type(savetext.GAME) ~= 'table' then return 0 end
        return T.ensure_hands_in_game(savetext.GAME)
    end
    T.hand_keys, T.hand_definitions = hand_keys, definitions

    for _, d in ipairs(data) do
        local full = 'tdg_' .. d.key
        local function valid(card)
            if not G or not G.GAME or (G.STAGES and G.STAGE ~= G.STAGES.RUN) then return false end
            return not (card and card.debuff) and G.GAME.hands and G.GAME.hands[full] ~= nil
        end
        local function use_planet(self, card, area, copier, amount)
            if not valid(card) then return false end
            if type(amount) ~= 'number' or amount ~= amount or amount < 1 or amount > 1e6 then return false end
            amount = math.floor(amount)
            -- use() overrides the native hand_type branch, so level exactly once here.
            if not T.safe_level_hand(full, amount, copier or card) then return false end
            T.add_qi(10*amount)
            T.add_resource('planets', amount)
            return true
        end
        SMODS.Consumable {
            key = d.planet, set = 'Planet', atlas = 'tdg_arcana', prefix_config = {atlas = false},
            pos = T.atlas_pos(d.art_index, 6), cost = 3, unlocked = true, discovered = true,
            config = {hand_type = full},
            loc_txt = {name = d.planet_name, text = {
                'Sobe {C:attention}#1#{} nível de', '{C:attention}#2#{}.',
                '{C:mult}+#3#{} Mult e {C:chips}+#4#{} Fichas por nível.',
                'Concede {C:attention}10 Qi{} após o uso.',
            }},
            loc_vars = function(self, info_queue, card)
                local h = G and G.GAME and G.GAME.hands and G.GAME.hands[full] or definitions[full]
                return {vars = {1, d.name, h.l_mult, h.l_chips}}
            end,
            can_use = function(self, card) return not not valid(card) end,
            use = function(self, card, area, copier) return use_planet(self, card, area, copier, 1) end,
            -- Compatible with installed stacking extensions; not required by native SMODS.
            bulk_use = function(self, card, area, copier, amount) return use_planet(self, card, area, copier, amount) end,
            in_pool = function(self, args)
                -- Collection/pool construction outside a run is harmless. No played>0 softlock.
                return not G or not G.GAME or not G.GAME.hands or G.GAME.hands[full] ~= nil
            end,
        }
        catalogue.planets[#catalogue.planets + 1] = {key = 'c_tdg_' .. d.planet, name = d.planet_name,
            category = 'Planet', hand_type = full, art_index = d.art_index,
            description = 'Sobe ' .. d.name .. ' em 1 nível (+' .. d.l_mult .. ' Mult, +' .. d.l_chips .. ' Fichas), concede 10 Qi e conta um planeta após o uso bem-sucedido.',
            art_prompt = d.art_prompt, atlas = 'tdg_arcana', art_position = T.atlas_pos(d.art_index, 6)}
    end
    T.hands_catalog = catalogue
end

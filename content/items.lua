-- TDG — Ascensão. Fan adaptation; values and recipes are original mod design.
-- API reference: installed Steamodded 1.0.0~BETA-1224a and Talisman.
return function(T)
    local SET = {elixir = 'tdg_Elixir', technique = 'tdg_Technique', relic = 'tdg_Relic'}
    local colour = {elixir = HEX('65D6A0'), technique = HEX('76ACFF'), relic = HEX('E7B767')}
    local offsets = {elixir = 0, technique = 8, relic = 16, voucher = 24,
        enhancement = 36, seal = 44, edition = 50, booster = 54, back = 63, tag = 69}
    local prefixes = {Consumable = 'c', Voucher = 'v', Enhancement = 'm',
        Seal = '', Edition = 'e', Booster = 'p', Back = 'b', Tag = 'tag'}
    T.items_catalog = {
        schema_version = 1, mod = 'TDG — Ascensão', language = 'pt_BR',
        adaptation = 'Fan mod não oficial; efeitos, elementos, receitas e valores são adaptações de design.',
        atlas = {key = 'tdg_items', columns = 12, rows = 8, px = 71, py = 95,
            width_1x = 852, height_1x = 760, width_2x = 1704, height_2x = 1520},
        extra_atlases = {{key = 'tdg_tags', path = 'tdg_tags.png', columns = 6, rows = 1,
            px = 34, py = 34, width_1x = 204, height_1x = 34, width_2x = 408, height_2x = 68}},
        offsets = offsets, index_base = 1, items = {},
    }

    local function register(class, category, index, def, effect, art)
        def.unlocked, def.discovered = true, true
        def.atlas = def.atlas or 'tdg_items'
        def.pos = def.pos or T.atlas_pos(index, 12)
        def.prefix_config = def.prefix_config or {}
        def.prefix_config.atlas = false
        if class == 'Edition' then def.prefix_config.shader = false end
        local short_key = def.key
        local prefix = prefixes[class]
        local full_key = (prefix ~= '' and prefix .. '_' or '') .. 'tdg_' .. short_key
        T.items_catalog.items[#T.items_catalog.items + 1] = {
            category = category, class = class, index = index, key = full_key,
            registration_key = short_key, name = def.loc_txt.name, effect = effect,
            atlas = def.atlas, pos = {x = def.pos.x, y = def.pos.y},
            main_atlas_pos = T.atlas_pos(index, 12), art_prompt = art,
            set = def.set, requires = def.requires, shader = def.shader,
        }
        SMODS[class](def)
    end

    SMODS.Atlas {key = 'tdg_tags', prefix_config = {key = false}, path = 'tdg_tags.png', px = 34, py = 34}
    for _, category in ipairs({'elixir', 'technique', 'relic'}) do
        local names = {elixir = 'Elixir', technique = 'Técnica', relic = 'Relíquia'}
        SMODS.ConsumableType {
            key = SET[category], primary_colour = colour[category], secondary_colour = colour[category],
            collection_rows = {4, 4}, shop_rate = category == 'relic' and 0.8 or 1.2,
            select_card = 'consumeables',
            loc_txt = {name = names[category], collection = ({elixir = 'Elixires', technique = 'Técnicas', relic = 'Relíquias'})[category] .. ' de cultivação',
                undiscovered = {name = 'Conhecimento oculto', text = {'Encontre esta carta', 'para revelar seus segredos'}}},
        }
    end

    local function state() return T.state() end
    local function run()
        return G and G.GAME and G.GAME.current_round ~= nil and
            (not G.STAGES or G.STAGE == G.STAGES.RUN)
    end
    local function realm() return math.max(1, math.min(12, state().realm or 1)) end
    local function resource(key) return state()[key] or 0 end
    local function gain(key, amount) T.add_resource(key, amount) end
    local function enough(key, amount) return resource(key) >= amount end
    local function spend(key, amount) gain(key, -amount) end
    local function room(area, buffer)
        return area and area.config and area.cards and
            #area.cards + (buffer or 0) < (area.config.card_limit or 0)
    end
    local function consumable_room()
        return run() and room(G.consumeables, G.GAME.consumeable_buffer)
    end
    local function selected(minimum, maximum)
        local cards = G and G.hand and G.hand.highlighted
        if not cards or #cards < minimum or #cards > maximum then return nil end
        local out = {}
        for _, card in ipairs(cards) do
            if card.area ~= G.hand or not card.ability then return nil end
            out[#out + 1] = card
        end
        return out
    end
    local function highlighted(minimum, maximum)
        return run() and selected(minimum, maximum) ~= nil
    end
    local function live_blind()
        return run() and G.GAME.blind and G.GAME.blind.in_blind and
            (G.STATE == G.STATES.SELECTING_HAND or
                (G.STATE == G.STATES.PLAY_TAROT and G.TAROT_INTERRUPT == G.STATES.SELECTING_HAND))
    end
    local function visible_hands()
        local result = {}
        for _, name in ipairs(G and G.handlist or {'High Card', 'Pair', 'Two Pair', 'Three of a Kind',
            'Straight', 'Flush', 'Full House', 'Four of a Kind', 'Straight Flush', 'Five of a Kind',
            'Flush House', 'Flush Five'}) do
            local hand = G and G.GAME and G.GAME.hands and G.GAME.hands[name]
            if hand and hand.visible ~= false then result[#result + 1] = name end
        end
        return result
    end
    local function favourite_hand()
        local best, count
        for _, name in ipairs(visible_hands()) do
            local played = G.GAME.hands[name].played or 0
            if not best or played > count then best, count = name, played end
        end
        return best
    end
    local function random_key(keys, seed)
        return pseudorandom_element(keys, pseudoseed('tdg_' .. seed))
    end
    local function elemental_diversity()
        local n = 0
        for _, element in ipairs({'fire', 'water', 'wood', 'metal', 'earth'}) do
            if ((state().elements or {})[element] or 0) > 0 then n = n + 1 end
        end
        return n
    end
    local function safe_context(context)
        return not context.blueprint and not context.retrigger_joker and not context.retrigger_joker_check
    end
    -- Main scoring runs for every card repetition. Persist one mutation per card/hand.
    local function stamp(context, period)
        local s, r = state(), G.GAME.current_round or {}
        local blind = G.GAME.round_resets and G.GAME.round_resets.blind_states or {}
        return table.concat({tostring(s.hands or 0), tostring(s.blinds or 0),
            tostring(r.hands_played or 0), tostring(period == 'discard' and r.discards_used or ''),
            tostring(G.GAME.round_resets and G.GAME.round_resets.ante or 1),
            tostring(blind.Small or '') .. tostring(blind.Big or '') .. tostring(blind.Boss or '')}, ':')
    end
    local function once(card, label, context, period)
        if not safe_context(context) then return false end
        local owner = card and card.ability
        if not owner then
            local s = state()
            s.stats = s.stats or {}
            owner = s.stats
        end
        owner.tdg_item_triggers = owner.tdg_item_triggers or {}
        local id = stamp(context, period)
        if owner.tdg_item_triggers[label] == id then return false end
        owner.tdg_item_triggers[label] = id
        return true
    end
    local function playing(context) return context.main_scoring and context.cardarea == G.play end
    local function held(context) return context.main_scoring and context.cardarea == G.hand end
    local function round_held(context)
        return context.end_of_round and context.playing_card_end_of_round and not context.game_over and context.cardarea == G.hand and
            not context.repetition and not context.individual
    end
    local function use_count(category, key)
        local counters = {elixir = 'elixirs', technique = 'techniques', relic = 'relics'}
        gain(counters[category], 1)
        local s = state()
        s.stats = s.stats or {}
        s.stats.item_uses = s.stats.item_uses or {}
        s.stats.item_uses[key] = math.min(1e100, (s.stats.item_uses[key] or 0) + 1)
    end
    local function consumable(category, n, key, name, text, can_use, action, effect, art, cost)
        register('Consumable', category, offsets[category] + n, {
            key = key, set = SET[category], cost = cost or (category == 'relic' and 6 or 4),
            loc_txt = {name = name, text = text}, config = {},
            can_use = function(self, card) return run() and can_use(self, card) or false end,
            -- A failed preflight leaves the original card in place in the native use flow.
            keep_on_use = function(self, card) return not (run() and can_use(self, card)) end,
            use = function(self, card, area, copier)
                if not run() or not can_use(self, card) then return false end
                if action(self, card, area, copier) == false then return false end
                use_count(category, self.key)
                if card and card.juice_up then card:juice_up(0.3, 0.5) end
                return true
            end,
        }, effect, art)
    end
    local always = function() return true end
    local elixir_keys = {'c_tdg_spirit_gather', 'c_tdg_soul_nourish', 'c_tdg_demon_refining',
        'c_tdg_jade_dew', 'c_tdg_dragon_blood', 'c_tdg_purple_mist', 'c_tdg_yin_yang', 'c_tdg_rebirth'}
    local technique_keys = {'c_tdg_heavenly_god', 'c_tdg_lightning_dragon', 'c_tdg_phoenix_nine',
        'c_tdg_inscription_art', 'c_tdg_shadow_step', 'c_tdg_seven_spirits', 'c_tdg_array_ten_thousand', 'c_tdg_demon_fusion'}
    local enhancement_keys = {'m_tdg_spirit_stone', 'm_tdg_dragon_meridian', 'm_tdg_phoenix',
        'm_tdg_ice_jade', 'm_tdg_ancient_gold', 'm_tdg_five_elements', 'm_tdg_soul_script', 'm_tdg_void_root'}
    local seal_keys = {'tdg_soul_lotus', 'tdg_thunder', 'tdg_alchemist', 'tdg_inscription', 'tdg_demon', 'tdg_ancestral'}

    consumable('elixir', 1, 'spirit_gather', 'Pílula da Concentração Espiritual',
        {'Receba {C:attention}80 + 20 por reino{} de Qi'}, always,
        function() T.add_qi(80 + 20 * realm()) end,
        'Qi imediato: 80 + 20 × reino; conta como um elixir.', 'Frasco de jade com pílulas verdes e espiral de energia espiritual.')
    consumable('elixir', 2, 'soul_nourish', 'Pílula Nutridora da Alma',
        {'Receba {C:attention}60{} Qi e {C:attention}2{} insight'}, always,
        function() T.add_qi(60); gain('insight', 2) end,
        '+60 Qi e +2 insight; prepara técnicas e a edição Espaço-Tempo.', 'Pílula violeta flutuando sobre um lótus dourado.')
    consumable('elixir', 3, 'demon_refining', 'Pílula do Refino Demoníaco',
        {'Receba {C:attention}6{} essência e {C:attention}40{} Qi'}, always,
        function() gain('essence', 6); T.add_qi(40) end,
        '+6 essência e +40 Qi; abastece caldeirão, fusão e altar.', 'Três pérolas rubras em uma tigela de alquimia de bronze.')
    consumable('elixir', 4, 'jade_dew', 'Orvalho do Jade Celestial',
        {'Até {C:attention}2{} cartas selecionadas ganham', '{C:chips}40 + 10 por reino{} fichas permanentes'},
        function() return highlighted(1, 2) end,
        function() local bonus = 40 + 10 * realm(); for _, c in ipairs(selected(1, 2)) do
            c.ability.perma_bonus = math.min(1e100, (c.ability.perma_bonus or 0) + bonus) end end,
        'Adiciona 40 + 10 × reino a perma_bonus de 1–2 cartas, preservando melhorias/selos/edições.', 'Gotas de jade azul caindo sobre duas folhas luminosas.')
    consumable('elixir', 5, 'dragon_blood', 'Sangue do Dragão Ancestral',
        {'Transforme {C:attention}1{} carta selecionada', 'em {C:attention}Meridiano do Dragão{}'},
        function() return highlighted(1, 1) end,
        function() selected(1, 1)[1]:set_ability(G.P_CENTERS.m_tdg_dragon_meridian) end,
        'Aplica m_tdg_dragon_meridian a uma carta: Xmult escala com o reino.', 'Ampola rubra envolvida por um pequeno dragão de energia dourada.')
    consumable('elixir', 6, 'purple_mist', 'Névoa do Lótus Púrpura',
        {'Aplique o {C:attention}Selo do Lótus da Alma{}', 'a {C:attention}1{} carta selecionada'},
        function() return highlighted(1, 1) end,
        function() selected(1, 1)[1]:set_seal('tdg_soul_lotus', true, true) end,
        'Sela uma carta para gerar essência uma vez por mão ao pontuar.', 'Frasco de vidro com névoa púrpura e lótus espiritual.')
    consumable('elixir', 7, 'yin_yang', 'Pílula da Harmonia Yin-Yang',
        {'Receba {C:attention}3{} karma e {C:attention}3{} essência', 'Mais {C:attention}25{} Qi por elemento dominado'}, always,
        function() gain('karma', 3); gain('essence', 3); T.add_qi(25 * elemental_diversity()) end,
        '+3 karma, +3 essência, +25 Qi por elemento com contagem positiva (máximo cinco).', 'Duas pílulas branca e negra orbitando um símbolo yin-yang de jade.')
    consumable('elixir', 8, 'rebirth', 'Pílula da Reencarnação',
        {'Requer reino {C:attention}Lendário{} ou superior', 'Retorne a Bronze, estrela 1, com {C:attention}0{} Qi',
            'Preserve insight e ganhe {C:attention}15 + 5 por reino{}', 'Receba {C:attention}1{} reencarnação para o bônus universal'},
        function() return realm() >= 5 end,
        function()
            local s, old_realm = state(), realm()
            gain('insight', 15 + 5 * old_realm); gain('rebirths', 1)
            s.qi, s.realm, s.stage = 0, 1, 1
            s.tribulation = s.tribulation or {}
            s.tribulation.progress, s.tribulation.active = 0, false
            T.notify('Uma nova vida começa.', G.C.PURPLE)
        end,
        'Reencarna a partir do reino 5: zera Qi/reino/estágio e tribulação ativa; preserva recursos, histórico, insight e reencarnações; +15+5×reino insight e +1 rebirth.', 'Pílula branca com uma fênix e um relógio circular, renascimento espiritual.', 8)

    consumable('technique', 1, 'heavenly_god', 'Técnica do Deus Celestial',
        {'Eleve sua mão mais jogada em {C:attention}3{} níveis', 'Receba {C:attention}40{} Qi'},
        function() return favourite_hand() ~= nil end,
        function(self, card) T.safe_level_hand(favourite_hand(), 3, card); T.add_qi(40) end,
        '+3 níveis na mão visível mais jogada, empate por ordem nativa; +40 Qi.', 'Pergaminho dourado com sete estrelas ligadas por meridianos celestes.')
    consumable('technique', 2, 'lightning_dragon', 'Dragão Alado do Relâmpago',
        {'Aplique o {C:attention}Selo do Trovão{}', 'a até {C:attention}2{} cartas selecionadas'},
        function() return highlighted(1, 2) end,
        function() for _, c in ipairs(selected(1, 2)) do c:set_seal('tdg_thunder', true, true) end end,
        'Selo do Trovão em 1–2 cartas; repetições aumentam nos reinos 6 e 12.', 'Dragão alado azul sobre um pergaminho com relâmpagos.')
    consumable('technique', 3, 'phoenix_nine', 'Nove Transformações da Fênix',
        {'Transforme até {C:attention}2{} cartas selecionadas', 'em {C:attention}Inscrições da Fênix{}'},
        function() return highlighted(1, 2) end,
        function() for _, c in ipairs(selected(1, 2)) do c:set_ability(G.P_CENTERS.m_tdg_phoenix) end end,
        'Aplica melhoria de Mult crescente por reino e geração de essência a 1–2 cartas.', 'Fênix vermelha atravessando nove anéis de caligrafia dourada.')
    consumable('technique', 4, 'inscription_art', 'Arte das Inscrições Antigas',
        {'Até {C:attention}2{} cartas selecionadas recebem', 'uma melhoria TDG aleatória', 'Receba {C:attention}2{} insight'},
        function() return highlighted(1, 2) end,
        function() for i, c in ipairs(selected(1, 2)) do
            c:set_ability(G.P_CENTERS[random_key(enhancement_keys, 'inscription_' .. i)])
        end; gain('insight', 2) end,
        'Melhoria aleatória de uma das oito TDG em cada uma de 1–2 cartas, RNG do jogo; +2 insight.', 'Pincel de jade traçando oito runas diferentes num pergaminho azul.')
    consumable('technique', 5, 'shadow_step', 'Passos da Sombra',
        {'Durante um blind, receba', '{C:blue}+1{} mão e {C:red}+2{} descartes'}, live_blind,
        function() ease_hands_played(1); ease_discard(2) end,
        '+1 mão e +2 descartes apenas enquanto seleciona cartas num blind ativo.', 'Pegadas violeta atravessando uma ponte de névoa noturna.')
    consumable('technique', 6, 'seven_spirits', 'Confluência dos Sete Espíritos',
        {'Selecione de {C:attention}1{} a {C:attention}5{} cartas', 'Receba {C:attention}35{} Qi e {C:attention}1{} insight', 'por elemento distinto entre elas'},
        function() return highlighted(1, 5) end,
        function() local seen, n = {}, 0; for _, c in ipairs(selected(1, 5)) do
            local element = T.element(c); if not seen[element] then seen[element] = true; n = n + 1 end
        end; T.add_qi(35 * n); gain('insight', n) end,
        '35 Qi e 1 insight por elemento distinto de 1–5 cartas, via T.element; não altera contagens globais dos elementos.', 'Sete silhuetas espirituais circundando uma esfera com cinco cores elementais.')
    consumable('technique', 7, 'array_ten_thousand', 'Formação das Dez Mil Runas',
        {'Gaste {C:attention}3{} essência', 'Eleve todas as mãos visíveis em {C:attention}1{} nível'},
        function() return enough('essence', 3) and #visible_hands() > 0 end,
        function(self, card) for _, name in ipairs(visible_hands()) do T.safe_level_hand(name, 1, card) end; spend('essence', 3) end,
        'Custa 3 essência e eleva cada mão visível em um nível; não paga se não puder usar.', 'Matriz de runas azuis sobre um círculo ritual de pedra.')
    consumable('technique', 8, 'demon_fusion', 'Fusão de Espíritos Demoníacos',
        {'Gaste {C:attention}4{} essência; selecione {C:attention}2{} cartas', 'Ambas recebem o mesmo selo TDG aleatório',
            'e {C:mult}+5{} Mult permanente; receba {C:attention}100{} Qi'},
        function() return enough('essence', 4) and highlighted(2, 2) end,
        function() local seal = random_key(seal_keys, 'demon_fusion'); for _, c in ipairs(selected(2, 2)) do
            c:set_seal(seal, true, true); c.ability.perma_mult = math.min(1e100, (c.ability.perma_mult or 0) + 5)
        end; spend('essence', 4); T.add_qi(100) end,
        'Custa 4 essência: mesmo selo TDG aleatório em exatamente duas cartas e +5 perma_mult em ambas; +100 Qi.', 'Dois espíritos demoníacos convergindo num caldeirão com runas rubras.')

    consumable('relic', 1, 'spacetime_book', 'Livro do Demônio do Espaço-Tempo',
        {'Receba {C:attention}12{} insight', 'e Qi igual a {C:attention}50%{} do custo da próxima ascensão'}, always,
        function() local qi = math.floor(T.threshold(state()) * 0.5); gain('insight', 12); T.add_qi(qi) end,
        '+12 insight e metade do custo atual de ascensão em Qi, calculado antes do ganho.', 'Livro antigo flutuante com vórtice azul, folhas douradas e ampulheta.')
    consumable('relic', 2, 'demon_pot', 'Caldeirão dos Espíritos Demoníacos',
        {'Gaste {C:attention}3{} essência para criar', 'um {C:attention}Elixir{} TDG aleatório', '{C:inactive}(Requer uma vaga livre){}'},
        function() return enough('essence', 3) and consumable_room() end,
        function() local created = T.create_consumable(SET.elixir, random_key(elixir_keys, 'demon_pot'))
            if not created then return false end; spend('essence', 3) end,
        'Transmuta 3 essência em um dos oito elixires com RNG; exige vaga livre e só paga após criação.', 'Caldeirão de bronze negro contendo almas e pérolas verdes luminosas.')
    consumable('relic', 3, 'soul_crystal', 'Cristal de Medição da Alma',
        {'Transforme {C:attention}1{} carta selecionada', 'em {C:attention}Pedra Espiritual{}', 'Receba {C:attention}3{} insight'},
        function() return highlighted(1, 1) end,
        function() selected(1, 1)[1]:set_ability(G.P_CENTERS.m_tdg_spirit_stone); gain('insight', 3) end,
        'Aplica Pedra Espiritual em uma carta e concede 3 insight; preserva selo e edição.', 'Cristal transparente num suporte de prata, luz revelando meridianos.')
    consumable('relic', 4, 'thunder_sword', 'Espada do Deus do Trovão',
        {'Uma carta selecionada recebe a edição', '{C:attention}Forjada no Trovão{} e o {C:attention}Selo do Trovão{}'},
        function() return highlighted(1, 1) end,
        function() local c = selected(1, 1)[1]; c:set_edition('e_tdg_thunderforged', true, true); c:set_seal('tdg_thunder', true, true) end,
        'Aplica edição de Mult crescente por reino e selo de repetição na mesma carta.', 'Espada azul prateada cravada em pedra, relâmpagos em sua lâmina.')
    consumable('relic', 5, 'ancestral_map', 'Mapa do Reino Ancestral',
        {'Crie uma {C:attention}Técnica{} TDG aleatória', 'e receba {C:attention}3{} insight', '{C:inactive}(Requer uma vaga livre){}'},
        function() return consumable_room() end,
        function() if not T.create_consumable(SET.technique, random_key(technique_keys, 'ancestral_map')) then return false end
            gain('insight', 3) end,
        'Cria uma das oito técnicas via RNG e dá +3 insight após criação; exige vaga livre.', 'Mapa de seda com montanhas flutuantes e um portal celestial dourado.')
    consumable('relic', 6, 'temporal_ring', 'Anel da Memória Temporal',
        {'Aplique a edição {C:attention}Espaço-Tempo{}', 'a {C:attention}1{} carta selecionada'},
        function() return highlighted(1, 1) end,
        function() selected(1, 1)[1]:set_edition('e_tdg_spacetime', true, true) end,
        'Edição Espaço-Tempo em uma carta, Xmult cresce com insight preservado na reencarnação.', 'Anel de prata com esfera azul e fragmentos de relógio em suspensão.')
    consumable('relic', 7, 'glory_token', 'Medalhão da Cidade da Glória',
        {'Receba {C:money}$20{} e {C:attention}2{} karma'}, always,
        function() ease_dollars(20); gain('karma', 2) end,
        '+$20 e +2 karma; apoio econômico para vouchers e caminhos.', 'Medalhão dourado com muralhas e um sol sobre a Cidade da Glória.')
    consumable('relic', 8, 'divine_altar', 'Altar do Imperador Divino',
        {'Gaste {C:attention}5{} essência e {C:attention}3{} karma', 'Aplique a edição {C:attention}Mandato Divino{}', 'a {C:attention}1{} carta selecionada'},
        function() return enough('essence', 5) and enough('karma', 3) and highlighted(1, 1) end,
        function() selected(1, 1)[1]:set_edition('e_tdg_divine', true, true); spend('essence', 5); spend('karma', 3) end,
        'Custa 5 essência e 3 karma: aplica Mandato Divino (expoente Talismã ou Xmult de fallback).', 'Altar imperial com chama branca, coroa e pilares de jade violeta.', 8)

    local function voucher(n, key, name, text, effect, callbacks, requires)
        local def = {key = key, cost = requires and 15 or 10, config = {}, requires = requires,
            loc_txt = {name = name, text = text}}
        for k, v in pairs(callbacks) do def[k] = v end
        register('Voucher', 'voucher', offsets.voucher + n, def, effect,
            'Vale ornamental de cultivação: ' .. name .. ', em jade e ouro, símbolo central legível, sem texto rasterizado.')
    end
    local function slots(area_key, n)
        local function change(amount)
            local area = G and G[area_key]
            if not area or not area.config then return end
            if area.change_size then area:change_size(amount)
            else area.config.card_limit = area.config.card_limit + amount end
        end
        return {redeem = function() change(n) end, unredeem = function() change(-n) end}
    end
    voucher(1, 'jade_satchel', 'Bolsa de Jade', {'{C:attention}+1{} espaço para consumíveis'},
        '+1 vaga de consumível, remoção simétrica via unredeem.', slots('consumeables', 1))
    voucher(2, 'celestial_vault', 'Tesouro Celestial', {'{C:attention}+2{} espaços para consumíveis'},
        '+2 vagas de consumíveis além da Bolsa de Jade; remoção simétrica.', slots('consumeables', 2), {'v_tdg_jade_satchel'})
    voucher(3, 'soul_pavilion', 'Pavilhão das Almas', {'{C:attention}+1{} espaço de Coringa'},
        '+1 vaga de Coringa, remoção simétrica.', slots('jokers', 1))
    voucher(4, 'divine_palace', 'Palácio Divino', {'{C:attention}+1{} espaço de Coringa'},
        '+1 vaga adicional de Coringa além do Pavilhão; remoção simétrica.', slots('jokers', 1), {'v_tdg_soul_pavilion'})
    voucher(5, 'qi_spring', 'Fonte de Qi', {'Receba {C:attention}25{} Qi antes de cada mão'},
        '+25 Qi por mão, uma vez; blueprint/retrigger não duplicam ganho.', {calculate = function(self, card, context)
            if context.before and once(card, 'qi_spring', context) then T.add_qi(25) end
        end})
    voucher(6, 'dragon_vein', 'Veia do Dragão', {'Receba mais {C:attention}60{} Qi antes de cada mão'},
        '+60 Qi por mão, cumulativo com Fonte de Qi.', {calculate = function(self, card, context)
            if context.before and once(card, 'dragon_vein', context) then T.add_qi(60) end
        end}, {'v_tdg_qi_spring'})
    voucher(7, 'alchemist_license', 'Licença de Alquimista', {'Usar um {C:attention}Elixir{} concede {C:attention}2{} essência'},
        '+2 essência por uso real de elixir, sem ativar em geração ou blueprint.', {calculate = function(self, card, context)
            if safe_context(context) and context.using_consumeable and context.consumeable and
                context.consumeable.ability.set == SET.elixir then gain('essence', 2) end
        end})
    voucher(8, 'immortal_furnace', 'Fornalha Imortal', {'Usar um {C:attention}Elixir{} cria outro aleatório',
        'se houver vaga, e concede {C:attention}2{} insight'},
        'Por uso real de elixir: +2 insight e um elixir aleatório se couber; não encadeia usos automaticamente.',
        {calculate = function(self, card, context)
            if safe_context(context) and context.using_consumeable and context.consumeable and
                context.consumeable.ability.set == SET.elixir then
                gain('insight', 2)
                if consumable_room() then T.create_consumable(SET.elixir, random_key(elixir_keys, 'immortal_furnace')) end
            end
        end}, {'v_tdg_alchemist_license'})
    voucher(9, 'inscription_library', 'Biblioteca das Inscrições', {'Usar uma {C:attention}Técnica{} concede {C:attention}2{} insight'},
        '+2 insight por uso real de técnica.', {calculate = function(self, card, context)
            if safe_context(context) and context.using_consumeable and context.consumeable and
                context.consumeable.ability.set == SET.technique then gain('insight', 2) end
        end})
    voucher(10, 'heavenly_archive', 'Arquivo Celestial', {'Usar uma {C:attention}Técnica{} eleva', 'a mão mais jogada em {C:attention}1{} nível'},
        '+1 nível na mão visível mais jogada por uso de técnica; cumulativo com Biblioteca.',
        {calculate = function(self, card, context)
            if safe_context(context) and context.using_consumeable and context.consumeable and
                context.consumeable.ability.set == SET.technique and favourite_hand() then
                T.safe_level_hand(favourite_hand(), 1, card)
            end
        end}, {'v_tdg_inscription_library'})
    voucher(11, 'demon_contract', 'Pacto Demoníaco', {'Receba {C:attention}2{} essência antes de mãos', 'que contenham um {C:attention}Par{}'},
        '+2 essência uma vez antes de mãos cujo poker_hands.Pair não está vazio.',
        {calculate = function(self, card, context)
            if context.before and context.poker_hands and context.poker_hands.Pair and
                next(context.poker_hands.Pair) and once(card, 'demon_contract', context) then gain('essence', 2) end
        end})
    voucher(12, 'sovereign_pact', 'Juramento do Soberano', {'No cálculo final: {X:mult,C:white}X1 + 0,1 por reino{} Mult'},
        'Xmult final 1 + 0,1 × reino, cumulativo com o Pacto Demoníaco.',
        {calculate = function(self, card, context)
            if context.final_scoring_step then return {x_mult = 1 + 0.1 * realm()} end
        end}, {'v_tdg_demon_contract'})

    local function enhancement(n, key, name, text, effect, calculate, fields)
        local def = {key = key, loc_txt = {name = name, text = text}, config = {}, calculate = calculate}
        for k, v in pairs(fields or {}) do def[k] = v end
        register('Enhancement', 'enhancement', offsets.enhancement + n, def, effect,
            'Textura de carta de cultivação: ' .. name .. ', borda ornamental, centro espaçoso para naipe e valor.')
    end
    enhancement(1, 'spirit_stone', 'Pedra Espiritual', {'{C:chips}+60 + 20 por reino{} fichas',
        'Ao pontuar, receba {C:attention}8{} Qi uma vez por mão'},
        'Ao pontuar: +60+20×reino chips; +8 Qi uma vez por carta/mão.', function(self, card, context)
            if playing(context) then
                if once(card, 'spirit_stone', context) then T.add_qi(8) end
                return {chips = 60 + 20 * realm()}
            end
        end)
    enhancement(2, 'dragon_meridian', 'Meridiano do Dragão', {'{X:mult,C:white}X1,8 + 0,15 por reino{} Mult'},
        'Xmult 1,8+0,15×reino apenas no main_scoring/G.play.', function(self, card, context)
            if playing(context) then return {x_mult = 1.8 + 0.15 * realm()} end
        end)
    enhancement(3, 'phoenix', 'Inscrição da Fênix', {'{C:mult}+12 + 3 por reino{} Mult',
        'Ao pontuar, receba {C:attention}1{} essência uma vez por mão'},
        '+12+3×reino mult e +1 essência por carta/mão.', function(self, card, context)
            if playing(context) then
                if once(card, 'phoenix', context) then gain('essence', 1) end
                return {mult = 12 + 3 * realm()}
            end
        end)
    enhancement(4, 'ice_jade', 'Jade da Alma Gélida', {'Mantida na mão: {X:mult,C:white}X1,5 + 0,05 por reino{} Mult',
        'Mantida ao fim da rodada: {C:attention}+1{} insight'},
        'Held Xmult 1,5+0,05×reino; +1 insight por carta mantida ao fim da rodada.', function(self, card, context)
            if held(context) then return {x_mult = 1.5 + 0.05 * realm()} end
            if round_held(context) and once(card, 'ice_jade_round', context) then gain('insight', 1) end
        end)
    enhancement(5, 'ancient_gold', 'Ouro Ancestral', {'Ao pontuar: {C:money}$2 + $1 a cada 3 reinos{}',
        '{C:inactive}(Também paga em repetições){}'},
        'Dollars 2+floor(reino/3) em cada pontuação; repetições podem repetir o pagamento.', function(self, card, context)
            if playing(context) then return {dollars = 2 + math.floor(realm() / 3)} end
        end)
    enhancement(6, 'five_elements', 'Raiz dos Cinco Elementos', {'Conta como {C:attention}todos os naipes{}',
        '{X:mult,C:white}X1 + 0,25 por elemento dominado{} Mult'},
        'any_suit=true; Xmult 1+0,25×quantidade de elementos com contagem positiva.', function(self, card, context)
            if playing(context) then return {x_mult = 1 + 0.25 * elemental_diversity()} end
        end, {any_suit = true})
    enhancement(7, 'soul_script', 'Escrita do Reino da Alma', {'Ao pontuar, eleve esta mão em {C:attention}1{} nível',
        'e receba {C:attention}1{} insight, uma vez por mão'},
        'Uma vez por carta/mão: T.safe_level_hand(scoring_name,1) e +1 insight; não repete em retrigger.',
        function(self, card, context)
            if playing(context) and context.scoring_name and once(card, 'soul_script', context) then
                T.safe_level_hand(context.scoring_name, 1, card); gain('insight', 1)
            end
        end)
    enhancement(8, 'void_root', 'Raiz do Vazio', {'{C:chips}+120 + 5 por insight{} fichas',
        'Sempre pontua; sem valor nem naipe', 'Ao pontuar, receba {C:attention}15{} Qi uma vez por mão'},
        'Sem rank/suit/base, always_scores; +120+5×insight chips (cap1e100); +15 Qi por carta/mão.',
        function(self, card, context)
            if playing(context) then
                if once(card, 'void_root', context) then T.add_qi(15) end
                return {chips = math.min(1e100, 120 + 5 * resource('insight'))}
            end
        end, {no_rank = true, no_suit = true, replace_base_card = true, always_scores = true})

    local function seal(n, key, name, text, effect, calculate, badge)
        register('Seal', 'seal', offsets.seal + n, {
            key = key, badge_colour = HEX(badge), loc_txt = {name = name, label = name, text = text},
            config = {}, calculate = calculate,
        }, effect, 'Overlay transparente de selo: ' .. name .. ', emblema central, bordas e cantos transparentes, sem fundo opaco.')
    end
    seal(1, 'soul_lotus', 'Selo do Lótus da Alma', {'Ao pontuar: {C:attention}+1{} essência', 'uma vez por mão'},
        '+1 essência por carta/mão ao pontuar.', function(self, card, context)
            if playing(context) and once(card, 'soul_lotus', context) then gain('essence', 1) end
        end, 'C47CFF')
    seal(2, 'thunder', 'Selo do Trovão', {'Repita esta carta {C:attention}1{} vez ao pontuar',
        'Mais uma repetição nos reinos {C:attention}6{} e {C:attention}12{}'},
        'context.repetition/G.play retorna 1+floor(reino/6) repetitions; no máximo três.', function(self, card, context)
            if context.repetition and context.cardarea == G.play then
                return {repetitions = 1 + math.floor(realm() / 6), message = 'Trovão!', card = card}
            end
        end, '65BFFF')
    seal(3, 'alchemist', 'Selo da Associação Alquimista', {'Mantida ao fim da rodada:',
        'crie um {C:attention}Elixir{} TDG aleatório', '{C:inactive}(Requer uma vaga livre){}'},
        'Uma vez por carta/rodada mantida: cria elixir aleatório se houver vaga; sem pagar recursos.',
        function(self, card, context)
            if round_held(context) and consumable_room() and once(card, 'alchemist_round', context) then
                T.create_consumable(SET.elixir, random_key(elixir_keys, 'alchemist_seal'))
            end
        end, '65D6A0')
    seal(4, 'inscription', 'Selo das Inscrições Antigas', {'Ao descartar esta carta:', '{C:attention}+2{} insight'},
        '+2 insight uma vez por carta/ação de descarte, guardando other_card e marcador persistente.',
        function(self, card, context)
            if context.discard and context.other_card == card and once(card, 'inscription_discard', context, 'discard') then
                gain('insight', 2)
            end
        end, 'F0C76E')
    seal(5, 'demon', 'Selo do Espírito Demoníaco', {'Ao pontuar: {X:mult,C:white}X1 + 0,1 por essência{} Mult',
        '{C:inactive}(Máximo X31){}', 'Receba {C:attention}10{} Qi uma vez por mão'},
        'Xmult 1+0,1×min(300,essência), +10 Qi por carta/mão.', function(self, card, context)
            if playing(context) then
                if once(card, 'demon', context) then T.add_qi(10) end
                return {x_mult = 1 + math.min(300, resource('essence')) * 0.1}
            end
        end, 'EC6B73')
    seal(6, 'ancestral', 'Selo da Herança Ancestral', {'Mantida ao fim da rodada:',
        'eleve a última mão em {C:attention}2{} níveis', 'e receba {C:attention}30{} Qi'},
        'Uma vez por carta/rodada mantida: +2 níveis last_hand_played se existir e +30 Qi.',
        function(self, card, context)
            if round_held(context) and once(card, 'ancestral_round', context) then
                local name = G.GAME.last_hand_played
                if name and G.GAME.hands and G.GAME.hands[name] then T.safe_level_hand(name, 2, card) end
                T.add_qi(30)
            end
        end, 'BDA1FF')

    local function edition(n, key, name, shader, text, effect, calculate, badge, weight)
        register('Edition', 'edition', offsets.edition + n, {
            key = key, shader = shader, loc_txt = {name = name, label = name, text = text},
            config = {}, badge_colour = HEX(badge), extra_cost = n + 2, in_shop = true,
            weight = weight, get_weight = function(self) return self.weight * ((G.GAME and G.GAME.edition_rate) or 1) end,
            sound = {sound = shader == 'negative' and 'negative' or shader .. '1', per = 1, vol = 0.4},
            calculate = calculate,
        }, effect, 'Carta de amostra da edição ' .. name .. ', padrão cósmico ornamental ' .. badge .. ', shader nativo ' .. shader .. '.')
    end
    edition(1, 'radiant', 'Alma Radiante', 'foil', {'{C:chips}+120 + 30 por reino{} fichas'},
        'Chips 120+30×reino em pre_joker ou main_scoring/G.play; shader foil.', function(self, card, context)
            if context.pre_joker or playing(context) then return {chips = 120 + 30 * realm()} end
        end, '69DCCD', 8)
    edition(2, 'thunderforged', 'Forjada no Trovão', 'holo', {'{C:mult}+40 + 8 por reino{} Mult'},
        'Mult 40+8×reino em pre_joker ou main_scoring/G.play; shader holo.', function(self, card, context)
            if context.pre_joker or playing(context) then return {mult = 40 + 8 * realm()} end
        end, '75AEFF', 6)
    edition(3, 'spacetime', 'Espaço-Tempo', 'polychrome', {'{X:mult,C:white}X2 + 0,05 por insight{} Mult', '{C:inactive}(Máximo X1000){}'},
        'Xmult min(1000,2+0,05×insight) em post_joker ou main_scoring/G.play; shader polychrome.', function(self, card, context)
            if context.post_joker or playing(context) then return {x_mult = math.min(1000, 2 + 0.05 * resource('insight'))} end
        end, 'AF85F5', 3)
    edition(4, 'divine', 'Mandato Divino', 'negative', {'Talismã: Mult elevado a {C:attention}1,08 + 0,02 por reino{}',
        'e {C:attention}+0,01{} por reencarnação, até {C:attention}2{}', 'Sem Talismã: bônus {X:mult,C:white}XMult{} equivalente'},
        'T.power_effect(min(2,1,08+0,02×reino+0,01×rebirths)); shader negative, não adiciona slots.',
        function(self, card, context)
            if context.post_joker or playing(context) then
                return T.power_effect(math.min(2, 1.08 + 0.02 * realm() + 0.01 * resource('rebirths')))
            end
        end, 'EBCF85', 1)

    local pack_n = 0
    for _, category in ipairs({'elixir', 'technique', 'relic'}) do
        local labels = {elixir = 'Alquimia', technique = 'Artes Marciais', relic = 'Tesouros Ancestrais'}
        for _, size in ipairs({{key = 'normal', label = '', extra = 3, choose = 1, cost = 4, weight = 1},
            {key = 'jumbo', label = 'Jumbo ', extra = 5, choose = 1, cost = 6, weight = 0.7},
            {key = 'mega', label = 'Mega ', extra = 5, choose = 2, cost = 8, weight = 0.35}}) do
            pack_n = pack_n + 1
            local pack_set, label = SET[category], labels[category]
            local pack_key = category .. '_' .. size.key
            register('Booster', 'booster', offsets.booster + pack_n, {
                key = pack_key, kind = pack_set, cost = size.cost, weight = size.weight,
                config = {extra = size.extra, choose = size.choose}, draw_hand = true, select_card = 'consumeables',
                loc_txt = {name = size.label .. 'Pacote de ' .. label, group_name = 'Pacote de ' .. label,
                    text = {'Guarde {C:attention}#1#{} de até', '{C:attention}#2#{} consumíveis de ' .. label,
                        '{C:inactive}(Requer espaço para guardar){}'}},
                create_card = function(self, card, i)
                    return {set = pack_set, area = G.pack_cards, skip_materialize = true,
                        soulable = false, key_append = 'tdg_' .. pack_key .. '_' .. i}
                end,
            }, 'Guardar ' .. size.choose .. ' entre ' .. size.extra .. ' de ' .. pack_set ..
                '; custo $' .. size.cost .. '; peso ' .. size.weight .. '; select_card=consumeables.',
                'Pacote lacrado de ' .. label .. ' ' .. size.label .. ', ornamentação de cultivação, jade e dourado.')
        end
    end

    local function back(n, key, name, text, effect, config, apply, calculate, art)
        register('Back', 'back', offsets.back + n, {key = key, loc_txt = {name = name, text = text},
            config = config, apply = apply, calculate = calculate}, effect, art)
    end
    back(1, 'glory_city', 'Cidade da Glória', {'Comece com {C:money}+$15{}, {C:attention}40{} Qi e {C:attention}3{} karma'},
        'config.dollars=15; início +40 Qi e +3 karma.', {dollars = 15},
        function() T.add_qi(40); gain('karma', 3) end, nil,
        'Verso de carta com muralhas da Cidade da Glória sob aurora dourada.')
    back(2, 'alchemist', 'Associação dos Alquimistas', {'{C:attention}+1{} espaço de consumível; comece em {C:attention}Alquimia{}',
        'Receba {C:attention}8{} essência e dois elixires iniciais'},
        'Caminho alchemist, +8 essência, +1 vaga nativa, Concentração Espiritual e Refino Demoníaco iniciais.',
        {consumable_slot = 1, consumables = {'c_tdg_spirit_gather', 'c_tdg_demon_refining'}},
        function() state().path = 'alchemist'; gain('essence', 8) end, nil,
        'Verso de carta com caldeirão da Associação dos Alquimistas e chamas verdes.')
    back(3, 'winged_dragon', 'Família Dragão Alado', {'{C:blue}+1{} mão, {C:red}-1{} descarte por rodada',
        'Comece com {C:attention}80{} Qi', 'Antes da mão: {C:attention}15{} Qi por carta de Fogo pontuante'},
        'Config nativa +1 mão/-1 descarte; início +80 Qi; before +15 Qi por T.element=fire na scoring_hand.',
        {hands = 1, discards = -1}, function() T.add_qi(80) end,
        function(self, deck, context)
            if context.before and once(nil, 'winged_dragon_back', context) then
                local n = 0; for _, c in ipairs(context.scoring_hand or {}) do if T.element(c) == 'fire' then n = n + 1 end end
                T.add_qi(15 * n)
            end
        end, 'Verso azul com dragão alado, relâmpagos e brasão de família.')
    back(4, 'inscription', 'Biblioteca das Inscrições', {'{C:attention}+1{} tamanho de mão; comece em {C:attention}Inscrições{}',
        'Receba {C:attention}5{} insight e um Cristal de Medição da Alma', 'Todos os Ases começam com o {C:attention}Selo das Inscrições{}'},
        'Caminho inscription, +5 insight, +1 hand_size, cristal inicial; aplica selo de descarte a todos os Ases após criar o deck.',
        {hand_size = 1, consumables = {'c_tdg_soul_crystal'}},
        function()
            state().path = 'inscription'; gain('insight', 5)
            T.defer(function() for _, c in ipairs(G.playing_cards or {}) do
                if c:get_id() == 14 then c:set_seal('tdg_inscription', true, true) end
            end end)
        end, nil, 'Verso com matriz de runas em jade azul, biblioteca antiga e quatro estrelas.')
    back(5, 'demon', 'Caldeirão da Fusão Demoníaca', {'{C:attention}+1{} espaço de Coringa; {C:red}-1{} descarte',
        'Comece em {C:attention}Fusão Demoníaca{} com {C:attention}12{} essência', 'No cálculo final: {X:mult,C:white}X1 + 0,05 por essência{} Mult', '{C:inactive}(Máximo X16){}'},
        'Caminho demon, +12 essência, +1 joker_slot/-1 descarte nativos; Xmult final 1+0,05×min(300,essência).',
        {joker_slot = 1, discards = -1}, function() state().path = 'demon'; gain('essence', 12) end,
        function(self, deck, context)
            if context.final_scoring_step then return {x_mult = 1 + 0.05 * math.min(300, resource('essence'))} end
        end, 'Verso rubro com dois espíritos entrelaçados sobre um caldeirão negro.')
    back(6, 'spacetime', 'Herdeiro do Espaço-Tempo', {'Comece com {C:money}-$4{}, {C:attention}15{} insight',
        'e {C:attention}1{} reencarnação', 'Vencer um chefe concede {C:attention}160{} Qi e {C:attention}2{} karma'},
        'config.dollars=-4; +15 insight/+1 rebirth inicial; end_of_round global de chefe +160 Qi/+2 karma uma vez.',
        {dollars = -4}, function() gain('insight', 15); gain('rebirths', 1) end,
        function(self, deck, context)
            if context.end_of_round and context.main_eval and not context.game_over and not context.individual and not context.repetition and
                G.GAME.blind and G.GAME.blind.boss and once(nil, 'spacetime_back', context) then
                T.add_qi(160); gain('karma', 2)
            end
        end, 'Verso com o Livro do Espaço-Tempo, ampulheta dourada e um círculo de renascimento.')

    local function tag(n, key, name, text, effect, apply, art)
        register('Tag', 'tag', offsets.tag + n, {key = key, atlas = 'tdg_tags', pos = {x = n - 1, y = 0},
            min_ante = 1, loc_txt = {name = name, text = text}, config = {}, apply = apply}, effect, art)
    end
    local function immediate(action)
        return function(self, tag_card, context)
            if context.type ~= 'immediate' or tag_card.triggered then return end
            tag_card.triggered = true
            tag_card:yep('+', G.C.GOLD, function() action(); return true end)
            return true
        end
    end
    tag(1, 'qi', 'Marca da Fonte Espiritual', {'Receba {C:attention}150 + 25 por reino{} Qi'},
        'Tag immediate: Qi 150+25×reino, consumida uma vez.', immediate(function() T.add_qi(150 + 25 * realm()) end),
        'Ícone quadrado: gota de Qi verde dentro de uma fonte de jade, transparência exterior.')
    tag(2, 'insight', 'Marca da Iluminação', {'Receba {C:attention}8{} insight e {C:attention}2{} karma'},
        'Tag immediate: +8 insight/+2 karma uma vez.', immediate(function() gain('insight', 8); gain('karma', 2) end),
        'Ícone quadrado: olho espiritual dourado sobre pergaminho azul, transparência exterior.')
    tag(3, 'essence', 'Marca do Refino', {'Receba {C:attention}10{} essência e {C:money}$8{}'},
        'Tag immediate: +10 essência/+$8 uma vez.', immediate(function() gain('essence', 10); ease_dollars(8) end),
        'Ícone quadrado: pequeno caldeirão rubro com três pérolas espirituais, transparência exterior.')
    tag(4, 'alchemy', 'Marca da Caravana Alquimista', {'No início da próxima loja com vaga:',
        'receba um {C:attention}Elixir{} TDG aleatório'},
        'shop_start, aguarda vaga; cria um elixir aleatório, só consome tag após criação bem-sucedida.',
        function(self, tag_card, context)
            if context.type ~= 'shop_start' or tag_card.triggered or not consumable_room() then return end
            local created = T.create_consumable(SET.elixir, random_key(elixir_keys, 'alchemy_tag'))
            if not created then return end
            tag_card.triggered = true; tag_card:yep('+', colour.elixir, function() return true end); return true
        end, 'Ícone quadrado: bolsa de jade com pílula verde, transparência exterior.')
    tag(5, 'technique', 'Marca do Mestre Errante', {'No início da próxima loja com vaga:',
        'receba uma {C:attention}Técnica{} TDG aleatória'},
        'shop_start, aguarda vaga; cria uma técnica aleatória, só consome tag após criação bem-sucedida.',
        function(self, tag_card, context)
            if context.type ~= 'shop_start' or tag_card.triggered or not consumable_room() then return end
            local created = T.create_consumable(SET.technique, random_key(technique_keys, 'technique_tag'))
            if not created then return end
            tag_card.triggered = true; tag_card:yep('+', colour.technique, function() return true end); return true
        end, 'Ícone quadrado: pergaminho azul com asa de dragão, transparência exterior.')
    tag(6, 'heritage', 'Marca da Herança Ancestral', {'Eleve todas as mãos visíveis em {C:attention}1{} nível',
        'e receba {C:attention}40{} Qi'},
        'Tag immediate: T.safe_level_hand em todas as mãos visíveis +40 Qi uma vez.',
        immediate(function() for _, name in ipairs(visible_hands()) do T.safe_level_hand(name, 1) end; T.add_qi(40) end),
        'Ícone quadrado: livro dourado com montanha celestial e halo violeta, transparência exterior.')
end

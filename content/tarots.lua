-- TDG 1.1.0: true Tarot cards, using the installed Steamodded API.
return function(T)
    local C = {}
    local factories = {}
    local pending = setmetatable({}, {__mode = 'k'})
    T.tarots_catalog = {
        schema_version = 1, mod = 'TDG — Ascensão', version = '1.1.0',
        category = 'tarot', set = 'Tarot', language = 'pt_BR', index_base = 1,
        atlas = {key = 'tdg_arcana', columns = 6, rows = 3, px = 71, py = 95,
            width_1x = 426, height_1x = 285, width_2x = 852, height_2x = 570,
            tarot_indices = {1, 12}, planet_indices = {13, 18}},
        adaptation = 'Fan mod não oficial; arcanos e efeitos são adaptações originais de cultivação.',
        items = C,
    }

    local function run()
        return G and G.GAME and G.GAME.current_round and
            (not G.STAGES or G.STAGE == G.STAGES.RUN)
    end
    local function available(card)
        return card and card.ability and card.base and not card.removed and
            not card.destroyed and not card.shattered and not card.getting_sliced
    end
    local function selection(minimum, maximum, physical)
        local hand = G and G.hand
        local list = hand and hand.highlighted
        if not list or #list < minimum or #list > maximum then return nil end
        local result, seen = {}, {}
        for _, c in ipairs(list) do
            if seen[c] or c.area ~= hand or not available(c) then return nil end
            if physical and (not c.base.value or not c.base.suit or
                not SMODS.Ranks[c.base.value] or not SMODS.Suits[c.base.suit] or
                (SMODS.has_no_rank and SMODS.has_no_rank(c)) or
                (SMODS.has_no_suit and SMODS.has_no_suit(c))) then return nil end
            seen[c] = true
            result[#result + 1] = c
        end
        return result
    end
    local function value(key) return T.state()[key] or 0 end
    local function pay(key, amount) T.add_resource(key, -amount) end
    local function enough(key, amount) return value(key) >= amount end
    local function consumable_room()
        local area = G and G.consumeables
        return area and area.cards and area.config and
            #area.cards + (G.GAME.consumeable_buffer or 0) < area.config.card_limit
    end
    local function deck_ready()
        return G and G.deck and G.deck.config and G.playing_cards and G.deck.emplace and
            G.deck.config.card_limit ~= nil
    end
    local function native_rank(card) return SMODS.Ranks[card.base.value].id end
    local function edition_key(card)
        local edition = card.edition
        if type(edition) ~= 'table' or not next(edition) then return nil end
        if edition.key then return edition.key end
        for key, present in pairs(edition) do if present == true then return key end end
    end
    local function inherit_pair()
        local cards = selection(2, 2, true)
        if not cards then return nil end
        local a, b = native_rank(cards[1]), native_rank(cards[2])
        if a == b then return nil end
        local donor, target = a > b and cards[1] or cards[2], a > b and cards[2] or cards[1]
        if not donor.seal and not edition_key(donor) then return nil end
        if donor.seal == target.seal and edition_key(donor) == edition_key(target) then return nil end
        return donor, target
    end
    local function destruction_targets()
        local targets = selection(1, 2)
        if not targets or not G.playing_cards then return nil end
        local live = 0
        for _, c in ipairs(G.playing_cards) do if available(c) then live = live + 1 end end
        if live <= #targets then return nil end
        for _, c in ipairs(targets) do
            if SMODS.is_eternal(c, {destroy_cards = true}) then return nil end
        end
        return targets
    end
    local function planet_candidates()
        local list, least_played = {}, nil
        for _, center in ipairs(G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Planet or {}) do
            local hand = center.config and G.GAME.hands and G.GAME.hands[center.config.hand_type]
            if hand and hand.visible ~= false and
                not (G.GAME.banned_keys and G.GAME.banned_keys[center.key]) then
                local played = hand.played or 0
                if least_played == nil or played < least_played then list, least_played = {}, played end
                if played == least_played then list[#list + 1] = center.key end
            end
        end
        -- Mod loading order must not bias a seeded tie between equally neglected hands.
        table.sort(list)
        return list
    end
    local suit_cycle = {Hearts = 'Diamonds', Diamonds = 'Clubs', Clubs = 'Spades', Spades = 'Hearts'}
    local elemental_suits = {{element = 'fire', suit = 'Hearts'}, {element = 'water', suit = 'Spades'},
        {element = 'wood', suit = 'Clubs'}, {element = 'metal', suit = 'Diamonds'}}
    local function elemental_candidates()
        local candidates, lowest = {}, nil
        local elements = T.state().elements or {}
        for _, pair in ipairs(elemental_suits) do
            local amount = elements[pair.element] or 0
            if lowest == nil or amount < lowest then candidates, lowest = {}, amount end
            if amount == lowest then candidates[#candidates + 1] = pair end
        end
        return candidates
    end
    local function can_change_suits(minimum, maximum)
        local cards = selection(minimum, maximum, true)
        if not cards then return false end
        for _, c in ipairs(cards) do if not suit_cycle[c.base.suit] then return false end end
        return true
    end
    local function change_bases(changes)
        local applied = {}
        for _, change in ipairs(changes) do
            local c = change.card
            local before = {card = c, suit = c.base.suit, rank = c.base.value}
            local changed = SMODS.change_base(c, change.suit, change.rank)
            if not changed then
                for _, old in ipairs(applied) do SMODS.change_base(old.card, old.suit, old.rank) end
                return false
            end
            applied[#applied + 1] = before
        end
        return true
    end
    local function adopt_playing_card(card, id)
        G.playing_card = id
        card.playing_card = id
        card.params = copy_table(card.params or {})
        card.params.playing_card = id
        card:add_to_deck()
        G.deck.config.card_limit = G.deck.config.card_limit + 1
        G.playing_cards[#G.playing_cards + 1] = card
        G.deck:emplace(card)
        if card.start_materialize then card:start_materialize() end
        if G.deck.shuffle then G.deck:shuffle('tdg_tarot_' .. tostring(id)) end
        playing_card_joker_effects({card})
        return card
    end
    local function consume_kept_source(card, copier)
        -- Factory Tarots stay in the inventory until creation succeeds. The native
        -- use flow sees keep_on_use=true and will not dissolve/remove this source.
        if not card or copier then return end
        if card.area then card.area:remove_card(card) end
        card:remove_from_deck()
        card:start_dissolve()
    end
    local function successful_use(key)
        T.add_resource('tarots', 1)
        local state = T.state()
        state.stats = state.stats or {}
        state.stats.tarot_uses = state.stats.tarot_uses or {}
        state.stats.tarot_uses[key] = math.min(1e100, (state.stats.tarot_uses[key] or 0) + 1)
    end
    local factory_builders = {
        soul_mirror = function(targets)
            local source = targets[1]
            local id = (G.playing_card or 0) + 1
            local original_params, original_id = source.params, source.params and source.params.playing_card
            local clone = copy_card(source, nil, nil, id)
            if original_params then original_params.playing_card = original_id; source.params = original_params end
            if clone then
                clone.params = copy_table(original_params or clone.params or {})
                clone.params.playing_card = id
            end
            return clone
        end,
        earth_seed = function()
            return SMODS.create_card {set = 'Base', area = G.deck, suit = 'Spades', rank = '2',
                enhancement = 'm_tdg_void_root', seal = 'tdg_ancestral', no_edition = true,
                skip_materialize = true, key_append = 'tdg_earth_seed'}
        end,
        lost_constellation = function()
            local key = pseudorandom_element(planet_candidates(), pseudoseed('tdg_lost_constellation'))
            return SMODS.create_card {set = 'Planet', key = key, area = G.consumeables,
                skip_materialize = true, key_append = 'tdg_lost_constellation'}
        end,
    }
    -- A UI preflight must precede Card.use_consumeable: that method records
    -- profile usage before calling obj.use, and use_card always emits the context.
    -- Prepared cards are not adopted, charged, or stored in the save state.
    function T.prepare_tarot_use(card)
        local entry = card and card.config and card.config.center and factories[card.config.center.key]
        if not entry then return true end
        if pending[card] then return true end
        if not entry.allowed(card.config.center, card) then return false end
        local targets = G.hand and selection(1, 5) or nil
        local used = G.GAME.used_jokers
        local old_used, used_changes = {}, {}
        for key, flag in pairs(used or {}) do old_used[key] = flag end
        local result = entry.build(targets)
        -- Card.set_ability marks used centers during construction. Keep pool
        -- bookkeeping unchanged until the prepared Card is actually committed.
        for key, flag in pairs(used or {}) do
            if old_used[key] ~= flag then used_changes[key] = flag end
            if old_used[key] == nil then used[key] = nil end
        end
        for key, flag in pairs(old_used) do used[key] = flag end
        if not result then return false end
        pending[card] = {result = result, targets = targets, game = G.GAME, used_changes = used_changes}
        return true
    end
    function T.cancel_tarot_preflight(card)
        local preparation = pending[card]
        if not preparation then return end
        pending[card] = nil
        local result = preparation.result
        if result and not result.added_to_deck and not result.removed then
            -- Native remove releases sprites and removes the temporary Card from
            -- G.I.CARD. It was never inserted in an area or G.playing_cards.
            if result.remove then
                -- Card.remove also renumbers the entire live deck and clears a
                -- used-center flag. A temporary Card must not change either.
                local ids = {}
                for _, existing in ipairs(G.playing_cards or {}) do ids[existing] = existing.playing_card end
                local used = G.GAME and G.GAME.used_jokers
                local key = result.config and result.config.center and result.config.center.key
                local old_used = used and key and used[key]
                result:remove()
                for existing, id in pairs(ids) do existing.playing_card = id end
                if used and key then used[key] = old_used end
            elseif result.start_dissolve then result:start_dissolve() end
        end
    end
    function T.install_tarot_use_guard()
        if not G or not G.FUNCS or type(G.FUNCS.use_card) ~= 'function' then return false end
        if G.FUNCS.use_card == T._tarot_use_guard then return true end
        local previous = G.FUNCS.use_card
        local function packed(...) return {n = select('#', ...), ...} end
        local function guarded(e, ...)
            local card = e and e.config and e.config.ref_table
            local entry = card and card.config and card.config.center and factories[card.config.center.key]
            -- Packing a factory Tarot is selection, not use. Ordinary Tarots and
            -- every unrelated card retain the previous native/modded callback.
            if not entry or card.area == G.pack_cards then return previous(e, ...) end
            if card.check_use and card:check_use() then return previous(e, ...) end
            if not T.prepare_tarot_use(card) then return false end
            local result = packed(pcall(previous, e, ...))
            if not result[1] then
                T.cancel_tarot_preflight(card)
                error(result[2], 0)
            end
            if pending[card] then
                local locked = G.CONTROLLER and G.CONTROLLER.locks and G.CONTROLLER.locks.use
                if not locked then
                    T.cancel_tarot_preflight(card)
                elseif G.E_MANAGER and Event then
                    -- Native/modded use may run later. This nonblocking monitor
                    -- retains the preparation until obj.use commits or the use
                    -- lock is released; it never races ahead and retries creation.
                    G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0,
                        blocking = false, blockable = false, func = function()
                            if not pending[card] then return true end
                            if G.CONTROLLER and G.CONTROLLER.locks and G.CONTROLLER.locks.use then return false end
                            T.cancel_tarot_preflight(card)
                            return true
                        end}))
                end
            end
            return unpack(result, 2, result.n)
        end
        T._tarot_use_guard = guarded
        G.FUNCS.use_card = guarded
        return true
    end
    local function tarot(index, key, name, text, description, art_prompt, predicate, action, factory)
        local function allowed(self, card)
            if not run() then return false end
            if card and (card.debuff or card.REMOVED or card.removed or card.destroyed or
                card.shattered or card.getting_sliced) then return false end
            -- Buy-and-use has no source area. Factory failures must preserve their
            -- source, so these three cards are bought normally and used in inventory.
            if factory and (not card or card.area ~= G.consumeables) then return false end
            return not not predicate(self, card)
        end
        if factory then factories['c_tdg_' .. key] = {allowed = allowed, build = factory_builders[key]} end
        C[#C + 1] = {category = 'tarot', class = 'Consumable', set = 'Tarot', index = index,
            key = 'c_tdg_' .. key, registration_key = key, name = name,
            description = description, effect = description, art_prompt = art_prompt,
            atlas = 'tdg_arcana', pos = T.atlas_pos(index, 6),
            use_rule = factory and 'Compre/guarde e use no inventário; falha de criação preserva a carta.' or
                'Uso direto em pacotes Arcanos; a compra comum guarda no inventário.'}
        SMODS.Consumable {
            key = key, set = 'Tarot', atlas = 'tdg_arcana', prefix_config = {atlas = false},
            pos = T.atlas_pos(index, 6), cost = 3, unlocked = true, discovered = true,
            select_card = factory and 'consumeables' or nil, loc_txt = {name = name, text = text}, config = {},
            can_use = allowed,
            keep_on_use = function(self, card) return factory or not allowed(self, card) end,
            use = function(self, card, area, copier)
                local preparation = factory and pending[card]
                if not preparation then
                    if not allowed(self, card) then return false end
                    if factory then
                        if not T.prepare_tarot_use(card) then return false end
                        preparation = pending[card]
                    end
                end
                if preparation and preparation.game ~= G.GAME then T.cancel_tarot_preflight(card); return false end
                local targets = preparation and preparation.targets or (G.hand and selection(1, 5) or nil)
                if action(self, card, targets, preparation and preparation.result) == false then
                    if factory then T.cancel_tarot_preflight(card) end
                    return false
                end
                if factory then
                    if G.GAME.used_jokers then
                        for key, flag in pairs(preparation.used_changes) do G.GAME.used_jokers[key] = flag end
                    end
                    pending[card] = nil
                end
                successful_use(self.key)
                if factory then consume_kept_source(card, copier) end
                -- Only cosmetics are deferred; all costs and successful mutations
                -- commit together and callbacks never read a later highlighted list.
                T.defer(function()
                    if card and not card.removed and card.juice_up then card:juice_up(0.3, 0.5) end
                    for _, c in ipairs(targets or {}) do
                        if available(c) and c.juice_up then c:juice_up(0.3, 0.3) end
                    end
                    if G and G.hand and G.hand.unhighlight_all then G.hand:unhighlight_all() end
                end)
                return true
            end,
        }
    end

    tarot(1, 'elemental_river', 'Rio dos Cinco Elementos',
        {'Gire o naipe de até {C:attention}4{} cartas selecionadas',
            'Fogo → Metal → Madeira → Água → Fogo', 'Receba {C:attention}10{} Qi por carta', '{C:inactive}(Requer valor e naipe){}'},
        'Gire a afinidade de 1–4 cartas: Fogo→Metal→Madeira→Água→Fogo. Preserve valor, melhoria, selo e edição; +10 Qi por carta.',
        'Rio circular de jade passando por chama vermelha, metal dourado, folha verde e água azul; arcano de cultivação com moldura dourada.',
        function() return can_change_suits(1, 4) end,
        function(self, card, targets)
            local changes = {}
            for _, c in ipairs(targets) do changes[#changes + 1] = {card = c, suit = suit_cycle[c.base.suit]} end
            if not change_bases(changes) then return false end
            T.add_qi(10 * #targets)
        end)
    tarot(2, 'celestial_balance', 'Balança Celestial',
        {'Troque os valores de {C:attention}2{} cartas selecionadas',
            'de valores diferentes; preserve seus naipes', 'Receba {C:attention}2{} insight', '{C:inactive}(Requer cartas com valor e naipe){}'},
        'Troque os valores de exatamente duas cartas de valores diferentes, preservando naipes e propriedades; +2 insight.',
        'Balança de bronze entre duas cartas rúnicas em alturas diferentes, esfera de alma no centro; arcano em azul e ouro.',
        function() local cards = selection(2, 2, true); return cards and cards[1].base.value ~= cards[2].base.value end,
        function(self, card, targets)
            local a, b = targets[1], targets[2]
            if not change_bases({{card = a, rank = b.base.value}, {card = b, rank = a.base.value}}) then return false end
            T.add_resource('insight', 2)
        end)
    tarot(3, 'soul_mirror', 'Espelho da Alma',
        {'Gaste {C:attention}4{} essência para clonar', 'uma carta selecionada no baralho',
            'Preserve valor, naipe, melhoria, selo e edição', '{C:inactive}(Compre/guarde e use no inventário){}'},
        'Gaste 4 essência para clonar uma carta selecionada no baralho, preservando suas propriedades.',
        'Espelho de jade duplicando a mesma carta espiritual, reflexos violeta e dourados, moldura de tarô original.',
        function() return enough('essence', 4) and selection(1, 1) and deck_ready() end,
        function(self, card, targets, clone)
            adopt_playing_card(clone, (G.playing_card or 0) + 1)
            pay('essence', 4)
        end, true)
    tarot(4, 'fate_offering', 'Oferenda ao Destino',
        {'Destrua até {C:attention}2{} cartas selecionadas', 'Receba {C:attention}2{} karma e {C:attention}40{} Qi por carta',
            'Preserve ao menos uma carta no baralho', '{C:inactive}(Não afeta cartas eternas){}'},
        'Destrua 1–2 cartas selecionadas e ganhe 2 karma e 40 Qi por carta; preserve ao menos uma carta no baralho.',
        'Duas cartas dissolvendo em pétalas diante de altar de pedra; balança de destino e chama espiritual branca.',
        function() return destruction_targets() ~= nil end,
        function(self, card, targets)
            SMODS.destroy_cards(targets, nil, true)
            local removed = 0
            for _, c in ipairs(targets) do if c.destroyed or c.shattered then removed = removed + 1 end end
            if removed == 0 then return false end
            T.add_resource('karma', 2 * removed); T.add_qi(40 * removed)
        end)
    tarot(5, 'ancestral_inheritance', 'Herança Ancestral',
        {'Gaste {C:attention}2{} karma; selecione {C:attention}2{} cartas',
            'A menor recebe o selo e a edição da maior', 'A doadora é preservada; valores devem diferir', '{C:inactive}(A maior deve ter selo ou edição){}'},
        'Gaste 2 karma: a carta de menor valor recebe o selo e a edição da carta de maior valor entre duas selecionadas; preserve a doadora.',
        'Duas mãos, anciã e jovem, compartilhando uma gema de selo e uma aura cósmica; pergaminho de linhagem.',
        function() return enough('karma', 2) and inherit_pair() ~= nil end,
        function()
            local donor, target = inherit_pair()
            target:set_seal(donor.seal, true, true)
            target:set_edition(copy_table(donor.edition or {}), true, true)
            pay('karma', 2)
        end)
    tarot(6, 'earth_seed', 'Semente da Terra',
        {'Gaste {C:attention}3{} essência para adicionar', 'uma {C:attention}Raiz do Vazio{} ao baralho',
            'com {C:attention}Selo da Herança Ancestral{}', '{C:inactive}(Compre/guarde e use no inventário){}'},
        'Gaste 3 essência para adicionar ao baralho uma carta Raiz do Vazio com Selo da Herança Ancestral.',
        'Semente dourada brotando de uma rocha flutuante, raiz azul envolvendo uma carta de pedra e selo ancestral.',
        function() return enough('essence', 3) and deck_ready() and G.P_CENTERS.m_tdg_void_root end,
        function(self, source, targets, card)
            adopt_playing_card(card, (G.playing_card or 0) + 1)
            pay('essence', 3)
        end, true)
    tarot(7, 'elemental_mandate', 'Mandato Elemental',
        {'Até {C:attention}3{} cartas recebem o naipe', 'do elemento menos praticado entre os quatro naipes',
            'Seu domínio cresce {C:attention}3{} por carta', '{C:inactive}(Empates aleatórios; requer valor e naipe){}'},
        '1–3 cartas recebem o naipe do elemento menos praticado entre Fogo/Água/Madeira/Metal; fortaleça o domínio desse elemento em 3 por carta.',
        'Imperador espiritual escolhendo a mais tênue de quatro chamas elementais sobre cartas de jade.',
        function() return can_change_suits(1, 3) end,
        function(self, card, targets)
            local pair = pseudorandom_element(elemental_candidates(), pseudoseed('tdg_elemental_mandate'))
            local changes = {}
            for _, c in ipairs(targets) do changes[#changes + 1] = {card = c, suit = pair.suit} end
            if not change_bases(changes) then return false end
            local state = T.state(); state.elements = state.elements or {}
            state.elements[pair.element] = math.min(1e100, (state.elements[pair.element] or 0) + 3 * #targets)
        end)
    tarot(8, 'tribulation_lantern', 'Lanterna da Tribulação',
        {'Gaste {C:attention}4{} karma para completar', 'o desafio da tribulação ativa',
            'A recompensa exige vencer o chefe', '{C:inactive}(Requer tribulação ainda incompleta){}'},
        'Gaste 4 karma para completar o desafio da tribulação ativa; a recompensa continua condicionada à vitória no chefe.',
        'Lanterna celestial dourada protegendo um cultivador de relâmpagos violeta, céu de tribulação.',
        function()
            local tr = T.state().tribulation
            return enough('karma', 4) and tr and tr.active and (tr.progress or 0) < (tr.target or 1)
        end,
        function() local tr = T.state().tribulation; tr.progress = tr.target or 1; pay('karma', 4) end)
    tarot(9, 'open_path', 'Caminho Aberto',
        {'Mude de caminho: Alquimia → Fusão → Inscrições', 'Sem caminho começa em {C:attention}Alquimia{}',
            'Primeira escolha grátis; demais custam {C:attention}2{} essência'},
        'Mude de caminho em ciclo: nenhum→Alquimia→Fusão Demoníaca→Inscrições→Alquimia; primeira escolha grátis, demais custam 2 essência.',
        'Três caminhos de pedra convergindo em portal, caldeirão verde, espírito rubro e runas azuis; viajante visto de costas.',
        function() return T.state().path == 'none' or enough('essence', 2) end,
        function()
            local state = T.state()
            if state.path ~= 'none' then pay('essence', 2) end
            state.path = ({none = 'alchemist', alchemist = 'demon', demon = 'inscription', inscription = 'alchemist'})[state.path] or 'alchemist'
        end)
    tarot(10, 'soul_auction', 'Leilão das Almas',
        {'Venda até {C:attention}10{} essência por {C:money}$3{} cada', 'Receba {C:attention}1{} karma',
            '{C:inactive}(Requer ao menos 1 essência){}'},
        'Venda até 10 essência por $3 cada e ganhe 1 karma; requer pelo menos 1 essência.',
        'Leilão de pérolas espirituais em uma balança com moedas de bronze e jade; estandarte da Cidade da Glória.',
        function() return enough('essence', 1) end,
        function() local amount = math.min(10, math.floor(value('essence')))
            ease_dollars(3 * amount, true); pay('essence', amount); T.add_resource('karma', 1)
        end)
    tarot(11, 'lost_constellation', 'Constelação Perdida',
        {'Gaste {C:attention}3{} insight para criar o {C:planet}Planeta{}', 'da mão visível menos jogada',
            'Empates aleatórios; requer uma vaga livre', '{C:inactive}(Compre/guarde e use no inventário){}'},
        'Gaste 3 insight para criar o Planeta da mão visível menos jogada, incluindo mãos TDG; requer vaga livre.',
        'Astrólogo desenhando uma constelação quase apagada com seis planetas e uma carta celestial; luz azul suave.',
        function() return enough('insight', 3) and consumable_room() and #planet_candidates() > 0 end,
        function(self, source, targets, card)
            card:add_to_deck()
            G.consumeables:emplace(card)
            if card.start_materialize then card:start_materialize() end
            pay('insight', 3)
        end, true)
    tarot(12, 'dao_ladder', 'Escada Celestial',
        {'Selecione {C:attention}5{} cartas com valor e naipe', 'Da esquerda para a direita na mão,',
            'seus valores se tornam {C:attention}2, 4, 6, 8, 10{}', 'Preserve naipes, melhorias, selos e edições'},
        'Selecione cinco cartas: da esquerda para a direita, seus valores se tornam 2,4,6,8,10; preserve naipes e propriedades.',
        'Cinco degraus suspensos com símbolos 2,4,6,8,10, ascensão ao Dao acima de nuvens douradas, moldura de tarô.',
        function() return selection(5, 5, true) ~= nil end,
        function(self, card, targets)
            local positions = {}
            for i, c in ipairs(G.hand.cards) do positions[c] = i end
            table.sort(targets, function(a, b) return positions[a] < positions[b] end)
            local changes = {}
            for i, c in ipairs(targets) do changes[#changes + 1] = {card = c, rank = tostring(i * 2)} end
            return change_bases(changes)
        end)
    T.install_tarot_use_guard()
end

-- TDG — Ascensão. Effects are game-design adaptations of Tales of Demons and Gods.
-- Steamodded 1.0.0~BETA-1224a / Talisman 2.7. No score arithmetic in Lua.
return function(T)
    local LIMIT = 1e100
    local catalogue = {}
    local function grow(e, key, n)
        e[key] = math.min(LIMIT, math.max(0, (e[key] or 0) + n))
        return e[key]
    end
    local function clean(c)
        return not c.blueprint and not c.retrigger_joker and not c.retrigger_joker_check
            and not c.repetition and not c.repetition_only
    end
    local function before(c) return c.before and clean(c) and not c.individual end
    local function ending(c) return c.end_of_round and clean(c) and not c.individual end
    local function played(c) return c.individual and c.cardarea == G.play and c.other_card end
    local function held(c) return c.individual and c.cardarea == G.hand and not c.end_of_round and c.other_card end
    local function repeat_play(c) return c.repetition and c.cardarea == G.play and c.other_card end
    local function rank(c)
        if not c or (SMODS.has_no_rank and SMODS.has_no_rank(c)) then return 0 end
        return c:get_id()
    end
    local function face(c) return c and not c.debuff and c:is_face() end
    local function suit(c, s) return c and not c.debuff and c:is_suit(s) end
    local function enhancement(c, key)
        return c and not c.debuff and SMODS.has_enhancement(c, key)
    end
    local function count(cards, predicate)
        local n = 0
        for _, c in ipairs(cards or {}) do if predicate(c) then n = n + 1 end end
        return n
    end
    local function size(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
    local function first(c) return c.other_card == (c.scoring_hand or {})[1] end
    local function last(c)
        local h = c.scoring_hand or {}; return #h > 0 and c.other_card == h[#h]
    end
    local function hand(c, h) return c.scoring_name == h end
    local function parts(c, h) return c.poker_hands and c.poker_hands[h] and next(c.poker_hands[h]) end
    local function realm() return math.min(12, math.max(1, T.state().realm or 1)) end
    local function stage() return math.min(5, math.max(1, T.state().stage or 1)) end
    local function msg(s) return {message = s, colour = G.C.GREEN} end
    local function power(n) return T.power_effect(math.min(3, math.max(1.01, n))) end
    local function current_round() return G.GAME.current_round or {} end
    local function is_boss() return G.GAME.blind and G.GAME.blind.boss end
    local function ready(card, set, key)
        local made = T.create_consumable(set, key)
        if made then return msg('Recebido!') end
    end
    local function level(c, card, n)
        if c.scoring_name then T.safe_level_hand(c.scoring_name, n or 1, card) end
    end
    local function elem_set(cards)
        local found = {}
        for _, c in ipairs(cards or {}) do
            if not c.debuff then found[T.element(c)] = true end
        end
        return found
    end
    local function pure_money_at_least(n)
        -- Lua 5.1 ordered comparisons need matching types on both sides.
        if type(to_big) == 'function' then return to_big(G.GAME.dollars or 0) >= to_big(n) end
        return (G.GAME.dollars or 0) >= n
    end
    local function score_at_least_fraction(fraction)
        local score, target = G.GAME.chips or 0, G.GAME.blind.chips
        if type(to_big) == 'function' then return to_big(score) >= to_big(target)*fraction end
        return score >= target*fraction
    end
    local function charge(n) if pure_money_at_least(n) then ease_dollars(-n, true); return true end end
    local function set_enhancement(c, key)
        if c and not c.debuff and G.P_CENTERS[key] then c:set_ability(G.P_CENTERS[key]); return true end
    end
    local function clone_to_deck(source)
        -- Queued once by the owning Joker, never by individual scoring/repetitions.
        T.defer(function()
            if not source or source.removed or source.destroyed or not G.deck then return end
            G.playing_card = (G.playing_card or 0) + 1
            local new = copy_card(source, nil, nil, G.playing_card)
            new:add_to_deck()
            G.deck.config.card_limit = G.deck.config.card_limit + 1
            G.playing_cards[#G.playing_cards + 1] = new
            G.deck:emplace(new)
            new:start_materialize()
            playing_card_joker_effects({new})
        end)
    end
    local function J(key, name, archetype, rarity, pattern, text, extra, calculate, options)
        options = options or {}
        local index = #catalogue + 1
        local lines = {}
        for line in text:gmatch('[^|]+') do lines[#lines + 1] = line end
        local entry = {key = 'j_tdg_' .. key, name = name, archetype = archetype,
            rarity = rarity, pattern = pattern, effect = text, art_index = index}
        catalogue[index] = entry
        local def = {
            key = key, atlas = 'tdg_jokers', pos = T.atlas_pos(index, 12),
            rarity = rarity, cost = options.cost or ({5, 7, 10, 20})[rarity],
            unlocked = true, discovered = true,
            blueprint_compat = options.blueprint ~= false,
            eternal_compat = options.eternal ~= false,
            perishable_compat = options.perishable ~= false,
            config = {extra = extra or {}},
            loc_txt = {name = name, text = lines},
            tdg_archetype = archetype, tdg_art_index = index,
            tdg_pattern = pattern, tdg_effect = text,
            loc_vars = function(self, info_queue, card)
                local e = card and card.ability and card.ability.extra or self.config.extra
                if type(options.vars) == 'function' then return {vars = options.vars(e, card)} end
                local vars = {}
                for _, k in ipairs(options.vars or {}) do vars[#vars + 1] = e[k] end
                return {vars = vars}
            end,
            calculate = function(self, card, context)
                if not G or not G.GAME or not context then return end
                return calculate(self, card, context, card.ability.extra)
            end,
        }
        if options.card_limit then def.config.card_limit = options.card_limit end
        def.add_to_deck, def.remove_from_deck = options.add_to_deck, options.remove_from_deck
        def.update = options.update
        SMODS.Joker(def)
    end

    -- 1–12: companions, teachers and the defence of Glory City.
    J('nie_li', 'Nie Li', 'personagem', 3, 'crescimento por descoberta',
        'Cada tipo de mão novo concede {C:attention}20 Qi{}|e aumenta este Coringa em {X:mult,C:white}X0.3{} Mult.|Atualmente: {X:mult,C:white}X#1#{} Mult',
        {x = 1, seen = {}}, function(self, card, c, e)
            if before(c) and c.scoring_name and not e.seen[c.scoring_name] then
                e.seen[c.scoring_name] = true; grow(e, 'x', 0.3); T.add_qi(20); return msg('Memórias!')
            end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false})
    J('ye_ziyun', 'Ye Ziyun', 'personagem', 2, 'cartas mantidas por elemento',
        'Cartas de {C:spades}Espadas{} pontuadas dão {C:chips}+45{} Fichas.|Damas de Espadas mantidas na mão|dão {X:mult,C:white}X1.5{} Mult cada.', {}, function(self, card, c)
            if played(c) and suit(c.other_card, 'Spades') then return {chips = 45} end
            if held(c) and rank(c.other_card) == 12 and suit(c.other_card, 'Spades') then return {x_mult = 1.5} end
        end)
    J('xiao_ninger', 'Xiao Ning’er', 'personagem', 2, 'repetição por reino',
        'Cartas de {C:diamonds}Ouros{} pontuadas dão {C:mult}+8{} Mult.|A partir do reino {C:attention}Ouro{},|repete essas cartas {C:attention}1{} vez.', {}, function(self, card, c)
            if played(c) and suit(c.other_card, 'Diamonds') then return {mult = 8} end
            if repeat_play(c) and realm() >= 3 and suit(c.other_card, 'Diamonds') then return {repetitions = 1} end
        end)
    J('lu_piao', 'Lu Piao', 'personagem', 1, 'mão específica e economia',
        '{C:attention}Dois Pares{} dão {C:mult}+24{} Mult.|Jogar Dois Pares concede {C:money}$3{}|uma vez por mão.', {}, function(self, card, c)
            if before(c) and hand(c, 'Two Pair') then return {dollars = 3} end
            if c.joker_main and hand(c, 'Two Pair') then return {mult = 24} end
        end)
    J('du_ze', 'Du Ze', 'personagem', 2, 'diversidade elemental',
        'Mãos pontuadas com {C:attention}3{} elementos distintos|concedem {C:attention}12 Qi{} e {X:mult,C:white}X2{} Mult.', {}, function(self, card, c)
            local diverse = size(elem_set(c.scoring_hand)) >= 3
            if before(c) and diverse then T.add_qi(12); return msg('+12 Qi') end
            if c.joker_main and diverse then return {x_mult = 2} end
        end)
    J('duan_jian', 'Duan Jian', 'personagem', 3, 'figuras mantidas',
        'Cada {C:attention}figura{} mantida na mão|dá {X:mult,C:white}X1.4{} Mult.|Se o Caminho for Fusão Demoníaca, dá {X:mult,C:white}X1.7{}.', {}, function(self, card, c)
            if held(c) and face(c.other_card) then return {x_mult = T.state().path == 'demon' and 1.7 or 1.4} end
        end)
    J('zhang_ming', 'Zhang Ming', 'personagem', 1, 'nível de mão limitado por blind',
        'A primeira {C:attention}Sequência{} de cada blind|sobe {C:attention}1{} nível e concede {C:attention}8 Qi{}.', {used = false}, function(self, card, c, e)
            if c.setting_blind and clean(c) then e.used = false end
            if before(c) and parts(c, 'Straight') and not e.used then
                e.used = true; level(c, card); T.add_qi(8); return msg('Treinamento!')
            end
        end, {blueprint = false})
    J('wei_nan', 'Wei Nan', 'personagem', 1, 'posição na mão pontuada',
        'A última carta pontuada dá {C:chips}+80{} Fichas.|Se seu valor for {C:attention}5 ou menos{},|também dá {X:mult,C:white}X1.5{} Mult.', {}, function(self, card, c)
            if played(c) and last(c) and not c.other_card.debuff then
                return {chips = 80, x_mult = rank(c.other_card) >= 1 and rank(c.other_card) <= 5 and 1.5 or 1}
            end
        end)
    J('zhu_xiangjun', 'Zhu Xiangjun', 'personagem', 1, 'paridade',
        'Valores ímpares pontuados dão {C:chips}+30{} Fichas.|Valores pares pontuados dão {C:mult}+6{} Mult.|Áses contam como ímpares.', {}, function(self, card, c)
            if played(c) and not c.other_card.debuff then
                local r = rank(c.other_card); if r == 0 then return end
                if r == 14 or r % 2 == 1 then return {chips = 30} end
                return {mult = 6}
            end
        end)
    J('xiao_xue', 'Xiao Xue', 'personagem', 1, 'crescimento por descarte',
        'Cada figura descartada concede {C:attention}3 Qi{}|e aumenta este Coringa em {C:mult}+2{} Mult.|Atualmente: {C:mult}+#1#{} Mult', {mult = 0}, function(self, card, c, e)
            if c.pre_discard and clean(c) then
                local n = count(c.full_hand, face); if n > 0 then grow(e, 'mult', 2*n); T.add_qi(3*n); return msg('Disciplina!') end
            end
            if c.joker_main then return {mult = e.mult} end
        end, {vars = {'mult'}, perishable = false})
    J('yang_xin', 'Yang Xin', 'personagem', 2, 'crescimento por elixir',
        'Usar um {C:attention}Elixir{} aumenta este Coringa|em {X:mult,C:white}X0.25{} Mult e dá {C:attention}1 essência{}.|Atualmente: {X:mult,C:white}X#1#{} Mult', {x = 1}, function(self, card, c, e)
            if c.using_consumeable and clean(c) and c.consumeable and c.consumeable.ability.set == 'tdg_Elixir' then
                grow(e, 'x', 0.25); T.add_resource('essence', 1); return msg('Receita refinada!')
            end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false})
    J('ye_mo', 'Ye Mo', 'personagem', 3, 'chefe e cultivação',
        'Contra Chefes: {X:mult,C:white}X3{} Mult.|Vencer um Chefe concede {C:attention}40 Qi{}|e {C:attention}2 insight{}.', {}, function(self, card, c)
            if ending(c) and is_boss() and not c.game_over then T.add_qi(40); T.add_resource('insight', 2); return msg('Glória!') end
            if c.joker_main and is_boss() then return {x_mult = 3} end
        end)

    -- 13–24: bonds, missions and spiritual laws.
    J('ye_zong', 'Ye Zong', 'personagem', 2, 'primeira mão sem descarte',
        'Na primeira mão do blind, sem descartar,|dá {C:chips}+150{} Fichas e {C:attention}15 Qi{}.', {}, function(self, card, c)
            local r = current_round(); local ok = (r.hands_played or 0) == 0 and (r.discards_used or 0) == 0
            if before(c) and ok then T.add_qi(15); return msg('+15 Qi') end
            if c.joker_main and ok then return {chips = 150} end
        end)
    J('chen_lin_jian', 'Chen Linjian', 'personagem', 2, 'missão de aprimoramentos',
        'Missão: pontuar {C:attention}3 melhorias{} diferentes.|Ao concluir: {X:mult,C:white}X3{} Mult e uma {C:attention}Relíquia{}.|A recompensa aguarda uma vaga.|Progresso: {C:attention}#1#/3{}',
        {seen = {}, progress = 0, done = false, reward = false}, function(self, card, c, e)
            if before(c) and not e.done then
                for _, v in ipairs(c.scoring_hand or {}) do
                    local k = v.config.center.key
                    if not v.debuff and v.config.center.set == 'Enhanced' then e.seen[k] = true end
                end
                e.progress = math.min(3, size(e.seen))
                if e.progress >= 3 then e.done = true; e.reward = true end
            end
            if clean(c) and e.reward and (c.after or c.ending_shop or ending(c)) then
                if T.create_consumable('tdg_Relic') then e.reward = false; return msg('Tesouro encontrado!') end
            end
            if c.joker_main and e.done then return {x_mult = 3} end
        end, {vars = {'progress'}, perishable = false})
    J('gu_lan', 'Gu Lan', 'personagem', 2, 'tamanho da mão e madeira',
        '{C:attention}+1{} tamanho de mão.|Cartas de {C:clubs}Paus{} mantidas na mão|dão {C:chips}+25{} Fichas cada.', {}, function(self, card, c)
            if held(c) and suit(c.other_card, 'Clubs') then return {chips = 25} end
        end, {add_to_deck = function() G.hand:change_size(1) end, remove_from_deck = function() G.hand:change_size(-1) end})
    J('gu_bei', 'Gu Bei', 'personagem', 3, 'coleção de tipos de consumível',
        '{C:attention}+1{} vaga de consumível.|Cada tipo de consumível usado pela primeira vez|aumenta este Coringa em {X:mult,C:white}X0.5{} Mult.|Atualmente: {X:mult,C:white}X#1#{} Mult',
        {x = 1, seen = {}}, function(self, card, c, e)
            if c.using_consumeable and clean(c) and c.consumeable then
                local s = c.consumeable.ability.set
                if s and not e.seen[s] then e.seen[s] = true; grow(e, 'x', 0.5); return msg('Coleção ampliada!') end
            end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false,
            add_to_deck = function() G.consumeables.config.card_limit = G.consumeables.config.card_limit + 1 end,
            remove_from_deck = function() G.consumeables.config.card_limit = G.consumeables.config.card_limit - 1 end})
    J('long_yuyin', 'Long Yuyin', 'personagem', 2, 'desafio de cartas altas',
        'Jogar exatamente {C:attention}5{} cartas de valor 10 ou maior|aumenta este Coringa em {X:mult,C:white}X0.4{} Mult.|Atualmente: {X:mult,C:white}X#1#{} Mult', {x = 1}, function(self, card, c, e)
            if before(c) and #(c.full_hand or {}) == 5 and count(c.full_hand, function(v) return not v.debuff and rank(v) >= 10 end) == 5 then
                grow(e, 'x', 0.4); return msg('Superação!')
            end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false})
    J('li_xingyun', 'Li Xingyun', 'personagem', 2, 'economia por venda',
        'Vender outro Coringa concede {C:attention}10 Qi{}|e aumenta este Coringa em {C:mult}+8{} Mult.|Atualmente: {C:mult}+#1#{} Mult', {mult = 0}, function(self, card, c, e)
            if c.selling_card and clean(c) and c.card and c.card ~= card and c.card.ability.set == 'Joker' then
                grow(e, 'mult', 8); T.add_qi(10); return msg('Aliança renovada!')
            end
            if c.joker_main then return {mult = e.mult} end
        end, {vars = {'mult'}, perishable = false})
    J('xiao_yu', 'Xiao Yu', 'personagem', 2, 'alternância de tipos de mão',
        'Alternar entre {C:attention}Par{} e {C:attention}Sequência{}|aumenta este Coringa em {X:mult,C:white}X0.3{} Mult.|Outras mãos interrompem a alternância.|Atualmente: {X:mult,C:white}X#1#{} Mult', {x = 1, previous = ''}, function(self, card, c, e)
            if before(c) then
                local now = hand(c, 'Pair') and 'pair' or (parts(c, 'Straight') and 'straight' or '')
                if now ~= '' and e.previous ~= '' and now ~= e.previous then grow(e, 'x', 0.3) end
                e.previous = now
            end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false})
    J('yu_yan', 'Yu Yan', 'personagem', 3, 'fogo e cultivo por reino',
        'Cada carta de {C:hearts}Copas{} pontuada|dá {X:mult,C:white}X#1#{} Mult.|Bônus: 1 + 0.1 por reino de cultivação.', {}, function(self, card, c)
            if played(c) and suit(c.other_card, 'Hearts') then return {x_mult = 1 + 0.1*realm()} end
        end, {vars = function() return {1 + 0.1*realm()} end})
    J('ying_yueru', 'Ying Yueru', 'personagem', 3, 'profecia de mão rara',
        'A primeira mão de cada blind que foi jogada|no máximo {C:attention}1{} vez nesta run sobe {C:attention}2{} níveis.|Mãos com até 1 uso dão {X:mult,C:white}X2{} Mult.', {used = false, active = false}, function(self, card, c, e)
            if c.setting_blind and clean(c) then e.used = false end
            if before(c) then
                local h = G.GAME.hands and G.GAME.hands[c.scoring_name]
                e.active = h and (h.played or 0) <= 1 or false
                if e.active and not e.used then e.used = true; level(c, card, 2); return msg('Premonição!') end
            end
            if c.joker_main and e.active then return {x_mult = 2} end
        end)
    J('ming', 'Ming', 'personagem', 2, 'crescimento por destruição',
        'Cada carta de baralho destruída aumenta|este Coringa em {C:chips}+35{} Fichas.|Atualmente: {C:chips}+#1#{} Fichas', {chips = 0}, function(self, card, c, e)
            if c.remove_playing_cards and clean(c) then grow(e, 'chips', 35*#(c.removed or {})); return msg('Almas reunidas!') end
            if c.joker_main then return {chips = e.chips} end
        end, {vars = {'chips'}, perishable = false})
    J('imperador_sabio', 'Imperador Sábio', 'personagem', 4, 'potência e tribulação',
        'Durante uma Tribulação: {C:attention}Mult^#1#{}.|Fora dela: {X:mult,C:white}X4{} Mult.|Expoente cresce com o reino.|Sem Talismã, a potência vira XMult.', {}, function(self, card, c)
            if c.joker_main then
                if (T.state().tribulation or {}).active then return power(1.2 + 0.025*realm()) end
                return {x_mult = 4}
            end
        end, {vars = function() return {1.2 + 0.025*realm()} end})
    J('ancestral_kong_ming', 'Ancestral Kong Ming', 'personagem', 4, 'patrimônio de insight',
        'Cada {C:attention}5 insight{} dão {C:mult}+10{} Mult,|até {C:mult}+1000{}.|A partir de {C:attention}25 insight{}: {C:attention}Mult^1.2{}.|Sem Talismã, a potência vira XMult.', {}, function(self, card, c)
            if c.joker_main then
                local n = math.min(500, T.state().insight or 0)
                local ret = n >= 25 and power(1.2) or {}
                ret.mult = math.floor(n/5)*10; return ret
            end
        end)

    -- 25–36: spirit mechanics. Repetitions grant score, never duplicate resources.
    J('panda_presas', 'Panda de Presas', 'espírito', 2, 'equilíbrio vermelho e preto',
        'Se a mão pontuada contiver pelo menos|{C:attention}2 vermelhas{} e {C:attention}2 pretas{},|dá {X:mult,C:white}X2.5{} Mult.', {}, function(self, card, c)
            if c.joker_main then
                local red = count(c.scoring_hand, function(v) return suit(v, 'Hearts') or suit(v, 'Diamonds') end)
                local black = count(c.scoring_hand, function(v) return suit(v, 'Spades') or suit(v, 'Clubs') end)
                if red >= 2 and black >= 2 then return {x_mult = 2.5} end
            end
        end)
    J('sombra_demonio', 'Sombra do Demônio', 'espírito', 2, 'repetição da primeira carta',
        'Em mãos de até {C:attention}3{} cartas jogadas,|repete a primeira carta pontuada {C:attention}2{} vezes.', {}, function(self, card, c)
            if repeat_play(c) and first(c) and #(c.full_hand or {}) <= 3 then return {repetitions = 2} end
        end)
    J('fenix_gelo', 'Fênix de Gelo', 'espírito', 2, 'repetição de cartas mantidas',
        'Repete cartas de {C:spades}Espadas{} mantidas na mão|{C:attention}1{} vez durante a pontuação.|Não repete pagamentos de fim de rodada.', {}, function(self, card, c)
            if c.repetition and c.cardarea == G.hand and not c.end_of_round and suit(c.other_card, 'Spades') then
                if c.card_effects and c.card_effects[1] and (next(c.card_effects[1]) or #c.card_effects > 1) then return {repetitions = 1} end
            end
        end)
    J('relampago_celeste', 'Espírito do Relâmpago Celeste', 'espírito', 2, 'sequência e repetição',
        'Em {C:attention}Sequências{}, repete cada carta pontuada|{C:attention}1{} vez; no Caminho Fusão Demoníaca, {C:attention}2{} vezes.', {}, function(self, card, c)
            if repeat_play(c) and parts(c, 'Straight') then return {repetitions = T.state().path == 'demon' and 2 or 1} end
        end)
    J('dragao_sangue', 'Dragão de Sangue', 'espírito', 3, 'coleção de valores por blind',
        'Pontuar {C:attention}5 valores{} distintos em um blind|aumenta este Coringa em {X:mult,C:white}X0.5{} Mult,|uma vez por blind. Atualmente: {X:mult,C:white}X#1#{}',
        {x = 1, seen = {}, used = false}, function(self, card, c, e)
            if c.setting_blind and clean(c) then e.seen = {}; e.used = false end
            if before(c) and not e.used then
                for _, v in ipairs(c.scoring_hand or {}) do local r = rank(v); if not v.debuff and r > 0 then e.seen[tostring(r)] = true end end
                if size(e.seen) >= 5 then e.used = true; grow(e, 'x', 0.5); return msg('Sangue desperto!') end
            end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false})
    J('qilin_celeste', 'Qilin Celeste', 'espírito', 3, 'primeira mão sem figuras',
        'A primeira mão de cada blind sem figuras|pontuadas concede {C:attention}1 insight{} e {C:attention}15 Qi{}.|Mãos sem figuras dão {X:mult,C:white}X2{} Mult.', {used = false}, function(self, card, c, e)
            if c.setting_blind and clean(c) then e.used = false end
            local ok = #(c.scoring_hand or {}) > 0 and count(c.scoring_hand, face) == 0
            if before(c) and ok and not e.used then e.used = true; T.add_resource('insight', 1); T.add_qi(15); return msg('Pureza!') end
            if c.joker_main and ok then return {x_mult = 2} end
        end)
    J('macaco_espiritual', 'Macaco Espiritual', 'espírito', 2, 'cópia de carta limitada',
        'A primeira mão de {C:attention}1 carta{} de cada blind|copia essa carta para o baralho após pontuar.', {used = false}, function(self, card, c, e)
            if c.setting_blind and clean(c) then e.used = false end
            if c.after and clean(c) and not e.used and #(c.full_hand or {}) == 1 and not c.full_hand[1].debuff then
                e.used = true; clone_to_deck(c.full_hand[1]); return msg('Imitação!')
            end
        end, {blueprint = false})
    J('serpente_alada', 'Serpente Alada', 'espírito', 1, 'cartas jogadas não pontuadas',
        'A primeira carta pontuada dá {X:mult,C:white}X1.5{} Mult,|mais {X:mult,C:white}X0.5{} por carta jogada que não pontuou.', {}, function(self, card, c)
            if played(c) and first(c) and not c.other_card.debuff then
                return {x_mult = 1.5 + 0.5*math.max(0, #(c.full_hand or {}) - #(c.scoring_hand or {}))}
            end
        end)
    J('tigre_presabranca', 'Tigre de Presas Brancas', 'espírito', 1, 'mãos restantes',
        'Na última mão disponível, cada carta pontuada|dá {C:chips}+50{} Fichas e {C:mult}+5{} Mult.', {}, function(self, card, c)
            if played(c) and not c.other_card.debuff and (current_round().hands_left or 0) == 0 then return {chips = 50, mult = 5} end
        end)
    J('tartaruga_negra', 'Tartaruga Negra', 'espírito', 2, 'pedra e mão mantida',
        'Cartas de {C:attention}Pedra{} pontuadas dão {C:chips}+100{} Fichas.|Cada carta mantida na mão dá {C:chips}+10{} Fichas.', {}, function(self, card, c)
            if played(c) and enhancement(c.other_card, 'm_stone') then return {chips = 100} end
            if held(c) and not c.other_card.debuff then return {chips = 10} end
        end)
    J('leao_escarlate', 'Leão Escarlate', 'espírito', 2, 'reserva de fogo por descarte',
        'Descartar Copas aumenta este Coringa em|{C:mult}+3{} Mult por carta; reinicia ao vencer um Chefe.|Atualmente: {C:mult}+#1#{} Mult', {mult = 0}, function(self, card, c, e)
            if c.pre_discard and clean(c) then grow(e, 'mult', 3*count(c.full_hand, function(v) return suit(v, 'Hearts') end)) end
            if c.joker_main then return {mult = e.mult} end
            if ending(c) and is_boss() and not c.game_over then e.mult = 0 end
        end, {vars = {'mult'}})
    J('cervo_esmeralda', 'Cervo Esmeralda', 'espírito', 1, 'renda de cartas mantidas',
        'Ao vencer um blind, cada carta de {C:clubs}Paus{}|mantida na mão rende {C:money}$1{} e {C:attention}2 Qi{}.', {}, function(self, card, c)
            if ending(c) and not c.game_over then
                local n = count(G.hand.cards, function(v) return suit(v, 'Clubs') end)
                if n > 0 then T.add_qi(2*n); return {dollars = n} end
            end
        end, {blueprint = false})

    -- 37–48: spiritual contracts and families.
    J('dragao_negro', 'Dragão Negro', 'espírito', 3, 'consumo de essência por blind',
        'Ao escolher um blind, consome {C:attention}2 essência{}|para ganhar {X:mult,C:white}X0.5{} Mult permanente.|Atualmente: {X:mult,C:white}X#1#{} Mult', {x = 1}, function(self, card, c, e)
            if c.setting_blind and clean(c) and (T.state().essence or 0) >= 2 then
                T.add_resource('essence', -2); grow(e, 'x', 0.5); return msg('Devorado!')
            end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false})
    J('raposa_nove_caudas', 'Raposa de Nove Caudas', 'espírito', 2, 'probabilidade controlada',
        'Cada {C:attention}9{} pontuado dá {C:mult}+9{} Mult.|Cada mão com 9 pontuado tem {C:green}1 em 3{} chance|de gerar um {C:tarot}Tarô{}, se houver vaga.', {}, function(self, card, c)
            if before(c) and count(c.scoring_hand, function(v) return not v.debuff and rank(v) == 9 end) > 0 then
                if SMODS.pseudorandom_probability(card, 'tdg_raposa', 1, 3, 'tdg_raposa') then return ready(card, 'Tarot') end
            end
            if played(c) and not c.other_card.debuff and rank(c.other_card) == 9 then return {mult = 9} end
        end)
    J('borboleta_onirica', 'Borboleta Onírica', 'espírito', 2, 'ciclo de três mãos iguais',
        'Jogar o mesmo tipo de mão {C:attention}3{} vezes seguidas|sobe essa mão {C:attention}2{} níveis e dá {C:attention}1 insight{}.|Sequência atual: {C:attention}#1#/3{}', {previous = '', streak = 0}, function(self, card, c, e)
            if before(c) then
                e.streak = c.scoring_name == e.previous and e.streak + 1 or 1; e.previous = c.scoring_name or ''
                if e.streak >= 3 then e.streak = 0; level(c, card, 2); T.add_resource('insight', 1); return msg('Sonho realizado!') end
            end
        end, {vars = {'streak'}, blueprint = false})
    J('espirito_ancestral', 'Espírito Ancestral', 'espírito', 3, 'potência por reencarnação',
        'Dá {X:mult,C:white}X2{} Mult.|Após uma Reencarnação, dá {C:attention}Mult^#1#{}.|Expoente cresce até 1.8 com Reencarnações.|Sem Talismã, a potência vira XMult.', {}, function(self, card, c)
            if c.joker_main then
                local n = T.state().rebirths or 0
                if n > 0 then return power(1.1 + 0.05*math.min(n, 14)) end
                return {x_mult = 2}
            end
        end, {vars = function() return {1.1 + 0.05*math.min(T.state().rebirths or 0, 14)} end})
    J('familia_marcas', 'Família das Marcas Celestiais', 'facção', 1, 'valores baixos por reino',
        'Cartas {C:attention}2, 3 e 4{} pontuadas|dão {C:chips}+#1#{} Fichas cada.|Bônus: 20 + 10 por reino.', {}, function(self, card, c)
            if played(c) and not c.other_card.debuff and rank(c.other_card) >= 2 and rank(c.other_card) <= 4 then return {chips = 20 + 10*realm()} end
        end, {vars = function() return {20 + 10*realm()} end})
    J('familia_vento_neve', 'Família Vento e Neve', 'facção', 2, 'recompensa por avanço de reino',
        'Ao escolher um blind em um reino maior que o|último registrado, concede {C:blue}+1 mão{} nesse blind.|Cartas de Espadas pontuadas dão {C:mult}+4{} Mult.', {realm = 1}, function(self, card, c, e)
            if c.setting_blind and clean(c) then
                if realm() > e.realm then e.realm = realm(); ease_hands_played(1); return msg('+1 mão') end
                e.realm = realm()
            end
            if played(c) and suit(c.other_card, 'Spades') then return {mult = 4} end
        end)
    J('familia_dragao_alado', 'Família Dragão Alado', 'facção', 2, 'flush de metal',
        'Mãos com pelo menos {C:attention}4 Ouros{} pontuados|dão {X:mult,C:white}X2.5{} Mult e {C:attention}10 Qi{}.|No Caminho Inscrições, também dão {C:attention}1 essência{}.', {}, function(self, card, c)
            local ok = count(c.scoring_hand, function(v) return suit(v, 'Diamonds') end) >= 4
            if before(c) and ok then T.add_qi(10); if T.state().path == 'inscription' then T.add_resource('essence', 1) end; return msg('Asas abertas!') end
            if c.joker_main and ok then return {x_mult = 2.5} end
        end)
    J('familia_sagrada', 'Família Sagrada', 'facção', 2, 'investimento ao escolher blind',
        'Ao escolher um blind, paga {C:money}$5{} se puder|para ganhar {X:mult,C:white}X0.3{} Mult permanente.|Atualmente: {X:mult,C:white}X#1#{} Mult', {x = 1}, function(self, card, c, e)
            if c.setting_blind and clean(c) and charge(5) then grow(e, 'x', 0.3); return msg('Influência!') end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false})
    J('associacao_alquimistas', 'Associação dos Alquimistas', 'facção', 1, 'renda por elixir',
        'Usar um {C:attention}Elixir{} concede {C:money}$4{}|e {C:attention}2 essência{}.|No Caminho Alquimia, concede {C:money}$6{}.', {}, function(self, card, c)
            if c.using_consumeable and clean(c) and c.consumeable and c.consumeable.ability.set == 'tdg_Elixir' then
                T.add_resource('essence', 2); return {dollars = T.state().path == 'alchemist' and 6 or 4}
            end
        end, {blueprint = false})
    J('instituto_orquidea', 'Instituto Orquídea Sagrada', 'facção', 1, 'nível por uso de técnica',
        'Usar uma {C:attention}Técnica{} sobe a mão mais jogada|{C:attention}1{} nível e concede {C:attention}1 insight{}.|Empates seguem a ordem das mãos.', {}, function(self, card, c)
            if c.using_consumeable and clean(c) and c.consumeable and c.consumeable.ability.set == 'tdg_Technique' then
                local best, n = nil, -1
                for _, k in ipairs(G.handlist or {}) do local h = G.GAME.hands[k]; if h and h.visible and (h.played or 0) > n then best, n = k, h.played or 0 end end
                if best then T.safe_level_hand(best, 1, card); T.add_resource('insight', 1); return msg('Estudo!') end
            end
        end, {blueprint = false})
    J('guilda_trevas', 'Guilda das Trevas', 'facção', 2, 'karma por venda',
        'Vender outro Coringa dá {C:attention}1 karma{} e|aumenta este Coringa em {X:mult,C:white}X0.2{} Mult.|Atualmente: {X:mult,C:white}X#1#{} Mult', {x = 1}, function(self, card, c, e)
            if c.selling_card and clean(c) and c.card and c.card ~= card and c.card.ability.set == 'Joker' then
                grow(e, 'x', 0.2); T.add_resource('karma', 1); return msg('Pacto selado!')
            end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false})
    J('seita_penas_divinas', 'Seita das Penas Divinas', 'facção', 2, 'composição de personagens',
        'Dá {C:mult}+8{} Mult por outro Coringa TDG|do arquétipo {C:attention}personagem{}.|Nie Li também concede {X:mult,C:white}X2{} Mult.', {}, function(self, card, c)
            if c.joker_main then
                local n = count(G.jokers.cards, function(v) return v ~= card and not v.debuff and v.config.center.tdg_archetype == 'personagem' end)
                return {mult = 8*n, x_mult = T.has_joker('j_tdg_nie_li') > 0 and 2 or 1}
            end
        end)

    -- 49–60: organisations and tools. Resource costs are paid only on success.
    J('liga_demonios', 'Liga dos Demônios', 'facção', 3, 'slots e composição de espíritos',
        '{C:attention}+1{} vaga de Coringa.|Dá {X:mult,C:white}X0.4{} Mult adicional por outro|Coringa TDG do arquétipo {C:attention}espírito{}.', {}, function(self, card, c)
            if c.joker_main then
                local n = count(G.jokers.cards, function(v) return v ~= card and not v.debuff and v.config.center.tdg_archetype == 'espírito' end)
                return {x_mult = 1 + 0.4*n}
            end
        end, {card_limit = 1})
    J('vale_trovao', 'Vale do Trovão', 'facção', 2, 'pular blind',
        'Pular um blind concede {C:attention}25 Qi{} e aumenta|este Coringa em {C:chips}+75{} Fichas.|Atualmente: {C:chips}+#1#{} Fichas', {chips = 0}, function(self, card, c, e)
            if c.skip_blind and clean(c) then T.add_qi(25); grow(e, 'chips', 75); return msg('Cultivo isolado!') end
            if c.joker_main then return {chips = e.chips} end
        end, {vars = {'chips'}, perishable = false})
    J('reino_abissal', 'Reino Abissal', 'facção', 3, 'dívida e karma',
        'Com menos de {C:money}$10{}, dá {X:mult,C:white}X3{} Mult.|Ao vencer um blind nessa condição,|concede {C:attention}2 karma{} e {C:money}$4{}.', {}, function(self, card, c)
            if c.joker_main and not pure_money_at_least(10) then return {x_mult = 3} end
            if ending(c) and not c.game_over and not pure_money_at_least(10) then T.add_resource('karma', 2); return {dollars = 4} end
        end)
    J('cidade_gloria', 'Cidade da Glória', 'facção', 2, 'defesa sem descartes',
        'Vencer um blind sem descartar aumenta|este Coringa em {X:mult,C:white}X0.3{} Mult e dá {C:money}$3{}.|Atualmente: {X:mult,C:white}X#1#{} Mult', {x = 1}, function(self, card, c, e)
            if ending(c) and not c.game_over and (current_round().discards_used or 0) == 0 then grow(e, 'x', 0.3); return {dollars = 3} end
            if c.joker_main then return {x_mult = e.x} end
        end, {vars = {'x'}, perishable = false})
    J('livro_tempo', 'Livro do Espírito Demoníaco Temporal', 'artefato', 4, 'ciclo temporal de mãos',
        'A cada {C:attention}3 mudanças{} de tipo de mão,|sobe a mão atual {C:attention}2{} níveis e dá {C:attention}2 insight{}.|Dá {C:attention}Mult^1.25{} após 6 mudanças totais.|Sem Talismã, a potência vira XMult.', {previous = '', changes = 0, total = 0}, function(self, card, c, e)
            if before(c) then
                if e.previous ~= '' and c.scoring_name ~= e.previous then grow(e, 'changes', 1); grow(e, 'total', 1) end
                e.previous = c.scoring_name or ''
                if e.changes >= 3 then e.changes = 0; level(c, card, 2); T.add_resource('insight', 2); return msg('Tempo reescrito!') end
            end
            if c.joker_main and e.total >= 6 then return power(1.25) end
        end, {perishable = false})
    J('caldeirao_espiritos', 'Caldeirão dos Espíritos Demoníacos', 'artefato', 2, 'alquimia com vaga verificada',
        'Ao vencer um blind, transforma {C:attention}3 essência{}|em um {C:attention}Elixir{}, se houver vaga.|No Caminho Alquimia, custa {C:attention}2 essência{}.', {}, function(self, card, c)
            if ending(c) and not c.game_over then
                local cost = T.state().path == 'alchemist' and 2 or 3
                if (T.state().essence or 0) >= cost and T.create_consumable('tdg_Elixir') then
                    T.add_resource('essence', -cost); return msg('Refinado!')
                end
            end
        end, {blueprint = false})
    J('vinha_divina', 'Vinha Divina', 'artefato', 2, 'crescimento por cartas adicionadas',
        'Cada carta adicionada ao baralho aumenta|este Coringa em {C:chips}+20{} Fichas|e concede {C:attention}2 Qi{}. Atual: {C:chips}+#1#{} Fichas', {chips = 0}, function(self, card, c, e)
            if c.playing_card_added and clean(c) then
                local n = #(c.cards or {}); if n > 0 then grow(e, 'chips', 20*n); T.add_qi(2*n); return msg('Raízes novas!') end
            end
            if c.joker_main then return {chips = e.chips} end
        end, {vars = {'chips'}, perishable = false})
    J('cristal_alma', 'Cristal da Alma', 'artefato', 1, 'reino e estágio',
        'Dá {C:chips}+#1#{} Fichas e {C:mult}+#2#{} Mult.|Fichas: 25 por reino.|Mult: 3 por estrela ou estágio.', {}, function(self, card, c)
            if c.joker_main then return {chips = 25*realm(), mult = 3*stage()} end
        end, {vars = function() return {25*realm(), 3*stage()} end})
    J('pedra_espiritual', 'Pedra Espiritual', 'artefato', 1, 'renda por cultivação',
        'Ao vencer um blind, rende {C:money}$1{} por reino,|até {C:money}$12{}.|Ganha {C:money}$1{} de valor de venda por Chefe vencido.', {}, function(self, card, c)
            if ending(c) and not c.game_over then
                if is_boss() then
                    card.ability.extra_value = math.min(LIMIT, (card.ability.extra_value or 0) + 1); card:set_cost()
                end
                return {dollars = realm()}
            end
        end, {blueprint = false})
    J('armadura_lendaria', 'Armadura Lendária', 'artefato', 3, 'proteção contra derrota limitada',
        'Salva a run {C:attention}1{} vez se a pontuação acumulada|atingir pelo menos {C:attention}25%{} do alvo do blind.|Também dá {C:chips}+120{} Fichas.|Proteção disponível: {C:attention}#1#{}', {used = false}, function(self, card, c, e)
            if ending(c) and c.game_over and not e.used and G.GAME.blind and score_at_least_fraction(0.25) then
                e.used = true; T.add_resource('karma', 1); return {saved = true, message = 'Protegido!', colour = G.C.BLUE}
            end
            if c.joker_main then return {chips = 120} end
        end, {vars = function(e) return {e.used and 'não' or 'sim'} end})
    J('espada_deus_trovao', 'Espada do Deus do Trovão', 'artefato', 2, 'ás e selo',
        'Áses pontuados dão {C:chips}+80{} Fichas.|Áses com selo são repetidos {C:attention}1{} vez.', {}, function(self, card, c)
            if played(c) and not c.other_card.debuff and rank(c.other_card) == 14 then return {chips = 80} end
            if repeat_play(c) and not c.other_card.debuff and rank(c.other_card) == 14 and c.other_card.seal then return {repetitions = 1} end
        end)
    J('inscricao_celestial', 'Inscrição Celestial', 'artefato', 2, 'transmutação por mão específica',
        'A primeira {C:attention}Sequência{} de cada blind aprimora|a primeira carta pontuada para {C:attention}Bônus{}.|No Caminho Inscrições, também ganha selo Azul.', {used = false}, function(self, card, c, e)
            if c.setting_blind and clean(c) then e.used = false end
            if before(c) and not e.used and parts(c, 'Straight') then
                local v = (c.scoring_hand or {})[1]
                if v and not v.debuff then
                    e.used = true; set_enhancement(v, 'm_bonus')
                    if T.state().path == 'inscription' then v:set_seal('Blue', true) end
                    return msg('Gravado!')
                end
            end
        end, {blueprint = false})

    -- 61–72: controlled copying, longer quests and the ascension finale.
    J('pergaminho_destino', 'Pergaminho do Destino', 'artefato', 2, 'missão sequencial de mãos',
        'Missão em ordem: {C:attention}Par → Dois Pares → Full House{}.|Outras mãos não apagam o progresso.|Ao concluir: {C:attention}3 insight{} e {C:attention}Mult^1.2{}.|Progresso: {C:attention}#1#/3{}. Sem Talismã: XMult.',
        {progress = 0}, function(self, card, c, e)
            local sequence = {'Pair', 'Two Pair', 'Full House'}
            if before(c) and e.progress < 3 and hand(c, sequence[e.progress + 1]) then
                e.progress = e.progress + 1
                if e.progress == 3 then T.add_resource('insight', 3); return msg('Destino cumprido!') end
                return msg('Destino avança!')
            end
            if c.joker_main and e.progress >= 3 then return power(1.2) end
        end, {vars = {'progress'}, perishable = false})
    J('anel_espacial', 'Anel Espacial', 'artefato', 2, 'espaço de consumíveis',
        '{C:attention}+2{} vagas de consumível.|Dá {C:mult}+6{} Mult por vaga de consumível vazia.', {}, function(self, card, c)
            if c.joker_main then
                local n = math.max(0, G.consumeables.config.card_limit - #G.consumeables.cards - (G.GAME.consumeable_buffer or 0))
                return {mult = 6*n}
            end
        end, {add_to_deck = function() G.consumeables.config.card_limit = G.consumeables.config.card_limit + 2 end,
            remove_from_deck = function() G.consumeables.config.card_limit = G.consumeables.config.card_limit - 2 end})
    J('espelho_alma', 'Espelho da Alma', 'artefato', 3, 'cópia controlada do coringa à esquerda',
        'Na primeira mão de cada blind, copia os|efeitos do Coringa à esquerda durante a pontuação.|Respeita compatibilidade Blueprint.|Não copia Qi, missões ou criação de cartas TDG.', {}, function(self, card, c)
            if (current_round().hands_played or 0) ~= 0 then return end
            if not (c.joker_main or c.individual or c.repetition) or c.end_of_round then return end
            local at
            for i, v in ipairs(G.jokers.cards) do if v == card then at = i; break end end
            if at and at > 1 then return SMODS.blueprint_effect(card, G.jokers.cards[at - 1], c) end
        end)
    J('muralha_gloria', 'Muralha da Glória', 'artefato', 1, 'descartes restantes',
        'Dá {C:chips}+40{} Fichas por descarte restante.|Vencer um blind com {C:attention}3{} descartes restantes|concede {C:attention}1 essência{}.', {}, function(self, card, c)
            local n = current_round().discards_left or 0
            if c.joker_main then return {chips = 40*n} end
            if ending(c) and not c.game_over and n >= 3 then T.add_resource('essence', 1); return msg('Muralha intacta!') end
        end)
    J('ruinas_orquidea', 'Ruínas da Orquídea', 'missão', 2, 'missão renovável de quatro naipes',
        'Missão: pontuar os {C:attention}4 naipes{}.|Gera uma {C:attention}Técnica{} e reinicia após receber.|Sem vaga, preserva a recompensa.|Progresso: {C:attention}#1#/4{}', {seen = {}, progress = 0}, function(self, card, c, e)
            if before(c) then
                for _, v in ipairs(c.scoring_hand or {}) do
                    for _, s in ipairs({'Hearts', 'Diamonds', 'Clubs', 'Spades'}) do if suit(v, s) then e.seen[s] = true end end
                end
                e.progress = size(e.seen)
            end
            if clean(c) and e.progress >= 4 and (c.after or c.ending_shop or ending(c)) then
                if T.create_consumable('tdg_Technique') then e.seen = {}; e.progress = 0; return msg('Ruínas exploradas!') end
            end
        end, {vars = {'progress'}, blueprint = false})
    J('caca_bestas', 'Caça às Bestas', 'missão', 1, 'missão de sete figuras',
        'A cada {C:attention}7 figuras{} pontuadas, recebe|{C:money}$7{}, {C:attention}14 Qi{} e {C:attention}1 essência{}.|Conta cada carta uma vez por mão.|Progresso: {C:attention}#1#/7{}', {progress = 0}, function(self, card, c, e)
            if before(c) then
                grow(e, 'progress', count(c.scoring_hand, face))
                local rewards = math.floor(e.progress/7)
                if rewards > 0 then e.progress = e.progress % 7; T.add_qi(14*rewards); T.add_resource('essence', rewards); return {dollars = 7*rewards} end
            end
        end, {vars = {'progress'}, blueprint = false})
    J('torneio_genios', 'Torneio dos Gênios', 'missão', 2, 'missão de vitória em uma mão',
        'Vencer {C:attention}3 blinds{} usando só 1 mão em cada|desbloqueia {X:mult,C:white}X4{} Mult e dá {C:attention}3 insight{}.|Progresso: {C:attention}#1#/3{}', {progress = 0}, function(self, card, c, e)
            if ending(c) and not c.game_over and e.progress < 3 and (current_round().hands_played or 0) == 1 then
                e.progress = e.progress + 1
                if e.progress == 3 then T.add_resource('insight', 3); return msg('Campeão!') end
                return msg('Vitória!')
            end
            if c.joker_main and e.progress >= 3 then return {x_mult = 4} end
        end, {vars = {'progress'}, perishable = false})
    J('sete_espiritos', 'Sete Espíritos', 'missão', 3, 'missão de sete valores e essência',
        'Missão: pontuar {C:attention}7 valores{} diferentes.|Ao concluir: {C:attention}7 essência{} e {X:mult,C:white}X3.5{} Mult.|Progresso: {C:attention}#1#/7{}', {seen = {}, progress = 0, done = false}, function(self, card, c, e)
            if before(c) and not e.done then
                for _, v in ipairs(c.scoring_hand or {}) do local r = rank(v); if not v.debuff and r > 0 then e.seen[tostring(r)] = true end end
                e.progress = math.min(7, size(e.seen))
                if e.progress == 7 then e.done = true; T.add_resource('essence', 7); return msg('Sete almas!') end
            end
            if c.joker_main and e.done then return {x_mult = 3.5} end
        end, {vars = {'progress'}, perishable = false})
    J('elixir_imortalidade', 'Elixir da Imortalidade', 'artefato', 3, 'progressão por pacotes e rerrolagens',
        'Abrir pacotes ou rerrolar a loja acumula cargas.|A cada {C:attention}4 cargas{}, gera um {C:attention}Elixir{} se houver vaga.|Preserva cargas sem vaga; apenas 1 por evento.|Cargas: {C:attention}#1#{}', {charges = 0}, function(self, card, c, e)
            if clean(c) then
                if c.open_booster or c.reroll_shop then grow(e, 'charges', 1) end
                if (c.open_booster or c.reroll_shop or c.ending_shop) and e.charges >= 4 then
                    if T.create_consumable('tdg_Elixir') then e.charges = e.charges - 4; return msg('Elixir preparado!') end
                end
            end
        end, {vars = {'charges'}, blueprint = false})
    J('tribulacao_nove_raios', 'Tribulação dos Nove Raios', 'missão', 3, 'crescimento por chefes e potência',
        'Cada Chefe vencido concede {C:attention}18 Qi{}|e aumenta o expoente de Mult em {C:attention}0.03{}, até 1.8.|Atualmente: {C:attention}Mult^#1#{}.|Sem Talismã, a potência vira XMult.', {exponent = 1.08}, function(self, card, c, e)
            if ending(c) and not c.game_over and is_boss() then e.exponent = math.min(1.8, e.exponent + 0.03); T.add_qi(18); return msg('Raio dominado!') end
            if c.joker_main then return power(e.exponent) end
        end, {vars = {'exponent'}, perishable = false})
    J('reencarnacao', 'Reencarnação', 'artefato', 3, 'memória dos reinos e reencarnações',
        'Registra o maior reino observado enquanto está presente.|Dá {X:mult,C:white}X#1#{} Mult: 1 + 0.3 por reino registrado|e +1 por Reencarnação, até 20 Reencarnações.|Mantém o reino registrado após reencarnar.', {highest = 1}, function(self, card, c, e)
            if before(c) or (c.setting_blind and clean(c)) or (c.using_consumeable and clean(c)) then e.highest = math.max(e.highest, realm()) end
            if c.joker_main then return {x_mult = 1 + 0.3*e.highest + math.min(20, T.state().rebirths or 0)} end
        end, {vars = function(e) return {1 + 0.3*e.highest + math.min(20, T.state().rebirths or 0)} end, perishable = false,
            add_to_deck = function(self, card)
                card.ability.extra.highest = math.max(card.ability.extra.highest, realm())
            end,
            update = function(self, card)
                -- The mod's universal Qi runs after Joker calculations. Per-frame
                -- observation also catches meditation and end-of-blind promotions.
                if G and G.GAME and card.added_to_deck and card.area == G.jokers then
                    card.ability.extra.highest = math.max(card.ability.extra.highest, realm())
                end
            end})
    J('deus_espiritual', 'Deus Espiritual', 'personagem', 4, 'potência por domínio elemental',
        'Com {C:attention}4 elementos{} pontuados: {C:attention}Mult^#1#{}.|Com menos elementos: {X:mult,C:white}X5{} Mult.|Expoente: 1.25 + 0.04 por reino.|Sem Talismã, a potência vira XMult.', {}, function(self, card, c)
            if c.joker_main then
                if size(elem_set(c.scoring_hand)) >= 4 then return power(1.25 + 0.04*realm()) end
                return {x_mult = 5}
            end
        end, {vars = function() return {1.25 + 0.04*realm()} end})

    assert(#catalogue == 72, 'TDG: expected exactly 72 Jokers')
    T.joker_catalog = catalogue
end

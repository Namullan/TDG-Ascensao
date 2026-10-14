-- Blind hooks receive the registered SMODS definition; calculate also receives
-- the runtime Blind. Per-encounter state belongs to G.GAME, never the definition.
return function(T)
    local function states()
        local run = T.state()
        if type(run.boss_state) ~= 'table' then run.boss_state = {} end
        return run.boss_state
    end

    local function encounter(self, create)
        local all = states()
        local s = all[self.key]
        if type(s) ~= 'table' then
            if not create then return nil end
            s = {active = true, reverted = false, hand_delta = 0, discard_delta = 0,
                hands = 0, last_hand = '', phase = 1, paid = 2}
            all[self.key] = s
        end
        return s
    end

    local function running(self)
        local blind = G and G.GAME and G.GAME.blind
        return blind and not blind.disabled and blind.config and blind.config.blind
            and blind.config.blind.key == self.key
    end

    local function begin(self, reset)
        if reset then return encounter(self, true) end
        local old = encounter(self, false)
        -- A redundant set_blind call must not subtract a capacity twice.
        if old and old.active and not old.reverted then return old end
        states()[self.key] = nil
        return encounter(self, true)
    end

    local function restore(self)
        local s = encounter(self, false)
        if not s or s.reverted then return end
        s.reverted, s.active = true, false
        if s.hand_delta ~= 0 and G.hand and G.hand.change_size then
            G.hand:change_size(-s.hand_delta)
        end
        if s.discard_delta ~= 0 and G.GAME.current_round then
            ease_discard(-s.discard_delta, true)
        end
        s.hand_delta, s.discard_delta = 0, 0
    end

    local function shrink_hand(s)
        local size = G.hand and G.hand.config and G.hand.config.card_limit
        if type(size) ~= 'number' or not G.hand.change_size then return end
        local amount = math.min(1, math.max(0, math.floor(size) - 1))
        if amount > 0 and s.hand_delta == 0 then
            s.hand_delta = -amount
            G.hand:change_size(s.hand_delta)
        end
    end

    local function shrink_discards(s)
        local left = G.GAME.current_round and G.GAME.current_round.discards_left
        if type(left) ~= 'number' then return end
        local amount = math.min(1, math.max(0, math.floor(left) - 1))
        if amount > 0 and s.discard_delta == 0 then
            s.discard_delta = -amount
            ease_discard(s.discard_delta, true)
        end
    end

    local function at_least(value, target)
        if type(to_big) == 'function' then return to_big(value) >= to_big(target) end
        return value >= target
    end

    local function scale(value, factor, minimum)
        if factor == 1 then return value end
        -- Preserve BigNum values and their precision throughout the score path.
        if type(to_big) == 'function' then
            local result = to_big(value) * to_big(factor)
            return result < to_big(minimum) and to_big(minimum) or result
        end
        return math.max(minimum, value * factor)
    end

    local function modified(self, mult, chips, mult_factor, chip_factor)
        if not running(self) then return mult, chips, false end
        local triggered = mult_factor < 1 or chip_factor < 1
        if triggered then G.GAME.blind.triggered = true end
        return scale(mult, mult_factor, 1), scale(chips, chip_factor, 0), triggered
    end

    local function marks(cards)
        local n = 0
        for _, card in ipairs(cards or {}) do
            if card.seal or (card.edition and next(card.edition)) then n = n + 1 end
        end
        return n
    end

    local function repeated_ranks(cards)
        local seen, repeats = {}, 0
        for _, card in ipairs(cards or {}) do
            if not SMODS.has_no_rank(card) then
                local rank = card:get_id()
                if seen[rank] then repeats = repeats + 1 else seen[rank] = true end
            end
        end
        return repeats
    end

    local function affinities(cards)
        local seen, n = {}, 0
        for _, card in ipairs(cards or {}) do
            local element = T.element(card)
            if not seen[element] then seen[element], n = true, n + 1 end
        end
        return n
    end

    local function clean(context)
        return not (context.blueprint or context.retrigger_joker or
            context.retrigger_joker_check or context.repetition or context.individual)
    end

    local function remember(self, blind, context)
        if not running(self) or not clean(context) or not context.after then return end
        local s = encounter(self, true)
        if not s.active then return end
        s.last_hand = context.scoring_name or ''
        s.hands = math.min(1e6, (s.hands or 0) + 1)
        if self.key == 'bl_tdg_sage_decree' then
            s.phase = (s.phase or 1) % 3 + 1
            if blind and blind.set_text then blind:set_text() end
        end
    end

    local function register(def)
        def.atlas = 'tdg_blinds'
        def.prefix_config = {atlas = false}
        def.discovered = true
        def.dollars = def.dollars or 6
        def.mult = def.mult or 2
        def.debuff = {}
        def.set_blind = def.set_blind or begin
        def.disable, def.defeat = restore, restore
        def.calculate = def.calculate or remember
        def.in_pool = function(self)
            if not T.mod.config.enabled then return false end
            local ante = G.GAME.round_resets and G.GAME.round_resets.ante or 1
            -- With custom in_pool Steamodded checks showdown separately but not min.
            return at_least(ante, self.boss.min or 1)
        end
        SMODS.Blind(def)
    end

    register {
        key = 'sacred_tribute', pos = {x = 0, y = 0}, boss = {min = 1},
        boss_colour = {0.62, 0.16, 0.14, 1},
        loc_txt = {name = 'Tributo da Família Sagrada', text = {
            'Paga até $2 por mão, sem criar dívida.',
            'Se faltava saldo: Mult base X0,75.'}},
        press_play = function(self)
            if not running(self) then return end
            local s = encounter(self, true)
            local paid = 2
            while paid > 0 and not at_least(G.GAME.dollars or 0, paid) do paid = paid - 1 end
            s.paid = paid
            if paid > 0 then ease_dollars(-paid, true) end
        end,
        modify_hand = function(self, cards, poker_hands, text, mult, chips)
            local s = encounter(self, true)
            return modified(self, mult, chips, s.paid < 2 and 0.75 or 1, 1)
        end,
    }

    register {
        key = 'snow_wind_mist', pos = {x = 0, y = 1}, boss = {min = 2},
        boss_colour = {0.24, 0.48, 0.68, 1},
        loc_txt = {name = 'Névoa de Vento Nevado', text = {
            '-1 tamanho de mão neste chefe.',
            'Preserva pelo menos 1 vaga.'}},
        set_blind = function(self, reset)
            if reset then return end
            local s = begin(self)
            if s.hand_delta == 0 then shrink_hand(s) end
        end,
    }

    register {
        key = 'dark_guild_claws', pos = {x = 0, y = 2}, boss = {min = 2},
        boss_colour = {0.34, 0.16, 0.45, 1},
        loc_txt = {name = 'Garras da Guilda Sombria', text = {
            'Cada carta jogada com selo ou edição:',
            '-8% Mult base, até -32%.'}},
        modify_hand = function(self, cards, poker_hands, text, mult, chips)
            return modified(self, mult, chips, 1 - 0.08 * math.min(4, marks(cards)), 1)
        end,
    }

    register {
        key = 'qilin_bottleneck', pos = {x = 0, y = 3}, boss = {min = 3},
        boss_colour = {0.68, 0.39, 0.11, 1},
        loc_txt = {name = 'Gargalo do Qilin', text = {
            'Cada valor repetido nas cartas jogadas:',
            '-10% Fichas base, até -40%.',
            'Cartas sem valor não contam.'}},
        modify_hand = function(self, cards, poker_hands, text, mult, chips)
            return modified(self, mult, chips, 1, 1 - 0.10 * math.min(4, repeated_ranks(cards)))
        end,
    }

    register {
        key = 'soul_realm_mirror', pos = {x = 0, y = 4}, boss = {min = 3},
        boss_colour = {0.16, 0.55, 0.55, 1},
        loc_txt = {name = 'Espelho do Reino da Alma', text = {
            'Repetir o tipo da mão anterior neste',
            'chefe reduz o Mult base em 40%.'}},
        modify_hand = function(self, cards, poker_hands, text, mult, chips)
            local s = encounter(self, true)
            return modified(self, mult, chips, s.last_hand ~= '' and s.last_hand == text and 0.60 or 1, 1)
        end,
    }

    register {
        key = 'inscription_labyrinth', pos = {x = 0, y = 5}, boss = {min = 2},
        boss_colour = {0.15, 0.50, 0.33, 1},
        loc_txt = {name = 'Labirinto das Inscrições', text = {
            'Jogar menos de 2 afinidades diferentes:',
            'Fichas base X0,70.',
            'Afinidades usam o naipe físico/Terra.'}},
        modify_hand = function(self, cards, poker_hands, text, mult, chips)
            return modified(self, mult, chips, 1, affinities(cards) < 2 and 0.70 or 1)
        end,
    }

    register {
        key = 'glory_city_siege', pos = {x = 0, y = 6}, boss = {min = 8, showdown = true},
        dollars = 8, mult = 2,
        boss_colour = {0.48, 0.20, 0.32, 1},
        loc_txt = {name = 'Cerco de Glory City', text = {
            '-1 descarte, preservando pelo menos 1.',
            'Jogar menos de 5 cartas:',
            'Mult base X0,70.'}},
        set_blind = function(self, reset)
            if reset then return end
            local s = begin(self)
            if s.discard_delta == 0 then shrink_discards(s) end
        end,
        modify_hand = function(self, cards, poker_hands, text, mult, chips)
            return modified(self, mult, chips, #(cards or {}) < 5 and 0.70 or 1, 1)
        end,
    }

    local decrees = {'3 afinidades', 'sem selos/edições', 'mudar o tipo de mão'}
    register {
        key = 'sage_decree', pos = {x = 0, y = 7}, boss = {min = 8, showdown = true},
        dollars = 8, mult = 2,
        boss_colour = {0.49, 0.29, 0.55, 1},
        loc_txt = {name = 'Decreto do Imperador Sábio', text = {
            'Alterna 3 afinidades, sem marcas, mão nova.',
            'Falhar reduz a base de Mult/Fichas em 35%.',
            'Decreto atual: #1#.'}},
        loc_vars = function(self)
            local s = encounter(self, false)
            return {vars = {decrees[s and s.active and s.phase or 1] or decrees[1]}}
        end,
        collection_loc_vars = function() return {vars = {decrees[1]}} end,
        modify_hand = function(self, cards, poker_hands, text, mult, chips)
            local s = encounter(self, true)
            local phase = s.phase or 1
            local failed = (phase == 1 and affinities(cards) < 3) or
                (phase == 2 and marks(cards) > 0) or
                (phase == 3 and s.last_hand ~= '' and s.last_hand == text)
            local factor = failed and 0.65 or 1
            return modified(self, mult, chips, factor, factor)
        end,
    }
end

-- The cultivation state uses ordinary bounded counters. Scores stay in SMODS/Talisman.
return function(T)
    local realms = {'Bronze', 'Prata', 'Ouro', 'Ouro Negro', 'Lendário',
        'Destino Celestial', 'Estrela Celestial', 'Eixo Celestial', 'Dao do Dragão',
        'Ancestral Marcial', 'Imperador Divino', 'Deus Espiritual'}
    T.realms = realms
    local function bounded(n, lo, hi)
        if type(n) ~= 'number' or n ~= n then return lo end
        return math.max(lo, math.min(hi, n))
    end
    function T.new_state()
        return {version = 2, qi = 0, realm = 1, stage = 1, insight = 0,
            essence = 3, karma = 0, rebirths = 0, hands = 0, blinds = 0, bosses = 0,
            elixirs = 0, techniques = 0, relics = 0, tarots = 0, planets = 0, path = 'none',
            boss_state = {},
            elements = {fire = 0, water = 0, wood = 0, metal = 0, earth = 0},
            tribulation = {progress = 0, target = 2, active = false, kind = 1},
            stats = {breakthroughs = 0, tribulations = 0, meditation = 0, forged = 0},
            last_hand = '', harmony = 0, qi_rate = 1, essence_rate = 1,
            meditation_cost = 4, meditation_gain = 35, universal_bonus = 0}
    end
    function T.normalize_state(s)
        local d = T.new_state()
        s = type(s) == 'table' and s or d
        for k, v in pairs(d) do
            if type(v) == 'table' then
                if type(s[k]) ~= 'table' then s[k] = v end
                for a, b in pairs(v) do if s[k][a] == nil then s[k][a] = b end end
            elseif s[k] == nil then s[k] = v end
        end
        s.version = 2
        s.realm = math.floor(bounded(s.realm, 1, #realms))
        s.stage = math.floor(bounded(s.stage, 1, 5))
        for _, k in ipairs({'qi','insight','essence','karma','rebirths','hands','blinds',
            'bosses','elixirs','techniques','relics','tarots','planets'}) do s[k] = bounded(s[k], 0, 1e100) end
        if not ({none=true, alchemist=true, demon=true, inscription=true})[s.path] then s.path='none' end
        return s
    end
    local preview = T.new_state()
    function T.state()
        if not G or not G.GAME then return preview end
        if not G.GAME.tdg then G.GAME.tdg = T.new_state() end
        return G.GAME.tdg
    end
    function T.threshold(s)
        s = s or T.state()
        return math.floor((35 + 20 * s.realm * s.realm) * (1 + 0.4 * (s.stage - 1)))
    end
    function T.realm_name(s)
        s = s or T.state()
        return realms[s.realm] .. ' ' .. s.stage .. (s.realm <= 5 and ' estrela(s)' or 'º estágio')
    end
    function T.add_resource(key, amount)
        local s = T.state()
        if type(amount) ~= 'number' or amount ~= amount then return 0 end
        s[key] = bounded((type(s[key]) == 'number' and s[key] or 0) + amount, 0, 1e100)
        return s[key]
    end
    function T.add_qi(amount)
        local s = T.state()
        if type(amount) ~= 'number' or amount <= 0 or amount ~= amount then return 0 end
        amount = amount * (s.qi_rate or 1) * (s.path == 'alchemist' and 1.2 or 1)
        T.add_resource('qi', amount)
        local breakthroughs = 0
        -- At most 59 promotions per call. The highest realm stores Qi for rebirth.
        while (s.realm < #realms or s.stage < 5) and s.qi >= T.threshold(s) do
            s.qi = s.qi - T.threshold(s)
            s.stage = s.stage + 1
            if s.stage > 5 then
                s.stage, s.realm = 1, s.realm + 1
                T.add_resource('insight', s.realm)
                T.add_resource('essence', 2)
            end
            s.stats.breakthroughs = s.stats.breakthroughs + 1
            breakthroughs = breakthroughs + 1
        end
        if breakthroughs > 0 then T.notify('Ascensão: ' .. T.realm_name(s), G.C.TDG_JADE) end
        return breakthroughs
    end
    function T.xmult()
        local s = T.state()
        return math.min(1e100, (1 + (s.realm-1)*0.4 + (s.stage-1)*0.12 +
            s.insight*0.025 + (s.universal_bonus or 0)) * (1 + s.rebirths*0.75))
    end
    function T.is_talisman()
        local m = SMODS and SMODS.Mods and SMODS.Mods.Talisman
        return type(to_big) == 'function' and (not m or m.can_load ~= false)
    end
    function T.power_effect(exponent)
        exponent = bounded(exponent, 1, 3)
        return T.is_talisman() and {e_mult = exponent} or {x_mult = 1+10*(exponent-1)}
    end
    function T.element(card)
        if not card or (SMODS.has_no_suit and SMODS.has_no_suit(card)) or
            (card.config and card.config.center and card.config.center.key == 'm_stone') then return 'earth' end
        return ({Hearts='fire', Spades='water', Clubs='wood', Diamonds='metal'})[(card.base or {}).suit] or 'earth'
    end
    function T.has_joker(key)
        local n = 0
        for _, c in ipairs(G and G.jokers and G.jokers.cards or {}) do
            if c.config.center.key == key and not c.debuff then n=n+1 end
        end
        return n
    end
    function T.count_enhancement(key)
        local n=0
        for _, c in ipairs(G and G.playing_cards or {}) do
            if SMODS.has_enhancement(c,key) then n=n+1 end
        end
        return n
    end
    function T.atlas_pos(index, columns)
        index, columns = index-1, columns or 12
        return {x = index%columns, y = math.floor(index/columns)}
    end
    function T.defer(fn)
        if G and G.E_MANAGER and Event then
            G.E_MANAGER:add_event(Event({trigger='immediate', func=function() fn(); return true end}))
        else fn() end
    end
    function T.notify(message, colour)
        if attention_text and G and G.jokers then
            attention_text({text=message, scale=0.55, hold=1.5, backdrop_colour=colour or G.C.TDG_JADE,
                align='cm', major=G.jokers, offset={x=0,y=-0.4}})
        end
    end
    function T.create_consumable(set, key)
        local area=G and G.consumeables
        if not area or #area.cards + (G.GAME.consumeable_buffer or 0) >= area.config.card_limit then return nil end
        if key and not G.P_CENTERS[key] then return nil end
        local c=SMODS.add_card({set=set, key=key, area=area, key_append='tdg_reward'})
        return c
    end
    function T.create_joker(key)
        local area=G and G.jokers
        if not area or #area.cards + (G.GAME.joker_buffer or 0) >= area.config.card_limit then return nil end
        if key and not G.P_CENTERS[key] then return nil end
        return SMODS.add_card({set='Joker', key=key, area=area, key_append='tdg_reward'})
    end
    function T.safe_level_hand(hand, amount, source)
        if G and G.GAME and G.GAME.hands and G.GAME.hands[hand] and amount > 0 then
            level_up_hand(source, hand, true, amount)
            return true
        end
        return false
    end
    T.tribulation_names={'Harmonia: 3 elementos em uma mão','Disciplina: 2 mãos sem descartar',
        'Inscrição: 2 cartas aprimoradas em uma mão','Determinação: repetir o tipo de mão'}
    function T.calculate(context)
        if not T.mod.config.enabled or not G or not G.GAME or context.blueprint or
            context.retrigger_joker or context.retrigger_joker_check then return end
        local s=T.state()
        if context.setting_blind then
            s.round_discards=0
            local boss=G.GAME.blind and G.GAME.blind.boss
            s.tribulation={active=not not boss,kind=(s.bosses%4)+1,progress=0,target=1}
            if s.tribulation.kind==2 then s.tribulation.target=2 end
        elseif context.pre_discard then
            s.round_discards=(s.round_discards or 0)+1
        elseif context.before then
            s.hands=s.hands+1
            local elements, diversity, enhanced={},0,0
            for _, c in ipairs(context.scoring_hand or {}) do
                if not c.debuff then
                    local el=T.element(c)
                    if not elements[el] then diversity=diversity+1; elements[el]=true end
                    s.elements[el]=math.min(1e100,s.elements[el]+1)
                    if c.config.center.key ~= 'c_base' then enhanced=enhanced+1 end
                end
            end
            s.harmony=diversity
            local level=G.GAME.hands[context.scoring_name or 'High Card']
            local native_level=level and level.level or 1
            if type(native_level) ~= 'number' then
                -- Talisman stores hand levels as BigNums too. Cap this small XP bonus
                -- before converting; the scoring values themselves are never converted.
                if type(to_big)=='function' and type(to_number)=='function' then
                    native_level=native_level>=to_big(40) and 40 or to_number(native_level)
                else native_level=1 end
            end
            T.add_qi(12+3*diversity+math.min(40,native_level)+s.realm*2+
                (s.path=='inscription' and enhanced*8 or 0))
            local tr=s.tribulation
            if tr.active and tr.progress < tr.target then
                local success=(tr.kind==1 and diversity>=3) or
                    (tr.kind==2 and (s.round_discards or 0)==0) or
                    (tr.kind==3 and enhanced>=2) or
                    (tr.kind==4 and s.last_hand==context.scoring_name)
                if success then tr.progress=tr.progress+1 end
            end
            s.last_hand=context.scoring_name or ''
        elseif context.end_of_round and not context.individual and not context.repetition and context.main_eval then
            s.blinds=s.blinds+1
            T.add_qi(25+s.realm*12)
            T.add_resource('essence', s.essence_rate or 1)
            if G.GAME.blind and G.GAME.blind.boss then
                s.bosses=s.bosses+1
                T.add_resource('insight', 1)
                if s.tribulation.active and s.tribulation.progress>=s.tribulation.target then
                    s.stats.tribulations=s.stats.tribulations+1
                    T.add_qi(70*s.realm)
                    T.add_resource('insight',2)
                    T.add_resource('essence',3)
                    T.notify('Tribulação superada!',G.C.GOLD)
                end
                s.tribulation.active=false
            end
        elseif context.repetition and context.cardarea==G.play and s.path=='demon' and
            context.scoring_hand and context.other_card==context.scoring_hand[1] then
            return {repetitions=1, message='Fusão', colour=G.C.TDG_JADE}
        elseif context.final_scoring_step then
            local result={x_mult=T.xmult(),message=T.realm_name(s),colour=G.C.TDG_JADE}
            if s.realm>=6 then
                for k,v in pairs(T.power_effect(1+0.018*(s.realm-5)+math.min(0.4,s.rebirths*0.015))) do
                    if k=='x_mult' then result.x_mult=result.x_mult*v else result[k]=v end
                end
            end
            return result
        end
    end
    function T.choose_path(path)
        if not ({alchemist=true,demon=true,inscription=true})[path] then return false end
        local s=T.state()
        if s.path==path then return false end
        local cost=s.path=='none' and 0 or 8
        if not T.in_shop() or not T.can_pay(cost) then return false end
        if cost>0 then ease_dollars(-cost,true) end
        s.path=path
        return true
    end
    function T.can_pay(cost)
        local dollars=G and G.GAME and G.GAME.dollars or 0
        if type(to_big)=='function' then return to_big(dollars)>=to_big(cost) end
        return dollars>=cost
    end
    function T.in_shop()
        return G and G.STAGES and G.STAGE==G.STAGES.RUN and G.STATES and G.STATE==G.STATES.SHOP
    end
    function T.meditate()
        local s=T.state()
        if not T.in_shop() or not T.can_pay(s.meditation_cost) then return false end
        ease_dollars(-s.meditation_cost,true)
        s.stats.meditation=s.stats.meditation+1
        T.add_qi(s.meditation_gain+s.realm*10)
        return true
    end
    function T.forge()
        local s=T.state()
        if not T.in_shop() or s.essence<3 then return false end
        if not T.create_consumable('tdg_Elixir') then return false end
        s.essence=s.essence-3
        s.stats.forged=s.stats.forged+1
        return true
    end
end

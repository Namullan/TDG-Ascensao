return function(T)
    local jade,ink,gold=G.C.TDG_JADE,G.C.TDG_INK,G.C.TDG_GOLD
    local function row(nodes,padding)
        return {n=G.UIT.R,config={align='cm',padding=padding or 0.06},nodes=nodes}
    end
    local function text(value,scale,colour)
        return row({{n=G.UIT.T,config={text=value,scale=scale or 0.32,
            colour=colour or G.C.WHITE,shadow=true,maxw=10}}},0.025)
    end
    local function button(label,callback,func,width)
        return UIBox_button({label={label},button=callback,func=func,
            colour=jade,minw=width or 3,minh=0.48,scale=0.30})
    end
    local path_names={none='Sem caminho',alchemist='Alquimia',demon='Fusão Demoníaca',inscription='Inscrições'}
    local function active()
        return T.mod.config.enabled and G.STAGE==G.STAGES.RUN
    end
    local function render_panel()
        local s=T.state()
        local progress=s.realm==12 and s.stage==5 and 'Ápice alcançado — Qi para reencarnação' or
            'Qi '..math.floor(s.qi)..' / '..T.threshold(s)..' para avançar'
        local nodes={
            text('TDG — ASCENSÃO',0.60,gold),
            text(T.realm_name(s),0.48,jade),text(progress,0.36),
            text('X'..string.format('%.2f',T.xmult())..' Mult de cultivação em cada mão',0.32,gold),
            text('Essência '..math.floor(s.essence)..'  |  Compreensão '..math.floor(s.insight)..
                '  |  Karma '..math.floor(s.karma),0.32),
            text('Reencarnações '..math.floor(s.rebirths)..'  |  Mãos cultivadas '..s.hands..
                '  |  Tribulações vencidas '..s.stats.tribulations,0.28,gold),
            text('Caminho: '..path_names[s.path]..' — primeiro gratuito; trocar custa $8',0.29,jade),
            row({button('Alquimia','tdg_alchemist','tdg_can_alchemist',2.7),
                button('Fusão Demoníaca','tdg_demon','tdg_can_demon',2.7),
                button('Inscrições','tdg_inscription','tdg_can_inscription',2.7)}),
            text('Alquimia: +20% Qi. Fusão: repete a primeira carta pontuada.',0.29),
            text('Inscrições: +8 Qi por carta aprimorada pontuada.',0.29),
            row({button('Meditar $'..s.meditation_cost..' → +'..
                (s.meditation_gain+s.realm*10)..' Qi','tdg_meditate','tdg_can_meditate',4.0),
                button('Forjar elixir: 3 Essências','tdg_forge','tdg_can_forge',4.0)}),
            text(T.in_shop() and 'Práticas disponíveis nesta loja.' or 'Práticas e caminhos disponíveis na loja.',0.28,gold),
        }
        if s.tribulation.active then
            nodes[#nodes+1]=text('TRIBULAÇÃO '..s.tribulation.progress..'/'..s.tribulation.target,0.37,gold)
            nodes[#nodes+1]=text(T.tribulation_names[s.tribulation.kind],0.29)
        else
            nodes[#nodes+1]=text('Tribulações nos chefes: +Qi, Essência e Compreensão ao cumprir o objetivo.',0.27)
        end
        local e=s.elements
        nodes[#nodes+1]=text('Fogo '..e.fire..' • Água '..e.water..' • Madeira '..e.wood..
            ' • Metal '..e.metal..' • Terra '..e.earth,0.29,jade)
        nodes[#nodes+1]=text('Copas = Fogo • Espadas = Água • Paus = Madeira • Ouros = Metal • Pedra = Terra',0.26)
        nodes[#nodes+1]=text('Jogue mãos para cultivar; cada promoção fortalece todas as suas mãos.',0.28)
        if s.realm>=6 then
            nodes[#nodes+1]=text(T.is_talisman() and 'Talismã: cultivação celestial aplica potência ao Mult.' or
                'Cultivação celestial aplica XMult adicional.',0.29,gold)
        end
        return create_UIBox_generic_options({back_func='exit_overlay_menu',contents={
            {n=G.UIT.C,config={align='cm',padding=0.15,colour=ink,r=0.15},nodes=nodes}}})
    end
    G.FUNCS.tdg_panel=function()
        G.SETTINGS.paused=true
        G.FUNCS.overlay_menu({definition=render_panel()})
    end
    local function refresh()
        if save_run and active() then save_run() end
        G.FUNCS.tdg_panel()
    end
    for _, path in ipairs({'alchemist','demon','inscription'}) do
        local p=path
        G.FUNCS['tdg_'..p]=function() if T.choose_path(p) then refresh() end end
        G.FUNCS['tdg_can_'..p]=function(e)
            local s=T.state()
            local can=active() and T.in_shop() and s.path~=p and T.can_pay(s.path=='none' and 0 or 8)
            e.config.button=can and 'tdg_'..p or nil
            e.config.colour=can and jade or G.C.UI.BACKGROUND_INACTIVE
        end
    end
    G.FUNCS.tdg_meditate=function() if T.meditate() then refresh() end end
    G.FUNCS.tdg_forge=function() if T.forge() then refresh() end end
    G.FUNCS.tdg_can_meditate=function(e)
        local can=active() and T.in_shop() and T.can_pay(T.state().meditation_cost)
        e.config.button=can and 'tdg_meditate' or nil
        e.config.colour=can and jade or G.C.UI.BACKGROUND_INACTIVE
    end
    G.FUNCS.tdg_can_forge=function(e)
        local can=active() and T.in_shop() and T.state().essence>=3 and
            #G.consumeables.cards+(G.GAME.consumeable_buffer or 0)<G.consumeables.config.card_limit
        e.config.button=can and 'tdg_forge' or nil
        e.config.colour=can and jade or G.C.UI.BACKGROUND_INACTIVE
    end
    local function find(node,id)
        if node.config and node.config.id==id then return node end
        for _, child in ipairs(node.nodes or {}) do local found=find(child,id); if found then return found end end
    end
    T.hud_values={realm='',qi=''}
    G.FUNCS.tdg_hud_update=function(e)
        local s=T.state()
        T.hud_values.realm=T.realms[s.realm]..' '..s.stage
        T.hud_values.qi='Qi '..math.floor(s.qi)..'/'..T.threshold(s)..'  •  Ess. '..math.floor(s.essence)
        e.config.button=active() and 'tdg_panel' or nil
        e.config.colour=active() and ink or G.C.UI.BACKGROUND_INACTIVE
    end
    local original_hud=create_UIBox_HUD
    function create_UIBox_HUD(...)
        local hud=original_hud(...)
        if T.mod.config.cultivation_hud then
            local container=find(hud,'row_round')
            if container then
                -- A small, live panel beneath the native round controls.
                local owner
                local function parent(node)
                    for _,ch in ipairs(node.nodes or {}) do
                        if ch==container then owner=node; return end
                        parent(ch)
                        if owner then return end
                    end
                end
                parent(hud)
                if owner then owner.nodes[#owner.nodes+1]={n=G.UIT.R,
                    config={id='tdg_hud',align='cm',padding=0.05,colour=ink,r=0.10,
                        button='tdg_panel',func='tdg_hud_update',hover=true,shadow=true},nodes={
                        {n=G.UIT.C,config={align='cm',minw=4.8},nodes={
                            row({{n=G.UIT.T,config={text='CULTIVAR  ',scale=0.28,colour=gold}},
                                {n=G.UIT.T,config={ref_table=T.hud_values,ref_value='realm',scale=0.28,colour=jade}}},0.01),
                            row({{n=G.UIT.T,config={ref_table=T.hud_values,ref_value='qi',scale=0.24,colour=G.C.WHITE}}},0.01)}}}} end
            end
        end
        return hud
    end
    local original_shop=G.UIDEF.shop
    function G.UIDEF.shop(...)
        local shop=original_shop(...)
        if T.mod.config.enabled then
            local next_round=find(shop,'next_round_button')
            local owner
            local function parent(node)
                for _,ch in ipairs(node.nodes or {}) do
                    if ch==next_round then owner=node; return end
                    parent(ch); if owner then return end
                end
            end
            if next_round then parent(shop) end
            if owner then owner.nodes[#owner.nodes+1]=button('Pavilhão de Cultivo','tdg_panel',nil,2.8) end
        end
        return shop
    end
    T.mod.config_tab=function()
        return {n=G.UIT.ROOT,config={align='cm',padding=0.16,colour=ink,r=0.1},nodes={
            text('TDG — Ascensão',0.55,gold),
            create_toggle({label='Cultivação em todos os baralhos',ref_table=T.mod.config,ref_value='enabled'}),
            create_toggle({label='Mostrar painel de cultivação',ref_table=T.mod.config,ref_value='cultivation_hud'}),
            create_toggle({label='Início generoso: $6 e +1 vaga de cada tipo',ref_table=T.mod.config,ref_value='generous_start'}),
            text('Reinicie a partida para aplicar as vagas iniciais.',0.28),
            text('Cultive jogando mãos; abra CULTIVAR no painel da partida.',0.29,jade),
            text('Escolha seu caminho, medite e forje elixires na loja.',0.29),
            text('12 reinos, 5 estágios por reino e poder celestial com Talismã.',0.29),
            text('Fan mod inspirado em Tales of Demons and Gods, de Mad Snail.',0.26),
        }}
    end
end

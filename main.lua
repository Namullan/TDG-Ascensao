local T = {mod=SMODS.current_mod}
TDG=T
G.C.TDG_JADE={0.15,0.74,0.59,1}
G.C.TDG_INK={0.06,0.10,0.18,1}
G.C.TDG_GOLD={0.95,0.72,0.27,1}
SMODS.Atlas {key='jokers',path='tdg_jokers.png',px=71,py=95}
SMODS.Atlas {key='items',path='tdg_items.png',px=71,py=95}
SMODS.Atlas {key='arcana',path='tdg_arcana.png',px=71,py=95}
SMODS.Atlas {key='blinds',path='tdg_blinds.png',px=34,py=34,
    frames=21,atlas_table='ANIMATION_ATLAS'}
assert(SMODS.load_file('cultivation.lua'))()(T)
assert(SMODS.load_file('content/hands.lua'))()(T)
assert(SMODS.load_file('content/jokers.lua'))()(T)
assert(SMODS.load_file('content/items.lua'))()(T)
assert(SMODS.load_file('content/tarots.lua'))()(T)
assert(SMODS.load_file('content/blinds.lua'))()(T)
local previous_start_run=Game.start_run
function Game:start_run(args,...)
    if args and args.savetext then T.ensure_hands_in_save(args.savetext) end
    local result=previous_start_run(self,args,...)
    -- Restore the narrow Tarot guard if a later-loading mod wrapped the UI callback.
    T.install_tarot_use_guard()
    if G.GAME then
        G.GAME.tdg=T.normalize_state(G.GAME.tdg)
        if not (args and args.savetext) and T.mod.config.enabled and T.mod.config.generous_start then
            ease_dollars(6,true)
            -- CardArea's Steamodded limit getter is not initialized until its first update.
            G.consumeables:change_size(1)
            G.jokers:change_size(1)
        end
    end
    return result
end
T.mod.calculate=function(self,context) return T.calculate(context) end
assert(SMODS.load_file('ui.lua'))()(T)

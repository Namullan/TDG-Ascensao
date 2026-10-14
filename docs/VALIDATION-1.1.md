# Validação — TDG: Ascensão 1.1.0

Atualização em 14/10/2026. Esta página documenta as categorias novas e sua migração.

## Testes automatizados

**114 testes, zero falhas**, usando o LuaJIT real do Balatro por `tests/run_tdg_tests.py`. Os 15 arquivos Lua de produto e teste foram compilados. O catálogo verifica 179 conteúdos, chaves e posições de arte.

Cobertura: os 19 casos anteriores; detecção positiva/negativa e independente da ordem das seis novas mãos, naipes Curinga, mãos nativas, Ás, cartas sem valor e debuffs; evolução isolada dos seis planetas; saves antigos; oito chefes, seleção por Ante, dois showdown, previews, histórico, reversão de capacidades e BigNums; 12 Tarôs, custos, alvos, propriedades, destruição, criação, contadores, snapshots e preparação de uso.

As provas independentes dos módulos também executaram as funções nativas de alteração de cartas, evolução de mãos e uso de consumíveis. No fluxo de criação, corpos reais de `G.FUNCS.use_card`, `Card.use_consumeable` e `set_consumeable_usage` foram executados com fila de eventos diferida e motor gráfico substituído em memória. Falhas foram bloqueadas antes do registro de uso; sucessos construíram uma vez e contabilizaram uma vez.

## Execuções reais

As duas rodadas completas no Balatro real passaram, preservando os ambientes em `tests/tdg_smoke_runtime`. Os testes usam a identidade de save `TDGSmoke`, português brasileiro e Steam desativado; os saves reais do jogador não foram modificados.

| Configuração | Runtime | Assertions PASS registradas | Pontuação normal / nova mão |
|---|---|---:|---|
| Sem Talismã e sem Clonagem/Certeza/Ouro | `run-20261014-123907-175-81f6a700` | 887 | 13335 / 44451 |
| Talismã, BMM-Compat e Saturn; sem Clonagem/Certeza/Ouro | `run-20261014-122850-650-e880945e` | 912 | 1.857e498 / 1.603e426 |

As pontuações com Talismã permaneceram BigNums finitos acima de 1e308. Os números de assertions contam linhas PASS no log; não representam testes unitários distintos.

O fluxo real verificou os 147 conteúdos anteriores e os 32 novos: detecção e prioridade das seis mãos, uso isolado dos seis planetas, todos os 12 Tarôs, preparação única das três cartas de criação e falhas sem cobrança ou registro indevido. Pacotes Celestiais e Arcanos nativos geraram e usaram as cartas novas. Os oito chefes passaram pelos hooks nativos, histórico e reversão de capacidades uma única vez.

O worker de save gravou no disco um chefe ativo e os contadores positivos de Tarôs/planetas com a mão nova evoluída. A recarga desses arquivos preservou o estado e as capacidades. A migração passou com snapshot sintético 1.0 e com um arquivo genuíno da versão 1.0 criado numa execução anterior com Talismã, mantendo os BigNums e a cultivação existentes. O início generoso acrescentou corretamente uma vaga (consumíveis 2→3, coringas 5→6), sem repetir o bônus ao continuar.

As galerias finais renderizaram **20 telas nativas**, dez em cada escala 1x/2x, com todos os coringas, Tarôs, planetas, aprimoramentos, selos, versos e chefes. Os aprimoramentos foram conferidos em Reis de Copas e de Ouros. Recortes, proporções, molduras, índices de valor/naipe e células dos atlas passaram pela inspeção. A Raiz do Vazio oculta a face por sua regra própria; os demais aprimoramentos preservam os índices nativos.

O ZIP candidato foi extraído e iniciou uma partida no Balatro real, registrando os 179 conteúdos. Os 20 arquivos de código, configuração e atlas foram comparados por SHA256 entre a fonte, ambas as rodadas completas e o pacote. Logs e relatórios completos ficam em `tests/tdg_smoke_runtime/summary-1.1.json` e `STATUS-1.1.md` no projeto.

## Limites

O objetivo é validar funcionamento, cartas/mãos/chefes nativos, salvamento e Talismã. A versão 1.1 não pretende certificar uma campanha natural até a Ante 39 nem todas as combinações possíveis de mods externos.

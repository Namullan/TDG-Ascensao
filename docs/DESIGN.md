# Direção de jogo — TDG: Ascensão

A partida representa uma vida de cultivação. O baralho é o reino da alma; as cartas pontuadas alimentam afinidades, personagens guiam especializações e espíritos demoníacos transformam a forma de pontuar. A economia da loja financia meditação e alquimia. Chefes oferecem tribulações opcionais com recompensas permanentes.

A versão 1.1 adiciona 12 Tarôs, seis formações de mão, seus seis planetas e oito chefes próprios. Os Tarôs preparam padrões (naipes, valores, Terra e selos), os planetas evoluem as formações, e os chefes desafiam o padrão de construção com penalidades proporcionais. Isso conecta manipulação de baralho, progressão de mãos e encontros de chefe ao cultivo.

## Ciclo da partida

1. Jogar mãos concede Qi conforme diversidade de elementos, nível da mão e reino atual.
2. Qi suficiente é convertido automaticamente em estrelas/estágios. Ao alcançar um novo reino, o cultivador ganha Compreensão e Essência.
3. Todo estágio aumenta o multiplicador universal. No Destino Celestial e acima, Talismã permite potência de Mult; sem Talismã existe um bônus XMult alternativo.
4. Na loja, o Pavilhão de Cultivo permite escolher um caminho, comprar Qi com dinheiro e converter Essência em elixires.
5. Nos chefes, cumprir uma tribulação dá Qi, Compreensão e Essência adicionais. Não cumpri-la preserva a progressão normal.
6. Técnicas, elixires, relíquias, inscrições e espíritos passam a converter recursos entre si. Reencarnação e os conteúdos de fim de jogo sustentam novas escaladas.

## Os três caminhos

| Caminho | Regra central | Construção sugerida |
|---|---|---|
| Alquimia | +20% ao Qi recebido | Personagens alquimistas, elixires e economia de Essência |
| Fusão Demoníaca | Repete a primeira carta pontuada de cada mão | Espíritos, selos e edições de cartas |
| Inscrições | +8 Qi por carta aprimorada pontuada | Aprimoramentos, técnicas de transmutação e selos |

A primeira escolha é gratuita. Trocar de caminho custa $8 e só é possível na loja. A escolha pertence à partida salva.

## Cinco afinidades

Copas alimentam Fogo, Espadas alimentam Água, Paus alimentam Madeira, Ouros alimentam Metal e cartas sem naipe/Pedra alimentam Terra. São afinidades de design inspiradas em cultivação, sem substituir os naipes normais. Coringas e técnicas usam tanto o elemento da mão atual quanto o histórico de afinidades.

## Reinos e escalada

Bronze → Prata → Ouro → Ouro Negro → Lendário → Destino Celestial → Estrela Celestial → Eixo Celestial → Dao do Dragão → Ancestral Marcial → Imperador Divino → Deus Espiritual. Cada reino contém cinco estágios. O custo de ascensão cresce de forma quadrática com o reino e linear com seu estágio, evitando custos gigantes em XP e deixando os números astronômicos para a pontuação.

O bônus universal combina reino, estágio, Compreensão e Reencarnações. Técnicas e personagens complementam a escalada com crescimento, repetições limitadas, conversão de recursos e potência via Talismã. A expansão oferece meios de construir partidas além do limite numérico normal; chegar à Ante 39 depende das combinações, da seed e dos outros mods ativos.

## Tribulações

As tribulações alternam quatro objetivos: pontuar três elementos diferentes em uma mão; jogar duas mãos sem descartar; pontuar duas cartas aprimoradas em uma mão; repetir o tipo da mão anterior. Elas acrescentam objetivos de construção e decisão durante chefes sem punir o jogador com perda de conteúdo ao falhar.

## Regras técnicas de qualidade

- O estado de cultivação fica em `G.GAME.tdg`, dentro do save nativo.
- Blueprint e reativação de coringas podem repetir pontuação, mas não duplicam a progressão global.
- Cartas geradas respeitam vagas; receitas com inventário cheio preservam seus recursos.
- RNG segue a seed do Balatro.
- Pontuação passa pelas APIs de efeitos; o mod não converte pontuações enormes para números Lua.
- Contadores e recursos têm limites defensivos; ciclos de repetição devem permanecer pequenos.
- Clonagem, Certeza e Ouro permanecem expansões independentes.

## Identidade visual

Retratos de cultivadores, bestas espirituais, pagodas, cristais e artefatos em fundo de tinta azul; molduras de jade e ouro. Atlas próprio para coringas e itens. Selos e tags usam sigilos legíveis em tamanho pequeno. O painel de cultivo usa o mesmo jade para apresentar reino, Qi, recursos, caminhos e tribulações.

# TDG — Ascensão

Uma expansão de cultivação para **Balatro**, inspirada em **Tales of Demons and Gods**. Cultive sua alma, integre espíritos demoníacos, pratique alquimia e atravesse tribulações em uma partida com **179 conteúdos novos** e progressão própria.

**Versão 1.1.0 · Português brasileiro · Talismã opcional**

**English:** An unofficial cultivation expansion inspired by Tales of Demons and Gods. Adds 179 content entries, 12 cultivation realms, demon spirits, alchemy, tribulations, custom Tarot cards, poker hands, Planets and Boss Blinds. In-game text is Brazilian Portuguese. Optional Talisman support enables very large scores.

![Os 72 Coringas TDG com molduras e recortes padronizados](https://raw.githubusercontent.com/Namullan/TDG-Ascensao/main/assets/2x/tdg_jokers.png)

![Tarôs e Planetas próprios](https://raw.githubusercontent.com/Namullan/TDG-Ascensao/main/assets/2x/tdg_arcana.png)

## Conteúdo

| Conteúdo | Quantidade |
|---|---:|
| Coringas: personagens, espíritos, artefatos, facções e missões | 72 |
| Elixires, Técnicas e Relíquias | 24 |
| Vouchers | 12 |
| Aprimoramentos de cartas | 8 |
| Selos | 6 |
| Edições | 4 |
| Pacotes normais, jumbo e mega | 9 |
| Baralhos | 6 |
| Tags | 6 |
| Tarôs | 12 |
| Mãos de pôquer | 6 |
| Planetas | 6 |
| Boss Blinds | 8 |
| **Total** | **179** |

Há também **12 reinos com cinco estágios cada**, Qi, Essência, Compreensão, Karma, cinco afinidades, três caminhos, meditação, forja de elixires e reencarnação. A intenção é permitir construções mais fortes e partidas mais longas que no jogo base.

[Catálogo completo](https://github.com/Namullan/TDG-Ascensao/blob/main/docs/CATALOG.md) · [Código e downloads](https://github.com/Namullan/TDG-Ascensao) · [Relatar um problema](https://github.com/Namullan/TDG-Ascensao/issues)

## Instalação

Requer **Steamodded 1.0.0~BETA-1224a ou posterior** e **Lovely**. O pacote público declara as versões testadas `Steamodded-Steamodded-1.1224.0` e `Thunderstore-lovely-0.9.0`; o gerenciador instala essas dependências.

### Thunderstore ou r2modman

1. Selecione **Balatro** e crie ou escolha um perfil no gerenciador.
2. Instale **TDG**, de **Namullan**, com suas dependências.
3. Inicie pelo botão **Start modded / Iniciar com mods** do gerenciador.
4. Para pontuações acima do limite numérico normal, adicione [Talismã](https://github.com/SpectralPack/Talisman) seguindo as instruções do projeto. Ele é opcional e não acompanha o pacote.

Para testar um ZIP público antes de instalá-lo pelo catálogo, use **Settings → Import local mod / Importar mod local**. A importação local pode exigir instalar as dependências separadamente.

### Instalação manual

1. Feche o Balatro e instale Steamodded e Lovely seguindo as [instruções oficiais](https://github.com/Steamodded/smods/wiki).
2. Crie uma pasta `TDG` no diretório de Mods do Balatro. No Windows, o diretório é `%APPDATA%\Balatro\Mods`.
3. Extraia **o conteúdo** deste ZIP público para essa pasta. `TDG/mod.json` e `TDG/main.lua` devem ficar diretamente dentro dela, junto de `assets/` e `content/`.
4. Inicie o jogo com os mods carregados.

Use apenas uma instalação de TDG por perfil. Ao atualizar uma versão anterior, substitua os arquivos da mesma instalação com o jogo fechado.

## Começar a cultivar

Você pode usar qualquer baralho; os seis baralhos TDG oferecem pontos de partida diferentes. Cada mão ganha Qi e aproxima sua alma do próximo estágio. O avanço de reino acontece automaticamente, guarda o Qi excedente e fortalece o Mult das mãos seguintes.

Clique em **CULTIVAR** durante a partida ou em **Pavilhão de Cultivo** na loja. O painel mostra o reino, o estágio, seus recursos, afinidades e a tribulação atual. Na loja, você pode meditar, forjar Elixires e escolher um caminho:

| Caminho | Benefício |
|---|---|
| Alquimia | +20% ao Qi recebido |
| Fusão Demoníaca | Repete a primeira carta pontuada de cada mão |
| Inscrições | +8 Qi por carta aprimorada pontuada |

A primeira escolha é gratuita; trocar custa $8. Meditar custa $4 e gera Qi. Forjar um Elixir custa três Essências e exige uma vaga de consumível.

As afinidades seguem suas cartas: **Copas = Fogo**, **Espadas = Água**, **Paus = Madeira**, **Ouros = Metal** e **Pedra/cartas sem naipe = Terra**. Junte elementos, aprimoramentos e espíritos para sustentar seu crescimento.

Os reinos avançam de Bronze até Deus Espiritual. A **Pílula da Reencarnação**, disponível a partir de Lendário, devolve a alma a Bronze, preserva recursos e histórico e fortalece o ciclo seguinte.

### Consumíveis e tribulações

**Elixires** cultivam e aprimoram; **Técnicas** trabalham cartas e formações; **Relíquias** oferecem poderes avançados com custos ou condições. Pacotes TDG permitem guardar consumíveis para usá-los quando seus alvos estiverem preparados.

Todo Boss Blind pode trazer uma tribulação adicional de cultivação. Cumpra o objetivo mostrado no painel e vença o chefe para receber Qi, Compreensão e Essência extras.

## Tarôs, mãos e planetas

Os **12 Tarôs** aparecem na loja e em pacotes Arcanos. Giram naipes, trocam valores, clonam ou sacrificam cartas, transferem marcas, geram Terra e preparam novas formações.

**Espelho da Alma, Semente da Terra e Constelação Perdida** criam cartas e devem ser guardados antes do uso no inventário. Custos e alvos são descritos em cada carta; Constelação Perdida precisa de uma vaga adicional de consumível enquanto a fonte ainda ocupa seu lugar.

| Mão | Formação | Planeta |
|---|---|---|
| Ciclo Elemental | Quatro valores consecutivos, com quatro naipes distintos | Estrela da Glória |
| Dragões Gêmeos | Dois pares; cada par tem uma carta vermelha e uma preta | Lua Gêmea |
| Tríade Celestial | 3, 6 e 9, com três naipes distintos | Céu Triplo |
| Escada do Dao | Cinco valores com intervalo de dois, como 2/4/6/8/10 | Mundo do Dao |
| Matriz das Inscrições | Três valores distintos com três selos distintos | Domínio das Inscrições |
| Confluência dos Cinco Elementos | Uma carta de cada afinidade, incluindo Terra | Reino Espiritual |

As regras e exemplos aparecem no menu nativo de mãos. Cada planeta sobe sua própria mão em um nível e concede **10 Qi**; os seis entram na loja e nos pacotes Celestiais. Carta Naipe Curinga pode preencher naipes/cores nos padrões que os pedem. Curinga Borrado, Quatro Dedos e Atalho mantêm as regras próprias dessas mãos.

## Oito Boss Blinds

| Chefe | Desafio |
|---|---|
| Tributo da Família Sagrada | Até $2 por mão; saldo insuficiente reduz o Mult base |
| Névoa de Vento Nevado | -1 tamanho de mão durante o chefe |
| Garras da Guilda Sombria | Cartas jogadas com selo/edição reduzem o Mult base |
| Gargalo do Qilin | Valores repetidos reduzem as Fichas base |
| Espelho do Reino da Alma | Repetir o tipo da mão anterior reduz o Mult base |
| Labirinto das Inscrições | Menos de duas afinidades reduz as Fichas base |
| Cerco de Glory City — chefe final | -1 descarte e penalidade ao jogar menos de cinco cartas |
| Decreto do Imperador Sábio — chefe final | Alterna exigências de afinidades, marcas e mudança de mão |

Eles entram na seleção normal quando sua Ante mínima permite. Reduções temporárias de capacidade são devolvidas ao desativar ou derrotar o chefe e acompanham o save.

## Configuração e saves

Em **Mods → TDG — Ascensão → Configurações**, há três opções:

- **Cultivação em todos os baralhos:** controla ganhos e bônus da progressão universal.
- **Mostrar painel de cultivação:** mostra ou oculta o painel; a mudança aparece ao começar ou continuar uma partida.
- **Início generoso:** ligado por padrão, concede $6, uma vaga extra de Coringa e uma de consumível em partidas novas.

**Continuar** mantém reinos, recursos, caminhos, tribulações e reencarnações sem repetir os bônus iniciais. Saves da versão 1.0 recebem as seis mãos novas e conservam sua progressão. Partidas que contenham conteúdo TDG precisam do mod carregado para continuar.

## Talismã e validação

TDG funciona sem Talismã e oferece efeitos alternativos de XMult onde ele seria necessário. Com Talismã em um modo de números grandes, as construções podem superar o limite normal de pontuação.

A versão 1.1.0 passou por **114 testes automatizados**, partidas de teste no Balatro real com e sem Talismã, salvamento/recarga e migração da versão 1.0. As artes foram inspecionadas em cartas nativas nas escalas 1x/2x: recortes medidos, proporções preservadas, molduras alinhadas e áreas de valor/naipe legíveis.

O conjunto foi validado funcionalmente; uma campanha natural até a **Ante 39** e todas as combinações possíveis de mods ainda não foram certificadas. [Relatório de validação](https://github.com/Namullan/TDG-Ascensao/blob/main/docs/VALIDATION-1.1.md).

## Créditos e licença

Projeto de **Namullan**, desenvolvido com assistência de IA. As ilustrações foram geradas originalmente para este mod com **ImageGen**; selos, tags, emblemas e identidade visual incluem vetores originais. Nenhuma página do mangá ou arquivo do jogo base acompanha o pacote.

**Tales of Demons and Gods**, de Mad Snail, inspira a adaptação. É um **fan mod não oficial**, sem vínculo ou endosso dos criadores da obra ou de Balatro. Personagens, nomes e universos pertencem aos seus respectivos titulares. [Referências](https://github.com/Namullan/TDG-Ascensao/blob/main/docs/REFERENCES.md).

Código, documentação e assets originais são disponibilizados sob **MIT**, dentro dos direitos que o mantenedor pode licenciar; direitos de terceiros ficam expressamente excluídos. Veja [LICENSE](https://github.com/Namullan/TDG-Ascensao/blob/main/LICENSE). Steamodded, Lovely e Talismã têm suas próprias licenças e não estão incluídos na distribuição.

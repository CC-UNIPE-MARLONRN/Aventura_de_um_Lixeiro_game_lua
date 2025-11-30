# A Aventura de um Lixeiro

Este README descreve o jogo, suas três fases, controles, arquivos de sprite esperados e instruções rápidas para rodar e personalizar.

## Visão geral

Fluxo do jogo:
- Menu
- Fase 1 — Coleta (capturar lixos que caem)
- Fase 2 — Separação (classificar os lixos capturados)
- Fase 3 — Caminhão (transportar os lixeiros sem derrubá-los)
- Game Over / placar final

O jogo foi implementado em LÖVE (Love2D). O arquivo principal é `main.lua` e as configurações de janela estão em `conf.lua`.

## Fase 1 — Coleta
- Objetivo: mover o lixeiro e capturar lixos que caem do topo.
- Mecânica: itens e powerups caem; capturar aumenta `captured[tipo]` e concede pontos multiplicados por `scoreMultiplier`.
- Vidas: se um lixo tocar o chão, o jogador perde vidas (hearts). Quando hearts -> 0 o jogo avança para a Fase 2.
- Notas técnicas: taxa de spawn e pontos por tipo estão em `lixoSpawnRate` / `lixoPoints` no `main.lua`.

## Fase 2 — Separação (Em breve)
- Objetivo: para cada item coletado na Fase 1, escolher o lixeiro correto entre 5 categorias: Plásticos, Vidros, Metais, Papéis, Orgânicos.
- Mecânica: a fila `separation_queue` é criada a partir dos itens capturados; o jogador usa A/D para mover o cursor e ESPAÇO para confirmar.
- Pontuação: ao acertar, o jogador ganha imediatamente os pontos do item (valor em `lixoPoints`) e o item é colocado em `separated_items` para o caminhão.
- Customização: o mapeamento tipo→categoria padrão está na função `getCategoryForTipo(tipo)` em `main.lua`. Você pode editar essa função para corresponder aos seus assets.

## Fase 3 — Caminhão (Em breve)
- Objetivo: levar o caminhão até o destino sem derrubar os lixeiros empilhados no teto do caminhão.
- Mecânica: o caminhão anda automaticamente por um percurso longo; há vários obstáculos (bump/ramp). Use ESPAÇO para pular.
- Itens no caminhão: os itens corretamente separados aparecem como lixeiros sobre o caminhão (`truck.carried_bins`).
- Penalidade: se qualquer lixeiro cair durante o percurso (`truck_dropped == true`), os pontos da separação poderão ser perdidos (comportamento atual: perda total da separação). Pode-se alterar para perda parcial no código.
- Visual: se existir `sprites/truck_background.png` (ou `truck_bg.png` / `truck.png`) ele será usado como background do percurso; caso contrário desenha-se um chão simples.

## Controles
- A / D — mover o player (Fase 1) e cursor (Fase 2)
- ESPAÇO — iniciar jogo / confirmar seleção (Fase 2) / pular no caminhão (Fase 3)
- F11 — alterna fullscreen
- ESC — sair do fullscreen

## Arquivos de sprite esperados (pasta `sprites/`)
- `background.png` — background da área principal (Fase 1)
- `menu_background.png` — background do menu
- `lixeiro.png` — sprite base do lixeiro/player e também usado como recipiente no caminhão
- `powerup.png` — sprite do powerup
- `heart.png`, `half_heart.png` — ícones de vida
- `lixo 1.png` .. `lixo 8.png` — sprites para os tipos de lixo (o código também possui `lixos[10]` chamado `lixo.png`)
- Opcional: `truck_background.png` (ou `truck_bg.png` / `truck.png`) — background longo para a fase do caminhão

Observação: se você usar nomes de arquivos diferentes, ajuste as chamadas em `love.load()` dentro de `main.lua`.

## Como rodar
1. Instale LÖVE (Love2D) na sua máquina.
2. No diretório do projeto (onde estão `main.lua` e `conf.lua`) execute:

```bash
love .
```

## Pontuação e parâmetros úteis (editar em `main.lua`)
- `lixoPoints` — tabela com os pontos por tipo de lixo
- `lixoSpawnRate_BASE` — taxa base de spawn de lixos
- `POWERUP_DURATION_BASE` — duração base dos powerups
- `truck_destination_x` — controla o comprimento do percurso do caminhão

## Sugestões de personalização
- Substituir os retângulos da fase do caminhão por sprites/
- Ajustar o mapeamento `getCategoryForTipo(tipo)` para refletir a categorização real dos seus assets
- Mudar a penalidade do caminhão para perda parcial dos pontos (apenas dos bins caídos)
- Adicionar efeitos sonoros na captura, acerto/erro na separação e ao derrubar bins no caminhão

## Exemplo de alteração rápida: mudar o mapeamento de tipos
Edite a função `getCategoryForTipo(tipo)` em `main.lua`. Exemplo:
```lua
function getCategoryForTipo(tipo)
    local mapping = {
        [1] = 1, -- tipo 1 -> Plásticos
        [2] = 2, -- tipo 2 -> Vidros
        [3] = 3, -- tipo 3 -> Metais
        [4] = 4, -- tipo 4 -> Papéis
        [5] = 5, -- tipo 5 -> Orgânicos
        -- etc.
    }
    return mapping[tipo] or 1
end
```

## Próximos passos sugeridos
- Ajustar perda parcial no caminhão (não derrubar todos os bins de uma vez)
- Melhorar UI com feedback de acerto/erro na separação e um placar intermediário ao final do caminhão
- Substituir elementos gráficos por sprites mais detalhados e adicionar sons

---


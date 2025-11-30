function love.load()
    -- ================= CONFIGURAÇÕES DE LAYOUT =================
    -- Tela virtual (o jogo SEMPRE terá esta resolução interna)
    VIRTUAL_WIDTH = 1280
    VIRTUAL_HEIGHT = 960
    
    -- Define a área de jogo "Arcade" 4:3 com bordas
    -- Borda Esquerda: 128px | Área de Jogo: 1024px | Borda Direita (UI): 128px
    GAME_X_OFFSET = 128
    GAME_WIDTH = 1024
    UI_X_POS = GAME_X_OFFSET + GAME_WIDTH -- Começa em 1152
    UI_WIDTH = 128
    
    -- Lista dos tipos de lixo que existem para o painel de score
    available_lixo_types = {1, 2, 3, 4, 5, 6, 7, 8, 10}

    -- ================= SPRITES =================
    sprites = {}
    sprites.background = love.graphics.newImage('sprites/background.png')
    sprites.lixeiro = love.graphics.newImage('sprites/lixeiro.png')
    sprites.powerup = love.graphics.newImage('sprites/powerup.png')
    sprites.heart = love.graphics.newImage('sprites/heart.png')
    sprites.half_heart = love.graphics.newImage('sprites/half_heart.png')
    sprites.menu_background = love.graphics.newImage('sprites/menu_background.png')
    -- Tentar carregar um background específico para a pista do caminhão (opcional)
    if love.filesystem.getInfo('sprites/truck_background.png') then
        sprites.truck_background = love.graphics.newImage('sprites/truck_background.png')
    elseif love.filesystem.getInfo('sprites/truck_bg.png') then
        sprites.truck_background = love.graphics.newImage('sprites/truck_bg.png')
    elseif love.filesystem.getInfo('sprites/truck.png') then
        sprites.truck_background = love.graphics.newImage('sprites/truck.png')
    else
        sprites.truck_background = nil
    end

    -- Carregar todos os tipos de lixo
    sprites.lixos = {}
    for i = 1, 8 do
        sprites.lixos[i] = love.graphics.newImage('sprites/lixo ' .. i .. '.png')
    end
    sprites.lixos[10] = love.graphics.newImage('sprites/lixo.png')

    -- ================= CONFIGURAÇÕES =================
    -- Define a "tela virtual" onde o jogo será desenhada
    mainCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    
    -- Configura a janela real
    love.window.setMode(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, {
        resizable = true, 
        vsync = true, 
        minwidth = VIRTUAL_WIDTH / 2, 
        minheight = VIRTUAL_HEIGHT / 2
    })
    love.window.setTitle("A Aventura de um Lixeiro")
    love.window.maximize() -- Inicia maximizado

    -- ================= ENTIDADES =================
    player = {}
    player.x = (GAME_WIDTH / 2) + GAME_X_OFFSET -- Centralizado na área de jogo
    player.y = VIRTUAL_HEIGHT - 300
    player.speed = 260
    player.scale = 1.8
    player.width = sprites.lixeiro:getWidth() * player.scale
    player.height = sprites.lixeiro:getHeight() * player.scale

    lixos = {}
    powerups = {}

    -- ================= SISTEMAS =================
    score = 0
    hearts = 3
    maxHearts = 3

    lixoTimer = 0
    lixoSpawnRate_BASE = 1.5      
    lixoSpawnRate = lixoSpawnRate_BASE
    powerupTimer = 0
    powerupSpawnRate = 8

    captured = {
        [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0,
        [6] = 0, [7] = 0, [8] = 0, [9] = 0, [10] = 0
    }

    -- Pontos por tipo de lixo
    lixoPoints = {10, 15, 20, 25, 30, 40, 45, 50, 60, 100}

    powerupActive = false
    powerupDuration = 0
    playerSpeedMultiplier = 1

    -- VARIÁVEIS DO MULTIPLICADOR
    scoreMultiplier = 1           
    
    -- NOVO: Variável base para a duração do power-up (10 segundos)
    POWERUP_DURATION_BASE = 10      
    
    gameState = "menu"

    -- ================= FASES ADICIONAIS: SEPARAÇÃO E CAMINHÃO =================
    -- Fase de separação (fila gerada a partir dos lixos capturados)
    separation_queue = {}      -- lista de tipos (integers) para separar
    separation_index = 1       -- item atual na fila
    separation_cursor = 1      -- índice do lixeiro selecionado (1..5)
    separation_points = 0      -- pontos ganhos apenas na separação
    separated_items = {}       -- itens corretamente separados (serão colocados no caminhão)
    bins = {                   -- posições das 5 categorias dentro da área de jogo
        {name = "Plasticos"},
        {name = "Vidros"},
        {name = "Metais"},
        {name = "Papeis"},
        {name = "Organicos"}
    }

    -- Fase do caminhão
    truck = { x = GAME_X_OFFSET, y = VIRTUAL_HEIGHT - 200, w = 160, h = 80, speed = 180, vy = 0, onGround = true }
    truck_destination_x = GAME_X_OFFSET + GAME_WIDTH * 3 -- caminho mais longo
    truck_obstacles = {}       -- obstáculos no caminho (retângulos)
    truck_dropped = false      -- se algum lixeiro foi derrubado
    truck.carried_bins = {}    -- itens empilhados no caminhão
    truck.dropped_items = {}   -- itens que caíram do caminhão e caem na cena
    separation_finished = false
end

-- ================= UPDATE =================
function love.update(dt)
    if gameState == "playing" then
        updateGame(dt)
    elseif gameState == "separation" then
        updateSeparation(dt)
    elseif gameState == "truck" then
        updateTruck(dt)
    end
end

function updateGame(dt)
    -- Movimento do lixeiro (AJUSTADO PARA A ÁREA DE JOGO)
    if love.keyboard.isDown("a") then
        player.x = player.x - player.speed * playerSpeedMultiplier * dt
        if player.x < GAME_X_OFFSET then player.x = GAME_X_OFFSET end -- Limite esquerdo
    elseif love.keyboard.isDown("d") then
        player.x = player.x + player.speed * playerSpeedMultiplier * dt
        if player.x + player.width > UI_X_POS then -- Limite direito
            player.x = UI_X_POS - player.width
        end
    end

    spawnLixo(dt)
    spawnPowerup(dt)
    checkCollisions()

    -- Atualizar powerup
    if powerupActive then
        powerupDuration = powerupDuration - dt
        if powerupDuration <= 0 then
            powerupActive = false
            playerSpeedMultiplier = 1
            scoreMultiplier = 1 -- RESETAR o multiplicador quando o tempo acabar
            lixoSpawnRate = lixoSpawnRate_BASE -- Reverte a taxa de spawn
        end
    end

    -- Atualizar posição dos lixos e powerups
    for i, lixo in ipairs(lixos) do
        lixo.y = lixo.y + lixo.speed * dt
    end
    for i, p in ipairs(powerups) do
        p.y = p.y + p.speed * dt
    end

    -- Remover fora da tela
    for i = #lixos, 1, -1 do
        if lixos[i].y > VIRTUAL_HEIGHT then
            hearts = hearts - 0.5
            table.remove(lixos, i)
            if hearts <= 0 then
                hearts = 0
                -- Em vez de ir diretamente para gameover, vamos para a fase de separação
                prepareSeparation()
                gameState = "separation"
            end
        end
    end
    for i = #powerups, 1, -1 do
        if powerups[i].y > VIRTUAL_HEIGHT then
            table.remove(powerups, i)
        end
    end
end

-- ================= DESENHAR (NOVO SISTEMA DE CANVAS) =================
function love.draw()
    -- 1. Começa a desenhar no nosso canvas de 1280x960
    love.graphics.setCanvas(mainCanvas)
    
    -- Limpa o canvas (fundo preto para as bordas do arcade)
    love.graphics.clear(0, 0, 0) 
    
    -- 2. Chama as funções de desenho normais (elas agora desenham no canvas)
    if gameState == "menu" then
        drawMenu()
    elseif gameState == "playing" then
        drawGame()
    elseif gameState == "separation" then
        drawSeparation()
    elseif gameState == "truck" then
        drawTruck()
    elseif gameState == "gameover" then
        drawGameOver()
    end
    
    -- 3. Para de desenhar no canvas e volta para a tela principal
    love.graphics.setCanvas()
    
    -- 4. Desenha o canvas na tela, escalonado e centralizado (Letterbox/Pillarbox)
    
    -- Limpa a tela real (para as bordas fora do canvas)
    love.graphics.clear(0, 0, 0) 

    local winWidth, winHeight = love.graphics.getDimensions()
    
    -- Calcula a escala para caber na janela mantendo o aspect ratio
    local scale = math.min(winWidth / VIRTUAL_WIDTH, winHeight / VIRTUAL_HEIGHT)
    
    -- Calcula a posição para centralizar o canvas
    local drawX = (winWidth - (VIRTUAL_WIDTH * scale)) / 2
    local drawY = (winHeight - (VIRTUAL_HEIGHT * scale)) / 2
    
    -- Desenha o canvas final na tela
    love.graphics.draw(mainCanvas, drawX, drawY, 0, scale, scale)
end

--
-- FUNÇÃO DO MENU
--
function drawMenu()
    -- 1. Desenha o fundo do menu (sprites.menu_background) na área de jogo
    drawMenuBackground()

    -- 2. Texto "Aperte Espaço"
    
    love.graphics.setColor(255,255,255) -- COR BRANCA
    
    -- Parâmetros do love.graphics.printf (com todos os argumentos):
    local text = "PRESSIONE ESPAÇO PARA JOGAR"
    local x = GAME_X_OFFSET
    local y = VIRTUAL_HEIGHT - 80
    local limit = GAME_WIDTH
    local align = "left" 
    local r = 0      
    local sx = 2   
    local sy = 2   
    local ox = -150   
    local oy = 0     
    
    love.graphics.printf(text, x, y, limit, align, r, sx, sy, ox, oy)
    
    -- Resetar cor
    love.graphics.setColor(1, 1, 1)
end

function drawGame()
    drawBackground()
    drawHearts() -- Vidas
    drawScore() -- Painel de pontuação

    -- Lixeiro
    love.graphics.draw(sprites.lixeiro, player.x, player.y, 0, player.scale, player.scale)

    -- Lixos
    for i, lixo in ipairs(lixos) do
        love.graphics.draw(lixo.image, lixo.x, lixo.y, 0, lixo.scale, lixo.scale)
    end

    -- Powerups (Aumentado para 1.5x)
    for i, p in ipairs(powerups) do
        love.graphics.draw(sprites.powerup, p.x, p.y, 0, 1.5, 1.5)
    end
    
    drawPowerupStatus() -- Status do power-up
end

function drawGameOver()
    -- AJUSTADO: Desenha o fundo e o texto na área de jogo
    drawBackground()
    
    local text1 = "FIM DE JOGO"
    local text2 = "Pontuação Final: " .. score
    local text3 = "Pressione ESPAÇO para jogar novamente"
    local x = GAME_X_OFFSET
    local limit = GAME_WIDTH
    local align = "left" 
    local r = 0      
    local sx = 2   
    local sy = 2   
    local ox = -180   
    local oy = 0     
    
    

    love.graphics.setColor(1, 0, 0)
    love.graphics.printf(text1, x, VIRTUAL_HEIGHT/2 - 80, limit, align, r, sx, sy, -210, oy)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text2, x, VIRTUAL_HEIGHT/2, limit, align, r, sx, sy, ox, oy)
    
    love.graphics.setColor(0, 1, 0)
    love.graphics.printf(text3, x, VIRTUAL_HEIGHT/2 + 100, limit, align, r, sx, sy, -132, oy)
end

-- ================= FUNÇÕES DE DESENHO =================

--
-- FUNÇÃO: Força o background do menu a ter exatamente 1024x960
--
function drawMenuBackground()
    local bg = sprites.menu_background
    
    -- Calcule as escalas X e Y separadamente para forçar o preenchimento
    -- Scale X (sx): Força a largura da imagem a ser exatamente GAME_WIDTH (1024)
    local sx = GAME_WIDTH / bg:getWidth() 
    
    -- Scale Y (sy): Força a altura da imagem a ser exatamente VIRTUAL_HEIGHT (960)
    local sy = VIRTUAL_HEIGHT / bg:getHeight() 
    
    -- A posição X é o início da área de jogo
    local bgX = GAME_X_OFFSET
    
    -- A posição Y é o topo da área de jogo
    local bgY = 0
    
    -- Desenha a imagem com as novas escalas (pode ocorrer distorção)
    love.graphics.draw(bg, bgX, bgY, 0, sx, sy)
end

function drawBackground()
    -- AJUSTADO: Desenha o fundo apenas na área de jogo (1024x960)
    local bg = sprites.background
    -- Mantemos o cálculo anterior para evitar distorção no fundo do jogo, 
    -- fazendo com que ele cubra a área e o centro da imagem fique visível.
    local scale = math.max(
        GAME_WIDTH / bg:getWidth(),
        VIRTUAL_HEIGHT / bg:getHeight()
    )
    -- Centraliza a imagem dentro da área de jogo
    local bgX = GAME_X_OFFSET + (GAME_WIDTH - (bg:getWidth() * scale)) / 2
    local bgY = (VIRTUAL_HEIGHT - (bg:getHeight() * scale)) / 2

    love.graphics.draw(bg, bgX, bgY, 0, scale, scale)
end

function drawHearts()
    -- AJUSTADO: Desenha os corações dentro da área de jogo
    local spacing = 75
    local start_x = GAME_X_OFFSET + 5 -- Começa 5px dentro da área de jogo
    
    for i = 1, math.floor(hearts) do
        -- Escala diminuída para 0.08
        love.graphics.draw(sprites.heart, start_x + (i - 1) * spacing, 10, 0, 0.08, 0.08)
    end
    if hearts % 1 >= 0.5 then
        -- Escala diminuída para 0.08
        love.graphics.draw(sprites.half_heart, start_x + math.floor(hearts) * spacing, 10, 0, 0.08, 0.08)
    end
end

function drawScore()
    -- NOVO: Esta função agora desenha o PAINEL DE PONTUAÇÃO na borda direita
    
    local x_pos = UI_X_POS + 10 -- Posição X inicial dentro da borda direita
    local y_pos = 20
    local wrap = UI_WIDTH - 20 -- Largura de texto permitida
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PONTUAÇÃO", x_pos, y_pos, wrap, "left", 0, 1.4, 1.4)
    y_pos = y_pos + 25
    
    love.graphics.setColor(1, 1, 0) -- Amarelo para o número
    love.graphics.printf(score, x_pos, y_pos, wrap, "left", 0, 1.8, 1.8)
    y_pos = y_pos + 60
    
    -- Mostra o multiplicador de pontos no painel
    if scoreMultiplier > 1 then
        local multiplier_text = "x" .. scoreMultiplier .. " PTS"
        love.graphics.setColor(0, 1, 0) -- Verde
        love.graphics.printf(multiplier_text, x_pos, y_pos - 30, wrap, "left", 0, 1.2, 1.2)
        love.graphics.setColor(1, 1, 1) -- Volta ao branco
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("CAPTURADOS", x_pos, y_pos, wrap, "left", 0, 1.4, 1.4)
    y_pos = y_pos + 30
    
    -- Loop para desenhar cada tipo de lixo e sua contagem
    for _, tipo in ipairs(available_lixo_types) do
        local sprite = sprites.lixos[tipo]
        local count = captured[tipo]
        
        -- AJUSTE 1: Diminuindo a escala para 0.12
        local sprite_scale = 0.12
        
        -- Garante que temos um sprite (pode falhar se o 'tipo' não for carregado)
        if sprite then
            local sprite_w = sprite:getWidth() * sprite_scale
            local sprite_h = sprite:getHeight() * sprite_scale
            
            -- Desenha o ícone do lixo
            love.graphics.draw(sprite, x_pos, y_pos, 0, sprite_scale, sprite_scale)
            
            -- Desenha o "x" e a contagem ao lado do ícone
            love.graphics.printf("x " .. count, x_pos + sprite_w + 5, y_pos + 5, wrap - sprite_w, "left", 0, 1.3, 1.3)
            
            -- AJUSTE 2: Diminuindo o espaçamento vertical para 2
            y_pos = y_pos + sprite_h + 2
            
            -- Para o loop se sair da tela (mantido por segurança, mas agora deve caber mais)
            if y_pos > VIRTUAL_HEIGHT - 40 then
                break
            end
        end
    end
end

-- Função para desenhar o status do Power-up
function drawPowerupStatus()
    if powerupActive then
        local x = GAME_X_OFFSET + (GAME_WIDTH / 2)
        local y = VIRTUAL_HEIGHT - 30
        local time_left = math.ceil(powerupDuration)
        
        -- Desenha a caixa de fundo (opcional)
        love.graphics.setColor(0, 0, 0, 0.5) -- Fundo preto transparente
        love.graphics.rectangle("fill", x - 150, y - 5, 300, 30)
        
        -- Texto do multiplicador
        love.graphics.setColor(1, 1, 0) -- Amarelo
        local text = string.format("POWERUP ATIVO: X%d | TEMPO: %d s", scoreMultiplier, time_left)
        
        -- Desenha centralizado na área de jogo
        love.graphics.printf(text, GAME_X_OFFSET, y, GAME_WIDTH, "center")
        
        love.graphics.setColor(1, 1, 1)
    end
end


-- ================= GAMEPLAY =================
function spawnLixo(dt)
    lixoTimer = lixoTimer + dt
    if lixoTimer >= lixoSpawnRate then
        local random_index = math.random(1, #available_lixo_types)
        local tipo = available_lixo_types[random_index]

        local lixo = {}
        lixo.image = sprites.lixos[tipo]
        lixo.tipo = tipo
        lixo.scale = 0.3 + (tipo * 0.02) / 2
        
        local lixo_width = lixo.image:getWidth() * lixo.scale
        
        -- AJUSTADO: Spawn apenas dentro da área de jogo
        lixo.x = math.random(GAME_X_OFFSET, UI_X_POS - lixo_width)
        
        lixo.y = -100
        lixo.speed = 120 + tipo * 5
        
        table.insert(lixos, lixo)
        lixoTimer = 0
    end
end

function spawnPowerup(dt)
    powerupTimer = powerupTimer + dt
    if powerupTimer >= powerupSpawnRate then
        local p = {}
        local p_scale = 1.5 -- Escala do powerup (mantido em 1.5)
        local p_width = sprites.powerup:getWidth() * p_scale 
        
        -- AJUSTADO: Spawn apenas dentro da área de jogo
        p.x = math.random(GAME_X_OFFSET, UI_X_POS - p_width)
        
        p.y = -60
        p.speed = 100
        table.insert(powerups, p)
        powerupTimer = 0
    end
end

function checkCollisions()
    -- Checar colisão com lixos
    for i = #lixos, 1, -1 do
        local lixo = lixos[i]
        if checkOverlap(player.x, player.y, player.width, player.height,
                        lixo.x, lixo.y, lixo.image:getWidth() * lixo.scale, lixo.image:getHeight() * lixo.scale) then
            
            -- APLICA O MULTIPLICADOR AO SCORE
            score = score + (lixoPoints[lixo.tipo] * scoreMultiplier) 
            
            captured[lixo.tipo] = captured[lixo.tipo] + 1
            table.remove(lixos, i)
        end
    end

    -- Checar colisão com powerups
    for i = #powerups, 1, -1 do
        local p = powerups[i]
        local p_scale = 1.5
        local p_width = sprites.powerup:getWidth() * p_scale
        local p_height = sprites.powerup:getHeight() * p_scale
        
        if checkOverlap(player.x, player.y, player.width, player.height, p.x, p.y, p_width, p_height) then
            
            -- 1. LÓGICA PROGRESSIVA DO MULTIPLICADOR
            if not powerupActive then
                scoreMultiplier = 2 -- Primeiro power-up: 2x
            else
                scoreMultiplier = scoreMultiplier * 2 -- Multiplica o atual por 2 (4x, 8x, 16x...)
            end
            
            -- 2. LÓGICA PROGRESSIVA DA DURAÇÃO (DIMINUI 2 SEGUNDOS)
            -- A duração é calculada a partir do multiplicador
            local duration_multiplier = math.log(scoreMultiplier, 2)
            local new_duration = POWERUP_DURATION_BASE - (duration_multiplier - 1) * 2
            
            -- Garante que a duração mínima seja 2 segundos
            powerupDuration = math.max(2, new_duration)
            
            -- 3. APLICA OUTROS EFEITOS
            playerSpeedMultiplier = 2
            powerupActive = true
            lixoSpawnRate = lixoSpawnRate_BASE * 0.5 -- Aumenta o spawn (diminui o tempo)
            
            table.remove(powerups, i)
        end
    end
end

function checkOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x2 < x1 + w1 and
           y1 < y2 + h2 and
           y2 < y1 + h1
end

-- ================= CONTROLES =================
function love.keypressed(key)
    -- Controle rápido para a fase de separação (mover cursor)
    if gameState == "separation" then
        if key == "a" then
            separation_cursor = math.max(1, separation_cursor - 1)
            return
        elseif key == "d" then
            separation_cursor = math.min(#bins, separation_cursor + 1)
            return
        end
    end
    if key == "space" then
        if gameState == "menu" then
            resetGame()
            gameState = "playing"
        elseif gameState == "gameover" then
            resetGame()
            gameState = "playing"
        elseif gameState == "separation" then
            if separation_index <= #separation_queue then
                attemptAssignCurrent()
            else
                -- fila vazia: avançar ao caminhão
                prepareTruck()
                gameState = "truck"
            end
        elseif gameState == "truck" then
            -- pular
            if truck.onGround then
                truck.vy = -480
                truck.onGround = false
            end
        end
    
    -- Alterna tela cheia com F11
    elseif key == "f11" then
        local isFullscreen = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen)
        
    -- Sai da tela cheia com Esc
    elseif key == "escape" then
        if love.window.getFullscreen() then
            love.window.setFullscreen(false)
        end
    end
end

function resetGame()
    lixos = {}
    powerups = {}
    score = 0
    hearts = 3
    powerupActive = false
    powerupDuration = 0
    playerSpeedMultiplier = 1
    scoreMultiplier = 1 -- Zera o multiplicador no reset
    lixoSpawnRate = lixoSpawnRate_BASE -- Reverte a taxa de spawn
    for k in pairs(captured) do captured[k] = 0 end
    -- Reset das fases adicionais
    separation_queue = {}
    separation_index = 1
    separation_cursor = 1
    separation_points = 0
    truck_obstacles = {}
    truck_dropped = false
    separation_finished = false
end

-- ================= FASE: SEPARAÇÃO E CAMINHÃO (FUNÇÕES ADICIONAIS) =================

function prepareSeparation()
    -- Constrói a fila de itens a partir de 'captured'
    separation_queue = {}
    for tipo, qtd in pairs(captured) do
        for i = 1, qtd do
            table.insert(separation_queue, tipo)
        end
    end
    separation_index = 1
    separation_cursor = 3 -- começar no meio
    separation_points = 0
    separation_finished = false
    truck_dropped = false
    -- zera os contadores capturados (já estão guardados na fila)
    for k in pairs(captured) do captured[k] = 0 end
    separated_items = {}
end

-- Mapeamento simples: categoria = ((tipo - 1) % 5) + 1
function getCategoryForTipo(tipo)
    return ((tipo - 1) % 5) + 1
end

function updateSeparation(dt)
    -- A separação é controlada por teclas (a/d para mover, espaço para confirmar)
    -- mantemos vazio; entrada é tratada em love.keypressed
end

function drawSeparation()
    drawBackground()
    drawScore()
    local x = GAME_X_OFFSET
    local y = 80
    love.graphics.setColor(1,1,1)
    love.graphics.printf("FASE DE SEPARAÇÃO", x, y, GAME_WIDTH, "center")
    y = y + 50

    -- Desenha os lixeiros (bins)
    local bin_w = 140
    local spacing = (GAME_WIDTH - (bin_w * #bins)) / (#bins + 1)
    for i, b in ipairs(bins) do
        local bx = GAME_X_OFFSET + spacing * i + bin_w * (i - 1)
        local by = VIRTUAL_HEIGHT - 260
        b.x = bx
        b.y = by
        b.w = bin_w
        b.h = 160
        -- Destaque se selecionado
        if separation_cursor == i then
            love.graphics.setColor(0.2, 0.8, 0.2)
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
        end
        love.graphics.rectangle("fill", bx, by, bin_w, 160)
        love.graphics.setColor(0,0,0)
        love.graphics.printf(b.name, bx, by + 70, bin_w, "center")
    end

    -- Mostra o item atual (se houver)
    if separation_index <= #separation_queue then
        local tipo = separation_queue[separation_index]
        local sprite = sprites.lixos[tipo]
        if sprite then
            love.graphics.setColor(1,1,1)
            local sx = 1.2
            local imgW = sprite:getWidth() * sx
            local imgH = sprite:getHeight() * sx
            love.graphics.draw(sprite, GAME_X_OFFSET + (GAME_WIDTH - imgW)/2, VIRTUAL_HEIGHT/2 - imgH/2, 0, sx, sx)
        else
            love.graphics.setColor(1,1,1)
            love.graphics.printf("Item: " .. tostring(tipo), GAME_X_OFFSET, VIRTUAL_HEIGHT/2 - 20, GAME_WIDTH, "center")
        end
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Use A/D para selecionar o lixeiro e ESPAÇO para descartar no lixeiro correto", GAME_X_OFFSET, VIRTUAL_HEIGHT/2 + 140, GAME_WIDTH, "center")
    else
        love.graphics.setColor(1,1,0)
        love.graphics.printf("Separação concluída! Pressione ESPAÇO para continuar ao caminhão", GAME_X_OFFSET, VIRTUAL_HEIGHT/2, GAME_WIDTH, "center")
    end
end

function attemptAssignCurrent()
    if separation_index > #separation_queue then return end
    local tipo = separation_queue[separation_index]
    local chosen = separation_cursor
    local correct = (getCategoryForTipo(tipo) == chosen)
    if correct then
        local pts = (lixoPoints[tipo] or 0)
        separation_points = separation_points + pts
        score = score + pts -- adiciona pontos imediatamente durante a fase 2
        table.insert(separated_items, tipo)
    end
    separation_index = separation_index + 1
    -- Quando terminar, preparar caminhão
    if separation_index > #separation_queue then
        separation_finished = true
        prepareTruck()
        gameState = "truck"
    end
end

function prepareTruck()
    -- configura obstáculos automáticos ao longo do caminho
    truck.x = GAME_X_OFFSET
    truck.y = VIRTUAL_HEIGHT - 200
    truck.vy = 0
    truck.onGround = true
    truck_dropped = false
    truck_obstacles = {}
    truck.carried_bins = {}
    truck.dropped_items = {}
    -- coloca os itens separados no topo do caminhão com offsets
    local slotW = truck.w / math.max(1, #separated_items)
    for i, tipo in ipairs(separated_items) do
        local off = 10 + (i-1) * slotW
        table.insert(truck.carried_bins, { tipo = tipo, offx = off, offy = -30 })
    end
    -- cria muitos obstáculos ao longo de um caminho longo
    local pathStart = GAME_X_OFFSET + 300
    local pathEnd = truck_destination_x - 200
    local pathLen = pathEnd - pathStart
    local count = 12
    for i = 1, count do
        local t = (i-1) / (count-1)
        local ox = pathStart + t * pathLen + math.random(-50,50)
        local kind = (math.random() < 0.6) and "bump" or "ramp"
        local o = { x = ox, y = VIRTUAL_HEIGHT - 160, w = 80, h = (kind=="bump") and 40 or 80, kind = kind }
        table.insert(truck_obstacles, o)
    end
end

function updateTruck(dt)
    -- movimento automático para a direita; jogador pode pular com espaço (ver love.keypressed)
    truck.x = truck.x + truck.speed * dt
    -- aplicar gravidade
    if not truck.onGround then
        truck.vy = truck.vy + 1200 * dt
        truck.y = truck.y + truck.vy * dt
        if truck.y >= VIRTUAL_HEIGHT - 200 then
            truck.y = VIRTUAL_HEIGHT - 200
            truck.vy = 0
            truck.onGround = true
        end
    end

    -- checar colisões com obstáculos
    for i = #truck_obstacles, 1, -1 do
        local o = truck_obstacles[i]
        if checkOverlap(truck.x, truck.y, truck.w, truck.h, o.x, o.y, o.w, o.h) then
            -- se o caminhão está no chão e colidiu com obstáculo, os bins podem cair
            if truck.onGround then
                -- derrubar alguns ou todos os bins: para simplicidade, derruba todos
                if #truck.carried_bins > 0 then
                    for j = #truck.carried_bins, 1, -1 do
                        local b = truck.carried_bins[j]
                        -- cria item caindo
                        table.insert(truck.dropped_items, { x = truck.x + b.offx, y = truck.y + b.offy, vx = math.random(-80,80), vy = -200, tipo = b.tipo })
                        table.remove(truck.carried_bins, j)
                    end
                    truck_dropped = true
                end
            end
            table.remove(truck_obstacles, i)
        end
    end

    -- atualizar itens caindo
    for i = #truck.dropped_items, 1, -1 do
        local it = truck.dropped_items[i]
        it.vy = it.vy + 1200 * dt
        it.x = it.x + it.vx * dt
        it.y = it.y + it.vy * dt
        if it.y > VIRTUAL_HEIGHT then
            table.remove(truck.dropped_items, i)
        end
    end

    -- chegada
    if truck.x >= truck_destination_x then
        -- Se derrubou algum lixeiro, as pontuações de separação são perdidas
        if truck_dropped then
            -- não adiciona separation_points
        else
            score = score + separation_points
        end
        gameState = "gameover"
    end
end

function drawTruck()
    drawBackground()
    drawScore()
    -- câmera simples: segue o caminhão
    local camX = math.max(0, truck.x - GAME_X_OFFSET - 200)

    -- desenha o chão longo (ou background específico da pista se existir)
    if sprites.truck_background then
        -- desenha o background cobrindo a extensão do caminho
        local bg = sprites.truck_background
        local totalW = truck_destination_x - GAME_X_OFFSET + 400
        local sx = totalW / bg:getWidth()
        local sy = 220 / bg:getHeight()
        love.graphics.setColor(1,1,1)
        love.graphics.draw(bg, GAME_X_OFFSET - camX, VIRTUAL_HEIGHT - 220, 0, sx, sy)
    else
        love.graphics.setColor(0.25,0.25,0.25)
        love.graphics.rectangle("fill", GAME_X_OFFSET - camX, VIRTUAL_HEIGHT - 220, truck_destination_x - GAME_X_OFFSET + 400, 220)
    end

    -- desenha obstáculos (com deslocamento da câmera)
    for i,o in ipairs(truck_obstacles) do
        local sx = o.x - camX
        love.graphics.setColor((o.kind=="bump") and {0.6,0.1,0.1} or {0.2,0.4,0.1})
        love.graphics.rectangle("fill", sx, o.y, o.w, o.h)
    end

    -- desenha o caminhão no mundo convertido para tela
    local tx = truck.x - camX
    love.graphics.setColor(0.2,0.6,0.9)
    love.graphics.rectangle("fill", tx, truck.y, truck.w, truck.h)

    -- desenha os bins empilhados no caminhão (usa o sprite do lixeiro como 'bin' se existir)
    for i,b in ipairs(truck.carried_bins) do
        local bx = tx + b.offx
        local by = truck.y + b.offy
        -- desenha o lixeiro (bin) como recipiente
        if sprites.lixeiro then
            local s = 0.9
            love.graphics.setColor(1,1,1)
            love.graphics.draw(sprites.lixeiro, bx, by - 10, 0, s, s)
        else
            love.graphics.setColor(0.6,0.6,0.6)
            love.graphics.rectangle("fill", bx, by - 10, 36, 48)
        end
        -- desenha o lixo dentro do lixeiro (ícone menor)
        local sprite = sprites.lixos[b.tipo]
        if sprite then
            love.graphics.setColor(1,1,1)
            love.graphics.draw(sprite, bx + 8, by + 6, 0, 0.18, 0.18)
        end
    end

    -- desenha itens caindo
    for i,it in ipairs(truck.dropped_items) do
        local sx = it.x - camX
        local sprite = sprites.lixos[it.tipo]
        if sprite then
            love.graphics.draw(sprite, sx, it.y, 0, 0.25, 0.25)
        else
            love.graphics.setColor(1,0,0)
            love.graphics.rectangle("fill", sx, it.y, 20, 20)
        end
    end

    love.graphics.setColor(1,1,1)
    love.graphics.printf("Caminhão: " .. (truck_dropped and "DERRUBOU ITENS!" or "Seguindo..."), GAME_X_OFFSET, 40, GAME_WIDTH, "center")
    love.graphics.printf("Use ESPAÇO para pular obstáculos e manter os itens no caminhão", GAME_X_OFFSET, 70, GAME_WIDTH, "center")
end
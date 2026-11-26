# 1500

Projeto de game com Godot 4 e modelos produzidos no Blender.

## Moradores — revisão 4 (estilo da referência)

As oito aparências foram refeitas mais próximas da referência estilizada enviada no chat: corpo liso (sem a decimação facetada), braços relaxados junto ao corpo (~9°), variações com escala proporcional (sem cabeça desproporcional), íris maiores e escuras, cabelo rente ao crânio caindo por trás dos ombros (estilos longo, curto, coque, ombros, franja, trança e rabo), saia em duas camadas com ponta diagonal, cinto de corda com nó e top faixa listrado. Fonte e geração: `tools/modelar_moradores_v4.py -- tudo` (usa `tools/variar_moradores_v4.py`), arquivo `art/blender/moradores_1500_v4.blend`; renders em `exports/revisao_moradores_v4/`. Os GLBs mantêm `Passo_E`, `Passo_D` e `Coletar`. Rigs de batalha regenerados por `tools/animar_moradores_batalha.py`, agora com ombro/cotovelo/pulso medidos no modelo. Retratos e miniaturas de menu regenerados. Versões anteriores (GLBs, rigs, retratos e script de rig) em `art/backup_moradores_v3/`.

## Iluminação — ciclo de luz revisado

Ciclo em `scripts/ambientes/iluminacao_diurna.gd`: alvorada rosada com névoa baixa, manhã limpa, meio-dia com sombras azuladas, hora dourada longa (sol baixo até ~18h30, sombras rasantes) e noite enluarada com sombras suaves e fogueira mais forte. Uma luz de contorno fria e sem sombra separa copas, ocas e moradores do chão. A luz aprovada das 16h foi preservada. O ambiente da clareira ganhou luz indireta (SSIL), oclusão mais definida, sombras mais macias, bloom suave e leve ajuste de contraste/saturação; o modo Leve desliga SSIL, SSAO e névoa volumétrica. Comparativo antes/depois em `exports/revisao_iluminacao/`, gerado por `tools/capturar_iluminacao.gd -- <prefixo>` em modo gráfico. Medição: ~72 FPS a 1280×720 em GPU integrada AMD.

## Padrão visual dos menus — casca interna

Todos os menus interativos usam a face clara e fibrosa da casca interna, com borda de casca externa: barra superior, avisos, painel da aldeia (Construir/Comunidade/Mapa/Expedições), mapa regional, expedições, combate, listas suspensas e dicas. Botões são lascas de fibra; o botão principal/ativo é tingido de urucum. Fontes: **Alegreya SC** em títulos e botões, **Alegreya Sans** nos textos.

O tema global está em `assets/ui/casca/tema_casca.tres` (configurado em Projeto → GUI → Tema). Texturas e tema são gerados a partir da arte aprovada `assets/ui/expedicoes/casca_interna_painel.png` por `tools/gerar_tema_casca.gd` (fases `texturas`, importação e `tema`). Atalhos para scripts em `scripts/ui/estilo_casca.gd`. Capturas em `exports/revisao_menus_casca/`, geradas por `tools/capturar_menus_casca.gd` em modo gráfico.

## Etapa 10 — combate manual integrado para teste

**Teste rápido:** abra `scenes/inspecao/combate_manual_etapa_10.tscn` e pressione **F6 no editor**. É uma partida jogável com equipe/expedição reais já preparadas, atributos normais e slots próprios em `user://inspecao_etapa_10`; não altera seus salvamentos da partida principal. Espaço ou **Pular introdução** abrevia a apresentação. A iniciativa define quem começa; a capivara é controlada pelas regras e prioriza fugir. O focinho começa voltado para a equipe. A câmera abre o tabuleiro no primeiro turno humano.

**Na partida F5:** centro de caça pronto → Caçar → equipe → armas → confirmação → **Jogar combate manual · capivara**. Escolha Arredores ou Margem do rio e envie. A preparação/viagem/busca continuam no relógio normal; quando o animal é encontrado, entra o encontro. O modo simulado permanece disponível, inclusive nas demais regiões/espécies.

Na luta, o personagem ativo está indicado nas fichas. **Mover** e clique numa casa verde; **Atacar** e clique no animal dentro do alcance; **Proteger** e clique em aliado adjacente. Mirar, Defender, Fugir e Encerrar turno agem pelos botões. Movimento custa 1 PA por até três passos; um ataque por turno; retirada custa 2 PA e pode falhar. Registro rolável mostra D20, modificadores, defesa e dano/armadura. Vida, PA, iniciativa, ferimentos, XP e carga são os dados reais. Animações articuladas de acerto/erro/impacto/esquiva, armas nas mãos, flecha/corda, câmera de ataque e sinais sonoros curtos acompanham os resultados. As oito aparências dos moradores têm rig e clipes próprios.

**F6/F7 na janela do jogo** salvam/carregam durante a luta, inclusive durante animação. Carregar recupera a ação já resolvida e a apresentação pode repetir a introdução, sem sortear de novo. A aldeia e viagens paralelas ficam congeladas; o botão **Voltar à aldeia** após o resultado restaura a câmera e mantém a pausa/velocidade anteriores. Recursos entram no estoque somente quando a equipe termina a viagem de volta. Derrotados podem sobreviver feridos ou morrer conforme as regras existentes.

Validação: `tests/test_etapa_10.gd`, **159 verificações headless / 163 gráficas, zero falhas**, com cliques reais, carga/salvamento, oito rigs, equipe de uma pessoa/dois arcos, preservação de pausa/velocidade, desfechos e aplicação única das consequências. Capturas em `exports/revisao_etapa_10/`. Cenas principais: `scenes/encontros/combate_manual.tscn`, `scripts/encontros/combate_manual.gd`; integrações em `principal.gd`, `expedicoes.gd`, `estado_partida.gd` e `painel_expedicoes.gd`.

Limite deliberado: apresentação manual somente da **capivara**, o primeiro animal aprovado da etapa 10. Outros animais continuam na simulação; alertas/intervenção da etapa 11 não foram iniciados. Balanceamento permanece provisório e o aceite da entrega depende do teste do responsável.

## Animações de batalha — demonstração visual preservada

Abra `scenes/inspecao/batalha_animacoes_etapa_10.tscn` e pressione **F6** no editor. Os botões ou teclas **1–6** demonstram lança acerta/erra, arco acerta/erra e capivara acerta/erra. **Câmera lenta** reduz a velocidade; **Perto/Visão tática** alternam câmeras; **Repor** ou **R** restauram as poses. **Interface** apresenta a proposta visual de vida/PA e ações táticas; **Ver animações** retorna à demonstração.

Vídeo real de 15 segundos em `exports/revisao_animacoes_batalha/movimentos_batalha.mp4`, com seis sequências capturadas no Godot; a imagem `07_interface_tatica.png` apresenta o painel tático. Essa inspeção antiga continua como demonstração controlada, com números ilustrativos e sem alterar partidas. Para jogar com as regras reais, use o fluxo integrado descrito acima.

As oito aparências receberam rigs articulados em cópias dos modelos aprovados: `assets/models/habitantes/batalha/`, fonte `art/blender/moradores_batalha.blend`. A capivara recebeu clipes novos em `assets/models/animais/batalha/capivara.glb`, fonte `art/blender/capivara_batalha.blend`. Modelos originais da aldeia e da capivara preservados. Conjunto visual autorizado para integração pelo responsável com “Termina então”.

## Apresentação do encontro — etapa 10

Abra `scenes/inspecao/encontro_capivara_etapa_10.tscn` e pressione **F6**. A apresentação começa atrás da dupla, revela a capivara e abre suavemente a câmera para o tabuleiro de **8 × 8**. **1** mostra a revelação; **2/Espaço** abrem a visão tática; **R** repete toda a sequência; **N** alterna tarde/noite. O focinho é orientado para o centro horizontal da equipe antes de revelar o animal, usando a frente real +Z do GLB. Não é uma rotação fixa.

A composição usa os moradores, capivara, mata e armas já aprovados. Nessa inspeção os destaques no chão são demonstrativos; o combate funcional está na seção inicial. A composição e as animações/interface foram autorizadas no chat. Essa inspeção não acessa partidas ou salvamentos. Capturas reais em `exports/revisao_encontro_capivara/`; `tools/revisar_encontro_capivara.gd` passou em 26 verificações headless e 30 gráficas, sem falhas.

## Inspecionar a capivara A — etapa 10

Abra `scenes/inspecao/capivara_etapa_10.tscn` e pressione **F6** no editor. **2** frente, **3** lateral, **4** costas, **5** comparação de escala com um morador, **1** câmera geral. **P** parada, **C** caminhada, **F** corrida, **N** tarde/noite. A inspeção é isolada da partida, sem caça ou salvamento. O modelo e a referência cinematográfica foram aprovados no chat; a composição produzida do encontro está na cena de inspeção descrita acima.

Fonte em `art/blender/capivara.blend`; GLB em `assets/models/animais/capivara.glb`. A pintura por face é preservada pelo pós-importador `scripts/inspecao/importar_capivara.gd`, configurado no arquivo de importação do GLB. Produção reproduzível no Blender por `tools/modelar_capivara.py` e depois `tools/finalizar_capivara.py`. Capturas reais do Godot em `exports/revisao_capivara/`; `tools/revisar_capivara.gd` confere importação, dimensões, cores, rig, pesos, movimentos e câmeras.

## Menu de expedições integrado à partida

Com **F5**, clique em um centro pronto de caça, pesca ou coleta. O menu de casca oferece **Caçar/Pescar/Enviar expedição**, **Acompanhar** e **Gerenciar** (alocação de trabalhadores). Escolha até dois moradores disponíveis → **Seguinte** → equipamento → **Seguinte** → destino e confirmação. Na caça, escolha arco/lança para cada integrante pelas abas com seus nomes. Pesca/coleta usam o equipamento básico existente. No centro de coleta, escolha **Coleta** ou **Reconhecimento** antes de selecionar a equipe. A entrada geral de Expedições também permite escolher o centro.

As fichas usam nomes, retratos, XP, atributos e disponibilidade da partida. Pessoas viajando ou alocadas em outro centro ficam bloqueadas; falecidos não aparecem. Listas maiores têm rolagem. **Acompanhar** mostra fases, carga, XP, condições de combate e retorno/retirada. **Esc** recolhe o painel e, no menu pequeno, fecha; **×** recolhe a tela expandida. F6/F7 na janela continuam salvando/carregando as viagens e armas escolhidas. A integração não muda o balanceamento ou as regras de combate.

Validação: `tests/test_menu_casca_integrado.gd` testa os quatro fluxos na partida com slots exclusivos em `user://testes_menu_casca/`. Capturas gráficas em `exports/revisao_menu_casca_integrado/`. O fonte visual compartilhado fica em `scripts/ui/menu_expedicao_casca.gd`; a inspeção usa sua própria fixture e a partida usa `scripts/partida/painel_expedicoes.gd`.

## Prévia do menu de expedições — casca de árvore

Abra `scenes/inspecao/menu_expedicoes_casca.tscn` e pressione **F6**. O menu contextual pequeno abre a sequência **Equipe → Equipamentos → Confirmar**. Clique em **Caçar**, selecione até duas pessoas, avance e escolha arco/lança por integrante. Voltar preserva as escolhas. **F1/F2/F3** alternam as prévias de caça/pesca/coleta; **1** ou **Esc** recolhem o painel. Pesca e coleta apresentam o equipamento básico do centro, sem novos bônus. Os oito retratos são renderizações dos GLBs reais; os dados pertencem a uma partida de demonstração, com XP ilustrativo. O envio está desativado e não há salvamento nessa cena.

O visual e a tipografia foram aprovados no chat e integrados à partida. Essa cena permanece como inspeção isolada. Capturas em `exports/revisao_menu_casca/`. `tools/revisar_menu_casca.gd` passou em 46 verificações headless e 52 gráficas com cliques reais, sem falhas. Inclui textos e botões na superfície clara, largura dos textos e acentos do português. A textura está em `assets/ui/expedicoes/`; os retratos em `assets/ui/retratos/`, reproduzíveis por `tools/gerar_retratos_moradores.gd` em modo gráfico. A revisão de margens usa Alegreya SC nos títulos/nomes/botões e Alegreya Sans nas informações, com arquivos e licenças OFL em `assets/ui/fonts/`.

## Documento mestre e andamento

O documento mestre é [`docs/GDD_1500.md`](docs/GDD_1500.md), versão 1.4, de 24/11/2026, copiado integralmente do arquivo fornecido pelo responsável. Consulte [`docs/PROGRESSO.md`](docs/PROGRESSO.md) para o estado real da implementação e das aprovações. O roadmap não autoriza executar etapas além da solicitada.

A etapa 4 integra o modelo de oca e a dupla aprovados, mais três variações de cada personagem. O recorte artístico escolhido é Tupinambá do litoral da atual Bahia. A referência visual está em `art/references/referencia_visual_1500.png`.

## Testar os moradores e a aldeia

**Etapa 9 integrada para testes.** Com F5, construa uma oca e **Caça** no menu Construir. O centro custa 25 madeiras e 12 fibras, leva 60 segundos e aceita até dois caçadores. Z/X giram antes de confirmar. Atribua os moradores ao centro e abra **Expedições**: escolha Caça, região investigada, equipe e arco/lança de cada integrante. Confirme e acompanhe viagem, confronto simulado e retorno. A primeira caça oferece capivara nos Arredores ou Margem do rio. Outras regiões investigadas oferecem fauna diferente. Caçadores alocados recebem especialização; moradores sem treinamento têm penalidade. O kit é reservado à viagem, sem fabricação ou itens duplicados no estoque.

A busca e viagem de referência somam 12 minutos a 1×; confronto acrescenta tempo. O painel mostra animal, rodada, HP, eventos e resultado. **Tentar retirada** faz o teste aprovado durante um turno humano com dois PA; pode falhar. Carne e couro só entram no estoque no retorno, respeitando capacidade e validade. Há risco real de ferimentos e mortes. Falecidos deixam de trabalhar, aparecer no mundo e consumir comida; IDs são preservados no histórico. F6/F7 na janela salvam/carregam também o confronto em andamento, sem repetir sorteio ou recompensa. O modo manual da capivara está integrado na etapa 10, descrita no início deste README; demais espécies seguem simuladas.

Para testar regras manualmente, abra `scenes/inspecao/arena_combate_etapa_9.tscn` e pressione **F6 no editor**. É uma arena abstrata de debug: 1/2 representam a equipe e A, o animal. Escolha espécie e semente, clique em destino/alvo no tabuleiro e use as ações. **Uma ação automática** executa a política sobre o mesmo motor; **Resolver automaticamente** termina a luta. Salvar/carregar nessa cena usa `user://arena_etapa_9/`, separado da partida. Pode-se comandar também o turno do animal para testes; use a ação automática se quiser que a política o controle. O tabuleiro não representa a arte final do RPG. Parâmetros provisórios em `assets/configuracoes/combate.json`.

A inspeção isolada do modelo permanece em `scenes/inspecao/centro_caca_etapa_9.tscn`. F6 no editor executa; na janela, 1 câmera normal, 2 frente, 3 lateral, 4 costas, 5 equipamentos e N dia/noite. Fonte em `art/blender/centro_caca_nivel_1.blend`, GLB em `assets/models/centro_caca_nivel_1.glb`. Capturas da integração em `exports/revisao_etapa_9_final/`.

Etapa 8 integrada após aprovação dos modelos A1/P1, com melhorias solicitadas de plantio modular e rotação. Com F5, construa a primeira oca e depois **Roça** e **Pesca** em Construir. Antes de confirmar qualquer construção, use **Z/X** ou os botões de giro para rotacionar em passos de 15°. A prévia e a validação consideram a orientação, que permanece no salvamento. A pesca precisa ficar em terra, a até dois metros da margem real do rio, sem avançar sobre a água.

O novo abrigo agrícola começa sem plantações. Clique nele e use **Preparar terrenos** em uma das duas áreas. Cada clique válido cria um quadrado de **1 × 1 m vazio**; quadrados vizinhos se encaixam. Continue para expandir e encerre com **Esc** ou botão direito. Depois clique num quadrado ou **clique e arraste** para selecionar vários, destacados em dourado. Escolha **Plantar milho** ou **Plantar mandioca** no painel inferior. A escolha afeta somente os terrenos selecionados. **Limpar seleção** ou Esc encerra a seleção. Não há custo material adicional por célula. As células devem ficar em terra livre, sem ocupar construções, pedras, fogueira ou outra célula, a até 14 metros do abrigo.

Atribua até dois agricultores, um por área. Terrenos vazios não crescem nem consomem trabalho. Após escolher o cultivo, cada planta cresce, colhe e replanta automaticamente, com seu próprio progresso. Mudar o cultivo de uma seleção programa a próxima safra das plantas já iniciadas; terrenos vazios e plantas ainda sem progresso recebem a cultura escolhida imediatamente. Sem agricultor o crescimento para. Um agricultor trabalha seis milhos ou nove mandiocas simultâneos no tempo base; áreas maiores dividem seu trabalho e levam mais tempo. Partidas anteriores preservam seus talhões e células já plantadas e podem acrescentar terrenos vazios sem perder a safra em andamento. Clique na pesca, abra Expedições e envie até dois moradores para uma região investigada com peixes. É preciso enviar cada viagem manualmente.

**Comunidade** mostra consumo, reserva estimada, dieta e perdas. Os dois primeiros adultos consomem quatro alimentos/dia. Há oito vegetais iniciais e capacidade compartilhada de 24 alimentos; vegetais duram quatro dias e peixes dois. Seis células de milho equivalem à área original: seis unidades/18 minutos; nove de mandioca: onze/28 minutos, com agricultor iniciante a 1×. Frações de rendimento e XP são acumuladas por área. Habilidade aumenta o rendimento até +30%. Os tempos avançam em 2×/3× e param com a pausa. Os detalhes de custos, XP e limiares são provisórios para balanceamento em testes, em `assets/configuracoes/alimentacao.json` e `scripts/partida/aldeia.gd`.

A cena `scenes/inspecao/agricultura_pesca_etapa_8.tscn` preserva a revisão visual isolada. Abra e pressione F6. Use 2 para a roça, 3 para pesca, 4 para as costas, Z/X/C para os estágios das plantas, N para dia/noite e 1 para a câmera geral. Capturas da integração real ficam em `exports/revisao_etapa_8_final/`.

- **Expedições** no menu inferior, na Comunidade, no mapa ou no painel de um centro de coleta abre o fluxo real da etapa 7. Escolha centro, Coleta ou Reconhecimento, região e até dois moradores disponíveis. Confirme o envio e consulte **Acompanhar**. Esc fecha o painel. Cada centro nível 1 permite uma equipe simultânea.
- Na janela do jogo, **F6** salva e **F7** carrega também viagens em andamento. O reconhecimento amplia as informações do mapa. A carga da coleta entra no estoque ao retornar, com excedente preservado até haver espaço.

- **M** ou **Mapa** abre o mapa regional da partida. Use roda para zoom, arraste/WASD para deslocar e R para recentrar. M/Esc retornam à aldeia. Informações descobertas entram no salvamento.
- A proposta visual aprovada está preservada em `scenes/inspecao/expedicoes_etapa_7.tscn`. Para usar expedições reais, execute a partida com F5.

Para avaliar o mapa regional ampliado da etapa 6, abra `scenes/inspecao/mapa_regional.tscn` e pressione F6. Use roda para zoom, arraste esquerdo/meio ou WASD para mover, R para recentrar e V para inspecionar a arte completa. Essa prévia visual usa informações ilustrativas e aguarda aprovação no chat. As capturas ficam em `exports/revisao_mapa_regional/`.

- A interface da etapa 5 reúne recursos, população e relógio na barra superior. Os ícones têm dicas ao passar o mouse. Os botões de pausa e velocidade controlam a partida. **UI** alterna a escala, **H** oculta/restaura e **Esc** recolhe o painel inferior. Abra **Construir** ou **Comunidade** para gerenciar a aldeia.
- **F5** inicia a aldeia. Selecione a fogueira, escolha a oca e clique quando a prévia estiver verde. Esc cancela. A primeira obra leva 18 segundos a 1x e recebe dois adultos. As seguintes precisam de uma pessoa livre.
- Na fogueira, construa o centro de coleta. Clique nele ou abra **Comunidade** e use o botão do setor junto ao nome do morador. **Liberar** encerra a alocação. Clique no nome para ver a ficha. A cada 60 segundos de trabalho há materiais e experiência; o vegetal ocasional ocorre a cada 20 ciclos. A coleta foi rebalanceada na etapa 8 para preservar a escassez alimentar.
- Quatro ocas completas apresentam as oito aparências. Para vê-las imediatamente, abra `scenes/inspecao/moradores_etapa_4.tscn` e pressione **F6**. Use 1 para a vista geral, 2 para a frente, 3 para as costas, C para caminhada, T para trabalho e P para a pose parada.
- O fonte editável é `art/blender/familia_moradores.blend`. As capturas em jogo estão em `exports/revisao_variacoes/`.

## Inspecionar a primeira oca — ETAPA 3

Abra `scenes/inspecao/oca_nivel_1.tscn` no Godot e pressione **F6** para executar essa cena. Com a janela focada: **1** mostra a câmera geral do jogo; **2**, a frente; **3**, a lateral; **4**, as costas. **N** alterna entre tarde e noite. No enquadramento 1, use WASD, roda do mouse, botão central com arraste, Q/E e R. F8 encerra o teste.

Essa cena apresenta o modelo junto à fogueira e à vegetação existentes para aprovação visual. A partida normal, executada com F5, conserva o início sem casas. O modelo editável está em `art/blender/oca_nivel_1.blend`, o exportado em `assets/models/oca_nivel_1.glb` e a cena reutilizável em `scenes/construcoes/oca_nivel_1.tscn`. Capturas reais do Godot estão em `exports/revisao_oca_nivel_1/`.

## Abrir e executar

Importe `project.godot` no Godot e pressione F5. A cena começa no dia 1, às 16h, com a fogueira nível 1, zero habitantes e o estoque provisório. Um dia dura 10 minutos reais a 1x. A barra superior e o painel inferior mostram os dados reais da partida.

Para inspecionar detalhes, abra `scenes/main.tscn`, selecione o nó `Clareira1500` e altere **Enquadramento Inicial** no Inspector para **Geral**, **Fogueira** ou **Rio**. Execute novamente com F5. **Qualidade De Inspecao** permite comparar **Completa** e **Leve**; a versão leve mantém o Forward+, a paleta e o sol, mas desativa a névoa volumétrica e a oclusão ambiente e usa sombras mais firmes. F8 encerra o teste. São configurações de inspeção, não o menu definitivo do jogo.

Com a janela do jogo focada:

| Controle | Ação |
|---|---|
| WASD | Deslocar câmera |
| Roda do mouse | Aproximar/afastar |
| Botão central + arraste | Deslocar câmera |
| Q / E | Rotacionar |
| Z / X durante posicionamento | Girar construção em passos de 15° |
| Esc / botão direito durante posicionamento | Encerrar construção ou plantio repetido |
| R | Voltar ao enquadramento principal |
| Espaço | Pausar/retomar o mundo, mantendo a câmera disponível |
| 1 / 2 / 3 | Velocidades 1x / 2x / 3x, sem retirar a pausa |
| F6 | Salvar manualmente |
| F7 | Carregar o salvamento manual |
| Shift + F7 | Carregar o salvamento automático |
| Ctrl + N | Nova partida independente; conserva o slot manual anterior até uma nova gravação manual |
| F9 | Imprimir dia, horário, velocidade e estado no painel Saída, somente em debug |

Para verificar persistência: pause com Espaço, salve com F6, pare com F8, execute novamente com F5 e carregue com F7. Horário, pausa, velocidade, estoque, fogueira e câmera serão recuperados. Cada execução começa uma nova partida até haver um menu de continuar; o carregamento é explícito nesta etapa. Em 3x, partindo das 16h, a cena fica noturna em cerca de 30 segundos.

## Salvamento local

Arquivos em `user://partidas/` (neste Windows: `%APPDATA%/Godot/app_userdata/1500/partidas/`). Não há dependência de banco de dados ou servidor. Os slots `manual.json` e `automatico.json` são independentes. Autosave a cada 60 segundos de tempo a 1x, na mudança de dia e no fechamento normal pela janela; em 3x o intervalo corresponde a 20 segundos reais. Pausar interrompe o intervalo. F8 é uma interrupção do editor: use F6 antes dele para garantir o ponto desejado.

Formato JSON versão 1, validado antes de carregar, com temporário validado antes da substituição do arquivo e backup `.bak` da gravação anterior saudável. Arquivo ausente, inválido ou de versão incompatível informa falha na Saída sem trocar a partida em memória. Ironman tem somente o contrato de dados reservado; sua seleção, regras e interface permanecem na etapa 23.

`assets/configuracoes/partida_inicial.tres` usa `scripts/partida/configuracao_partida.gd` para centralizar duração do dia, hora inicial, intervalo de autosave e estoque provisório.

## Verificações

- `tests/test_etapa_9.gd`: regras de D20, crítico, armadura, PA, iniciativa, movimento, obstáculos, proteção, retirada, incapacitação, sobrevivência, morte, XP, recompensa única, salvamento e equivalência manual/automático. Cem cenários controlados (20 sementes por espécie). `--headless --script res://tests/test_etapa_9.gd`.
- `tests/test_interface_etapa_9.gd`: construção real do centro, equipe e equipamentos, envio, acompanhamento, salvamento em combate, retorno e arena. Sem `--headless`, faz cliques reais e salva capturas em `exports/revisao_etapa_9_final/`.

- `tests/test_selecao_plantio.gd` verifica terreno preparado vazio, ausência de crescimento automático, seleção individual e por retângulo nos dois sentidos, cultivo só na seleção, culturas diferentes na mesma área, safra preservada e salvamento. Executar com `--headless --script res://tests/test_selecao_plantio.gd`; sem `--headless`, exercita cliques, arraste e botões reais e captura `exports/revisao_selecao_plantio/`.

- `tests/test_construcao_modular.gd` verifica grade, uma planta por célula, crescimento individual, expansão, sobreposições, trabalho compartilhado, conservação da safra, rotação de todos os tipos, seleção, proximidade da água e comparação com a malha real do rio, migração e salvamento. Executar com `--headless --script res://tests/test_construcao_modular.gd`; sem `--headless`, testa atalhos e cliques reais e salva capturas em `exports/revisao_construcao_modular/`.

- `tests/test_etapa_8.gd` cobre produção, XP, dois cultivos, troca de safra, consumo proporcional, falta e recuperação, validade, capacidade, excedentes, diversidade vegetal, migração, persistência, passos de tempo, pausa, velocidade e interface. Executar com `--headless --script res://tests/test_etapa_8.gd`; sem `--headless`, verifica o clique real de envio da pesca e gera capturas em `exports/revisao_etapa_8_final/`.

- `tests/test_interface_etapa_7.gd` verifica o fluxo real por botões, equipe, destino, acompanhamento, retorno, descobertas e carregamento. A execução gráfica gera capturas em `exports/revisao_etapa_7_final/`.

- `tests/test_etapas_6_7.gd` verifica conhecimento regional, conexões, tabelas, motor de dados das expedições, disponibilidade, persistência, cancelamento e descarga de excedente. Executar com `--headless --script res://tests/test_etapas_6_7.gd`.

- `tests/test_etapa_5.gd` verifica o HUD, tempo, alocação, escala, resoluções e eventos do mouse. Executar com `--script res://tests/test_etapa_5.gd` para teste gráfico com capturas em `exports/revisao_etapa_5/`. Também aceita `--headless`.

- `tests/test_etapa_4.gd` cobre a construção fundadora, obras normais, oito modelos, alocação, XP, lotação e salvamento. Execute com `--headless --script res://tests/test_etapa_4.gd`. A execução gráfica aceita `-- --capturas`.
- `tests/test_etapa_2.gd`: relógio independente de FPS, pausa, atalhos, estado, arquivos, backup, falhas, autosave, iluminação e controles. Executar com `--headless --script res://tests/test_etapa_2.gd`; o teste de GUI requer a execução gráfica do mesmo script, sem `--headless`.
- `tests/test_persistencia.gd`: executar em dois processos separados, primeiro com `-- --gravar`, depois sem o argumento.
- Testes usam pastas exclusivas em `user://testes_etapa_2/`, sem tocar nos slots reais.
- `tools/revisar_etapa_2.gd`: capturas gráficas da partida real em horários e enquadramentos diferentes, em `exports/revisao_etapa_2/`.

## Organização

- `scenes/`: cenas do jogo; entrada em `main.tscn`.
- `scenes/ambientes/clareira.tscn`: composição editável da ETAPA 1.
- `scripts/`: scripts GDScript.
- `scripts/partida/`: estado, relógio, salvamento e coordenação da partida.
- `scripts/camera/`: navegação e limites da câmera.
- `assets/models/`: modelos exportados em GLB para o Godot.
- `assets/materials/`, `assets/textures/`, `assets/audio/`, `assets/ui/`: recursos do jogo.
- `art/blender/`: arquivos-fonte `.blend`.
- `art/references/`: referências de arte.
- `docs/`: decisões de projeto e documentação.
- `exports/`: builds locais, ignorados pelo Git.
- `tools/`: scripts de produção no Blender, montagem da cena e captura/medição no Godot.

## Fluxo Blender → Godot

Salve os originais em `art/blender/` e exporte os modelos para `assets/models/` em glTF 2.0 binário (`.glb`). A pasta `art/` tem `.gdignore` para manter arquivos-fonte fora da importação e do jogo.

Use metros como referência (1 unidade = 1 metro), nomes descritivos em `snake_case` para os arquivos e confira escala, orientação, materiais e animações após importar. O formato GLB evita que o jogo dependa do Blender instalado para importar os modelos.

## Base técnica

Godot 4.7.2, Forward+ (Vulkan), janela de referência 1280 × 720 e suavização temporal. A anatomia dos moradores usa as Human Base Meshes do Blender Studio, sob CC0. Cabelos, roupas e adaptações de silhueta foram produzidos para o projeto. Fontes no Blender 5.2.2 LTS, exportadas em GLB. Shaders do Godot cuidam de água, solo, vento, chama e raios solares estilizados; o ambiente usa névoa volumétrica, luz solar com sombras e luz local da fogueira. A vegetação é uma interpretação artística, não uma identificação botânica nem uma alegação de fidelidade cultural.

Capturas e logs de avaliação estão em `exports/revisao_etapa_1/`. A medição interna usa 120 frames de aquecimento e 180 de amostragem, sem VSync. Os resultados desta cena não são uma promessa de desempenho para o jogo completo.

O Git já está inicializado. Caches, backups do Blender e builds não são versionados; fontes `.blend`, recursos e arquivos Godot `.uid` devem ser preservados.

# Árvore realista procedural

## Objetivo

Adicionar uma árvore decorativa e realista ao `Workspace`, gerada por script quando o servidor iniciar e sincronizada pelo Rojo.

## Arquitetura

O arquivo `src/Workspace/RealisticTree.server.lua` será um `Script` do servidor. Ele criará um `Model` chamado `RealisticTree` em `Workspace`.

O modelo terá:

- tronco formado por cilindros marrons, cada um menor que o anterior;
- galhos inclinados que partem da região superior do tronco;
- copa formada por partes esféricas verdes com pequenas variações de escala e cor;
- uma base circular de grama sob o tronco.

Todas as partes serão ancoradas e sem colisão. Antes de criar o modelo, o script removerá somente o modelo pré-existente com o mesmo nome, evitando duplicatas em execuções repetidas.

## Fluxo

1. O servidor executa o script.
2. O script remove uma árvore `RealisticTree` anterior, caso exista.
3. Cria tronco, galhos, copa e base no novo modelo.
4. Posiciona o modelo próximo à origem do mapa.

## Falhas e verificação

- O script usa somente APIs nativas do Roblox e não depende de rede ou assets externos.
- A verificação automatizada será `rojo build default.project.json -o build.rbxlx`.
- No Studio, a verificação manual é confirmar que há exatamente uma árvore no `Workspace`, com as peças ancoradas.

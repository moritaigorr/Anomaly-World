# Anomaly-World
## Anomaly World

Este projeto usa [Rojo 7](https://rojo.space/docs/v7/) para sincronizar os arquivos locais com o Roblox Studio.

### Estrutura

- `src/ReplicatedStorage` — módulos e recursos compartilhados.
- `src/ServerScriptService` — scripts do servidor (`*.server.lua`).
- `src/ServerStorage` — recursos somente do servidor.
- `src/StarterGui` — interfaces.
- `src/StarterPlayer/StarterPlayerScripts` — scripts do cliente (`*.client.lua`).
- `src/StarterPlayer/StarterCharacterScripts` — scripts ligados ao personagem.
- `src/Workspace` — conteúdo do mundo sincronizado pelo Rojo.

### Uso

1. Instale o [Rojo CLI e o plugin do Roblox Studio](https://rojo.space/docs/v7/getting-started/installation/).
2. Na raiz deste repositório, execute `rojo serve`.
3. No Roblox Studio, abra o plugin Rojo e conecte-se ao servidor local mostrado pelo comando.

Para gerar um arquivo de lugar, execute `rojo build -o build.rbxlx`.

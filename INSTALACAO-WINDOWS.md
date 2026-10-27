# Habblaud local no Windows

Projeto oficial: https://github.com/marmottajr/habblaud (versão 1.0.3).
Requer Docker Desktop em execução, Node 22.12+ e Codex no PATH do Windows.
Execute os comandos nesta pasta em PowerShell.

## Instalar ou refazer a configuração

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\habblaud.ps1 -Action Install
```

O instalador configura os hooks com backup, gera as montagens do Docker, compila a imagem
e registra o auxiliar de mensagens como tarefa do usuário `Habblaud-Codex-Bridge`, iniciada
no login. O auxiliar usa o Codex instalado no Windows. Não mova esta pasta sem reinstalar.
Se mudar a instalação do Node ou Codex, execute Install novamente.

Abra http://localhost:4747. O serviço só publica a porta na interface local (127.0.0.1).
As sessões do Codex são montadas somente para leitura; auth.json e config.toml não entram
no container. O Compose também detecta as sessões locais do Claude, se existirem.

**Após instalar:** reinicie o Codex, abra `/hooks` no CLI e revise/aprove os nove hooks do
Habblaud. O instalador não concede essa confiança por você. No terminal, execute `codex`
para abrir o CLI. A documentação oficial está em https://learn.chatgpt.com/docs/hooks.

Use este instalador Windows para reinstalar os hooks: o `npm run codex:install` original
gera aspas de shell Unix para os caminhos nativos desta máquina.

## Operação

```powershell
.\habblaud.ps1 -Action Start   # constrói/sobe o container e inicia o auxiliar
.\habblaud.ps1 -Action Status  # container, hooks e auxiliar
.\habblaud.ps1 -Action Logs    # logs do container; Ctrl+C sai
.\habblaud.ps1 -Action Stop    # para o auxiliar e remove o container, preservando dados
```

Se sua política bloquear scripts, use `powershell -NoProfile -ExecutionPolicy Bypass -File`
antes de `.\habblaud.ps1`, como no comando de instalação. Não é preciso alterar a política global.

O container usa `restart: unless-stopped`; volta quando o Docker iniciar, a menos que tenha
sido parado manualmente. Para voltar após reiniciar a máquina, habilite nas configurações do
Docker Desktop a opção de iniciar ao fazer login. O auxiliar aguarda o Docker ficar disponível.
Os dados do escritório ficam no volume `habblaud_habblaud-data`; os logs do auxiliar em
`.local/bridge.log`. Não use `docker compose down -v` se quiser preservar os dados.

## Desfazer a integração

```powershell
.\habblaud.ps1 -Action Stop
.\habblaud.ps1 -Action RemoveStartup
npm run codex:uninstall
```

Isso não apaga sessões do Codex nem o volume do escritório. Outros hooks são preservados.

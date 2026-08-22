# Handoff: Pesquisa de isolamento/sandboxing para múltiplos agentes de IA

**Created:** 2026-07-31 00:03
**Branch:** clean-main
**Status:** paused (pesquisa concluída, nenhuma decisão de implementação tomada ainda)

## Goal

O usuário roda 4-5 agentes de IA (Claude Code, Codex, OpenCode) simultaneamente em projetos diferentes e quer permitir execução autônoma de comandos (auto-approve/bypass permissions) sem expor a máquina host a risco — nem destruição de arquivos, nem exfiltração de credenciais. Sessão foi de pesquisa/comparação de ferramentas, sem implementação.

## What was done

Discussão em 3 etapas, nenhuma envolveu mudança de código:

1. **Daytona** (managed sandbox-as-a-service): avaliado como opção de isolamento de execução. Achado importante via WebSearch: ainda tem self-hosted (AGPL-3.0), mas desde junho/2026 o desenvolvimento principal migrou para repo privado — a versão pública no GitHub não recebe mais updates/fixes/releases, fica "as is" sem suporte. Relevante porque o caso de uso do usuário depende de segurança mantida ativamente.

2. **Alternativas ao Daytona**: mapeadas em duas categorias.
   - Managed: E2B (mais próximo do Daytona, foco em agentes de IA, mantido ativamente), Modal, Fly Machines, Anthropic Managed Agents/code execution.
   - Self-host: Docker puro (`docker run --rm --network none/allowlist`), Docker Compose, Devcontainers, Firecracker microVMs, VMs efêmeras em cloud própria.
   - Recomendação dada: testar Docker puro antes de adotar ferramenta paga, dado que resolve ~90% do ganho sem custo recorrente.

3. **aicontainer** (https://github.com/stefanoginella/aicontainer): ferramenta específica trazida pelo usuário, avaliada via WebFetch do README. Automatiza devcontainers sandboxed para Claude Code, Codex e OpenCode rodando em modo auto-approve/bypass. Cobre exatamente as lacunas identificadas nas opções anteriores:
   - Bloqueia leitura de `.env` e padrões fetch-and-execute via hook `PreToolUse`.
   - Bloqueia endpoints de cloud metadata (169.254.0.0/16, IMDS).
   - `NPM_CONFIG_IGNORE_SCRIPTS=true` (mitiga RCE via postinstall malicioso).
   - Shell configs (`.zshrc`/`.bashrc`/fish) geridos por root, agente não pode alterar.
   - Credenciais isoladas por projeto via named volumes.
   - Ponto de atenção: rede é **aberta por padrão** — isolamento de rede real (proteção contra exfiltração) só ativa se o usuário configurar o allowlist de iptables explicitamente.

4. **`/sandbox` do Claude Code vs aicontainer**: esclarecido que não são alternativas, são camadas complementares.
   - `/sandbox`: OS-level sandboxing do processo Bash (Seatbelt no macOS, bubblewrap/socat no Linux), restringe arquivos/domínios por comando, mas roda direto no host — não isola outros agentes (Codex, OpenCode) nem filesystem completo.
   - aicontainer: container-level isolation (Docker), cobre múltiplos agentes e exfiltração de credencial.
   - Recomendação dada: usar os dois juntos — aicontainer como isolamento estrutural primário, `/sandbox` ativado dentro do container via `.claude/settings.json` (chave `sandbox`, commitável) como defesa em profundidade adicional.

5. **nono (nono.sh, github.com/nolabs-ai/nono)**: trazido pelo usuário para comparar com aicontainer. Avaliado via WebSearch + WebFetch (docs.nono.sh redireciona para nono.sh/docs; detalhe técnico real está em nono.sh/docs/llms.txt). Diferença arquitetural chave: **não usa containers** — aplica isolamento via LSM do kernel diretamente no processo (Landlock no Linux, Seatbelt no macOS), sem overhead de Docker.
   - Filesystem: allow-list explícita via Landlock LSM.
   - Rede: domain filtering + **proxy com injeção de credencial** — o processo sandboxed nunca vê o segredo real, só um "phantom token" que o proxy resolve (OAuth flows, SPIFFE/SPIRE workload identity para outbound auth). Isso é mais forte que a abordagem do aicontainer, que sanitiza config mas ainda expõe credencial real quando o agente precisa autenticar de fato.
   - Credenciais: integra com keystore do sistema, 1Password, Bitwarden, Apple Passwords, arquivos ou env vars.
   - Rollback: snapshots de filesystem content-addressable com verificação de integridade (sem precisar reconstruir container).
   - Suporta mais agentes que aicontainer: Claude Code, Codex, Pi, Copilot, Hermes, OpenCode e outros.
   - Plataformas: Linux (Landlock) e macOS (Seatbelt) nativos; Windows só via wrapper WSL2.
   - Maturidade/backing: projeto da nolabs (cofundada por Luke Hinds, com histórico em Sigstore/Red Hat), 3.100+ stars, 80+ contribuidores, adoção citada em regulated industries — pesa mais que aicontainer (projeto individual) dado que o produto é literalmente segurança.
   - Ressalva importante: os próprios docs do nono dizem que "nono e containers se complementam" — Landlock restringe o processo mas roda no mesmo kernel do host; não é isolamento de kernel completo como um container/VM. Um exploit de kernel contorna Landlock; não contorna tão facilmente um namespace separado.
   - **Recomendação atualizada**: testar nono primeiro. Ataca mais diretamente o medo central do usuário (autonomia sem vazar credencial) via injeção de credencial no proxy, é mais leve (sem daemon Docker, sem overhead de container para 4-5 agentes simultâneos), suporta mais ferramentas, e tem backing técnico mais robusto que aicontainer. Guardar aicontainer como opção se depois of testar o usuário sentir necessidade de isolamento de kernel completo (não só do processo).

## Current state

- Nenhuma mudança de código nesta sessão.
- O working tree do repo dotfiles tem modificações pré-existentes e não relacionadas (`.gitignore`, `Makefile` modificados; vários arquivos novos não rastreados: skills, agents, backgrounds, scripts) — não tocados nesta conversa, provavelmente de trabalho anterior do usuário. Não assumir que pertencem a este handoff.
- Nem `aicontainer` nem `nono` foram instalados ou testados ainda. Próximo passo é testar **nono** primeiro (decisão do usuário ao pedir esta atualização do handoff).

## Key decisions

- Nenhuma decisão final tomada sobre qual ferramenta adotar em produção. A pesquisa convergiu para testar **nono primeiro**, com aicontainer como plano B se o usuário precisar de isolamento de kernel completo (container/VM) em vez de isolamento de processo (Landlock/Seatbelt).
- Daytona self-hosted foi descartado como primeira escolha pela falta de manutenção ativa do repo público desde jun/2026 — risco de segurança não corrigido em ferramenta cuja função é justamente segurança.
- aicontainer foi reavaliado de "candidata principal" para "plano B" depois de comparar com nono — nono cobre melhor o requisito central (exfiltração de credencial via injeção de proxy) e tem menos overhead (sem Docker).

## What's next

1. Instalar nono e rodar `nono` (ou comando equivalente do CLI — conferir docs em nono.sh/docs para o comando exato de instalação, não foi extraído nesta sessão).
2. Configurar Claude Code para rodar dentro do sandbox do nono num projeto de teste (não em dotfiles — usar um projeto de código real).
3. Validar isolamento de filesystem (Landlock allow-list) e de rede (domain filtering) na prática — confirmar que `.env`/SSH/credenciais reais não vazam para o processo sandboxed.
4. Testar o fluxo de injeção de credencial via proxy (phantom tokens) com uma autenticação real (ex: GitHub) para confirmar que o agente consegue operar sem ver o token de verdade.
5. Se nono se provar sólido, expandir para os outros agentes (Codex, OpenCode) e escalar de 1 para os 4-5 simultâneos.
6. Se nono tiver limitação bloqueante (ex: precisa de isolamento de kernel completo), cair para o plano B: instalar aicontainer (`npm install -g aicontainer`, requer Docker Engine 25+/Compose 2.24+/Node 18+) e configurar allowlist de rede via iptables (rede é aberta por padrão nessa ferramenta).

## Blockers / Open questions

- Comando exato de instalação/uso do nono não foi extraído nesta sessão (a página `nono.sh/docs/llms.txt` deu visão arquitetural mas não um "getting started" passo a passo) — primeira coisa a checar na próxima sessão.
- Nenhuma ambiguidade de requisito — só falta validação prática.

## How to continue

1. Ler este handoff.
2. Acessar https://nono.sh/docs (ou o índice completo em https://nono.sh/docs/llms.txt) para extrair o passo a passo de instalação/setup do CLI.
3. Instalar nono e testar num projeto de código real com Claude Code.
4. Seguir os passos em "What's next" em ordem.
5. Se nono não for viável, seguir o plano B (aicontainer) — passos preservados na seção acima.

## Key files

Nenhum arquivo de código foi criado ou modificado nesta sessão — é puramente pesquisa/decisão. Referências externas relevantes:
- https://nono.sh/ e https://nono.sh/docs — ferramenta a testar primeiro
- https://github.com/nolabs-ai/nono — repo oficial
- https://github.com/stefanoginella/aicontainer — plano B, avaliada anteriormente
- https://github.com/daytonaio/daytona — self-hosted mas sem manutenção ativa desde jun/2026
- https://code.claude.com/docs/en/sandboxing — docs oficiais do `/sandbox` (camada complementar, independente de qual sandbox estrutural for escolhido)

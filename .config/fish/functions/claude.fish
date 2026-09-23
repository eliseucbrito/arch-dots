function claude
    set sandbox 0
    set rest_argv
    for arg in $argv
        if test "$arg" = --sandbox
            set sandbox 1
        else
            set rest_argv $rest_argv $arg
        end
    end
    set argv $rest_argv

    set accounts_file "$HOME/.config/claude/accounts"

    if not test -f $accounts_file
        echo "Arquivo de contas não encontrado: $accounts_file"
        echo "Crie o arquivo com um nome de conta por linha."
        return 1
    end

    set accounts (grep -v '^\s*#' $accounts_file | grep -v '^\s*$')

    if test (count $accounts) -eq 0
        echo "Nenhuma conta configurada em $accounts_file"
        return 1
    end

    # # Use specified account directly if first argument is a valid account number
    # if test (count $argv) -ge 1
    #     set first_arg $argv[1]
    #     if string match -q '^\d+$' -- $first_arg
    #         and test $first_arg -ge 1
    #         and test $first_arg -le (count $accounts)
    #             # Use specified account directly
    #             set name $accounts[$first_arg]
    #             set dir_name (string lower $name | string replace -a ' ' '-')
    #             set -x CLAUDE_CONFIG_DIR "$HOME/.claude-$dir_name"
    #
    #             if test $sandbox -eq 1
    #                 nono run --silent --profile claude-multi --allow . -- /usr/bin/claude $argv
    #             else
    #                 /usr/bin/claude $argv
    #             end
    #             return 0
    #         end
    #     end
    # end

    echo ""
    echo "Selecione a conta Claude:"
    for i in (seq (count $accounts))
        echo "  $i) $accounts[$i]"
    end
    echo ""

    set total (count $accounts)
    read -P "Conta [1-$total]: " choice

    if not string match -qr '^\d+$' -- $choice
        or test $choice -lt 1
        or test $choice -gt $total
        echo "Opção inválida."
        return 1
    end

    set name $accounts[$choice]
    set dir_name (string lower $name | string replace -a ' ' '-')
    set -x CLAUDE_CONFIG_DIR "$HOME/.claude-$dir_name"

    if test $sandbox -eq 1
        # run (não wrap): mantém o supervisor nono vivo, necessário para o
        # proxy de credenciais gh/glab (esconde o token do agente). wrap faz
        # exec e some, mas não suporta --credential.
        # --silent: suprime o banner de capacidades e o hint de registry.
        set nono_args --silent --profile claude-multi --allow .

        # Marca a sessão para o segmento SANDBOX da statusline (nono herda o env).
        set -x NONO_SANDBOX_ACTIVE on

        # Dentro do herdr: instala o hook de integração no CLAUDE_CONFIG_DIR da
        # conta e libera o socket do herdr para o sandbox, senão o hook de
        # SessionStart não consegue reportar a sessão.
        if test "$HERDR_ENV" = 1; and test -n "$HERDR_SOCKET_PATH"
            test -f "$CLAUDE_CONFIG_DIR/hooks/herdr-agent-state.sh"
            or herdr integration install claude >/dev/null 2>&1
            set nono_args $nono_args --allow-unix-socket "$HERDR_SOCKET_PATH"

            # O herdr identifica o agente pelos processos do process group em
            # foreground do pane. `nono run` roda o claude num PTY proprio, entao
            # o herdr so enxerga `nono` e nunca registra o agente: sem status na
            # barra lateral e sem notificacoes. Renomear o argv[0] do supervisor
            # para `claude` faz a deteccao passar sem trocar run por wrap (wrap
            # nao suporta --credential, que o profile claude-multi usa para o
            # proxy de token gh/glab).
            bash -c 'exec -a claude "$@"' bash nono run $nono_args -- /usr/bin/claude $argv
            return $status
        end

        nono run $nono_args -- /usr/bin/claude $argv
    else
        /usr/bin/claude $argv
    end
end

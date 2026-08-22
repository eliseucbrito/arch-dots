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
    #                 nono run --profile claude-multi --allow . -- /usr/bin/claude $argv
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
        nono run --profile claude-multi --allow . -- /usr/bin/claude $argv
    else
        /usr/bin/claude $argv
    end
end

# Bash completion for manage.py
_manage_py_completions()
{
    local cur prev opts infra_dirs tofu_cmds
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    infra_dirs=""
    tofu_cmds="init plan apply destroy output refresh validate taint untaint show"

    case $COMP_CWORD in
        1)
            COMPREPLY=( $(compgen -W "${infra_dirs}" -- ${cur}) )
            ;;
        2)
            COMPREPLY=( $(compgen -W "${tofu_cmds}" -- ${cur}) )
            ;;
    esac
}

complete -F _manage_py_completions manage.py

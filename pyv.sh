#!/bin/sh
# -*- mode: sh -*-

PYV_DIR="${PYV_DIR:-${HOME_ALT:+$HOME_ALT/local/pyv}}"
PYV_DIR="${PYV_DIR:-$HOME/local/pyv}"
PYV_DISTS_DIR="$PYV_DIR/distributions"
PYV_REPOS_DIR="$PYV_DIR/repositories"
PYV_VENVS_DIR="$PYV_DIR/venvs"
PYV_DIST_DEFAULT_FILE="$PYV_DIR/default_distribution"
PYV_VENV_DEFAULT_FILE="$PYV_DIR/default_virtualenv"
# used/set by pyv later in the script
#PYV_VENV_CUR=
PYV_LINK_TARGET=venv

PYTHON_DIST_URL='https://www.python.org/ftp/python/${version}/Python-${version}.tgz'


_pyv_create_venvs_dir()
{
    mkdir -p "$PYV_VENVS_DIR" && return 0
    echo >&2 "unable to create '$PYV_VENVS_DIR'"
    return 1
}

_pyvenv_create_repos_dir()
{
    mkdir -p "$PYV_REPOS_DIR" && return 0
    echo >&2 "unable to create '$PYV_REPOS_DIR'"
    return 1
}


### distributions

_pyv_dist()
{
    if [ $# -eq 0 ]; then
        _pyv_dist_list
    else
        _pyv_dist_set_default "$@"
    fi
}

_pyv_dist_list()
{
    _pyv_dist_list_from_path
    _pyv_dist_list_repositories
}

_pyv_print_python()
(
     printf "%s%s:%s:%s\n" "${4:- }" "$1" "$2" "$3"
)

_pyv_dist_list_repositories()
(
    if cd "$PYV_DISTS_DIR" 2>/dev/null; then
        for d in *; do
            [ '*' = "$d" ] && continue
            _pyv_python_env "$d" "$PYV_DISTS_DIR" &&
            _pyv_print_python "$_pyv_python_env__name" \
                                "$_pyv_python_env__version" \
                                "$_pyv_python_env__path" \
                                "$_pyv_python_env__cur"
        done
    fi
)

_pyv_dist_list_from_path()
(
    _pyv_dist_list_from_path__python=`which python 2>/dev/null`
    [ $? -ne 0 ] && return 0
    _pyv_dist_list_from_path__path="${_pyv_dist_list_from_path__python%%/python}"
    _pyv_dist_list_from_path__version="`$_pyv_dist_list_from_path__python --version 2>&1`" ||
        _pyv_dist_list_from_path__version='undefined'
    cur=' '
    [ "from_path" = "$(_pyv_dist_default)" ] && cur='*'
    _pyv_print_python "from_path" "$_pyv_dist_list_from_path__version" \
                      "$_pyv_dist_list_from_path__path" "$cur"
)

_pyv_dist_default()
{
    _pyv_dist_default=`cat "$PYV_DIST_DEFAULT_FILE" 2>/dev/null`
    _pyv_dist_default="${_pyv_dist_default:-from_path}"

    echo "$_pyv_dist_default"
}

_pyv_dist_set_default()
{
    if [ "$1" = 'from_path' ]; then
        rm -f "$PYV_DIST_DEFAULT_FILE"
    else
        [ -d "$PYV_DISTS_DIR/$1" ] || return 1
        echo "$1" > "$PYV_DIST_DEFAULT_FILE"
    fi
}

_pyv_dist_exec()
(
    _pyv_dist_exec__dist="${1:-$(_pyv_dist_default)}"
    shift
    _pyv_dist_exec__path="$PATH"
    # _pyv_dist_exec__ld_path="$LD_LIBRARY_PATH"
    if [ "$_pyv_dist_exec__dist" != 'from_path' ]; then
        _pyv_dist_exec__dist_p="$PYV_DISTS_DIR/$_pyv_dist_exec__dist"
        _pyv_dist_exec__path="$_pyv_dist_exec__dist_p/bin:$_pyv_dist_exec__path"
        # _pyv_dist_exec__ld_path="$_pyv_dist_exec__dist_p/lib:$_pyv_dist_exec__ld_path"
        if [ ! -x "$_pyv_dist_exec__dist_p/bin/python" ]; then
            printf >&2 "python command is not available at $_pyv_dist_exec__dist_p/bin/python\n"
            return 1
        fi
    fi

    PATH="$_pyv_dist_exec__path"
    # LD_LIBRARY_PATH="$_pyv_dist_exec__ld_path"

    eval "$@"
)

_pyv_dist_cur_exec()
{
    _pyv_dist_exec "$(_pyv_dist_default)" "$@"
}

_pyv_dist_fix()
(
    for dist in "$PYV_DISTS_DIR"/*; do
        if cd "$dist/bin" 2>/dev/null; then
            if [ -x 'python' ] || [ -L 'python' ]; then
                continue
            fi
            echo $PWD: ln -s python[0-9]*.*[0-9] python
            ln -s python[0-9]*.*[0-9] python
        fi
    done
)

_pyv_dist_build()
(
    _pyv_dist_build__tmpdir=`mktemp -d` || return 1
    cd "$_pyv_dist_build__tmpdir" &&
        _pyv_dist_build_process "$@"
    set +e
    rm -Rf "$_pyv_dist_build__tmpdir"
)

_pyv_dist_build_process()
(
    set -e
    version="$1"
    eval _pyv_dist_build__url="\"$PYTHON_DIST_URL\""
    _pyv_dist_build__file="${_pyv_dist_build__url##*/}"
    curl -s -S -L "$_pyv_dist_build__url" -o "$_pyv_dist_build__file"
    tar -xzf "$_pyv_dist_build__file" &&
        rm "$_pyv_dist_build__file"
    cd *
    LDFLAGS="${LDFLAGS} ${PYV_OPENSSL:+-Wl,-rpath=$PYV_OPENSSL/lib}" ./configure --prefix "$PYV_DISTS_DIR/${PWD##*/}" ${PYV_OPENSSL:+--with-openssl=$PYV_OPENSSL} &&
        make &&
        make install
    _pyv_dist_fix
)

_pyv_dist_delete()
{
    [ -r "$PYV_DISTS_DIR"/"$1" ] && rm -Rf "$PYV_DISTS_DIR"/"$1"
}


### virtualenv

_pyv_venv_get_or_cur()
{
    _pyv_venv_get_or_cur="${1:-$PYV_VENV_CUR}"
    [ -z "$_pyv_venv_get_or_cur" ] && return 1
    return 0
}

_pyv_venv_get_or_path()
{
    _pyv_venv_get_or_path="${1:-${PWD##*/}}"
    [ -z "$_pyv_venv_get_or_path" ] && return 1
    return 0
}

_pyv_python_env()
{
    _pyv_python_env__cur=
    _pyv_python_env__version=
    _pyv_python_env__dist=
    _pyv_python_env__name="$1"
    [ -n "$_pyv_python_env__name" ] || return 1

    _pyv_python_env__path="${2:-$PYV_VENVS_DIR}/$_pyv_python_env__name"
    [ -d "$_pyv_python_env__path" ] || return 1

    _pyv_python_env__version="`$_pyv_python_env__path/bin/python --version 2>&1`" ||
        _pyv_python_env__version='undefined'
    _pyv_python_env__version="${_pyv_python_env__version%% \(*}"

    _pyv_python_env__dist="`readlink -e $_pyv_python_env__path/bin/python`"
    _pyv_python_env__dist="${_pyv_python_env__dist%/bin/python*}"
    if [ "$_pyv_python_env__dist" = "$_pyv_python_env__path" ]; then
        [ "$_pyv_python_env__name" = "$(_pyv_dist_default)" ] && _pyv_python_env__cur=*
    else
        [ "$_pyv_python_env__name" = "$PYV_VENV_CUR" ] && _pyv_python_env__cur=*
    fi
    return 0
}

_pyv_list_venvs()
(
    if cd "$PYV_VENVS_DIR"; then
        for venv in *; do
            [ '*' = "$venv" ] && continue
            _pyv_python_env "$venv" &&
            _pyv_print_python "$_pyv_python_env__name" \
                                "$_pyv_python_env__version" \
                                "$_pyv_python_env__path" \
                                "$_pyv_python_env__cur"
        done
    fi
)

_pyv_venv_set_cur()
{
    PYV_VENV_CUR="$1"
    VIRTUAL_ENV="$PYV_VENVS_DIR/$1"
    export VIRTUAL_ENV
}

_pyv_venv_unset_cur()
{
    PYV_VENV_CUR=
    VIRTUAL_ENV=
    export VIRTUAL_ENV
}

_pyv_venv_load_default()
{
    _pyv_venv_load_default=`cat "$PYV_VENV_DEFAULT_FILE" 2>/dev/null`
    [ -n "$_pyv_venv_load_default" ] && _pyv_set "$_pyv_venv_load_default"
}

_pyv_venv_set_default()
{
    [ -d "$PYV_VENVS_DIR/$1" ] || return 1
    echo "$1" > "$PYV_VENV_DEFAULT_FILE"
    if [ -z "$PYV_VENV_CUR" ]; then
        _pyv_venv_load_default
    fi
}

_pyv_venv()
{
    if [ $# -eq 0 ]; then
        _pyv_list_venvs
    else
        _pyv_venv_set_default "$@"
    fi
}

_pyv_list()
{
    printf "# distributions\n"
    _pyv_dist_list
    printf "\n"
    printf "# virtualenvs\n"
    _pyv_list_venvs
}

_pyv_venv_info()
(
    _pyv_venv_get_or_cur "$1" || return 1
    _pyv_python_env "$_pyv_venv_get_or_cur" || return 1
    printf "%13s=%s\n" \
           venv_name "$_pyv_python_env__name" \
           venv_version "$_pyv_python_env__version" \
           venv_path "$_pyv_python_env__path" \
           venv_dist "$_pyv_python_env__dist"
)

_pyv_create()
{
    [ -z "$1" ] && return 1
    _pyv_create="$PYV_VENVS_DIR/$1"
    if [ -e "$_pyv_create" ]; then
        echo >&2 "$_pyv_create already exists"
        return 1
    fi
    _pyv_create_venvs_dir || return 1

    _pyv_dist_exec "${2:-$(_pyv_dist_default)}" "python -m venv --clear \"$_pyv_create\""
    # _pyv_dist_exec "${2:-$(_pyv_dist_default)}" "pyvenv \"$_pyv_create\""

    _pyv_venv_fix "$_pyv_create"
}

_pyv_venv_is_current()
{
    [ "$PYV_VENV_CUR" = "$1" ]
}

_pyv_venv_fix()
(
    [ -z "$1" ] && return 1
    cd "$1/bin" || return 1
    version=`./python --version`
    version="${version#* }"
    version="${version%% *}"
    while [ -n "$version" ]; do
        bin="python$version"
        [ -x "$bin" ] || ln -s python "$bin"
        sub_version="${version##*.}"
        version="${version%$sub_version}"
        version="${version%.}"
    done
)

_pyv_recreate()
{
    _pyv_venv_get_or_cur "$1" || return 1
    _pyv_recreate="$_pyv_venv_get_or_cur"
    _pyv_recreate__version="$2"
    if [ -z "$_pyv_recreate__version" ]; then
        _pyv_python_env "$_pyv_recreate" &&
            _pyv_recreate__version="${_pyv_python_env__dist##*/}"
    fi
    _pyv_recreate__create_cmd=_pyv_create
    _pyv_venv_is_current "$_pyv_recreate" && _pyv_recreate__create_cmd=_pyv_set_or_create_set
    _pyv_delete "$_pyv_recreate"
    $_pyv_recreate__create_cmd "$_pyv_recreate" "$_pyv_recreate__version"
}

_pyv_delete()
{
    _pyv_venv_get_or_cur "$1" || return 1
    _pyv_delete="$_pyv_venv_get_or_cur"
    _pyv_delete__dir="$PYV_VENVS_DIR/$_pyv_delete"
    [ -d "$_pyv_delete__dir" ] || return 1
    rm -Rf "$_pyv_delete__dir"
    if _pyv_venv_is_current "$_pyv_delete"; then
        _pyv_unset
        _pyv_venv_load_default
    fi
}


_pyv_add_path()
{
    _pyv_add_path=$(cd "$1" 2>/dev/null && pwd -P)
    [ -z "$_pyv_add_path" ] && return 1

    for _pyv_add_path__d in sbin bin; do
        _pyv_add_path__d="$_pyv_add_path/$_pyv_add_path__d"
        [ -d "$_pyv_add_path__d" ] &&
            PATH="$_pyv_add_path__d:$PATH"
    done
    # for _pyv_add_path__d in lib; do
    #     _pyv_add_path__d="$_pyv_add_path/$_pyv_add_path__d"
    #     [ -d "$_pyv_add_path__d" ] &&
    #         LD_LIBRARY_PATH="$_pyv_add_path__d:$LD_LIBRARY_PATH"
    # done
    export PATH  # LD_LIBRARY_PATH
}

_pyv_remove_path()
{
    _pyv_remove_path=$(cd "$1" 2>/dev/null && pwd)
    for _pyv_remove_path__d in bin sbin; do
        _pyv_remove_path__d="$_pyv_remove_path/$_pyv_remove_path__d"
        _pyv_remove_path__front="${PATH%%$_pyv_remove_path__d*}"
        _pyv_remove_path__back="${PATH#$_pyv_remove_path__front}"
        _pyv_remove_path__back="${_pyv_remove_path__back#$_pyv_remove_path__d}"
        _pyv_remove_path__front="${_pyv_remove_path__front%:}"
        _pyv_remove_path__back="${_pyv_remove_path__back#:}"
        PATH="$_pyv_remove_path__front"
        [ -n "$_pyv_remove_path__back" ] &&
            PATH="${PATH:+$PATH:}$_pyv_remove_path__back"
    done
    # for _pyv_remove_path__d in lib; do
    #     _pyv_remove_path__d="$_pyv_remove_path/$_pyv_remove_path__d"
    #     _pyv_remove_path__front="${LD_LIBRARY_PATH%%$_pyv_remove_path__d*}"
    #     _pyv_remove_path__back="${LD_LIBRARY_PATH#$_pyv_remove_path__front}"
    #     _pyv_remove_path__back="${_pyv_remove_path__back#$_pyv_remove_path__d}"
    #     _pyv_remove_path__front="${_pyv_remove_path__front%:}"
    #     _pyv_remove_path__back="${_pyv_remove_path__back#:}"
    #     LD_LIBRARY_PATH="$_pyv_remove_path__front"
    #     [ -n "$_pyv_remove_path__back" ] &&
    #         LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$_pyv_remove_path__back"
    # done
    export PATH  # LD_LIBRARY_PATH
}

_pyv_set()
{
    _pyv_venv_get_or_path "$1" || return 1
    _pyv_set__short="$_pyv_venv_get_or_path"

    [ "$_pyv_set__short" = "$PYV_VENV_CUR" ] && return 0

    _pyv_set="$PYV_VENVS_DIR/$_pyv_set__short"
    if [ ! -e "$_pyv_set" ]; then
        #echo >&2 "$_pyv_set doesn't exist"
        return 1
    fi
    _pyv_unset
    _pyv_add_path "$_pyv_set" &&
        _pyv_venv_set_cur "$_pyv_set__short"
}

_pyv_unset()
{
    _pyv_venv_get_or_cur "$1" || return 1
    _pyv_unset__short="$_pyv_venv_get_or_cur"
    [ -z "$_pyv_unset__short" ] && return 0
    _pyv_unset="$PYV_VENVS_DIR/$_pyv_unset__short"
    _pyv_remove_path "$_pyv_unset" &&
        _pyv_venv_unset_cur
}

_pyv_create_set()
{
    _pyv_venv_get_or_path "$1" || return 1
    _pyv_create_set__id="$_pyv_venv_get_or_path"
    [ $# -gt 0 ] && shift

    _pyv_create "$_pyv_create_set__id" "$@" &&
        _pyv_set "$_pyv_create_set__id" "$@"
}

_pyv_set_or_create_set()
{
    _pyv_venv_get_or_path "$1"
    _pyv_set_or_create_set__id="$_pyv_venv_get_or_path"
    [ $# -gt 0 ] && shift

    _pyv_set "$_pyv_set_or_create_set__id" "$@" 2>/dev/null && return 0
    _pyv_create_set "$_pyv_set_or_create_set__id" "$@"
}

_pyv_link()
{
    _pyv_target="${1:-$PYV_LINK_TARGET}"

    _pyv_venv_get_or_cur "$2" || return 1
    _pyv_link__short="$_pyv_venv_get_or_cur"
    [ -z "$_pyv_link__short" ] && return 1

    _pyv_link="$PYV_VENVS_DIR/$_pyv_link__short"

    ln -sf "$_pyv_link" "$_pyv_target"
}


### help

_pyv_help()
{
    cat <<EOF
Usage is :
    pyv <action> <parameters>

With distribution action in :
    D | dist | dists                   : list distributions
    D | dist | dists <version>         : set default distribution
    fd | fix_dists                     : fix distributions
    bd | build | build_dist <version>  : build specified version
    dd | delete_dist <version>         : delete specified version

With virtualenv action in :
    v | venv | venvs                   : list virtual env
    v | venv | venvs <virtualenv>      : set default virtual env
    l | list                           : list distributions and virtualenv
    i | info                           : display info for virtualenv
    c | create <virtualenv>            : create virtualenv
    rc | recreate <virtualenv>         : recreate virtualenv
    d | delete <virtualenv>            : delete virtualenv
    s | set <virtualenv>               : set virtualenv
    u | unset <virtualenv>             : unset virtualenv
    cs | create_set <virtualenv>       : create and set virtualenv
    sc | set_or_create_set <virtualenv> : set or create and set virtualenv

Default action is to :
    set_or_create_set <virtualenv>
EOF
}


### pyv

_pyv()
{
    _pyv=

    case $1 in
        D|dist|dists|distribution|distributions)
            shift
            _pyv_dist "$@"
            _pyv__ret=$?
            ;;
        [Ff][Dd]|fix_dist|fix_dists|dist_fix|dists_fix)
            _pyv_dist_fix
            _pyv__ret=$?
            ;;
        build|build_dist|[Bb]|[Bb][Dd])
            shift
            _pyv_dist_build "$@"
            _pyv__ret=$?
            ;;
        delete_dist|[Dd][Dd])
            shift
            _pyv_dist_delete "$@"
            _pyv__ret=$?
            ;;
        v|venv|venvs)
            shift
            _pyv_venv "$@"
            _pyv__ret=$?
            ;;
        l|list|-l)
            _pyv_list
            _pyv__ret=$?
            ;;
        i|info)
            shift
            _pyv_venv_info "$@"
            _pyv__ret=$?
            ;;
        c|create)
            shift
            _pyv_create "$@"
            _pyv__ret=$?
            ;;
        rc|recreate)
            shift
            _pyv_recreate "$@"
            _pyv__ret=$?
            ;;
        d|delete)
            shift
            _pyv_delete "$@"
            _pyv__ret=$?
            ;;
        s|'set')
            shift
            _pyv_set "$@"
            _pyv__ret=$?
            ;;
        u|'unset')
            shift
            _pyv_unset "$@"
            _pyv__ret=$?
            ;;
        cs|create_set)
            shift
            _pyv_create_set "$@"
            _pyv__ret=$?
            ;;
        sc|set_or_create)
            shift
            _pyv_set_or_create_set "$@"
            _pyv__ret=$?
            ;;
        link)
            shift
            _pyv_link "$@"
            _pyv__ret=$?
            ;;
        -h|h|--help|help)
            _pyv_help "$@"
            _pyv__ret=$?
            ;;
        *)
            _pyv_set_or_create_set "$@"
            _pyv__ret=$?
            ;;
    esac

    return $_pyv__ret
}

pyv()
{
    _pyv "$@"
    pyv="$?"
    [ -n "$_pyv" ] && printf "%s\n" "$_pyv"
    return $pyv
}

_pyv_venv_load_default

:

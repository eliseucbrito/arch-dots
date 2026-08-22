#!/usr/bin/env bash

layout=$(hyprctl devices -j 2>/dev/null | python3 -c "
import sys, json
from collections import Counter
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
kbs = d.get('keyboards', [])
# O layout ativo real é refletido pelo teclado 'main' (aqui o virtual do
# fcitx5), pois é ele quem processa o grp:alts_toggle. Os teclados físicos
# ficam presos no layout inicial.
main = next((k for k in kbs if k.get('main')), None)
if main and main.get('active_keymap'):
    print(main['active_keymap'])
else:
    ls = [k['active_keymap'] for k in kbs if k.get('active_keymap')]
    print(Counter(ls).most_common(1)[0][0] if ls else '')
" 2>/dev/null)

[ -z "$layout" ] && exit 0

case "$layout" in
  *Brazil*|*Portuguese*) short="BR" ;;
  *intl*|*US*)           short="US" ;;
  *)                     short=$(printf '%.4s' "$layout") ;;
esac

printf '{"text":"%s","tooltip":"Layout: %s | Alt+Alt para alternar","class":"%s"}\n' \
  "$short" "$layout" "$(echo "$short" | tr '[:upper:]' '[:lower:]')"

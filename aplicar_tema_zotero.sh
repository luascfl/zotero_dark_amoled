#!/bin/bash
# V14 — AMOLED para Zotero 8 (Solução Final Shadow DOM + AutoConfig)
# Correções: highlight visível em menus de contexto; banners, botões e cabeçalhos cinza forçados a preto; searchbox e containers extras.
# ADICIONAL: Patch CSS final com ::part() e AutoConfig para injetar JS no Shadow DOM do campo de busca.

set -euo pipefail

echo "------------------------------------------------------"
echo "Aplicando tema 'Preto Verdadeiro' (V14) ao Zotero 8..."
echo "------------------------------------------------------"
echo "Ative 'toolkit.legacyUserProfileCustomizations.stylesheets' = true (Preferências > Avançadas > Editor de Configuração)."
read -r -p "Você já ativou esta configuração manual no Zotero? (s/n): " confirm
[[ "${confirm:-n}" =~ ^[sS]$ ]] || { echo "Ação cancelada."; exit 1; }

echo "1) Localizando perfil..."
CANDIDATES=()
PROFILE_BASES=(
  "${HOME}/.zotero"
  "${HOME}/.zotero-beta"
  "${HOME}/.var/app/org.zotero.Zotero/.zotero"
  "${HOME}/.var/app/org.zotero.ZoteroBeta/.zotero"
  "${HOME}/Library/Application Support/Zotero"
  "${HOME}/Library/Application Support/ZoteroBeta"
)
for base in "${PROFILE_BASES[@]}"; do
  [ -d "$base" ] || continue
  while IFS= read -r -d '' prefs; do
    dir="$(dirname "$prefs")"
    exists=0
    for saved in "${CANDIDATES[@]}"; do
      if [ "$saved" = "$dir" ]; then
        exists=1
        break
      fi
    done
    [ $exists -eq 1 ] && continue
    CANDIDATES+=("$dir")
  done < <(find "$base" -type f -name "prefs.js" -print0 2>/dev/null)
done

[ ${#CANDIDATES[@]} -gt 1 ] && { IFS=$'\n' CANDIDATES=($(printf '%s\n' "${CANDIDATES[@]}" | sort)); unset IFS; }

[ ${#CANDIDATES[@]} -gt 0 ] || { echo "ERRO: Nenhum perfil encontrado."; exit 1; }

if [ ${#CANDIDATES[@]} -eq 1 ]; then
  ZPROFILE="${CANDIDATES[0]}"
else
  echo "   Perfis encontrados:"
  for idx in "${!CANDIDATES[@]}"; do
    printf '   [%d] %s\n' "$((idx + 1))" "${CANDIDATES[$idx]}"
  done
  while :; do
    read -r -p "Selecione o perfil que deseja atualizar [1-${#CANDIDATES[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#CANDIDATES[@]} ]; then
      ZPROFILE="${CANDIDATES[$((choice - 1))]}"
      break
    fi
    echo "   Opção inválida."
  done
fi
echo "   Perfil: $ZPROFILE"

echo "2) Preparando userChrome.css..."
mkdir -p "$ZPROFILE/chrome"
CSS_FILE="$ZPROFILE/chrome/userChrome.css"
# Cria backup do arquivo existente
[ -f "$CSS_FILE" ] && cp -f "$CSS_FILE" "$CSS_FILE.bak.$(date +%Y%m%d-%H%M%S)"
# Limpa o arquivo (cria se não existir)
: > "$CSS_FILE"

echo "3) Instalando AutoConfig (carregamento de JS no Shadow DOM)..."

# Detecta diretório do app Zotero
ZOTERO_DIR=""
DEFAULTS_PREF_DIR=""
ZOTERO_DIRS=()
ZOTERO_DIR_CANDIDATES=(
  "/usr/lib/zotero"
  "/usr/lib/zotero-beta"
  "/opt/zotero"
  "/opt/zotero-beta"
  "${HOME}/Zotero"
  "${HOME}/Zotero_beta"
  "${HOME}/Zotero-beta"
  "${HOME}/.local/share/zotero"
  "${HOME}/.local/share/zotero-beta"
  "/Applications/Zotero.app/Contents/Resources"
  "/Applications/Zotero Beta.app/Contents/Resources"
  "${HOME}/Applications/Zotero.app/Contents/Resources"
  "${HOME}/Applications/Zotero Beta.app/Contents/Resources"
)
for candidate in "${ZOTERO_DIR_CANDIDATES[@]}"; do
  [ -d "$candidate/defaults/pref" ] || continue
  for saved in "${ZOTERO_DIRS[@]}"; do
    [ "$saved" = "$candidate" ] && continue 2
  done
  ZOTERO_DIRS+=("$candidate")
done

if [ ${#ZOTERO_DIRS[@]} -gt 1 ]; then
  IFS=$'\n' ZOTERO_DIRS=($(printf '%s\n' "${ZOTERO_DIRS[@]}" | sort)); unset IFS
fi

SELECTED_DIRS=()
if [ ${#ZOTERO_DIRS[@]} -gt 0 ]; then
  echo "   Instalações detectadas:"
  for dir in "${ZOTERO_DIRS[@]}"; do
    echo "    - $dir"
  done
  SELECTED_DIRS=("${ZOTERO_DIRS[@]}")
fi
IS_FLATPAK=0
if [ -d "${HOME}/.var/app/org.zotero.Zotero" ] || [ -d "${HOME}/.var/app/org.zotero.ZoteroBeta" ] || [ -d "${HOME}/.var/app/org.zotero.Zotero-beta" ]; then
  IS_FLATPAK=1
fi

if [ ${#SELECTED_DIRS[@]} -eq 0 ]; then
  if [ $IS_FLATPAK -eq 1 ]; then
    echo "   ⚠ Flatpak detectado. AutoConfig não será gravado (sistema somente leitura)."
    echo "   Usar build .tar.gz/.deb/.dmg ou rodar o JS manualmente no Console."
  else
    echo "   ⚠ Não encontrei o diretório do app Zotero. Pulei AutoConfig."
  fi
  # salva fallback no perfil para execução manual
  cat > "$ZPROFILE/chrome/searchbox-dark-fix.js" << 'JSEOF'
// Cole no Browser Console (Ctrl+Shift+J) do Zotero após abrir a UI:
(function () {
  function apply() {
    const doc = document;
    let ok = false;

    const textbox = doc.getElementById('zotero-tb-search-textbox');
    if (textbox && textbox.shadowRoot) {
      const existing = textbox.shadowRoot.getElementById('forced-dark-theme');
      if (existing) existing.remove();

      const textboxStyle = doc.createElement('style');
      textboxStyle.id = 'forced-dark-theme';
      textboxStyle.textContent = [
        ':host,*{background:#000!important;background-color:#000!important;background-image:none!important;color:#fff!important;-moz-appearance:none!important}',
        'input{caret-color:#fff!important}',
        '::placeholder{color:#aaa!important}',
        '.textbox-search-icons{background:#000!important}'
      ].join('');
      textbox.shadowRoot.appendChild(textboxStyle);

      textbox.style.setProperty('-moz-appearance', 'none', 'important');
      textbox.style.setProperty('appearance', 'none', 'important');
      textbox.style.setProperty('background', '#000', 'important');
      textbox.style.setProperty('color', '#fff', 'important');
      textbox.style.setProperty('border', '1px solid #222', 'important');
      textbox.style.setProperty('border-left', '0', 'important');
      textbox.style.setProperty('border-radius', '0 6px 6px 0', 'important');
      textbox.style.setProperty('box-shadow', 'none', 'important');

      const inputField = textbox.shadowRoot.querySelector('input');
      if (inputField) {
        inputField.style.setProperty('background', '#000', 'important');
        inputField.style.setProperty('color', '#fff', 'important');
        inputField.style.setProperty('box-shadow', 'none', 'important');
        inputField.style.setProperty('border', '0', 'important');
        inputField.style.setProperty('caret-color', '#fff', 'important');
      }

      textbox.shadowRoot.querySelectorAll('*').forEach(el => {
      if (el.tagName !== 'STYLE' && el.tagName !== 'LINK') {
        el.style.backgroundColor = '#000';
        el.style.color = '#fff';
      }
    });
      ok = true;
    }

    const dropHost = doc.getElementById('zotero-tb-search-dropmarker');
    if (dropHost && dropHost.shadowRoot) {
      const oldDrop = dropHost.shadowRoot.getElementById('forced-dark-theme-dropmarker');
      if (oldDrop) oldDrop.remove();

      const dropStyle = doc.createElement('style');
      dropStyle.id = 'forced-dark-theme-dropmarker';
      dropStyle.textContent = [
        ':host{background:#000!important;border:1px solid #222!important;border-right:none!important;border-radius:6px 0 0 6px!important;padding:0!important;display:flex;align-items:stretch;}',
        ':host(:focus-visible){outline:1px solid #666!important;}',
        'button{appearance:none!important;-moz-appearance:none!important;background:#000!important;color:#fff!important;border:0!important;border-radius:6px 0 0 6px!important;padding:2px 10px!important;font:inherit!important;min-height:var(--toolbarbutton-height,24px)!important;}',
        'button:hover,button[open="true"]{background:#0a0a0a!important;}',
        'menupopup{background:#000!important;color:#fff!important;border:1px solid #111!important;}',
        'menuitem{background:transparent!important;color:#fff!important;}',
        'menuitem[_moz-menuactive="true"],menuitem:hover{background:#111!important;}'
      ].join('');
      dropHost.shadowRoot.appendChild(dropStyle);

      dropHost.style.setProperty('-moz-appearance', 'none', 'important');
      dropHost.style.setProperty('appearance', 'none', 'important');
      dropHost.style.setProperty('background', '#000', 'important');
      dropHost.style.setProperty('color', '#fff', 'important');
      dropHost.style.setProperty('border', '1px solid #222', 'important');
      dropHost.style.setProperty('border-right', '0', 'important');
      dropHost.style.setProperty('border-radius', '6px 0 0 6px', 'important');
      dropHost.style.setProperty('padding', '0', 'important');
      dropHost.style.setProperty('margin', '0', 'important');
      dropHost.style.setProperty('box-shadow', 'none', 'important');

      const dropButton = dropHost.shadowRoot.querySelector('button');
      if (dropButton) {
        dropButton.style.setProperty('-moz-appearance', 'none', 'important');
        dropButton.style.setProperty('appearance', 'none', 'important');
        dropButton.style.setProperty('background', '#000', 'important');
        dropButton.style.setProperty('color', '#fff', 'important');
        dropButton.style.setProperty('border', '0', 'important');
        dropButton.style.setProperty('padding', '2px 10px', 'important');
        dropButton.style.setProperty('border-radius', '6px 0 0 6px', 'important');
        dropButton.style.setProperty('box-shadow', 'none', 'important');
      }
      ok = true;
    }

    const readerUi = doc.getElementById('reader-ui');
    if (readerUi) {
      const applyStyle = (node, rules) => {
        if (!node) return;
        Object.keys(rules).forEach(prop => node.style.setProperty(prop, rules[prop], 'important'));
      };
      applyStyle(readerUi, {
        background: '#000',
        'background-image': 'none',
        color: '#fff',
        'border-color': '#111',
        'box-shadow': 'none'
      });
      const toolbar = readerUi.querySelector('.toolbar');
      applyStyle(toolbar, {
        background: '#000',
        'background-image': 'none',
        color: '#fff',
        'border-color': '#111',
        'box-shadow': 'none'
      });
      if (toolbar) {
        toolbar.querySelectorAll('.center.tools, .center.tools *, .start, .start *, .end, .end *').forEach(el => {
          applyStyle(el, { color: '#fff', fill: '#fff' });
        });
        toolbar.querySelectorAll('button.toolbar-button, toolbarbutton').forEach(btn => {
          applyStyle(btn, {
            background: '#000',
            color: '#fff',
            fill: '#fff',
            border: '1px solid #333',
            'border-radius': '6px',
            'box-shadow': 'none'
          });
        });
        toolbar.querySelectorAll('button.toolbar-button svg path, button.toolbar-button svg g path, toolbarbutton svg path, button.toolbar-button svg g polygon, button.toolbar-button svg polygon').forEach(pathNode => {
          applyStyle(pathNode, { fill: '#fff', stroke: '#fff' });
        });
        toolbar.querySelectorAll('div.divider').forEach(divider => {
          applyStyle(divider, { background: '#111' });
        });
      }
      ok = true;
    }

    return ok;
  }

  let t = 0;
  (function tick() {
    if (apply() || ++t >= 60) return;
    setTimeout(tick, 200);
  })();

  const mo = new MutationObserver(() => apply());
  mo.observe(document, { subtree: true, childList: true });
  window.addEventListener('unload', () => {
    try { mo.disconnect(); } catch (_) {}
  }, { once: true });
})();
JSEOF
  echo "   Fallback salvo em: $ZPROFILE/chrome/searchbox-dark-fix.js"
  echo "   Prossiga para o passo 4 (CSS) e reinicie."
else
  for ZOTERO_DIR in "${SELECTED_DIRS[@]}"; do
    DEFAULTS_PREF_DIR="$ZOTERO_DIR/defaults/pref"
    echo "   Diretório do app: $ZOTERO_DIR"
    if [ -w "$ZOTERO_DIR" ]; then SUDO=""; else SUDO="sudo"; echo "   ⚠ Requer sudo para escrever em $ZOTERO_DIR"; fi
    $SUDO mkdir -p "$DEFAULTS_PREF_DIR"

    CONFIG_TYPE="autoconfig"
    CONFIG_FILE="$ZOTERO_DIR/autoconfig.cfg"
    if [ -f "$DEFAULTS_PREF_DIR/local_settings.js" ] && grep -q "mozilla.cfg" "$DEFAULTS_PREF_DIR/local_settings.js"; then
      CONFIG_TYPE="mozilla"
      CONFIG_FILE="$ZOTERO_DIR/mozilla.cfg"
    elif [ -f "$DEFAULTS_PREF_DIR/autoconfig.js" ] && grep -q "mozilla.cfg" "$DEFAULTS_PREF_DIR/autoconfig.js"; then
      CONFIG_TYPE="mozilla"
      CONFIG_FILE="$ZOTERO_DIR/mozilla.cfg"
    elif [ -f "$ZOTERO_DIR/mozilla.cfg" ]; then
      CONFIG_TYPE="mozilla"
      CONFIG_FILE="$ZOTERO_DIR/mozilla.cfg"
    fi

    if [ "$CONFIG_TYPE" = "mozilla" ]; then
      $SUDO tee "$DEFAULTS_PREF_DIR/autoconfig.js" >/dev/null <<'JS'
pref("general.config.filename", "mozilla.cfg");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);
JS
    else
      $SUDO tee "$DEFAULTS_PREF_DIR/autoconfig.js" >/dev/null <<'JS'
pref("general.config.filename", "autoconfig.cfg");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);
JS
    fi

    [ -f "$CONFIG_FILE" ] && $SUDO cp -f "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d-%H%M%S)"
    $SUDO tee "$CONFIG_FILE" >/dev/null <<'CFG'
// Patch AMOLED carregado por aplicar_tema_zotero.sh
try {
  var Cc = Components.classes;
  var Ci = Components.interfaces;
  var consoleSvc = Cc['@mozilla.org/consoleservice;1'].getService(Ci.nsIConsoleService);
  function log(msg) {
    var text = '[Zotero AMOLED] ' + msg;
    try { consoleSvc.logStringMessage(text); } catch (_) {}
    try { dump(text + '\n'); } catch (_) {}
  }
  try {
    Cc['@mozilla.org/preferences-service;1'].getService(Ci.nsIPrefBranch)
      .setBoolPref('extensions.zotero.amoled.autoconfig_active', true);
    log('pref extensions.zotero.amoled.autoconfig_active definida para true');
  } catch (err) {
    log('falha ao definir pref de diagnóstico: ' + err);
  }

  function patch(win) {
    try {
      var doc = win.document;
      if (!doc) {
        return false;
      }
      var ok = true;
      var textbox = doc.getElementById('zotero-tb-search-textbox');
      if (!textbox || !textbox.shadowRoot) {
        ok = false;
      } else {
        var shadow = textbox.shadowRoot;
        var existing = shadow.getElementById('forced-dark-theme');
        if (existing) {
          existing.remove();
        }
        var style = doc.createElement('style');
        style.id = 'forced-dark-theme';
        style.textContent = [
          ':host,*{background:#000!important;background-color:#000!important;background-image:none!important;color:#fff!important;-moz-appearance:none!important}',
          'input{caret-color:#fff!important}',
          '::placeholder{color:#aaa!important}',
          '.textbox-search-icons{background:#000!important}'
        ].join('');
        shadow.appendChild(style);

        textbox.style.setProperty('-moz-appearance', 'none', 'important');
        textbox.style.setProperty('appearance', 'none', 'important');
        textbox.style.setProperty('background', '#000', 'important');
        textbox.style.setProperty('color', '#fff', 'important');
        textbox.style.setProperty('border', '1px solid #222', 'important');
        textbox.style.setProperty('border-left', '0', 'important');
        textbox.style.setProperty('border-radius', '0 6px 6px 0', 'important');
        textbox.style.setProperty('box-shadow', 'none', 'important');

        var inputField = shadow.querySelector('input');
        if (inputField) {
          inputField.style.setProperty('background', '#000', 'important');
          inputField.style.setProperty('color', '#fff', 'important');
          inputField.style.setProperty('box-shadow', 'none', 'important');
          inputField.style.setProperty('border', '0', 'important');
          inputField.style.setProperty('caret-color', '#fff', 'important');
        }

        shadow.querySelectorAll('*').forEach(function(el) {
          if (el.tagName !== 'STYLE' && el.tagName !== 'LINK') {
            el.style.backgroundColor = '#000';
            el.style.color = '#fff';
          }
        });
      }

      var dropHost = doc.getElementById('zotero-tb-search-dropmarker');
      if (dropHost && dropHost.shadowRoot) {
        var dropShadow = dropHost.shadowRoot;
        var old = dropShadow.getElementById('forced-dark-theme-dropmarker');
        if (old) {
          old.remove();
        }
        var dropStyle = doc.createElement('style');
        dropStyle.id = 'forced-dark-theme-dropmarker';
        dropStyle.textContent = [
          ':host{background:#000!important;border:1px solid #222!important;border-right:none!important;border-radius:6px 0 0 6px!important;padding:0!important;display:flex;align-items:stretch;}',
          ':host(:focus-visible){outline:1px solid #666!important;}',
          'button{appearance:none!important;-moz-appearance:none!important;background:#000!important;color:#fff!important;border:0!important;border-radius:6px 0 0 6px!important;padding:2px 10px!important;font:inherit!important;min-height:var(--toolbarbutton-height,24px)!important;}',
          'button:hover,button[open="true"]{background:#0a0a0a!important;}',
          'menupopup{background:#000!important;color:#fff!important;border:1px solid #111!important;}',
          'menuitem{background:transparent!important;color:#fff!important;}',
          'menuitem[_moz-menuactive="true"],menuitem:hover{background:#111!important;}'
        ].join('');
        dropShadow.appendChild(dropStyle);

        dropHost.style.setProperty('-moz-appearance', 'none', 'important');
        dropHost.style.setProperty('appearance', 'none', 'important');
        dropHost.style.setProperty('background', '#000', 'important');
        dropHost.style.setProperty('color', '#fff', 'important');
        dropHost.style.setProperty('border', '1px solid #222', 'important');
        dropHost.style.setProperty('border-right', '0', 'important');
        dropHost.style.setProperty('border-radius', '6px 0 0 6px', 'important');
        dropHost.style.setProperty('padding', '0', 'important');
        dropHost.style.setProperty('margin', '0', 'important');
        dropHost.style.setProperty('box-shadow', 'none', 'important');

        var btn = dropShadow.querySelector('button');
        if (btn) {
          btn.style.setProperty('-moz-appearance', 'none', 'important');
          btn.style.setProperty('appearance', 'none', 'important');
          btn.style.setProperty('background', '#000', 'important');
          btn.style.setProperty('color', '#fff', 'important');
          btn.style.setProperty('border', '0', 'important');
          btn.style.setProperty('padding', '2px 10px', 'important');
          btn.style.setProperty('border-radius', '6px 0 0 6px', 'important');
          btn.style.setProperty('box-shadow', 'none', 'important');
        }
        ok = true;
      }

      var readerUi = doc.getElementById('reader-ui');
      if (readerUi) {
        ok = true;
        var applyStyle = function(node, rules) {
          if (!node) return;
          for (var prop in rules) {
            if (Object.prototype.hasOwnProperty.call(rules, prop)) {
              node.style.setProperty(prop, rules[prop], 'important');
            }
          }
        };

        applyStyle(readerUi, {
          'background': '#000',
          'background-image': 'none',
          'color': '#fff',
          'border-color': '#111',
          'box-shadow': 'none'
        });

        var toolbar = readerUi.querySelector('.toolbar');
        applyStyle(toolbar, {
          'background': '#000',
          'background-image': 'none',
          'color': '#fff',
          'border-color': '#111',
          'box-shadow': 'none'
        });

        if (toolbar) {
          toolbar.querySelectorAll('.center.tools, .center.tools *, .start, .start *, .end, .end *').forEach(function(el) {
            applyStyle(el, { 'color': '#fff', 'fill': '#fff' });
          });

          toolbar.querySelectorAll('button.toolbar-button, toolbarbutton').forEach(function(btn) {
            applyStyle(btn, {
              'background': '#000',
              'color': '#fff',
              'fill': '#fff',
              'border': '1px solid #333',
              'border-radius': '6px',
              'box-shadow': 'none'
            });
          });

          toolbar.querySelectorAll('button.toolbar-button svg path, button.toolbar-button svg g path, toolbarbutton svg path, button.toolbar-button svg g polygon, button.toolbar-button svg polygon').forEach(function(pathNode) {
            applyStyle(pathNode, { 'fill': '#fff', 'stroke': '#fff' });
          });

          toolbar.querySelectorAll('div.divider').forEach(function(divider) {
            applyStyle(divider, { 'background': '#111' });
          });
        }
      }

      return ok;
    } catch (err) {
      log('patch falhou: ' + err);
      return false;
    }
  }

  function arm(win) {
    if (!win || !win.document) {
      return;
    }
    var attempts = 0;
    function attempt() {
      if (patch(win)) {
        try {
          log('patch aplicado em ' + (win.document && win.document.documentURI || 'documento desconhecido'));
        } catch (_) {}
        return true;
      }
      return false;
    }
    if (attempt()) {
      return;
    }
    function tick() {
      if (attempt()) {
        return;
      }
      if (++attempts >= 60) {
        log('não consegui aplicar — shadow DOM ainda indisponível');
        return;
      }
      try { win.setTimeout(tick, 200); } catch (_) {}
    }
    tick();
    if (win.MutationObserver) {
      var mo = new win.MutationObserver(function () { attempt(); });
      mo.observe(win.document, { subtree: true, childList: true });
      win.addEventListener('unload', function () {
        try { mo.disconnect(); } catch (_) {}
      }, { once: true });
    }
  }

  var os = Cc['@mozilla.org/observer-service;1'].getService(Ci.nsIObserverService);
  function addObserver(topic, handler) {
    var observer = {
      observe(subject, topicName) {
        if (topicName !== topic) {
          return;
        }
        try { handler(subject); } catch (err) { log(topic + ' handler falhou: ' + err); }
      }
    };
    os.addObserver(observer, topic);
  }

  addObserver('chrome-document-loaded', function (subject) {
    try {
      var win = subject && subject.defaultView;
      if (win) {
        win.addEventListener('load', function () { arm(win); }, { once: true });
      }
    } catch (err) { log('chrome-document-loaded erro: ' + err); }
  });

  addObserver('domwindowopened', function (win) {
    try {
      win.addEventListener('load', function () { arm(win); }, { once: true });
    } catch (err) { log('domwindowopened erro: ' + err); }
  });

  addObserver('final-ui-startup', function () {
    try {
      var wm = Cc['@mozilla.org/appshell/window-mediator;1'].getService(Ci.nsIWindowMediator);
      var enumerator = wm.getEnumerator(null);
      while (enumerator && enumerator.hasMoreElements()) {
        var win = enumerator.getNext();
        if (win) {
          arm(win);
        }
      }
    } catch (err) { log('final-ui-startup erro: ' + err); }
  });
} catch (err) {
  try { dump('[Zotero AMOLED] Erro fatal: ' + err + '\n'); } catch (_) {}
}
CFG

    echo "   ✅ Configuração aplicada:"
    echo "      - $DEFAULTS_PREF_DIR/autoconfig.js (aponta para $CONFIG_TYPE)"
    echo "      - $CONFIG_FILE"
  done
fi


echo "4) Gravando regras AMOLED..."
cat <<'EOT' >> "$CSS_FILE"
/* --- TEMA PRETO ABSOLUTO (V14 - Zotero 8) --- */

/* Base */
:root, window, dialog, panel, menupopup { background:#000 !important; color:#fff !important; }

/* Top bars / toolbars / tabbar */
#titlebar, .titlebar-color, .titlebar-spacer, .titlebar-buttonbox-container, .titlebar-button,
#navigator-toolbox, toolbox, toolbar, .toolbar,
#tabs-toolbar, #toolbar-menubar, #main-menubar,
#zotero-items-toolbar, #zotero-collections-toolbar, #zotero-toolbar-collection-tree,
#zotero-reader-toolbar, #zotero-tabbar, .zotero-tabbar, #tabbar-toolbar,
#zotero-title-bar, #zotero-tabs-toolbar { -moz-appearance:none !important; background:#000 !important; color:#fff !important; border:none !important; }

/* Abas */
tabs, tab, .tab, .tabbrowser-tab, .tab-stack, .tab-background, .tab-content { background:#000 !important; color:#fff !important; border-color:#111 !important; }
tab[selected], .tab[selected], .tabbrowser-tab[selected] { background:#0a0a0a !important; }

/* Barra de abas (containers) */
#tab-bar-container, #tab-bar-container > div, #tab-bar-container .tab-bar-inner-container,
#tab-bar-container .tabs-wrapper, #tab-bar-container .tabs,
#browser, #zotero-tab-cover { background:#000 !important; color:#fff !important; border:none !important; }
#tab-bar-container .tab, #tab-bar-container .tab .tab-content { background:#000 !important; color:#fff !important; border-color:#111 !important; }
#tab-bar-container .splitter, #tab-bar-container .divider, #tab-bar-container .tab::after, #tab-bar-container .tab::before { background:#000 !important; border-color:#000 !important; }

/* Pesquisa / inputs */
textbox, search-textbox, input, textarea, menulist,
#zotero-search, #zotero-quicksearch, .search-container, .textbox-input-box, .textbox-search-icons { background:#000 !important; color:#fff !important; border:1px solid #222 !important; }
textbox::placeholder, input::placeholder, textarea::placeholder { color:#bbb !important; }
#zotero-tb-search-textbox, #zotero-tb-search-textbox > .textbox-input-box { background:#000 !important; color:#fff !important; border:1px solid #222 !important; }

/* Árvores / tabelas */
tree, treechildren, .treecol, .treecol-text,
.virtualized-table, .virtualized-table .header, .virtualized-table-header,
.virtualized-table .row, .virtualized-table .cell, .virtualized-table .cell .cell-text { background:#000 !important; color:#fff !important; border-color:#111 !important; }
.virtualized-table .row:hover { background:#0a0a0a !important; }
.virtualized-table .row.selected { background:#111 !important; }

/* Painéis principais */
#zotero-main-content, #zotero-collections-tree, #zotero-items-tree, #zotero-collections-pane,
#zotero-pane, #zotero-view-item, .zotero-view-item, .zotero-view-item-main,
.zotero-view-tabbox, .zotero-item-pane-content, #zotero-item-pane,
#zotero-tag-selector-container, .zotero-search-container, context-pane, #zotero-context-pane-inner { background:#000 !important; color:rgba(255,255,255,.87) !important; border:none !important; }

/* Cabeçalhos custom */
.custom-head, .custom-head.empty { background:#000 !important; color:#fff !important; }

/* Sidenav do item */
#zotero-view-item-sidenav, item-pane-sidenav, .zotero-view-item-sidenav { background:#000 !important; color:#fff !important; border:none !important; }
#zotero-view-item-sidenav .tab, #zotero-view-item-sidenav .tab[selected], #zotero-view-item-sidenav button, #zotero-view-item-sidenav .tab:hover { background:#000 !important; color:#fff !important; border-color:#111 !important; }

/* Splitters / bordas */
splitter, .splitter, .sidebar-splitter { background:#000 !important; border-color:#111 !important; }

/* Menus e popups — highlight visível */
menupopup, menu, menuitem, panel, tooltip { -moz-appearance:none !important; background:#000 !important; color:#fff !important; border:1px solid #111 !important; }
menuitem[_moz-menuactive="true"], menu[_moz-menuactive="true"], menupopup menuitem:hover, menulist > menupopup > menuitem[selected="true"] { background:#1f1f1f !important; color:#fff !important; }
menuitem[disabled], menuitem[disabled="true"] { color:#666 !important; }

/* Botões de toolbar e estados */
toolbarbutton, .toolbarbutton-1, button { background:transparent !important; color:#fff !important; border:none !important; }
toolbarbutton:hover, .toolbarbutton-1:hover, button:hover { background:#0a0a0a !important; }
toolbarbutton:active, .toolbarbutton-1:active, button:active, toolbarbutton[open="true"], .toolbarbutton-1[open="true"] { background:#111 !important; }
#zotero-tb-sync { background:transparent !important; color:#fff !important; }
#zotero-tb-sync:hover { background:#0a0a0a !important; }
#zotero-tb-sync:active, #zotero-tb-sync[open="true"] { background:#111 !important; }
#zotero-tb-sync[disabled], #zotero-tb-sync[disabled="true"] { color:#666 !important; }

/* Banners e avisos */
.banner-container, .banner, #sync-reminder-banner, #post-upgrade-banner,
#mac-word-plugin-install-container, #mac-word-plugin-install-banner,
#file-renaming-banner-container, #architecture-warning-container,
#post-upgrade-container, #retracted-items-banner, #retraction-header, #retraction-details,
#zotero-plugin-toolkit-prompt, .prompt-container { background:#000 !important; color:#fff !important; border:1px solid #111 !important; }

/* Caixas diversas */
#zotero-pane-progress-box, #zotero-lookup-multiline-progress, progress, richlistbox, #zotero-duplicates-merge-original-date { background:#000 !important; color:#fff !important; border:1px solid #111 !important; }
progress::-moz-progress-bar { background:#333 !important; }

/* Scrollbars */
:root { scrollbar-color:#444 #000 !important; }

/* Seleção em trees antigas */
treechildren::-moz-tree-row(selected) { background:#111 !important; }
treechildren::-moz-tree-cell-text(selected) { color:#fff !important; }

/* Correção final — Campo de busca da barra superior */
#zotero-tb-search-textbox,
#zotero-tb-search-textbox > .textbox-input-box,
#zotero-tb-search-textbox > .textbox-input-box > html|input,
#zotero-tb-search-textbox > .textbox-input-box > input,
#zotero-tb-search-textbox .textbox-search-icons {
  -moz-appearance: none !important;
  background: #000 !important;
  color: #fff !important;
  border: 1px solid #222 !important;
  box-shadow: none !important;
}

#zotero-tb-search-textbox:hover,
#zotero-tb-search-textbox:focus-within {
  background: #000 !important;
  border-color: #444 !important;
}

#zotero-tb-search-textbox::placeholder,
#zotero-tb-search-textbox > .textbox-input-box::placeholder,
#zotero-tb-search-textbox input::placeholder {
  color: #bbb !important;
}

/* --- PATCH: área "Todos os campos e etiquetas" --- */
#zotero-tb-search-textbox menulist,
#zotero-tb-search-textbox menulist > menulist-editable-box,
#zotero-tb-search-textbox menulist > menulist-editable-box > html|input,
#zotero-tb-search-textbox menulist > menulist-editable-box > html|div,
#zotero-tb-search-textbox menulist > menulist-editable-box > html|span {
  -moz-appearance: none !important;
  background: #000 !important;
  color: #fff !important;
  border: 1px solid #333 !important;
  box-shadow: none !important;
}

/* Dropmarker */
#zotero-tb-search-textbox menulist dropmarker {
  -moz-appearance: none !important;
  background: #000 !important;
  border-left: 1px solid #333 !important;
  padding: 0 4px !important;
}

/* Hover e foco */
#zotero-tb-search-textbox menulist:hover,
#zotero-tb-search-textbox menulist:focus-within {
  background: #0a0a0a !important;
  border-color: #666 !important;
}

/* Anti-cinza geral dentro do search-textbox */
#zotero-tb-search-textbox,
#zotero-tb-search-textbox * {
  -moz-appearance: none !important;
  background-image: none !important;
}

/* Bloco do menulist do filtro */
#zotero-tb-search-textbox menulist,
#zotero-tb-search-textbox menulist > * ,
#zotero-tb-search-textbox .menulist-label-box,
#zotero-tb-search-textbox .menulist-label,
#zotero-tb-search-textbox .menulist-dropmarker {
  -moz-appearance: none !important;
  background: #000 !important;
  color: #fff !important;
  border: 0 !important;
  box-shadow: none !important;
}

/* Caixa dos ícones à esquerda */
#zotero-tb-search-textbox .textbox-search-icons,
#zotero-tb-search-textbox .textbox-search-icon,
#zotero-tb-search-textbox .textbox-search-clear {
  -moz-appearance: none !important;
  background: #000 !important;
  border: 0 !important;
  box-shadow: none !important;
}

/* Divisor sutil */
#zotero-tb-search-textbox menulist { border-right: 1px solid #333 !important; }

/* Campo de texto contínuo preto */
#zotero-tb-search-textbox > .textbox-input-box,
#zotero-tb-search-textbox > .textbox-input-box > html|input {
  -moz-appearance: none !important;
  background: #000 !important;
  color: #fff !important;
  border: 0 !important;
  box-shadow: none !important;
  background-clip: padding-box !important;
}

/* --- ::part(search-input) --- */
#zotero-tb-search-textbox::part(search-input),
#zotero-tb-search-textbox input[part="search-input"] {
  -moz-appearance: none !important;
  background: #000 !important;
  color: #fff !important;
  border: 1px solid #333 !important;
  box-shadow: none !important;
  outline: none !important;
  background-image: none !important;
}
#zotero-tb-search-textbox::part(search-input)::placeholder,
#zotero-tb-search-textbox input[part="search-input"]::placeholder {
  color: #aaa !important;
}
#zotero-tb-search-textbox:focus-within::part(search-input),
#zotero-tb-search-textbox:focus-within input[part="search-input"],
#zotero-tb-search-textbox:hover::part(search-input),
#zotero-tb-search-textbox:hover input[part="search-input"] {
  border-color: #666 !important;
}
#zotero-tb-search-textbox input[part="search-input"]::-moz-text-control-editing-root,
#zotero-tb-search-textbox input[part="search-input"]::-moz-field {
  background: #000 !important;
  color: #fff !important;
}

/* Kernel do campo e seleção */
#zotero-tb-search-textbox,
#zotero-tb-search-textbox::part(search-input),
#zotero-tb-search-textbox input[part="search-input"] {
  -moz-appearance: none !important;
  background: #000 !important;
  color: #fff !important;
  border: 1px solid #333 !important;
  border-radius: 6px !important;
  background-clip: padding-box !important;
  background-image: none !important;
  box-shadow: none !important;
  outline: none !important;
  border-image: none !important;
  filter: none !important;
  caret-color: #fff !important;
}
#zotero-tb-search-textbox input[part="search-input"]::-moz-text-control-editing-root,
#zotero-tb-search-textbox input[part="search-input"]::-moz-field {
  background: #000 !important;
  color: #fff !important;
  background-image: none !important;
  border: 0 !important;
  box-shadow: none !important;
}
#zotero-tb-search-textbox::part(search-input)::placeholder,
#zotero-tb-search-textbox input[part="search-input"]::placeholder { color: #aaa !important; }
#zotero-tb-search-textbox::part(search-input)::selection,
#zotero-tb-search-textbox input[part="search-input"]::selection { background: #224 !important; color: #fff !important; }

/* Menulist acoplado ao filtro */
#zotero-tb-search-textbox menulist,
#zotero-tb-search-textbox menulist > menulist-editable-box,
#zotero-tb-search-textbox menulist > menulist-editable-box > html|input,
#zotero-tb-search-textbox menulist dropmarker {
  -moz-appearance: none !important;
  background: #000 !important;
  color: #fff !important;
  border: 0 !important;
  border-image: none !important;
  background-image: none !important;
  box-shadow: none !important;
}
#zotero-tb-search-textbox menulist { border-right: 1px solid #333 !important; }

/* ===== Shadow DOM host ===== */
#zotero-tb-search-textbox,
search-textbox#zotero-tb-search-textbox {
  background: #000 !important;
  background-color: #000 !important;
  background-image: none !important;
  color: #fff !important;
  border: 1px solid #333 !important;
  -moz-appearance: none !important;
}
/* Leitor integrado (PDF) */
#reader-ui,
#reader-ui .toolbar,
#reader-ui .toolbar *,
#reader-ui .titlebar {
  background: #000 !important;
  background-image: none !important;
  background-color: #000 !important;
  color: #fff !important;
  border-color: #111 !important;
  fill: #fff !important;
  box-shadow: none !important;
}
#reader-ui .toolbar toolbarbutton,
#reader-ui .toolbar .toolbarbutton-icon,
#reader-ui .toolbar .toolbarbutton-text,
#reader-ui .toolbar .toolbarbutton-badge {
  color: #fff !important;
  fill: #fff !important;
}
#reader-ui .toolbar toolbarbutton:hover,
#reader-ui .toolbar button.toolbar-button:hover {
  background: #0a0a0a !important;
}
#outerContainer,
#outerContainer * {
  background-color: #000 !important;
  color: #fff !important;
}
#outerContainer .page,
#outerContainer canvas {
  background-color: #111 !important;
}
#outerContainer .textLayer span {
  color: #fff !important;
}
#outerContainer .highlightLayer .highlightSelection,
#outerContainer .highlightLayer .annotationLayer {
  mix-blend-mode: normal !important;
}
#viewerContainer {
  background-color: #000 !important;
}
#reader-ui .toolbar,
#reader-ui .toolbar * {
  color: #fff !important;
  fill: #fff !important;
}
#reader-ui .toolbar .center.tools,
#reader-ui .toolbar .end,
#reader-ui .toolbar .end * {
  color: #fff !important;
}
#reader-ui .toolbar button.toolbar-button,
#reader-ui .toolbar button.toolbar-button *,
#reader-ui .toolbar toolbarbutton,
#reader-ui .toolbar toolbarbutton * {
  background: #000 !important;
  background-image: none !important;
  color: #fff !important;
  fill: #fff !important;
  border: 1px solid #333 !important;
  box-shadow: none !important;
  border-radius: 6px !important;
}
#reader-ui .toolbar button.toolbar-button:hover,
#reader-ui .toolbar toolbarbutton:hover {
  background: #111 !important;
  color: #fff !important;
}
#reader-ui .toolbar button.toolbar-button svg path,
#reader-ui .toolbar button.toolbar-button svg g path,
#reader-ui .toolbar toolbarbutton svg path,
#reader-ui .toolbar button.toolbar-button svg g polygon,
#reader-ui .toolbar button.toolbar-button svg polygon {
  fill: #fff !important;
  stroke: #fff !important;
}
#reader-ui .toolbar div.divider {
  background: #111 !important;
}

/* Parts do Shadow DOM */
#zotero-tb-search-textbox::part(search-input) {
  background: #000 !important;
  color: #fff !important;
  caret-color: #fff !important;
  border: 0 !important;
  -moz-appearance: none !important;
}
#zotero-tb-search-textbox::part(search-input)::placeholder { color: #aaa !important; }
#zotero-tb-search-textbox::part(search-sign),
#zotero-tb-search-textbox::part(clear-icon) {
  background: transparent !important;
  filter: invert(1) brightness(0.8) !important;
}
EOT

echo "5) Feito."
echo "Deixe o tema nativo do Zotero em 'Escuro', reinicie o aplicativo e verifique a barra de busca."


echo ""
echo "Snippet para inspeção (cole no Console do Zotero e pressione Enter):"
cat <<'JS_INSPECT'
(() => {
  const doc = window.document;
  const overlay = doc.createElement('div');
  overlay.style.cssText = 'position:fixed;pointer-events:none;z-index:2147483647;border:2px solid #3cf;background:rgba(51,204,255,0.12);transition:all 0.08s ease;';
  const label = doc.createElement('div');
  label.style.cssText = 'position:fixed;pointer-events:none;z-index:2147483648;background:#000;padding:4px 6px;border-radius:4px;font:12px monospace;color:#0ff;max-width:420px;white-space:pre-wrap;box-shadow:0 2px 12px rgba(0,0,0,.7);';
  doc.documentElement.appendChild(overlay);
  doc.documentElement.appendChild(label);
  let lastLoggedSelector = null;

  function describe(el) {
    if (!el || el.nodeType !== 1) {
      return '';
    }
    const parts = [];
    let node = el;
    while (node && node.nodeType === 1 && parts.length < 4) {
      let selector = node.tagName.toLowerCase();
      if (node.id) {
        selector += '#' + node.id;
      } else if (node.classList && node.classList.length) {
        selector += '.' + Array.from(node.classList).slice(0, 3).join('.');
      }
      parts.unshift(selector);
      node = node.parentElement;
    }
    return parts.join(' > ');
  }

  function positionLabel(rect) {
    const labelRect = label.getBoundingClientRect();
    let top = rect.bottom + 6;
    if (top + labelRect.height > window.innerHeight) {
      top = rect.top - labelRect.height - 6;
    }
    let left = rect.left;
    if (left + labelRect.width > window.innerWidth) {
      left = window.innerWidth - labelRect.width - 6;
    }
    if (left < 6) left = 6;
    if (top < 6) top = 6;
    label.style.left = `${left}px`;
    label.style.top = `${top}px`;
  }

  function onMove(event) {
    const el = event.target;
    if (!el || el === overlay || el === label) {
      return;
    }
    const rect = el.getBoundingClientRect();
    overlay.style.opacity = '1';
    overlay.style.left = `${rect.left}px`;
    overlay.style.top = `${rect.top}px`;
    overlay.style.width = `${rect.width}px`;
    overlay.style.height = `${rect.height}px`;
    const styles = window.getComputedStyle(el);
    const selector = describe(el);
    const info = `${selector}
background: ${styles.backgroundColor}
color: ${styles.color}`;
    label.textContent = info;
    if (selector && selector !== lastLoggedSelector) {
      console.log('[Zotero AMOLED Inspector]', selector, '| background:', styles.backgroundColor, '| color:', styles.color);
      lastLoggedSelector = selector;
    }
    positionLabel(rect);
  }

  function cleanup() {
    window.removeEventListener('mousemove', onMove, true);
    window.removeEventListener('keydown', onKey, true);
    window.removeEventListener('click', onClick, true);
    overlay.remove();
    label.remove();
    console.log('[Zotero AMOLED] Inspector encerrado.');
  }

  function onKey(event) {
    if (event.key === 'Escape') {
      cleanup();
    }
  }

  function onClick(event) {
    event.preventDefault();
    event.stopPropagation();
    cleanup();
  }

  window.addEventListener('mousemove', onMove, true);
  window.addEventListener('keydown', onKey, true);
  window.addEventListener('click', onClick, true);
  console.log('[Zotero AMOLED] Passe o mouse para inspecionar. Clique ou ESC para sair.');
})();
JS_INSPECT

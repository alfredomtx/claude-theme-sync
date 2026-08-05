

# Claude Theme Sync

Sincroniza automáticamente el tema de [Claude Code](https://claude.ai/code) con el modo oscuro/claro de macOS.

Al cambiar la apariencia de macOS, este daemon actualiza instantáneamente la configuración del tema de Claude Code para que tu próxima sesión coincida con el tema del sistema.

## Instalación

```bash
git clone https://github.com/alfredomtx/claude-theme-sync.git
cd claude-theme-sync
./install.sh
```

¡Eso es todo! El daemon ya se está ejecutando y se iniciará automáticamente al iniciar sesión.

## Requisitos

- macOS
- Herramientas de línea de comandos de Xcode (`xcode-select --install`)
- [Claude Code](https://claude.ai/code)

## ¿Cómo funciona?

1. Un daemon ligero en Swift escucha las notificaciones de cambio de tema de macOS
2. Cuando cambia el tema del sistema, actualiza `~/.claude.json` con el tema correspondiente
3. Todas las sesiones de Claude Code se actualizan en tiempo real

## Comandos

```bash
# Verificar si está en ejecución
launchctl list | grep claude-theme-sync

# Ver registros
tail -f ~/.claude/theme-sync/claude-theme-sync.log

# Reiniciar
launchctl unload ~/Library/LaunchAgents/com.claude.theme-sync.plist
launchctl load ~/Library/LaunchAgents/com.claude.theme-sync.plist
```

## Desinstalación

```bash
~/.claude/theme-sync/uninstall.sh
```

## Detalles técnicos

Claude Code almacena su preferencia de tema en `~/.claude.json`:

```json
{
  "theme": "dark",
  ...
}
```

Este daemon monitorea `AppleInterfaceThemeChangedNotification` y actualiza ese campo cuando cambia la apariencia de macOS.

## Licencia

MIT

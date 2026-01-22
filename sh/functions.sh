# call PDM functionality to activate venv.
# If no arg is supplied, return default pdm venv (usually `.venv/`)
function pdm-activate(){
  eval $(pdm venv activate "$1")
}

# load envfile in arg1, if not supplied, defaults to ".env"
function dotenv(){
  local envfile="${1:-.env}"
  set -a; source $envfile; set +a
}

function load_aa_env(){
  env_script="$HOME/.config/.global-env/env.sh"
  [ -f "$env_script" ] && \
  . "$env_script"
}

print_dir_and_subdirs() {
  echo "BASE_DIR=$1"
  for d in "$1"/*/; do
    [ -d "$d" ] && echo "SUBDIR=$(basename "$d")"
  done
}

notify-toast() {
    # Send Windows toast notifications from WSL
    #
    # Usage: notify-toast [OPTIONS] "title" "body"
    #
    # Options:
    #   --error, -e       Persistent alarm-style notification (stays until dismissed)
    #   --success, -s     Normal notification (default)
    #   --warning, -w     Long duration notification (~25 seconds)
    #   --url URL         Add button to open URL in browser
    #   --persistent, -p  Stay until manually dismissed (implies --error style)
    #
    # Examples:
    #   notify-toast "Build Complete" "No errors found"
    #   notify-toast --error "Build Failed" "Check terminal"
    #   notify-toast --url "https://example.com" "Done" "Click to view"

    local type="success"
    local url=""
    local persistent=false
    local title body title_escaped body_escaped toast_xml

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --error|-e)
                type="error"
                shift
                ;;
            --success|-s)
                type="success"
                shift
                ;;
            --warning|-w)
                type="warning"
                shift
                ;;
            --url)
                url="$2"
                shift 2
                ;;
            --persistent|-p)
                persistent=true
                shift
                ;;
            -*)
                echo "Unknown option: $1" >&2
                return 1
                ;;
            *)
                break
                ;;
        esac
    done

    title="${1:-Notification}"
    body="${2:-}"

    # Escape special characters for XML
    _notify_escape_xml() {
        local s="$1"
        s="${s//&/&amp;}"
        s="${s//</&lt;}"
        s="${s//>/&gt;}"
        s="${s//\"/&quot;}"
        s="${s//\'/&apos;}"
        printf '%s' "$s"
    }

    title_escaped=$(_notify_escape_xml "$title")
    body_escaped=$(_notify_escape_xml "$body")

    # Build the toast XML based on type
    if [[ "$type" == "error" ]] || [[ "$persistent" == true ]]; then
        # Persistent alarm-style toast
        toast_xml="<toast scenario='alarm'>"
        toast_xml+="<visual><binding template='ToastGeneric'>"
        toast_xml+="<text>$title_escaped</text>"
        [[ -n "$body_escaped" ]] && toast_xml+="<text>$body_escaped</text>"
        toast_xml+="</binding></visual>"
        toast_xml+="<actions>"
        if [[ -n "$url" ]]; then
            toast_xml+="<action content='Open' activationType='protocol' arguments='$url'/>"
        fi
        toast_xml+="<action content='Dismiss' arguments='dismiss' activationType='background'/>"
        toast_xml+="</actions>"
        toast_xml+="<audio src='ms-winsoundevent:Notification.Default'/>"
        toast_xml+="</toast>"
    elif [[ "$type" == "warning" ]]; then
        # Long duration toast
        toast_xml="<toast duration='long'>"
        toast_xml+="<visual><binding template='ToastGeneric'>"
        toast_xml+="<text>$title_escaped</text>"
        [[ -n "$body_escaped" ]] && toast_xml+="<text>$body_escaped</text>"
        toast_xml+="</binding></visual>"
        if [[ -n "$url" ]]; then
            toast_xml+="<actions>"
            toast_xml+="<action content='Open' activationType='protocol' arguments='$url'/>"
            toast_xml+="</actions>"
        fi
        toast_xml+="<audio src='ms-winsoundevent:Notification.Default'/>"
        toast_xml+="</toast>"
    else
        # Normal success toast
        toast_xml="<toast>"
        toast_xml+="<visual><binding template='ToastGeneric'>"
        toast_xml+="<text>$title_escaped</text>"
        [[ -n "$body_escaped" ]] && toast_xml+="<text>$body_escaped</text>"
        toast_xml+="</binding></visual>"
        if [[ -n "$url" ]]; then
            toast_xml+="<actions>"
            toast_xml+="<action content='Open' activationType='protocol' arguments='$url'/>"
            toast_xml+="</actions>"
        fi
        toast_xml+="<audio src='ms-winsoundevent:Notification.Default'/>"
        toast_xml+="</toast>"
    fi

    # PowerShell command to show the toast
    powershell.exe -Command - <<PWSH
\$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
\$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

\$xml = @'
$toast_xml
'@

\$XmlDocument = [Windows.Data.Xml.Dom.XmlDocument]::new()
\$XmlDocument.LoadXml(\$xml)
\$AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$AppId).Show(\$XmlDocument)
PWSH
}

# XDG_CONFIG_HOME normalization: fish and git already fall back to
# $HOME/.config themselves when this is unset (see install.sh's
# ${XDG_CONFIG_HOME:-$HOME/.config}), but abbreviations (nav.fish's cdc/cdcf)
# expand as literal text and can't inline that fallback -- make the default
# explicit here, once, so they have something to reference. No-op wherever
# XDG_CONFIG_HOME is already set to something else (e.g. this Beacon
# container, which points it off $HOME entirely onto durable NFS storage).
if not set -q XDG_CONFIG_HOME
    set -gx XDG_CONFIG_HOME "$HOME/.config"
end

# clauder: relocate its own durable storage to the workspace mount when
# running inside a Beacon container -- $BEACON_USER_DIR only exists there,
# and unlike $HOME (wiped/regenerated on every container recreate) it's
# NFS-backed and survives. Unset everywhere else (the Mac), so this is a
# no-op there. See workbench's src/clauder/paths.py for what it controls.
if set -q BEACON_USER_DIR
    set -gx CLAUDER_USER_HOME $BEACON_USER_DIR
end

function remove_substring_from_path
    set substring $argv[1]
    set matching_indices
    for i in (seq (count $PATH))
        set path_i $PATH[$i]
        if string match --quiet --regex ".*$substring.*" $path_i
            set -a matching_indices $i
        end
    end
    if test -n "$matching_indices"
        echo "remove_substring_from_path: removing the following paths from PATH"
        echo $PATH[$matching_indices]
        set -e PATH[$matching_indices]
    end
end



function lndir
    # directory which will be linked, relative or absolute
    set -l target_directory $argv[1]
    # directory into which the link will be placed, absolute
    set -l symlink_name $argv[2]

    # the symlink will have the same name as the target directory
    
    # Check if both arguments are provided
    if test -z "$target_directory" -o -z "$symlink_name"
        echo "Usage: lndir target_directory symlink_name"
        return 1
    end

    # # Check if symlink_name exists
    # if test -e "$symlink_name"
    #     # If it exists, check if it's a directory
    #     if test ! -d "$symlink_name"
    #         echo "symlink_name must be a directory."
    #         return 1
    #     end

    #     # If it's a directory, check if it's empty
    #     if test -n "$(ls -A $symlink_name)"
    #         echo "symlink_name must be an empty directory."
    #         return 1
    #     end
    # else
    #     # If symlink_name doesn't exist, create an empty directory
    #     echo "symlink_name does not exist, creating an empty directory."
    #     mkdir -p "$symlink_name"
    # end

    # Create a symbolic link with an absolute target path
    ln -s (readlink -f "$target_directory") "$symlink_name"
end


# load envfile in arg1, if not supplied, defaults to ".env"
function dotenv
  set -f envfile (if test -n "$argv"; echo $argv[1]; else; echo .env; end)
  # set -gx -a; source $envfile; set -e -gx
  if not test -f "$envfile"
    echo "Unable to load $envfile"
    return 1
  end
  echo "Loading $envfile"
  echo "Exporting keys:"
  for line in (cat $envfile | grep -v '^#' | grep -v '^\s*$')
    set item (string split -m 1 '=' $line)
    set -gx $item[1] $item[2]
    echo "  $item[1]"
  end
end

function load_aa_env
  set env_script ~/.config/.global-env/env.sh
  if functions -q bass
      bass source $env_script
  else
        set_color red
        echo "Install 'bass' to import POSIX env into fish."
        set_color normal
        return 1
    end
end

# `.dotfiles/`

General personal system config files

## Setup

```
git clone clone_url path/
```

Add to shell config file


#### bash

`.bashrc`
```bash
dotfile_directory="path/"
source "${dotfile_directory}/sh/{file-to-import}.sh"
```

#### fish

`~/.config/fish/config.fish`
```sh
DOTFILE_DIR=$HOME/.config/.dotfiles/fish source $DOTFILE_DIR/.fish
```
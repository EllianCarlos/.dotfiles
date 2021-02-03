#!/bin/bash
for filename in "$@"
do
    if [ -e ~/.dotfiles/$filename -o -d ~/.dotfiles/$filename ]; then
        [ -d $filename ] && echo "$filename é um diretório."
        echo "Criando $filename"
        ln -sv ~/.dotfiles/$filename ~/$filename
    else
        echo "$filename não encontrado";
    fi
done
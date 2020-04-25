#!/bin/bash

# intento de instalar los paquetes mencionados en la lista packages-extra.md

# --- instalación desde los repositorios oficiales de Arch Linux
packagelist_install=(
    ## Edtitores de código e IDEs
    atom
    # code # visual studio code (no instalar hasta comprobar si es bueno)
    dbeaver
    eclipse-java

    ## Juegos
    # hace falta instalar lib32-mesa (para procesadores intel) del repositorio
    # multilib para steam
    ttf-liberation # dependencia para steam
    steam # check diference between steam-native-runtime
    # mgba-sdl
    # 0ad
    # openttd
    openra

    ## Cryptomonedas
    # bitcoin core
    # bitcoin-qt

    ## Navegadores
    # firefox-developer-edition

    ## Chats y voideoconferencias
    telegram-desktop
    discord

    ## Máquinas virtuales
    virtualbox-host-modules-arch # para el kernel versión linux de arch
    virtualbox

    ## Emular Windows (necesitas habilitar el repositorio multilib en pacman.conf)
    # wine
    # winetricks

    # Conectar con Android (dispositivos móviles)
    kdeconnect
)

pacman -Syu
pacman -S --needed ${packagelist_install[@]}
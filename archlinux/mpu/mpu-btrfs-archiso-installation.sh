# mpu btrfs (systemd-boot) ARCHISO

# -- comprobación de red DHCP (por cable)
ping archlinux.org

# -- activamos el servidor SSH y configuramos una contraseña para root
# por si queremos realizar la instalación de forma remota
systemctl start sshd
passwd

# -- verificamos que entramos en modo UEFI
ls /sys/firmware/efi/efivars

# -- activamos el servidor ntp para la hora
timedatectl set-ntp true
timedatectl status # (verificación)

# -- inicio del particionado y formateo de los HDDs ----------------------------
lsblk

# - tabla de particiones GPT (systemd-boot)
# https://wiki.archlinux.org/index.php/EFI_system_partition#GPT_partitioned_disks
# https://fhackts.wordpress.com/2016/09/09/installing-archlinux-the-efisystemd-boot-way/
# https://gtronick.github.io/ALIG/
# NAME        SIZE  TYPE                    MOUNTPOINT
# sda       931,5G  disk
#   sda1    512,0M  part EFI System (ESP)   /boot
#   sda2      4,0G  part                    [SWAP]
#   sda3     80,0G  part                    /
#   sda4    846,9G  part                    /home

fdisk /dev/sda
# comandos de fdisk:
# m (listamos la ayuda)
# g (generamos una tabla GPT)
# n (creamos sda1)
# t (se selecciona automaticamente la única particion creada)
# 1 (cambiamos el tipo a EFI System)
# n (creamos sda2)
# n (creamos sda3)
# n (creamos sda4)
# p (mostramos cómo va a quedar el resultado)
# w (escribimos los cambios y salimos)

lsblk -fm
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mkfs.btrfs -L ROOT /dev/sda3
mkfs.btrfs -L HOME /dev/sda4

# montamos de forma correcta las particiones sobre el sistema de archivos a configurar
mount /dev/sda3 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir /mnt/home
mount /dev/sda4 /mnt/home
lsblk -fm

# -- instalamos el sistema base en el disco particionado (pensar en que
# paquetes son necesarios aquí desde el principio)
nano /etc/pacman.d/mirrorlist
# agregar al principio de todo la linea:
# Server = http://mirror.librelabucm.org/archlinux/$repo/os/$arch
pacman -Syy # refrescamos los repositorios al cambiar el mirrorlist
pacstrap /mnt base base-devel linux linux-firmware dosfstools exfat-utils btrfs-progs e2fsprogs ntfs-3g man-db man-pages texinfo sudo git nano

# -- generamos el fstab tal cual como lo tenemos montado en la instalación
genfstab -U /mnt >> /mnt/etc/fstab

# -- nos impersonamos como root en nuestro sistema de archivos a instalar
arch-chroot /mnt
# CHROOT MODE

# asignamos una contrseña a root
passwd

# creamos y configuramos un nuevo usuario para podrer instalar paquetes desde AUR
useradd -s /bin/bash -m cosmo # considerar quitar la opción -m (create_home)
passwd cosmo
env EDITOR=nano visudo
# agregar la siguiente linea:
# cosmo ALL=(ALL) ALL
# Si recreamos /home/cosmo manualmente hay que ejecutar:
# chown cosmo:cosmo /home/cosmo # considerar poner -R

# instalamos, habilitamos y ejecutamos ssh para poder continuar con la
# instalación desde otro pc de forma remota
pacman -S openssh
systemctl enable sshd

# configuramos la hora (no se porqué esto no funcinó bien la primera vez y
# luego tuve que volver a configurarlo desde gnome)
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc

# configuramos el idioma por defecto del equipo
nano /etc/locale.gen
# descomentamos:
# en_US.UTF-8 UTF-8
# es_ES.UTF-8 UTF-8
locale-gen
echo "LANG=es_ES.UTF-8" > /etc/locale.conf

# ponemos nombre al equipo
echo "mpu" > /etc/hostname
nano /etc/hosts
# - agregar las siguientes lineas
# 127.0.0.1	localhost
# ::1		localhost
# 127.0.1.1	mpu.jamaica.a3do.net	mpu

# instalamos y habilitamos el demonio más básico de dhcp para que al reiniciar
# no nos quedemos sin internet
pacman -S dhcpcd
systemctl enable dhcpcd

# --- módulos de kernel necesarios
# agregamos el módulo i915 al kernel de Linux y lo volvemos a configurar
# esto es para cargar KMS lo antes posible al inicio del boot
# https://wiki.archlinux.org/index.php/Kernel_mode_setting_(Espa%C3%B1ol)
nano /etc/mkinitcpio.conf
# modificar la linea MODULES=() --> MODULES=(i915)
mkinitcpio -p linux
# comprobar aquí si falta algún módulo por cargar para este hardware específico

# --- INICIO DE COMANDOS EXCLUSIVOS PARA MPU -----------------------------------
# (https://gist.github.com/imrvelj/c65cd5ca7f5505a65e59204f5a3f7a6d)
# solución para el error:
# Possibly missing firmware for module: aic94xx
# Possibly missing firmware for module: wd719x
su cosmo
mkdir -p ~/Work/aur
cd ~/Work/aur
git clone https://aur.archlinux.org/aic94xx-firmware.git; \
cd aic94xx-firmware; \
makepkg -sri; \
cd ..
git clone https://aur.archlinux.org/wd719x-firmware.git; \
cd wd719x-firmware; \
makepkg -sri; \
cd ..
# según los foros este no es necesario
# pero a mi me funciona para quitar este WARNING al compilar el nucleo
# ==> WARNING: Possibly missing firmware for module: xhci_pci
git clone https://aur.archlinux.org/upd72020x-fw.git; \
cd upd72020x-fw; \
makepkg -sri; \
cd ..
exit
mkinitcpio -p linux

# --- FINAL DE COMANDOS EXCLUSIVOS PARA MPU ------------------------------------

# --- GESTOR DE ARRANQUE DEL SISTEMA -------------------------------------------

# instalamos y habilitamos las actualizacionse tempranas de microcodigo
# para procesadores intel
pacman -S intel-ucode

# -- instalación de GRUB (lo dejo por si acaso)
pacman -S grub
grub-install --target=i386-pc /dev/sda # instalación para particiones MBR (MSDOS)
# editamos los boot parameters del kernel al iniciarlo, explicaciones:
# https://wiki.archlinux.org/index.php/Kernel_parameters_(Espa%C3%B1ol)
# https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html
# https://wiki.archlinux.org/index.php/Improving_performance#Watchdogs
# https://wiki.archlinux.org/index.php/Intel_graphics#Enable_early_KMS
nano /etc/default/grub
# editando la linea GRUB_CMDLINE_LINUX_DEFAULT para dejarla así:
# GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 nowatchdog i915.enable_guc=2"
# de paso, también reducimos el tiempo de espera en la pantalla de grub
# GRUB_TIMEOUT=2
grub-mkconfig -o /boot/grub/grub.cfg

# -- instalación systemd-boot
bootctl --path=/boot install
# Generar archivo de configuración de systemd-boot:
nano /boot/loader/loader.conf
# - Agregamos las siguientes líneas
# default arch
# timeout 0
# editor 0

# Generar el archivo de la entrada por defecto para systemd-boot:
echo $(blkid -s PARTUUID -o value /dev/sda3) > /boot/loader/entries/arch.conf
nano /boot/loader/entries/arch.conf
# - Se debe agregar lo siguiente, de manera que el serial generado, 
#   quede después de PARTUUID y antes de rw, como sigue:
# title ArchLinux
# linux /vmlinuz-linux
# initrd /intel-ucode.img 
# initrd /initramfs-linux.img
# options root=PARTUUID=14420948-2cea-4de7-b042-40f67c618660 rw
# - La línea: initrd /intel-ucode.img, sólo se debe poner cuando se ha instalado intel-ucode

# --- FIN GESTOR DE ARRANQUE DEL SISTEMA ---------------------------------------

# salimos del entorno chroot, y volvemos al instalador de arch (archiso)
exit
# BACK TO ARCHISO

# desmontamos con seguridad el entorno de instalación
sync
umount -R /mnt

# reiniciamos
reboot

# extraemos el medio de instalación (USB o CD/DVD)

# continuar con los pasos de mpu-first-boot-configs.sh

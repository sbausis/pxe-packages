
set -e

MIRROR=${MIRROR-"ch"}
SUITE=${SUITE-"wheezy"}
ARCH=${ARCH-"amd64"}
INTERFACE=${INTERFACE-""}

MIRROR_URL="http://ftp.${MIRROR}.debian.org/debian"
SUITE_URL="dists/${SUITE}/main"
ARCH_URL="installer-${ARCH}/current/images/netboot/${INTERFACE}"

URL="${MIRROR_URL}/${SUITE_URL}/${ARCH_URL}"

mkdir -p debian/${SUITE}/netinst/${ARCH}/${INTERFACE}

wget -O /tmp/${SUITE}_${ARCH}_netboot.tar.gz ${URL}/netboot.tar.gz
mkdir -p /tmp/${SUITE}_${ARCH}_netboot
tar -xzf /tmp/${SUITE}_${ARCH}_netboot.tar.gz -C /tmp/${SUITE}_${ARCH}_netboot

cp -f /tmp/${SUITE}_${ARCH}_netboot/debian-installer/${ARCH}/initrd.gz debian/${SUITE}/netinst/${ARCH}/${INTERFACE}/initrd.gz
cp -f /tmp/${SUITE}_${ARCH}_netboot/debian-installer/${ARCH}/linux debian/${SUITE}/netinst/${ARCH}/${INTERFACE}/linux
cp -f /tmp/${SUITE}_${ARCH}_netboot/debian-installer/${ARCH}/boot-screens/txt.cfg /tmp/${SUITE}_${ARCH}_txt.cfg
rm -Rf /tmp/${SUITE}_${ARCH}_netboot.tar.gz /tmp/${SUITE}_${ARCH}_netboot

LABEL="Debian ${SUITE} ${ARCH} ${INTERFACE} NetInstall"
KERNEL="debian/${SUITE}/netinst/${ARCH}/${INTERFACE}/linux"
#KERNEL=$(cat /tmp/${SUITE}_${ARCH}_txt.cfg | grep kernel | sed 's/^.*kernel //' | sed "s|debian-installer/${ARCH}|debian/${SUITE}/netinst/${ARCH}/${INTERFACE}|")
APPEND=$(cat /tmp/${SUITE}_${ARCH}_txt.cfg | grep append | sed 's/^.*append //' | sed "s|debian-installer/${ARCH}/initrd.gz|debian/${SUITE}/netinst/${ARCH}/${INTERFACE}/initrd.gz|")

cat <<EOF > config.txt
LABEL $LABEL
 KERNEL $KERNEL
 APPEND $APPEND
EOF

rm -f /tmp/${SUITE}_${ARCH}_txt.cfg config.sh
exit 0


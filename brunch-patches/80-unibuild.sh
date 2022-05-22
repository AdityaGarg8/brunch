# This patch creates a generic configuration for unibuild recovery images compatibility:
# - in case of json unibuild configuration (/roota/usr/share/chromeos-config/config.json), overwrite it with our generic configuration.
# - in case of squashfs unibuild configuration (/usr/share/chromeos-config/configfs.img), replace it with our generic configuration.
# In any case, send the recovery image name to the kernel so that it generates the corresponding HWID.

native_chromebook_image=0
for i in $(echo "$1" | sed 's#,# #g')
do
	if [ "$i" == "native_chromebook_image" ]; then native_chromebook_image=1; fi
done

ret=0
board=$(fgrep 'CHROMEOS_RELEASE_DESCRIPTION' /roota/etc/lsb-release | cut -d' ' -f5 | tr a-z A-Z)

if [ "$board" == "HATCH" ]; then
	hwid="JINLON-YTGY"
elif [ "$board" == "NAMI" ]; then
	hwid="AKALI"
elif [ "$board" == "OCTOPUS" ]; then
	hwid="BOBBA"
elif [ "$board" == "RAMMUS" ]; then
	hwid="SHYVANA"
elif [ "$board" == "VOLTEER" ]; then
	hwid="VOXEL-GFMQ"
elif [ "$board" == "ZORK" ]; then
	hwid="GUMBOZ-JPUQ"
else
	hwid="$board"
fi

cat >/roota/etc/init/hwid.conf <<HWID
start on starting boot-services

script
	echo "$(echo "$hwid")" > /sys/devices/platform/chromeos_acpi/HWID
end script
HWID
if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 0))); fi

if [ "$native_chromebook_image" -eq 1 ]; then
	if [ "$board" == "NAMI" ]; then
		sndcard="kblda7219max"
		device="$(cat /sys/class/dmi/id/board_name | sed 's# ##g' | tr [A-Z] [a-z])"
	fi
	if [ ! -z "sndcard" ] && [ ! -z "device" ] && [ -d /roota/usr/share/alsa/ucm/"$sndcard"."$device" ] && [ -f /roota/usr/share/alsa/ucm/"$sndcard"."$device"/"$sndcard"."$device".conf ]; then
		if [ -d /roota/usr/share/alsa/ucm/"$sndcard" ]; then rm -r /roota/usr/share/alsa/ucm/"$sndcard"; fi
		cp -r /roota/usr/share/alsa/ucm/"$sndcard"."$device" /roota/usr/share/alsa/ucm/"$sndcard"
		mv /roota/usr/share/alsa/ucm/"$sndcard"/"$sndcard"."$device".conf /roota/usr/share/alsa/ucm/"$sndcard"/"$sndcard".conf
	fi
fi

if [ -f /roota/usr/share/chromeos-config/config.json ]; then
	cat >/roota/usr/share/chromeos-config/config.json <<CONFIG
{
  "chromeos": {
    "configs": [
      {
        "arc": {
          "build-properties": {
            "device": "${board}_cheets",
            "metrics-tag": "brunch",
            "product": "${board}"
          }
        },
        "brand-code": "TBD",
        "camera": {
          "count": 2
        },
        "hardware-properties": {
          "has-base-accelerometer": true,
          "has-base-gyroscope": true,
          "has-base-light-sensor": true,
          "has-base-magnetometer": true,
          "has-lid-accelerometer": true,
          "has-lid-gyroscope": true,
          "has-lid-light-sensor": true,
          "has-lid-magnetometer": true,
          "has-touchscreen": true,
          "is-lid-convertible": true,
          "stylus-category": "external"
        },
        "identity": {
          "platform-name": "${board}",
          "smbios-name-match": "Brunch"
        },
        "name": "brunch",
        "test-label": "brunch"
      }
    ]
  }
}
CONFIG
	if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 1))); fi
elif [ -f /roota/usr/share/chromeos-config/configfs.img ]; then
	if [ ! -f /roota/usr/share/chromeos-config/identity.bin ] || [ "$(dd if=/roota/usr/share/chromeos-config/identity.bin bs=1 count=1 2>/dev/null | od -A none)" -eq 0 ]; then
		echo -ne "\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x11\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x62\x72\x75\x6e\x63\x68\x00" > /roota/usr/share/chromeos-config/identity.bin
	else
		echo -ne "\x02\x00\x00\x00\x01\x00\x00\x00\x11\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x62\x72\x75\x6e\x63\x68\x00" > /roota/usr/share/chromeos-config/identity.bin
	fi
	rm /roota/usr/share/chromeos-config/configfs.img
	if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 2))); fi
	mkdir -p /tmp/configfs/v1/chromeos/configs/0/arc/build-properties
	if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 3))); fi
	echo "${board}_cheets" > /tmp/configfs/v1/chromeos/configs/0/arc/build-properties/device
	echo "brunch" > /tmp/configfs/v1/chromeos/configs/0/arc/build-properties/metrics-tag
	echo "${board}" > /tmp/configfs/v1/chromeos/configs/0/arc/build-properties/product
	mkdir -p /tmp/configfs/v1/chromeos/configs/0/camera
	echo "2" > /tmp/configfs/v1/chromeos/configs/0/camera/count
	mkdir -p /tmp/configfs/v1/chromeos/configs/0/hardware-properties
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/has-base-accelerometer
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/has-base-gyroscope
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/has-base-light-sensor
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/has-base-magnetometer
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/has-lid-accelerometer
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/has-lid-gyroscope
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/has-lid-light-sensor
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/has-lid-magnetometer
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/has-touchscreen
	echo "true" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/is-lid-convertible
	echo "external" > /tmp/configfs/v1/chromeos/configs/0/hardware-properties/stylus-category
	mkdir -p /tmp/configfs/v1/chromeos/configs/0/identity
	echo "${board}" > /tmp/configfs/v1/chromeos/configs/0/identity/platform-name
	echo "Brunch" > /tmp/configfs/v1/chromeos/configs/0/identity/smbios-name-match
	echo "0" > /tmp/configfs/v1/chromeos/configs/0/identity/sku-id
	echo "TBD" > /tmp/configfs/v1/chromeos/configs/0/brand-code
	echo "brunch" > /tmp/configfs/v1/chromeos/configs/0/name
	echo "brunch" > /tmp/configfs/v1/chromeos/configs/0/test-label
	echo "{\"chromeos\": {\"configs\": [{\"identity\": {\"platform-name\": \"${board}\", \"smbios-name-match\": \"Brunch\"}}]}}" > /tmp/configfs/v1/identity.json
	mksquashfs /tmp/configfs/ /roota/usr/share/chromeos-config/configfs.img > /dev/null
	if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 4))); fi
	rm -r /tmp/configfs
	if [ ! "$?" -eq 0 ]; then ret=$((ret + (2 ** 5))); fi
fi

exit $ret

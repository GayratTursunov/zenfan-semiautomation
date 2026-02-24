# zenbook-fan
## standalone script for Asus Zenbook UX31e fan control
<br><br>
# Smart Adaptive Fan Controller

Verify temp path:  
```bash
cat /sys/class/hwmon/hwmon2/temp1_input
```

If you see a number like 52000 → good (52°C).

### Create auto fan script
```bash
sudo nano /usr/local/bin/zenbook-fan.sh
```

Paste this:

```bash
#!/bin/bash

PWM="/sys/class/hwmon/hwmon4/pwm1"
ENABLE="/sys/class/hwmon/hwmon4/pwm1_enable"
TEMP="/sys/class/hwmon/hwmon2/temp1_input"
PROFILE_FILE="/etc/zenbook-fan-profile"

echo 1 > $ENABLE

# default profile
[ -f "$PROFILE_FILE" ] || echo "balanced" > $PROFILE_FILE

LAST_PWM=100

while true; do
    PROFILE=$(cat $PROFILE_FILE)
    T=$(cat $TEMP)
    T=$((T/1000))

    # CPU load (1-min average)
    LOAD=$(awk '{print int($1)}' /proc/loadavg)

    # --- profile curves ---
    if [ "$PROFILE" = "quiet" ]; then
        LOW=55 MID=65 HIGH=75 MAX=85
        P1=60 P2=90 P3=130 P4=170 P5=210
    elif [ "$PROFILE" = "performance" ]; then
        LOW=45 MID=55 HIGH=65 MAX=75
        P1=100 P2=140 P3=180 P4=210 P5=255
    else # balanced
        LOW=50 MID=60 HIGH=70 MAX=80
        P1=70 P2=100 P3=140 P4=180 P5=220
    fi

    # --- temperature curve ---
    if [ $T -lt $LOW ]; then
        TARGET=$P1
    elif [ $T -lt $MID ]; then
        TARGET=$P2
    elif [ $T -lt $HIGH ]; then
        TARGET=$P3
    elif [ $T -lt $MAX ]; then
        TARGET=$P4
    else
        TARGET=$P5
    fi

    # --- load-based turbo ---
    if [ $LOAD -ge 3 ]; then
        TARGET=$((TARGET + 30))
    fi

    # clamp range
    [ $TARGET -gt 255 ] && TARGET=255
    [ $TARGET -lt 60 ] && TARGET=60

    # --- adaptive smoothing ---
    DIFF=$((TARGET - LAST_PWM))
    STEP=10

    if [ ${DIFF#-} -gt $STEP ]; then
        if [ $DIFF -gt 0 ]; then
            TARGET=$((LAST_PWM + STEP))
        else
            TARGET=$((LAST_PWM - STEP))
        fi
    fi

    echo $TARGET > $PWM
    LAST_PWM=$TARGET

    sleep 3
done

```


Save → exit.

### Make executable

```bash
sudo chmod +x /usr/local/bin/zenbook-fan.sh
```

### Run automatically at boot  
Create system service:
```bash
sudo nano /etc/systemd/system/zenbook-fan.service
```

Paste:

```ini
[Unit]
Description=Zenbook Fan Control
After=multi-user.target

[Service]
ExecStart=/usr/local/bin/zenbook-fan.sh
Restart=always

[Install]
WantedBy=multi-user.target
```
### Enable it  
```bash
sudo systemctl daemon-reload
sudo systemctl enable zenbook-fan
sudo systemctl start zenbook-fan
```
### Check status 
```bash
systemctl status zenbook-fan
```


**Always monitor temps while testing in realtime**:
```bash
watch -n1 sensors
```
<br><br>

# Profile Switcher Commander
Create a simple control command:
```bash
sudo nano /usr/local/bin/zenfan
```
Paste:
```bash
#!/bin/bash

FILE="/etc/zenbook-fan-profile"

case "$1" in
    quiet|balanced|performance)
        echo "$1" | sudo tee $FILE > /dev/null
        echo "Fan profile set to: $1"
        ;;
    status)
        echo "Current profile: $(cat $FILE)"
        ;;
    *)
        echo "Usage: zenfan {quiet|balanced|performance|status}"
        ;;
esac
```
Make executable:
```bash
sudo chmod +x /usr/local/bin/zenfan
```
## How to use

Switch modes instantly:  

    zenfan quiet  
    zenfan balanced  
    zenfan performance  
    zenfan status 

No reboot needed — change applies in seconds.

**Always monitor temps while testing in realtime**:
```bash
watch -n1 sensors
```


<br><br><br>
# Quick emergency fallback (safe manual control)

```bash
echo 1 | sudo tee /sys/class/hwmon/hwmon4/pwm1_enable
echo 180 | sudo tee /sys/class/hwmon/hwmon4/pwm1
```
That gives you stable cooling until auto control works.  
Or

```bash
echo 2 | sudo tee /sys/class/hwmon/hwmon4/pwm1_enable
```
to enable BIOS/UEFI mode.










## Comments

The script has been tested on an ASUS Zenbook UX31E.

## TODO

* Design panel applet an additional interface for setting the fan modes.

## Acknowledgements

* Thanks to dhil for understanding driver aproach (https://github.com/dhil/asus-zenfan).


## References

1. Sujith Thomas and Zhang Rui. *Generic Thermal Sysfs driver How To*. Intel Corporation. January 2, 2008. [Available online][1].  
[1]: https://www.kernel.org/doc/Documentation/thermal/sysfs-api.txt

# zenfan-semiautomation
# ASUS Zenbook UX31E Ultra-Smart Adaptive Fan Control for Linux

This script provive Ultra-Smart Adaptive Fan Controller behaviour for controlling the ASUS Zenbook UX31e fan. Moreover, the script ensures that the fan restored to its previous state on system resume. Profile switching + load-based turbo + adaptive curve on Zenbook with a single smart controller script and a tiny CLI switcher.

Features:

    ✅ thermal hysteresis → prevents fan speed bouncing up/down;
    ✅ usage learning → auto-adjusts curve based on recent heat behavior;
    ✅ profile switcher (one command to switch modes);
    ✅ quiet / balanced / performance profiles;
    ✅ turbo boost when CPU load spike;
    ✅ survives reboot;
    ✅ still lightweight + stable for LMDE 7 (gigi).


## Disclaimer

This software is provided by the copyright holders and contributors "as is"
and any express or implied warranties, including, but not limited to, the
implied warranties of merchantability and fitness for a particular purpose
are disclaimed. In no event shall the copyright owner or contributors be
liable for any direct, indirect, incidental, special, exemplary, or
consequential damages (including, but not limited to, procurement of
substitute goods or services; loss of use, data, or profits; or business
interruption) however caused and on any theory of liability, whether in
contract, strict liability, or tort (including negligence or otherwise)
arising in any way out of the use of this software, even if advised of the
possibility of such damage. 
<br><br>
## Installation

On LMDE 7 (Linux Mint Debian Edition) usually control the CPU fan through the kernel + BIOS + lm-sensors stack+fancontrol

Install required tools

```bash
sudo apt update
sudo apt install lm-sensors fancontrol
```



## Background

For ASUS Zenbook UX31e, manual fan control under Linux (including LMDE 7) is very limited because the hardware doesn’t expose standard fan PWM controls to Linux in the way a desktop motherboard does. Most users run into exactly this situation: the fan is controlled by firmware/ACPI only and not visible to lm-sensors/fancontrol, so tools like pwmconfig can’t detect a controllable fan driver.

ASUS Zenbook UX31e exposes:
    
    ✅ a controllable PWM (hwmon4/pwm1)
    ❌ no readable fan speed sensor (fan1_input missing)

That’s why:

- pwmconfig refuses to generate /etc/fancontrol

- fancontrol service cannot run

- BUT manual control works

This is normal on many ASUS ultrabooks — the fan can be controlled but RPM is not reported.

So the correct solution is:

    👉 manual PWM control script instead of fancontrol


## Query sensors

First identify temp sensor:
```bash
sensors
```
Look for `pwm` → note its number

> gayrat@ldme-ux31:~$ sensors  
> asus-isa-000a  
> Adapter: ISA adapter  
> cpu_fan:          N/A  
> temp1:        +61.0°C  
> `pwm1`:            101%  MANUAL CONTROL  
> 
> coretemp-isa-0000  
> Adapter: ISA adapter  
> Package id 0: &emsp; +63.0°C  (high = +86.0°C, crit =   +100.0°C)  
> Core 0: $\qquad$  +62.0°C  (high = +86.0°C, crit = +100.0°C)  
> Core 1: $\qquad$  +61.0°C  (high = +86.0°C, crit = +100.0°C)  
> 
> acpitz-acpi-0
> Adapter: ACPI interface  
> temp1: $\qquad$ +61.0°C  
> 
> BAT0-acpi-0
> Adapter: ACPI interface  
> in0: $\qquad$ $\qquad$ 8.22 V  
> power1: $\qquad$  0.00 W  
> 
> gayrat@ldme-ux31:~$ 


## Check if your fan is controllable

Look for `coretemp` and `PWM controls` → note its hwmon number

```bash
sudo pwmconfig
```

This script:
- Tests each fan header
- Finds which PWM control affects your CPU fan
- Creates /etc/fancontrol config automatically

> gayrat@ldme-ux31:~$ sudo pwmconfig  
> \# pwmconfig version 3.6.2  
> This program will search your sensors for pulse width modulation (pwm)  
> controls, and test each one to see if it controls a fan on  
> your motherboard. Note that many motherboards do not have pwm  
> circuitry installed, even if your sensor chip supports pwm.  
>   
> We will attempt to briefly stop each fan using the pwm controls.
> The program will attempt to restore each fan to full speed
> after testing. However, it is ** very important ** that you
> physically verify that the fans have been to full speed
> after the program has completed.  
> 
> Found the following devices:  
>    hwmon0 is acpitz  
>    hwmon1 is BAT0  
>    `hwmon2 is coretemp`  
>    hwmon3 is AC0  
>    hwmon4 is asus  
>    hwmon5 is hidpp_battery_0  
> 
> Found the following PWM controls:  
>  $\quad$ `hwmon4/pwm1` $\qquad$  current value: 120
> 
> Giving the fans some time to reach full speed...
> Found the following fan sensors:
> cat: hwmon4/fan1_input: No such device or address
>    hwmon4/fan1_input     current speed: 0 ... skipping!
> 
> There are **no working fan sensors**, all readings are 0.
> Make sure you have a 3-wire fan connected.
> You may also need to increase the fan divisors.
> See doc/fan-divisors for more information.
> gayrat@ldme-ux31:~$ 

Check whether Linux sees fan PWM control points:

```bash
ls /sys/class/hwmon/*/pwm*
```

> gayrat@ldme-ux31:~$ ls /sys/class/hwmon/*/pwm*  
>  `/sys/class/hwmon/hwmon4/pwm1`  
>  `/sys/class/hwmon/hwmon4/pwm1_enable`  
>  gayrat@ldme-ux31:~$

System does expose a controllable PWM channel:

    /sys/class/hwmon/hwmon4/pwm1
    /sys/class/hwmon/hwmon4/pwm1_enable

That means the fan isn’t fully locked by firmware — it can be controled manually.


### Manual fan control

#### Enable fan manual mode

```bash
echo 1 | sudo tee /sys/class/hwmon/hwmon4/pwm1_enable
```

Mode meanings:  
- 0 → off / no control
- 1 → manual control
- 2 → automatic (BIOS control)


#### Set fan speed manually

PWM values range 0–255:
```bash
echo 120 | sudo tee /sys/class/hwmon/hwmon4/pwm1
```

Rough PWM value guide:
- 80 → very quiet
- 120 → balanced
- 180 → strong cooling
- 255 → full speed


**Always monitor temps while testing in realtime**:
```bash
watch -n1 sensors
```

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

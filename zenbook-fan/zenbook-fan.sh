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
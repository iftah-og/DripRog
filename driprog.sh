#!/bin/bash
# DripRog
# GPIO23 drives the status indicator: LED, active piezo buzzer, or
# coin vibration motor (same pin, on/off). See HARDWARE.md for wiring.

# Configuration 
DEVICE="hw:0,0"
OUTPUT_DIR="/mnt/usb/recordings"
BUTTON_PIN=17
LED_PIN=23
STOP_FLAG="/tmp/stop_recording"

# libgpiod version detection (v1 and v2 differ; detect once)
if gpioset --help 2>&1 | grep -q -- '--chip'; then
    GPIOD_V2=1
else
    GPIOD_V2=0
fi

# Cleanup on exit
cleanup() {
    touch "$STOP_FLAG"
    killall arecord 2>/dev/null
    killall gpioset 2>/dev/null
    rm -f "$STOP_FLAG"
}
trap cleanup SIGINT SIGTERM EXIT

# GPIO helpers (hide the v1/v2 differences) 
_gpio_read() {
    if [ "$GPIOD_V2" = "1" ]; then
        gpioget --chip gpiochip0 --bias=pull-up "$1" 2>/dev/null
    else
        gpioget --bias=pull-up gpiochip0 "$1" 2>/dev/null
    fi
}

_gpio_is_low() {
    case "$1" in
        *inactive*|0|*=0) echo "1" ;;
        *)                echo "0" ;;
    esac
}

_gpio_hold() {
    killall gpioset 2>/dev/null
    sleep 0.05
    if [ "$GPIOD_V2" = "1" ]; then
        gpioset --chip gpiochip0 -p 10s "$1=$2" 2>/dev/null &
    else
        gpioset --mode=signal gpiochip0 "$1=$2" 2>/dev/null &
    fi
}

# Inputs: button and gain switch 
read_button() {
    _gpio_is_low "$(_gpio_read $BUTTON_PIN)"
}

read_gain_switch() {
    if [ "$(_gpio_is_low "$(_gpio_read 12)")" = "1" ]; then
        echo "24"
    elif [ "$(_gpio_is_low "$(_gpio_read 5)")" = "1" ]; then
        echo "60"
    elif [ "$(_gpio_is_low "$(_gpio_read 6)")" = "1" ]; then
        echo "80"
    else
        echo "104"
    fi
}

set_adc_level() {
    amixer -c 0 sset 'ADC' "$1" 2>/dev/null
}

# Status indicator and pulse patterns
led_on()  { _gpio_hold $LED_PIN 1; }
led_off() { _gpio_hold $LED_PIN 0; }

blink_led_background() {
    local times=$1
    (
        for i in $(seq 1 $times); do
            led_on;  sleep 0.3
            led_off; sleep 0.3
        done
    ) &
}

error_blink_pattern() {
    led_on;  sleep 0.15
    led_off; sleep 0.15
    led_on;  sleep 0.15
    led_off; sleep 0.6
}

shutdown_blink() {
    for i in 1 2 3 4 5 6 7 8 9 10; do
        led_on;  sleep 0.08
        led_off; sleep 0.08
    done
    led_off
    sleep 0.2
}

flush_buffer() {
    arecord -D "$DEVICE" -f S32_LE -r 192000 -c 2 -d 0.5 /dev/null 2>/dev/null
}

# USB / disk checks
check_usb_mounted() {
    if ! mount | grep " /mnt/usb " | grep -q "type vfat"; then
        return 1
    fi
    AVAILABLE=$(df -k /mnt/usb 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -z "$AVAILABLE" ] || [ "$AVAILABLE" -lt 2202010 ]; then
        return 1
    fi
    return 0
}

check_disk_space() {
    AVAILABLE=$(df -k /mnt/usb 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -z "$AVAILABLE" ] || [ "$AVAILABLE" -lt 2202010 ]; then
        return 1
    fi
    return 0
}

# Recording folder 
get_droprig_folder() {
    HIGHEST=$(ls -1d "$OUTPUT_DIR"/droprig-* 2>/dev/null | sed 's/.*droprig-//' | sort -n | tail -1)
    if [ -z "$HIGHEST" ]; then
        NEXT=1
    else
        NEXT=$((HIGHEST + 1))
    fi
    printf "%s/droprig-%03d" "$OUTPUT_DIR" "$NEXT"
}

# State and startup 
RECORDING=false
RECORD_PID=0
LAST_GAIN_LEVEL=""
DROPRIG_FOLDER=""
LOCKED_GAIN_LEVEL=""

INITIAL_GAIN=$(read_gain_switch)
set_adc_level "$INITIAL_GAIN"
LAST_GAIN_LEVEL="$INITIAL_GAIN"

led_on
sleep 0.5
led_off
sleep 0.5

# Wait for USB (button still works to shut down)
while ! check_usb_mounted; do
    BUTTON_STATE=$(read_button)
    if [ "$BUTTON_STATE" -eq 1 ]; then
        HOLD_COUNT=0
        while [ "$(read_button)" = "1" ]; do
            sleep 0.1
            HOLD_COUNT=$((HOLD_COUNT + 1))
            if [ $HOLD_COUNT -ge 50 ]; then
                touch /tmp/shutting_down
                killall gpioset 2>/dev/null
                shutdown_blink
                killall gpioset 2>/dev/null
                sync
                /sbin/shutdown -h now
                exit 0
            fi
        done
    fi
    error_blink_pattern
done

led_on

# Main loop
while true; do
    if [ "$RECORDING" = false ]; then
        CURRENT_GAIN=$(read_gain_switch)
        if [ "$CURRENT_GAIN" != "$LAST_GAIN_LEVEL" ]; then
            set_adc_level "$CURRENT_GAIN"
            LAST_GAIN_LEVEL="$CURRENT_GAIN"
        fi
        if ! check_usb_mounted; then
            while ! check_usb_mounted; do
                error_blink_pattern
            done
            led_on
        fi
    fi

    BUTTON_STATE=$(read_button)
    if [ -z "$BUTTON_STATE" ]; then
        BUTTON_STATE=0
    fi

    if [ "$BUTTON_STATE" -eq 1 ]; then
        HOLD_COUNT=0
        BLINK_DONE=false
        while [ "$(read_button)" = "1" ]; do
            sleep 0.1
            HOLD_COUNT=$((HOLD_COUNT + 1))
            if [ $HOLD_COUNT -eq 10 ] && [ "$RECORDING" = true ] && [ "$BLINK_DONE" = false ]; then
                led_on
                BLINK_DONE=true
            fi
            if [ $HOLD_COUNT -ge 50 ]; then
                touch /tmp/shutting_down
                touch "$STOP_FLAG"
                killall arecord 2>/dev/null
                killall gpioset 2>/dev/null
                sync
                shutdown_blink
                killall gpioset 2>/dev/null
                sync
                /sbin/shutdown -h now
                exit 0
            fi
        done

        # Long press while recording: stop and sync
        if [ $HOLD_COUNT -ge 8 ] && [ "$RECORDING" = true ]; then
            touch "$STOP_FLAG"
            sleep 0.2
            if [ $RECORD_PID -ne 0 ]; then
                kill $RECORD_PID 2>/dev/null
                sleep 0.5
                kill -9 $RECORD_PID 2>/dev/null
            fi
            killall -SIGTERM arecord 2>/dev/null
            sleep 0.5
            killall -9 arecord 2>/dev/null
            sync

            if ! check_disk_space; then
                for i in 1 2 3 4 5; do
                    led_on;  sleep 0.15
                    led_off; sleep 0.15
                    led_on;  sleep 0.15
                    led_off; sleep 0.6
                done
                led_on
            else
                for i in {1..8}; do
                    led_on;  sleep 0.1
                    led_off; sleep 0.1
                done
                sync
                sleep 0.5
                led_on
            fi

            rm -f "$STOP_FLAG"
            RECORDING=false
            RECORD_PID=0
            LOCKED_GAIN_LEVEL=""

        # Short press while idle: start recording
        elif [ $HOLD_COUNT -lt 8 ] && [ "$RECORDING" = false ]; then
            if ! check_usb_mounted; then
                error_blink_pattern
                led_on
                sleep 0.5
                continue
            fi

            if [ -z "$DROPRIG_FOLDER" ]; then
                DROPRIG_FOLDER=$(get_droprig_folder)
                mkdir -p "$DROPRIG_FOLDER" 2>/dev/null
            fi

            # Lock gain for the rest of the session
            LOCKED_GAIN_LEVEL=$(read_gain_switch)
            set_adc_level "$LOCKED_GAIN_LEVEL"
            LAST_GAIN_LEVEL="$LOCKED_GAIN_LEVEL"

            blink_led_background 5
            flush_buffer
            sleep 3
            led_off

            RECORDING=true
            rm -f "$STOP_FLAG"

            # Background recorder: fixed-length segments until stopped
            (
                while [ ! -f "$STOP_FLAG" ]; do
                    if ! check_disk_space; then
                        touch "$STOP_FLAG"
                        break
                    fi
                    FILENAME="$DROPRIG_FOLDER/field-$(date +%Y%m%d_%H%M%S).wav"
                    nice -n -20 arecord -D "$DEVICE" -f S32_LE -r 192000 -c 2 \
                            --buffer-size=262144 \
                            --period-size=16384 \
                            -d 1395 \
                            "$FILENAME" 2>/dev/null
                    [ -f "$STOP_FLAG" ] && break
                    sleep 0.1
                done
            ) &
            RECORD_PID=$!
        fi

        sleep 0.5
    fi

    if [ "$RECORDING" = true ]; then
        sleep 1.0
    else
        sleep 0.05
    fi
done

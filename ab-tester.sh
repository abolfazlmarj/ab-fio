#!/bin/sh

time=600
device=""
workload="all"
type=""
interval=3
fio_pid=""

trap 'if [ -n "$fio_pid" ]; then kill -INT "$fio_pid" 2>/dev/null; fi; exit 130' INT TERM

show_help() {
            echo "Usage: docker run --rm --privileged registry.local/ab-fio:v2.3.1 -d=<device> [options]"
            echo
            echo "Options:"
            echo "  -d, --device <device>      Device to test (required)"
            echo "  -t, --time <seconds>       Test duration in seconds (default: 600)"
            echo "  -w, --workload <workload>  FIO workload (default: all)"
            echo "                             Common: all|data|lat-r|lat-w|rnd-r|rnd-w|seq-r|seq-w"
            echo "                             SSD/NVMe: rnd-r2|rnd-w2"
            echo "                             NVMe: rnd-r3|rnd-w3"
            echo "  --type <type>              Device type: ssd|hdd|nvme (default: device ROTA)"
            echo "  --interval <seconds>       how many seconds to wait before running the next fio test (default: 3)"
            echo "  -h, --help                 Show this help message"
            echo
            echo "Examples:"
            echo "  docker run --rm --privileged registry.local/ab-fio:v2.3.1 -d=/dev/sdf -t=60 -w=rnd-w --type=ssd"
            echo "  docker run --rm --privileged registry.local/ab-fio:v2.3.1 -d /dev/sdf --time 60 -w data --type ssd"
}

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

while [ $# -gt 0 ]; do

    case "$1" in

        -t=*|--time=*)
            time="${1#-t=}"
            ;;

        -t|--time)
            shift
            time="$1"
            ;;

        -d=*|--device=*)
            device="${1#-d=}"
            ;;

        -d|--device)
            shift
            device="$1"
            ;;

        -w=*|--workload=*)
            workload="${1#-w=}"
            ;;

        -w|--workload)
            shift
            workload="$1"
            ;;

        --type=*)
            type="${1#--type=}"
            ;;

        --type)
            shift
            type="$1"
            ;;

        --interval=*)
            interval="${1#--interval=}"
            ;;

        --interval)
            shift
            interval="$1"
            ;;

        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use 'docker run --rm --privileged registry.local/ab-fio:v2.3.1 --help' for usage information."
            exit 1
            ;;
    esac
    shift
done

if [ -z "$device" ]; then
    echo "Error: device must be specified using -d=<device>"
    exit 1
fi

if [ -z "$type" ]; then
    if [ "$(cat "/sys/block/$(basename "$device")/queue/rotational")" -eq 1 ]; then
        type="hdd"
    else
        if echo "$device" | grep -q 'nvme'; then
            type="nvme"
        else
            type="ssd"
        fi
    fi
fi

case "$type" in
    hdd|ssd|nvme)
        ;;
    *)
        echo "Error: invalid type '$type'. Type must be 'hdd', 'ssd' or 'nvme'."
        exit 1
        ;;
esac

echo "testnum,rw,numjobs,iodepth,bs,iops,lat,bw,testfile,date"

case "$workload" in
    all)
        files=$(find "/app/$type/" -maxdepth 1 -type f -name '*.fio')
        ;;

    data)
        files=$(find "/data/" -maxdepth 1 -type f -name '*.fio')
        ;;

    lat-r|lat-w|rnd-r|rnd-w|seq-r|seq-w)
        files="/app/$type/$workload.fio"
        ;;

    rnd-r2|rnd-w2)
        case "$type" in
            ssd|nvme)
                files="/app/$type/$workload.fio"
                ;;
            *)
                echo "Error: workload '$workload' is not supported for type '$type'."
                exit 1
                ;;
        esac
        ;;

    rnd-r3|rnd-w3)
        case "$type" in
            nvme)
                files="/app/$type/$workload.fio"
                ;;
            *)
                echo "Error: workload '$workload' is not supported for type '$type'."
                exit 1
                ;;
        esac
        ;;

    *)
        echo "Error: invalid workload '$workload'."
        exit 1
        ;;
esac

mkdir -p /data/outputs
testnum=0
for i in $files;
do
testnum=$((testnum+1))
logfile="/data/outputs/$(basename "$i").log"
#output="$(fio $i --filename=$device --runtime=$time 2>&1)"

output_file=$(mktemp)
echo $(date) >> $logfile
echo "-------------------------$testnum-------------------------" >> $logfile

fio "$i" --filename="$device" --runtime="$time" >"$output_file" 2>&1 &
fio_pid=$!

wait "$fio_pid"
fio_status=$?

output=$(cat "$output_file")
echo "$output" >> $logfile
echo "-------------------------$testnum-------------------------" >> $logfile
echo $(date) >> $logfile

rm -f "$output_file"

fio_pid=""

if [ "$fio_status" -eq 130 ] || [ "$fio_status" -eq 2 ]; then
    echo "Test interrupted."
    exit 130
fi

rw=$(cat $i |grep rw|cut -d'=' -f2);
nj=$(cat $i |grep numjobs|cut -d'=' -f2);
iodepth=$(cat $i |grep iodepth|cut -d'=' -f2);
bs=$(cat $i |grep -e '^bs'|cut -d'=' -f2);

iops=$(echo "$output" |grep IOPS|cut -d '=' -f2|cut -d ',' -f1)
lat="$(echo "$output" |grep -e '^ *lat'|grep avg|cut -d '=' -f4|cut -d ',' -f1)$(echo "$output" |grep -e '^ *lat'|grep avg|cut -d '(' -f2|cut -d 's' -f1)"
bw=$(echo "$output" |grep IOPS|cut -d '=' -f3|cut -d 'B' -f1;)

echo $testnum,$rw,$nj,$iodepth,$bs,$iops,$lat,$bw,$(basename "$i"),$(date);
sleep $interval
done

## read the options
TEMP=`getopt -o m:v --long minute:,version -n 'myacrlab.sh' -- "$@"`
eval set -- "$TEMP"

## set an initial value for the flags
TMP_TIME="5"

while true ;
do
    case "$1" in
        -m|--minute) case "$2" in
            "") shift 2;;
            *) TMP_TIME="$2"; shift 2;;
            esac;;
        --version) VERSION=1; shift;;
        --) shift ; break ;;
        *) echo -e "Error: invalid argument\n" ; exit 3 ;;
    esac
done

secs=$(($TMP_TIME * 60))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K SEC\r"
   sleep 1
   : $((secs--))
done

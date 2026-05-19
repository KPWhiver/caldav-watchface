build:
    monkeyc -f monkey.jungle -y ../developer_key.der  -o bin/CaldavWatch.prg -d vivoactive4s -l 0

simulate:
    monkeydo bin/CaldavWatch.prg vivoactive4s

mount:
    jmtpfs garmin

unmount:
    umount garmin

install:
    cp bin/CaldavWatch.prg garmin/GARMIN/APPS/

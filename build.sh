#!/bin/bash

help() {
    echo "Usage:"
    echo "build.sh [-e example_name] [-b] [-s] [-w waveform_name] [-a parameters_list] [-c]"
    echo "Description:"
    echo "-e: Specify a example project. For example: -c counter. If not specified, the \"cpu\" directory is used as the project directory. \
        It will generate the \"build\" subfolder under the project directory."
    echo "-b: Build project using verilator and make tools automatically."
    echo "-s: Run simulation program. Use the \"build\" folders as work path."
    echo "-w: Open a specified waveform file using gtkwave. Use the \"build\" folders as work path."
    echo "-a: Parameters passed to the simulation program. For example: -a \"1 2 3 ......\". Multiple parameters require double quotes."
    echo "-c: Delete all \"build\" folders."
    exit 0
}

BUILD="false"
EXAMPLES="false"
SUMULATE="false"
CHECK_WAVE="false"
CLEAN="false"
PARAMETERS=

while getopts 'hbsw:e:a:c' OPT; do
    case $OPT in
        b) BUILD="true";;
        s) SUMULATE="true";;
        w) CHECK_WAVE="true"; WAVE_FILE="$OPTARG";;
        e) EXAMPLES="true"; EXAMPLES_PATH="$OPTARG";;
        a) PARAMETERS="$OPTARG";;
        c) CLEAN="true";;
        h) help;;
        ?) help;;
    esac
done

SHELL_PATH=$(dirname $(readlink -f "$0"))
MYINFO_FILE=$SHELL_PATH/myinfo.txt
V_TOP_FILE=top.v
EMU_FILE=emu
CPU_SRC_FOLDER=cpu
EXAMPLES_SRC_FOLDER=examples
BUILD_FOLDER=build

[ "$EXAMPLES" == "true" ] && SRC_PATH=$SHELL_PATH/$EXAMPLES_SRC_FOLDER/$EXAMPLES_PATH || SRC_PATH=$SHELL_PATH/$CPU_SRC_FOLDER
BUILD_PATH=$SRC_PATH/build

# Get id and name
ID=`sed '/^ID=/!d;s/.*=//' $MYINFO_FILE`
NAME=`sed '/^Name=/!d;s/.*=//' $MYINFO_FILE`
if [ ! $ID ] || [ ! $NAME ]; then
    echo "Please fill your information in myinfo.txt!!!"
    exit 1
fi
ID="${ID##*\r}"
NAME="${NAME##*\r}"

# Clean
if [ "$CLEAN" == "true" ]; then
    # delete all "build" folders
    find . -name "build" -print0 | xargs -0 rm -rf
    exit 0
fi

# Build project
if [ "$BUILD" == "true" ]; then
    cd $SRC_PATH
    CPP_SRC=`find . -maxdepth 1 -name "*.cpp"`
    verilator -Wall --cc --exe -o $EMU_FILE --trace -Mdir ./$BUILD_FOLDER --build $V_TOP_FILE $CPP_SRC
    if [ $? -ne 0 ]; then
        echo "Failed to run verilator!!!"
        exit 1
    fi
    cd $SHELL_PATH

    #git commit
    git add . -A --ignore-errors
    (echo $NAME && echo $ID && hostnamectl && uptime) | git commit -F - -q --author='tracer-oscpu2021 <tracer@oscpu.org>' --no-verify --allow-empty 1>/dev/null 2>&1
    sync
fi

# Simulate
if [ "$SUMULATE" == "true" ]; then
    echo "Simulating..."
    cd $BUILD_PATH
    ./$EMU_FILE $PARAMETERS
    if [ $? -ne 0 ]; then
        echo "Failed to simulate!!!"
        exit 1
    fi
    cd $SHELL_PATH
fi

# Check waveform
if [ "$CHECK_WAVE" == "true" ]; then
    cd $BUILD_PATH
    gtkwave $WAVE_FILE
    if [ $? -ne 0 ]; then
        echo "Failed to run gtkwave!!!"
        exit 1
    fi
    cd $SHELL_PATH
fi

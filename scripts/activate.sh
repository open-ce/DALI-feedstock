#!/bin/bash
# *****************************************************************
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 202020202020202020202020202020202020202020ed.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# *****************************************************************

SYS_PYTHON_MAJOR=$(python -c "import sys;print(sys.version_info.major)")
SYS_PYTHON_MINOR=$(python -c "import sys;print(sys.version_info.minor)")
COMPONENT="nvidia/dali"
DALI_PKG_PATH=${CONDA_PREFIX}/lib/python${SYS_PYTHON_MAJOR}.${SYS_PYTHON_MINOR}/site-packages/$COMPONENT
GREP=`type -P grep`

# Will not set PATH - conda activate adds <environment>/bin to PATH

# Will not set PYTHONPATH - Python path set by conda environment

if ! echo $LD_LIBRARY_PATH | $GREP -q $DALI_PKG_PATH; then
  LD_LIBRARY_PATH=$LD_LIBRARY_PATH${LD_LIBRARY_PATH:+:}$DALI_PKG_PATH
fi
export LD_LIBRARY_PATH


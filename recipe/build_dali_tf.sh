#!/bin/bash
# *****************************************************************
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2019, 2020. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# *****************************************************************
set -x

COMPILER=${CXX}

PYTHON=${PYTHON:-python}
LIB_NAME=${1:-"libdali_tf_current.so"}
SRCS="daliop.cc dali_dataset_op.cc"
INCL_DIRS="-I$CUDA_HOME/include -I$CONDA_PREFIX/include/"

DALI_CFLAGS=( $($PYTHON ./dali_compile_flags.py --cflags) )
DALI_LFLAGS=( $($PYTHON ./dali_compile_flags.py --lflags) )

TF_CFLAGS=( $($PYTHON -c 'import tensorflow as tf; print(" ".join(tf.sysconfig.get_compile_flags()))') )
TF_LFLAGS=( $($PYTHON -c 'import tensorflow as tf; print(" ".join(tf.sysconfig.get_link_flags()))') )


echo "$COMPILER"
echo "$PYTHON"
echo "$LIB_NAME"
echo "$INCL_DIRS"
for i in "${DALI_CFLAGS[@]}";do
  echo "$i"
done
for i in "${DALI_LFLAGS[@]}";do
  echo "$i"
done
for i in "${TF_CFLAGS[@]}";do
  echo "$i"
done
for i in "${TF_CFLAGS[@]}";do
  echo "$i"
done


${COMPILER} -std=c++11 -O2 -shared -fPIC ${SRCS} -o ${LIB_NAME} ${INCL_DIRS} -DNDEBUG ${TF_CFLAGS[@]} ${TF_LFLAGS[@]} ${DALI_CFLAGS[@]} ${DALI_LFLAGS[@]}

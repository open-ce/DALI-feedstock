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

# Create build directory for cmake and enter it
mkdir $SRC_DIR/build

cd $SRC_DIR/build

# Determine Architecture
ARCH="$(arch)"
if [ ${ARCH} = "x86_64" ]; then
    ARCH_LONGNAME="x86_64-conda_cos6"
elif [ ${ARCH} = "ppc64le" ]; then
    ARCH_LONGNAME="powerpc64le-conda_cos7"
else
    echo "Error: Unsupported Architecture. Expected: [x86_64|ppc64le] Actual: ${ARCH}"
    exit 1
fi

# Create 'gcc' symlink so nvcc can find it
ln -s $CONDA_PREFIX/bin/${ARCH_LONGNAME}-linux-gnu-gcc $CONDA_PREFIX/bin/gcc
ln -s $CONDA_PREFIX/bin/${ARCH_LONGNAME}-linux-gnu-g++ $CONDA_PREFIX/bin/g++

export CXXFLAGS=${CXXFLAGS/-std=c++??/-std=c++14}
# Add libjpeg-turbo location to front of CXXFLAGS so it is used instead of jpeg
export CXXFLAGS="-I$CONDA_PREFIX/libjpeg-turbo/include ${CXXFLAGS} -DNO_ALIGNED_ALLOC"

# Build
cmake -DBUILD_LMDB=${BUILD_LMDB:-ON}                      \
      -DLMDB_INCLUDE_DIR=$CONDA_PREFIX/include/ \
      -DLMDB_LIBRARIES=$CONDA_PREFIX/lib/liblmdb.so \
      -DCMAKE_CUDA_COMPILER=${CUDA_HOME}/bin/nvcc \
      -DCMAKE_CUDA_HOST_COMPILER=${CXX} \
      -DCUDA_rt_LIBRARY=$CONDA_PREFIX/${ARCH_LONGNAME}-linux-gnu/sysroot/usr/lib/librt.so \
      -DCUDA_TARGET_ARCHS=${CUDA_TARGET_ARCHS} \
      -DNVJPEG_ROOT_DIR=$CONDA_PREFIX/lib64/ \
      -DFFMPEG_ROOT_DIR=$CONDA_PREFIX \
      -DLIBSND_ROOT_DIR=$CONDA_PREFIX \
      -DJPEG_INCLUDE_DIR=$CONDA_PREFIX/libjpeg-turbo/lib64 \
      -DTIFF_INCLUDE_DIR=$PREFIX/lib \
      -DTIFF_LIBRARY=$PREFIX/lib/libtiff.so \
      -DJPEG_LIBRARY=$CONDA_PREFIX/libjpeg-turbo/lib64/libjpeg.so \
      -DCMAKE_INSTALL_PREFIX=$CONDA_PREFIX \
      -DCMAKE_PREFIX_PATH="$CONDA_PREFIX/libjpeg-turbo;$CONDA_PREFIX" \
      -DCUDA_CUDA_LIBRARY=$CONDA_PREFIX/lib/stubs/libcuda.so \
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-Release}     \
      -DBUILD_BENCHMARK=${BUILD_BENCHMARK:-ON}            \
      -DBUILD_NVTX=${BUILD_NVTX:-OFF}                     \
      -DBUILD_PYTHON=${BUILD_PYTHON:-ON}                  \
      -DBUILD_JPEG_TURBO=${BUILD_JPEG_TURBO:-ON}          \
      -DBUILD_NVJPEG=${BUILD_NVJPEG:-ON}                  \
      -DBUILD_LIBTIFF=${BUILD_LIBTIFF:-ON}                \
      -DBUILD_NVOF=${BUILD_NVOF:-ON}                      \
      -DBUILD_NVDEC=${BUILD_NVDEC:-ON}                    \
      -DBUILD_LIBSND=${BUILD_LIBSND:-ON}                  \
      -DBUILD_NVML=${BUILD_NVML:-ON}                      \
      -DBUILD_FFTS=${BUILD_FFTS:-ON}                      \
      -DVERBOSE_LOGS=${VERBOSE_LOGS:-OFF}                 \
      -DWERROR=${WERROR:-ON}                              \
      -DBUILD_WITH_ASAN=${BUILD_WITH_ASAN:-OFF}           \
      -DDALI_BUILD_FLAVOR=${NVIDIA_DALI_BUILD_FLAVOR}     \
      ..

make -j"$(nproc --all)" install

export PYTHONUSERBASE=$PREFIX


pip install --user dali/python
# Copy tensorflow plugin build script to working directory
cp $RECIPE_DIR/build_dali_tf.sh $SRC_DIR/dali_tf_plugin/build_dali_tf.sh

# Build tensorflow plugin
export LD_LIBRARY_PATH="$PWD/dali/python/nvidia/dali/:$PREFIX/lib:$LD_LIBRARY_PATH"
DALI_PATH=$PREFIX/lib/python${PY_VER}/site-packages/nvidia/dali

echo "DALI_PATH is ${DALI_PATH}"
pushd $SRC_DIR/dali_tf_plugin/
source ./build_dali_tf.sh $DALI_PATH/plugin/libdali_tf_current.so
popd

cp $SRC_DIR/build/dali/python/nvidia/dali/*.so $PREFIX/lib
cp $DALI_PATH/plugin/*.so $PREFIX/lib

# Move tfrecord2idx to host env so it can be found at runtime
cp $SRC_DIR/tools/tfrecord2idx $PREFIX/bin

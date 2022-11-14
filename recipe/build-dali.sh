#!/bin/bash
# *****************************************************************
# (C) Copyright IBM Corp. 2019, 2022. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************

# Determine Architecture

ARCH="$(arch)"
if [ ${ARCH} = "x86_64" ]; then
    ARCH_LONGNAME="x86_64-conda"
elif [ ${ARCH} = "ppc64le" ]; then
    ARCH_LONGNAME="powerpc64le-conda"
else
    echo "Error: Unsupported Architecture. Expected: [x86_64|ppc64le] Actual: ${ARCH}"
    exit 1
fi

# Create 'gcc' symlink so nvcc can find it
ln -s $CONDA_PREFIX/bin/${ARCH_LONGNAME}-linux-gnu-gcc $CONDA_PREFIX/bin/gcc
ln -s $CONDA_PREFIX/bin/${ARCH_LONGNAME}-linux-gnu-g++ $CONDA_PREFIX/bin/g++

# Force -std=c++14 in CXXFLAGS
export CXXFLAGS=${CXXFLAGS/-std=c++??/-std=c++14}

PYTHON_INCLUDE_DIR="$PREFIX/include/python${PY_VER}"
if [[ $PY_VER < '3.8' ]]; then
    PYTHON_INCLUDE_DIR+="m"
fi

# Add libjpeg-turbo location to front of CXXFLAGS so it is used instead of jpeg
export CXXFLAGS="-I$CONDA_PREFIX/libjpeg-turbo/include -I${PYTHON_INCLUDE_DIR} ${CXXFLAGS} -DNO_ALIGNED_ALLOC -Wno-error=free-nonheap-object -Wno-error=maybe-uninitialized -fplt"

# Create build directory for cmake and enter it
mkdir $SRC_DIR/build
cd $SRC_DIR/build
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
      -DJPEG_INCLUDE_DIR=$PREFIX/include \
      -DTIFF_INCLUDE_DIR=$PREFIX/lib \
      -DTIFF_LIBRARY=$PREFIX/lib/libtiff.so \
      -DJPEG_LIBRARY=$PREFIX/lib/libjpeg.so \
      -DCMAKE_INSTALL_PREFIX=$CONDA_PREFIX \
      -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
      -DCUDA_CUDA_LIBRARY=$CONDA_PREFIX/lib/stubs/libcuda.so \
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-Release}     \
      -DBUILD_BENCHMARK=${BUILD_BENCHMARK:-ON}            \
      -DBUILD_NVTX=${BUILD_NVTX:-OFF}                     \
      -DBUILD_PYTHON=${BUILD_PYTHON:-ON}                  \
      -DBUILD_JPEG_TURBO=${BUILD_JPEG_TURBO:-ON}          \
      -DBUILD_NVJPEG=${BUILD_NVJPEG:-ON}                  \
      -DBUILD_OPENCV=${BUILD_OPENCV:-ON}                  \
      -DBUILD_PROTOBUF=${BUILD_PROTOBUF:-ON}              \
      -DBUILD_NVJPEG2K=${BUILD_NVJPEG2K}                  \
      -DBUILD_LIBTIFF=${BUILD_LIBTIFF:-ON}                \
      -DBUILD_NVOF=${BUILD_NVOF:-ON}                      \
      -DBUILD_NVDEC=${BUILD_NVDEC:-ON}                    \
      -DBUILD_LIBSND=${BUILD_LIBSND:-ON}                  \
      -DBUILD_NVML=${BUILD_NVML:-ON}                      \
      -DBUILD_FFTS=${BUILD_FFTS:-ON}                      \
      -DVERBOSE_LOGS=${VERBOSE_LOGS:-OFF}                 \
      -DWERROR=${WERROR:-ON}                              \
      -DBUILD_WITH_ASAN=${BUILD_WITH_ASAN:-OFF}           \
      -DBUILD_LIBTAR=${BUILD_LIBTAR:-ON}                  \
      -DLIBTAR_ROOT_DIR=$CONDA_PREFIX                     \
      -DDALI_BUILD_FLAVOR=${NVIDIA_DALI_BUILD_FLAVOR}     \
      -DTIMESTAMP=${DALI_TIMESTAMP} -DGIT_SHA=${GIT_SHA-${GIT_FULL_HASH}} \
      ..

make -j"$(nproc --all)" install

export PYTHONUSERBASE=$PREFIX

# set RPATH of backend_impl.so and similar to $ORIGIN, $ORIGIN$UPDIRS, $ORIGIN$UPDIRS/.libs
PKGNAME_PATH=$PWD/dali/python/nvidia/dali
find $PKGNAME_PATH -type f -name "*.so*" -o -name "*.bin" | while read FILE; do
    UPDIRS=$(dirname $(echo "$FILE" | sed "s|$PKGNAME_PATH||") | sed 's/[^\/][^\/]*/../g')
    echo "Setting rpath of $FILE to '\$ORIGIN:\$ORIGIN$UPDIRS:\$ORIGIN$UPDIRS/.libs'"
    patchelf --set-rpath "\$ORIGIN:\$ORIGIN$UPDIRS:\$ORIGIN$UPDIRS/.libs" $FILE
    patchelf --print-rpath $FILE
done


$PYTHON -m pip install --no-deps --ignore-installed --user dali/python

# Install the activate / deactivate scripts that set environment variables
mkdir -p "${PREFIX}"/etc/conda/activate.d
mkdir -p "${PREFIX}"/etc/conda/deactivate.d
cp "${RECIPE_DIR}"/../scripts/activate.sh "${PREFIX}"/etc/conda/activate.d/activate-${PKG_NAME}.sh
cp "${RECIPE_DIR}"/../scripts/deactivate.sh "${PREFIX}"/etc/conda/deactivate.d/deactivate-${PKG_NAME}.sh

# Move tfrecord2idx to host env so it can be found at runtime
cp $SRC_DIR/tools/tfrecord2idx $PREFIX/bin

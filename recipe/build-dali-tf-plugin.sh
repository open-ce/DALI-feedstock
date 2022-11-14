#!/bin/bash
# *****************************************************************
# (C) Copyright IBM Corp. 2019, 2021. All Rights Reserved.
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

# Force -std=c++14 in CXXFLAGS
export CXXFLAGS=${CXXFLAGS/-std=c++??/-std=c++14}

PYTHON_INCLUDE_DIR="$PREFIX/include/python${PY_VER}"
if [[ $PY_VER < '3.8' ]]; then
    PYTHON_INCLUDE_DIR+="m"
fi

# Add libjpeg-turbo location to front of CXXFLAGS so it is used instead of jpeg
export CXXFLAGS="-I$PREFIX/include -I${PYTHON_INCLUDE_DIR} ${CXXFLAGS} -DNO_ALIGNED_ALLOC"

export PYTHONUSERBASE=$PREFIX

#$PYTHON -m pip install --no-deps --ignore-installed --user dali/python

# Build tensorflow plugin
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
DALI_PATH=$($PYTHON -c 'import nvidia.dali as dali; import os; print(os.path.dirname(dali.__file__))')
echo "DALI_PATH is ${DALI_PATH}"
pushd $SRC_DIR/dali_tf_plugin/
mkdir -p dali_tf_sdist_build
cd dali_tf_sdist_build

CUDA_VERSION="${cudatoolkit}"

cmake .. \
      -DCUDA_VERSION:STRING="${CUDA_VERSION}" \
      -DDALI_BUILD_FLAVOR=${NVIDIA_DALI_BUILD_FLAVOR} \
      -DTIMESTAMP=${DALI_TIMESTAMP} \
      -DGIT_SHA=${GIT_SHA}
make -j install
$PYTHON -m pip install --no-deps --ignore-installed .
popd

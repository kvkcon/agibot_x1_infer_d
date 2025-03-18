# 使用CUDA 11.8开发镜像（包含完整工具链）
FROM nvidia/cuda:11.8.0-devel-ubuntu22.04
# 将基础镜像升级为CUDA 12.x版本
# FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

# 设置非交互式安装环境
ENV DEBIAN_FRONTEND=noninteractive

# 安装匹配CUDA 11.8的cuDNN
RUN apt-get update && apt-get install -y \
    libcudnn8=8.6.0.*-1+cuda11.8 \
    libcudnn8-dev=8.6.0.*-1+cuda11.8

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    libprotobuf-dev \
    protobuf-compiler \
    software-properties-common \
    lsb-release \
    gnupg2 \
    libssl-dev \
    jstest-gtk \
    x11-apps \
    mesa-utils \
    && rm -rf /var/lib/apt/lists/*

# 安装 ROS2 Humble
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null
RUN apt-get update && apt-get install -y \
    ros-humble-desktop \
    ros-humble-gazebo-ros-pkgs \
    ros-humble-gazebo-ros2-control \
    ros-humble-joint-state-publisher \
    python3-colcon-common-extensions \
    && rm -rf /var/lib/apt/lists/*

# Install latest CMake (Add this after system dependencies installation)
RUN apt-get update && apt-get install -y ninja-build && \
    wget https://github.com/Kitware/CMake/releases/download/v3.28.3/cmake-3.28.3-linux-x86_64.sh && \
    sh cmake-3.28.3-linux-x86_64.sh --prefix=/usr/local --exclude-subdir && \
    rm cmake-3.28.3-linux-x86_64.sh

# 在构建ONNX Runtime前添加验证步骤
RUN ls -l /usr/local/cuda/bin/nvcc && \
    nvcc --version | grep "release 11.8" && \
    echo "CUDA Toolkit验证通过"

# 在 Dockerfile 中添加验证步骤
RUN ls -l /usr/local/cuda/lib64/libcudnn* && \
cat /usr/local/cuda/include/cudnn_version.h | grep CUDNN_MAJOR -A 2

# 构建ONNX Runtime
WORKDIR /root
RUN git clone --recursive https://github.com/microsoft/onnxruntime
RUN cd onnxruntime && \
    ./build.sh --config Release --build_shared_lib --parallel \
    --use_cuda --cuda_home /usr/local/cuda \
    --cudnn_home /usr/lib/x86_64-linux-gnu \
    --allow_running_as_root \
    --cmake_extra_defines "CUDAToolkit_ROOT=/usr/local/cuda"
# RUN cd onnxruntime && \
#     ./build.sh --config Release --update --build --parallel \
#     --build_shared_lib --use_cuda \
#     --allow_running_as_root \
#     --cuda_home /usr/local/cuda \
#     --cudnn_home /usr \
#     --cmake_extra_defines CUDNN_INCLUDE_DIR=/usr/include \
#     CUDNN_LIBRARY=/usr/lib/x86_64-linux-gnu

# 安装ONNX Runtime
RUN cd onnxruntime/build/Linux/Release && \
    make install

# 设置工作目录并复制项目代码
WORKDIR /workspace
COPY . /workspace/agibot_x1_infer_d

# 构建项目（示例）
RUN cd agibot_x1_infer_d && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc)

# 配置环境变量
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV ROS_DOMAIN_ID=42

# 初始化 ROS 环境
RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc
SHELL ["/bin/bash", "-c"]

CMD ["bash"]

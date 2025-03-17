# 使用 NVIDIA CUDA 基础镜像
FROM nvidia/cuda:11.8.0-base-ubuntu22.04

# 设置非交互式安装环境
ENV DEBIAN_FRONTEND=noninteractive

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
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

# 构建ONNX Runtime
WORKDIR /root
RUN git clone --recursive https://github.com/microsoft/onnxruntime
RUN cd onnxruntime && \
    ./build.sh --config Release --build_shared_lib --parallel --use_cuda --cuda_home /usr/local/cuda --cudnn_home /usr/lib/x86_64-linux-gnu

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

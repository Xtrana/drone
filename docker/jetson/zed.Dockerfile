
# NOTE: install pycuda and norfair in the container. 
# pip3 install pycuda==2023.1
# and pip3 install norfair


ARG IMAGE_NAME=dustynv/ros:humble-ros-base-l4t-r35.4.1
# CHANGE THE L4T version to 35.4.1 and jetpack version to 5.12
FROM ${IMAGE_NAME}

ARG ZED_SDK_MAJOR=4
ARG ZED_SDK_MINOR=0
ARG ZED_SDK_PATCH=7
ARG JETPACK_MAJOR=5
ARG JETPACK_MINOR=12
ARG L4T_MAJOR=35
ARG L4T_MINOR=4
ARG ROS2_DIST=humble       # ROS2 distribution

# ZED ROS2 Wrapper dependencies version
ARG XACRO_VERSION=2.0.8
ARG DIAGNOSTICS_VERSION=3.0.0
ARG AMENT_LINT_VERSION=0.12.4
ARG GEOGRAPHIC_INFO_VERSION=1.0.4
ARG ROBOT_LOCALIZATION_VERSION=3.4.2
ENV DEBIAN_FRONTEND noninteractive

# Disable apt-get warnings
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 42D5A192B819C5DA || true && \
  apt-get update || true && apt-get install -y --no-install-recommends apt-utils dialog && \
  rm -rf /var/lib/apt/lists/*
  
ENV TZ=Europe/Paris

RUN apt-get update && apt-get upgrade -y

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \ 
  apt-get update && \
  apt-get install --yes lsb-release wget less udev sudo build-essential cmake python3 python3-dev python3-pip python3-wheel git jq libpq-dev zstd usbutils && \    
  rm -rf /var/lib/apt/lists/*

# Install the ZED SDK
RUN echo "# R${L4T_MAJOR} (release), REVISION: ${L4T_MINOR}" > /etc/nv_tegra_release && \
  apt-get update -y || true && \
  apt-get install -y --no-install-recommends zstd wget less cmake curl gnupg2 \
  build-essential python3 python3-pip python3-dev python3-setuptools libusb-1.0-0-dev -y && \
  pip install protobuf && \
  wget -q --no-check-certificate -O ZED_SDK_Linux_JP.run \
  https://download.stereolabs.com/zedsdk/${ZED_SDK_MAJOR}.${ZED_SDK_MINOR}/l4t${L4T_MAJOR}.${L4T_MINOR}/jetsons && \
  chmod +x ZED_SDK_Linux_JP.run ; ./ZED_SDK_Linux_JP.run silent skip_tools && \
  rm -rf /usr/local/zed/resources/* && \
  rm -rf ZED_SDK_Linux_JP.run && \
  rm -rf /var/lib/apt/lists/*

# Install the ZED ROS2 Wrapper
ENV ROS_DISTRO ${ROS2_DIST}

# Install the ZED ROS2 Wrapper
WORKDIR /root/ros2_ws/src
RUN git clone --recursive https://github.com/stereolabs/zed-ros2-wrapper.git

# Install missing dependencies
WORKDIR /root/ros2_ws/src
RUN wget https://github.com/ros/xacro/archive/refs/tags/${XACRO_VERSION}.tar.gz -O - | tar -xvz && mv xacro-${XACRO_VERSION} xacro && \
  wget https://github.com/ros/diagnostics/archive/refs/tags/${DIAGNOSTICS_VERSION}.tar.gz -O - | tar -xvz && mv diagnostics-${DIAGNOSTICS_VERSION} diagnostics && \
  wget https://github.com/ament/ament_lint/archive/refs/tags/${AMENT_LINT_VERSION}.tar.gz -O - | tar -xvz && mv ament_lint-${AMENT_LINT_VERSION} ament-lint && \
  wget https://github.com/cra-ros-pkg/robot_localization/archive/refs/tags/${ROBOT_LOCALIZATION_VERSION}.tar.gz -O - | tar -xvz && mv robot_localization-${ROBOT_LOCALIZATION_VERSION} robot-localization && \
  wget https://github.com/ros-geographic-info/geographic_info/archive/refs/tags/${GEOGRAPHIC_INFO_VERSION}.tar.gz -O - | tar -xvz && mv geographic_info-${GEOGRAPHIC_INFO_VERSION} geographic-info && \
  cp -r geographic-info/geographic_msgs/ . && \
  rm -rf geographic-info && \
  git clone https://github.com/ros-drivers/nmea_msgs.git --branch ros2 && \  
  git clone https://github.com/ros/angles.git --branch humble-devel

# Check that all the dependencies are satisfied
WORKDIR /root/ros2_ws
RUN apt-get update -y || true && rosdep update && \
  rosdep install --from-paths src --ignore-src -r -y && \
  rm -rf /var/lib/apt/lists/*

# Install cython
RUN python3 -m pip install --upgrade cython

# Build the dependencies and the ZED ROS2 Wrapper
RUN /bin/bash -c "source /opt/ros/$ROS_DISTRO/install/setup.bash && \
  colcon build --parallel-workers $(nproc) \
  --event-handlers console_direct+ --base-paths src \
  --cmake-args ' -DCMAKE_BUILD_TYPE=Release' \
  ' -DCMAKE_LIBRARY_PATH=/usr/local/cuda/lib64/stubs' \
  ' -DCMAKE_CXX_FLAGS="-Wl,--allow-shlib-undefined"' \
  ' --no-warn-unused-cli' "

# install some deps
RUN pip install transforms3d setuptools==58.2.0

# copy the package
COPY drone_vision_pkg /root/ros2_ws/src/drone_pkg

WORKDIR /root/ros2_ws/
# build drone_pkg
RUN /bin/bash -c "source /opt/ros/$ROS_DISTRO/install/setup.bash && \
    colcon build --packages-select drone_pkg"

# Check that all the dependencies are satisfied
WORKDIR /root/ros2_ws
RUN apt-get update -y || true && rosdep update && \
  rosdep install --from-paths src --ignore-src -r -y && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /root/ros2_ws

# Setup environment variables
COPY ros_entrypoint_jetson.sh /sbin/ros_entrypoint.sh
RUN sudo chmod 755 /sbin/ros_entrypoint.sh

ENTRYPOINT ["/sbin/ros_entrypoint.sh"]
CMD ["bash"]


# docker run --runtime nvidia -it --privileged --ipc=host --pid=host -e NVIDIA_DRIVER_CAPABILITIES=all -e DISPLAY \
#-v /dev:/dev -v /tmp/.X11-unix/:/tmp/.X11-unix \
# -v ${HOME}/zed_docker_ai/:/usr/local/zed/resources/ \
#  dev:trt_zed2


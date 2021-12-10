ARG ROS_DISTRO=noetic

FROM ros:${ROS_DISTRO}-ros-core AS build-env
ENV DEBIAN_FRONTEND=noninteractive \
    BUILD_HOME=/var/lib/build \
    IL_SDK_PATH=/opt/inertiallabs_ins

RUN set -xue \
# Kinetic and melodic have python3 packages but they seem to conflict
&& [ $ROS_DISTRO = "noetic" ] && PY=python3 || PY=python \
# Turn off installing extra packages globally to slim down rosdep install
&& echo 'APT::Install-Recommends "0";' > /etc/apt/apt.conf.d/01norecommend \
&& apt-get update \
&& apt-get install -y \
 build-essential cmake \
 fakeroot dpkg-dev debhelper \
 $PY-rosdep $PY-rospkg $PY-bloom \
 ros-${ROS_DISTRO}-gps-umd rospack-tools git

# Set up non-root build user
ARG BUILD_UID=1000
ARG BUILD_GID=${BUILD_UID}

RUN set -xe \
&& groupadd -o -g ${BUILD_GID} build \
&& useradd -o -u ${BUILD_UID} -d ${BUILD_HOME} -rm -s /bin/bash -g build build

# Install build dependencies using rosdep
COPY --chown=build:build inertiallabs_msgs/package.xml ${IL_SDK_PATH}/inertiallabs_msgs/package.xml

RUN set -xe \
&& apt-get update \
&& rosdep init \
&& rosdep update --rosdistro=${ROS_DISTRO} \
&& rosdep install -y --from-paths ${IL_SDK_PATH}

RUN sudo git clone --depth 1 https://github.com/vishnubob/wait-for-it.git ~/.base-image/wait-for-it && \
    sudo mv ~/.base-image/wait-for-it/wait-for-it.sh /usr/bin

# Set up build environment
COPY --chown=build:build inertiallabs_msgs ${IL_SDK_PATH}/inertiallabs_msgs
COPY --chown=build:build inertiallabs_sdk ${IL_SDK_PATH}/inertiallabs_sdk
COPY --chown=build:build inertiallabs_ins ${IL_SDK_PATH}/inertiallabs_ins
COPY --chown=build:build cav_msgs ${IL_SDK_PATH}/cav_msgs

USER build:build
WORKDIR ${BUILD_HOME}

RUN set -xe \
&& mkdir src \
&& ln -s ${IL_SDK_PATH} ./src

FROM build-env

RUN /opt/ros/${ROS_DISTRO}/env.sh catkin_make -DCMAKE_BUILD_TYPE=Release

# Entrypoint for running Inertial Labs ROS:
CMD ["bash", "-c", "set -e \
&& . ./devel/setup.bash \
&& rosrun inertiallabs_ins il_ins \"$@\" \
", "ros-entrypoint"]